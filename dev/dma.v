// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// DMA engine peripheral.

// Memory operations to configure and initiate a copy go through
// the slave memory interface; the copy is performed through
// the master memory interface.

// Memory operations done through the slave memory interface
// in order to configure the DMA engine channels and initiate
// a copy must be ARCHBITSZ, otherwise undefined behavior
// will be the result.

// Memory map for PIRWOP:
// When the byte offset is 0*(ARCHBITSZ/8), the readed value is the total number of channels.
// The written value select the channel to be configured by PIWROP.
// When the byte offset is 1*(ARCHBITSZ/8), the readed value is the channel byte amount left to copy.
// The written value, when not 0 or -1 is the channel byte amount to copy.
// Writing a value that is not 0 or -1 during the channel ongoing copy,
// increments the channel byte amount to copy by the new value written.
// Writing 0 terminates the channel ongoing copy if there was any.
// Writing -1 do not modify the channel amount to copy and is to be used
// to obtain the channel byte amount left to copy without modifying it.
//
// Memory map for PIWROP:
// Four ARCHBITSZ memory mapped registers are used
// to configure the DMA engine channel selected by PIRWOP:
// Byte offset 0*(ARCHBITSZ/8)	| Dest start addr
// Byte offset 1*(ARCHBITSZ/8)	| Dest end   addr
// Byte offset 2*(ARCHBITSZ/8)	| Src  start addr
// Byte offset 3*(ARCHBITSZ/8)	| Src  end   addr
//
// PIRDOP is ignored.

// A channel starts copying when its byte amount left to copy is not 0.

// During the copy, the source and destination addresses, wrap around
// in their respective range until the byte amount left to copy reach 0.

// During the copy, 64bits, 32bits, 16bits or 8bits memory accesses are done
// depending on the alignment of the source and destination addresses; hence
// the fastest copy occurs when addresses are aligned to ARCHBITSZ.

// An interrupt is raised when the byte amount left to copy of a channel reaches 0.
// Note that when an interrupt-acknowledge occurs, it is only for the channels
// that raised an interrupt at the time of the acknowledge; if after the acknowledge,
// and while processing the interrupt, another channel raises an interrupt, the processing
// of that interrupt should be ignored if the channel had already been processed.

// The source and destination ranges can overlap only if they have the same size
// and the destination region is at a lower address than the source region.

// Parameters:
//
// CHANNELCNT:
// 	Number of DMA channels.
// 	It must be non-null.

// Ports:
//
// rst_i
// 	This input reset this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// m_pi1_op_o
// m_pi1_addr_o
// m_pi1_data_o
// m_pi1_data_i
// m_pi1_sel_o
// m_pi1_rdy_i
// 	PerInt master memory interface.
//
// s_pi1_op_i
// s_pi1_addr_i
// s_pi1_data_i
// s_pi1_data_o
// s_pi1_sel_i
// s_pi1_rdy_o
// s_pi1_mapsz_o
// 	PerInt slave memory interface.
//
// wait_i
// 	When this signal is high, the DMA engine completes
// 	the ongoing memory operation and wait until this signal
// 	becomes low to resume the copy.
// 	It should be set to the signal "|op" of one or more competing
// 	master devices so as to detect when they need to be served.
// 	by the interconnect.
// 	It makes the DMA engine issue PINOOP during a copy, so that
// 	the interconnect can serve other devices; in fact, the interconnect
// 	will not allow any other device to access memory until the device
// 	currently using memory issue a PINOOP.
// 	Hence this input signal allows the DMA engine to copy data
// 	without stalling other competing master devices.
//
// intrqst_o
// 	This signal is set high to request an interrupt;
// 	an interrupt is raised when the byte amount left
// 	to copy reaches 0.
//
// intrdy_i
// 	This signal become low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to automatically lower intrqst_o.

module dma (

	rst_i,

	clk_i,

	m_pi1_op_o,
	m_pi1_addr_o,
	m_pi1_data_i,
	m_pi1_data_o,
	m_pi1_sel_o,
	m_pi1_rdy_i,

	s_pi1_op_i,
	s_pi1_addr_i,
	s_pi1_data_i,
	s_pi1_data_o,
	s_pi1_sel_i,
	s_pi1_rdy_o,
	s_pi1_mapsz_o,

	wait_i,

	intrqst_o,
	intrdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter CHANNELCNT = 1;

localparam CLOG2CHANNELCNT = clog2(CHANNELCNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

output reg  [2 -1 : 0]             m_pi1_op_o;
output reg  [ADDRBITSZ -1 : 0]     m_pi1_addr_o;
output reg  [ARCHBITSZ -1 : 0]     m_pi1_data_o;
input  wire [ARCHBITSZ -1 : 0]     m_pi1_data_i;
output reg  [(ARCHBITSZ/8) -1 : 0] m_pi1_sel_o;
input  wire                        m_pi1_rdy_i;

input  wire [2 -1 : 0]             s_pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     s_pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     s_pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     s_pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] s_pi1_sel_i;  /* not used */
output wire                        s_pi1_rdy_o;
output wire [ARCHBITSZ -1 : 0]     s_pi1_mapsz_o;

input wire wait_i;

output wire intrqst_o;
input  wire intrdy_i;

assign s_pi1_mapsz_o = (4*(ARCHBITSZ/8));

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

// Commands.
localparam CMDCHANSEL = 0;
localparam CMDSETXFER = 1;
localparam CMDSETBTSZ = 2; // TODO: Set maximum bit size transfer ...

// Registers set by PIWROP through the slave memory interface
// in order to configure the DMA engine.
reg [ARCHBITSZ -1 : 0] srcstartaddr [CHANNELCNT -1 : 0];
reg [ARCHBITSZ -1 : 0] srcendaddr   [CHANNELCNT -1 : 0];
reg [ARCHBITSZ -1 : 0] dststartaddr [CHANNELCNT -1 : 0];
reg [ARCHBITSZ -1 : 0] dstendaddr   [CHANNELCNT -1 : 0];

// Registers which hold the current addresses within
// the source and destination ranges respectively.
reg [ARCHBITSZ -1 : 0] srccuraddr [CHANNELCNT -1 : 0];
reg [ARCHBITSZ -1 : 0] dstcuraddr [CHANNELCNT -1 : 0];

// Registers which hold channel indexes.
// curchannel is used to index the channel
// which will drive the master memory interface.
// selchannel is used to index the channel
// to configure through the slave memory interface.
reg [CLOG2CHANNELCNT -1 : 0] curchannel;
reg [CLOG2CHANNELCNT -1 : 0] selchannel;

wire [ARCHBITSZ -1 : 0] srcstartaddr_curchannel = srcstartaddr[curchannel];
wire [ARCHBITSZ -1 : 0] dststartaddr_curchannel = dststartaddr[curchannel];

localparam ARCHBITSZMAX = 256;
wire [ARCHBITSZMAX -1 : 0] srccuraddr_curchannel = srccuraddr[curchannel];
wire [ARCHBITSZMAX -1 : 0] dstcuraddr_curchannel = dstcuraddr[curchannel];

wire [ARCHBITSZ -1 : 0] srcendaddr_curchannel = srcendaddr[curchannel];
wire [ARCHBITSZ -1 : 0] dstendaddr_curchannel = dstendaddr[curchannel];

// Nets computing the range left within
// the source and destination ranges respectively.
wire [ARCHBITSZ -1 : 0] srcbytesleft = ((srcendaddr_curchannel - srccuraddr_curchannel) + 1);
wire [ARCHBITSZ -1 : 0] dstbytesleft = ((dstendaddr_curchannel - dstcuraddr_curchannel) + 1);

// Register which hold the byte amount left to copy.
reg [ARCHBITSZ -1 : 0] bytesleft [CHANNELCNT -1 : 0];

wire [ARCHBITSZ -1 : 0] bytesleft_curchannel = bytesleft[curchannel];
wire [ARCHBITSZ -1 : 0] bytesleft_selchannel = bytesleft[selchannel];

// DMA engine states.
localparam STATESTANDBY  = 0;
localparam STATEDO8BITS  = 1;
localparam STATEDO16BITS = 2;
localparam STATEDO32BITS = 3;
localparam STATEDO64BITS = 4;
localparam STATEMAXVALUE = 5;

// Register which holds the DMA engine state.
reg [clog2(STATEMAXVALUE) -1 : 0] state;

assign s_pi1_rdy_o = (state == STATESTANDBY);

reg [CHANNELCNT -1 : 0] intrqst_o_en;

wire [CHANNELCNT -1 : 0] intrqst_o_;
assign intrqst_o = |intrqst_o_;

genvar gen_intrqst_o_idx;
generate for (gen_intrqst_o_idx = 0; gen_intrqst_o_idx < CHANNELCNT; gen_intrqst_o_idx = gen_intrqst_o_idx + 1) begin :gen_intrqst_o
// An interrupt for a channel is raised when the byte amount left to copy reaches 0.
assign intrqst_o_[gen_intrqst_o_idx] = (!bytesleft[gen_intrqst_o_idx] && intrqst_o_en[gen_intrqst_o_idx]);
end endgenerate

// Register used to detect a falling edge on "intrdy_i".
reg intrdy_i_sampled;
wire intrdy_i_negedge = (!intrdy_i && intrdy_i_sampled);

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);

// ### Nets declared as reg so as to be useable by verilog within the always block.
reg [(CLOG2ARCHBITSZBY8 +1) -3 : 0] dstselidx32bits;
reg [(CLOG2ARCHBITSZBY8 +1) -3 : 0] srcselidx32bits;
reg [CLOG2ARCHBITSZ -1 : 0]         rightshiftamountforstatedo32bits;
reg [CLOG2ARCHBITSZ -1 : 0]         leftshiftamountforstatedo32bits;
reg [ARCHBITSZ -1 : 0]              m_pi1_data_o_forstatedo32bits;
reg [(CLOG2ARCHBITSZBY8 +1) -2 : 0] dstselidx16bits;
reg [(CLOG2ARCHBITSZBY8 +1) -2 : 0] srcselidx16bits;
reg [CLOG2ARCHBITSZ -1 : 0]         rightshiftamountforstatedo16bits;
reg [CLOG2ARCHBITSZ -1 : 0]         leftshiftamountforstatedo16bits;
reg [ARCHBITSZ -1 : 0]              m_pi1_data_o_forstatedo16bits;
always @* begin
	if (ARCHBITSZ > 32) begin
		dstselidx32bits                  = dstcuraddr_curchannel[clog2(64/8) -1 : 2];
		srcselidx32bits                  = srccuraddr_curchannel[clog2(64/8) -1 : 2];
		rightshiftamountforstatedo32bits = ({{CLOG2ARCHBITSZ{1'b0}}, srcselidx32bits} << 5);
		leftshiftamountforstatedo32bits  = ({{CLOG2ARCHBITSZ{1'b0}}, dstselidx32bits} << 5);
		m_pi1_data_o_forstatedo32bits    = (m_pi1_data_i >> rightshiftamountforstatedo32bits) << leftshiftamountforstatedo32bits;
	end else begin
		dstselidx32bits                  = 0;
		srcselidx32bits                  = 0;
		rightshiftamountforstatedo32bits = 0;
		leftshiftamountforstatedo32bits  = 0;
		m_pi1_data_o_forstatedo32bits    = m_pi1_data_i;
	end
	if (ARCHBITSZ > 16) begin
		dstselidx16bits                  = dstcuraddr_curchannel[clog2(32/8) -1 : 1];
		srcselidx16bits                  = srccuraddr_curchannel[clog2(32/8) -1 : 1];
		rightshiftamountforstatedo16bits = ({{CLOG2ARCHBITSZ{1'b0}}, srcselidx16bits} << 4);
		leftshiftamountforstatedo16bits  = ({{CLOG2ARCHBITSZ{1'b0}}, dstselidx16bits} << 4);
		m_pi1_data_o_forstatedo16bits    = (m_pi1_data_i >> rightshiftamountforstatedo16bits) << leftshiftamountforstatedo16bits;
	end else begin
		dstselidx16bits                  = 0;
		srcselidx16bits                  = 0;
		rightshiftamountforstatedo16bits = 0;
		leftshiftamountforstatedo16bits  = 0;
		m_pi1_data_o_forstatedo16bits    = m_pi1_data_i;
	end
end
wire [(CLOG2ARCHBITSZBY8 +1) -1 : 0] dstselidx8bits                  = dstcuraddr_curchannel[CLOG2ARCHBITSZBY8 -1 : 0];
wire [(CLOG2ARCHBITSZBY8 +1) -1 : 0] srcselidx8bits                  = srccuraddr_curchannel[CLOG2ARCHBITSZBY8 -1 : 0];
wire [CLOG2ARCHBITSZ -1 : 0]         rightshiftamountforstatedo8bits = ({{CLOG2ARCHBITSZ{1'b0}}, srcselidx8bits} << 3);
wire [CLOG2ARCHBITSZ -1 : 0]         leftshiftamountforstatedo8bits  = ({{CLOG2ARCHBITSZ{1'b0}}, dstselidx8bits} << 3);
wire [ARCHBITSZ -1 : 0]              m_pi1_data_o_forstatedo8bits    = (m_pi1_data_i >> rightshiftamountforstatedo8bits) << leftshiftamountforstatedo8bits;

reg [2 -1 : 0] prev_m_pi1_op_o;

integer rst_bytesleft_idx;
integer gen_intrqst_o_en_idx;
always @(posedge clk_i) begin

	if (rst_i) begin

		m_pi1_op_o <= PINOOP;

		for (rst_bytesleft_idx = 0; rst_bytesleft_idx < CHANNELCNT; rst_bytesleft_idx = rst_bytesleft_idx + 1)
			bytesleft[rst_bytesleft_idx] <= 0;

		state <= STATESTANDBY;

	end else if (ARCHBITSZ > 32 && state == STATEDO64BITS) begin

		if (m_pi1_rdy_i) begin

			m_pi1_op_o <= PIWROP;
			m_pi1_addr_o <= dstcuraddr_curchannel[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			m_pi1_data_o <= m_pi1_data_i;
			m_pi1_sel_o <= 8'b11111111;

			if (srccuraddr_curchannel == srcendaddr_curchannel)
				srccuraddr[curchannel] <= srcstartaddr_curchannel;
			else
				srccuraddr[curchannel] <= srccuraddr_curchannel + 8;

			if (dstcuraddr_curchannel == dstendaddr_curchannel)
				dstcuraddr[curchannel] <= dststartaddr_curchannel;
			else
				dstcuraddr[curchannel] <= dstcuraddr_curchannel + 8;

			bytesleft[curchannel] <= bytesleft_curchannel - 8;

			state <= STATESTANDBY;
		end

	end else if (ARCHBITSZ > 16 && state == STATEDO32BITS) begin

		if (m_pi1_rdy_i) begin

			m_pi1_op_o <= PIWROP;
			m_pi1_addr_o <= dstcuraddr_curchannel[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			m_pi1_data_o <= m_pi1_data_o_forstatedo32bits;
			m_pi1_sel_o <= ({{(ARCHBITSZ/8){1'b0}}, 4'b1111} << {dstselidx32bits, 2'b00});

			if (srccuraddr_curchannel == srcendaddr_curchannel)
				srccuraddr[curchannel] <= srcstartaddr_curchannel;
			else
				srccuraddr[curchannel] <= srccuraddr_curchannel + 4;

			if (dstcuraddr_curchannel == dstendaddr_curchannel)
				dstcuraddr[curchannel] <= dststartaddr_curchannel;
			else
				dstcuraddr[curchannel] <= dstcuraddr_curchannel + 4;

			bytesleft[curchannel] <= bytesleft_curchannel - 4;

			state <= STATESTANDBY;
		end

	end else if (state == STATEDO16BITS) begin

		if (m_pi1_rdy_i) begin

			m_pi1_op_o <= PIWROP;
			m_pi1_addr_o <= dstcuraddr_curchannel[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			m_pi1_data_o <= m_pi1_data_o_forstatedo16bits;
			m_pi1_sel_o <= ({{(ARCHBITSZ/8){1'b0}}, 2'b11} << {dstselidx16bits, 1'b0});

			if (srccuraddr_curchannel == srcendaddr_curchannel)
				srccuraddr[curchannel] <= srcstartaddr_curchannel;
			else
				srccuraddr[curchannel] <= srccuraddr_curchannel + 2;

			if (dstcuraddr_curchannel == dstendaddr_curchannel)
				dstcuraddr[curchannel] <= dststartaddr_curchannel;
			else
				dstcuraddr[curchannel] <= dstcuraddr_curchannel + 2;

			bytesleft[curchannel] <= bytesleft_curchannel - 2;

			state <= STATESTANDBY;
		end

	end else if (state == STATEDO8BITS) begin

		if (m_pi1_rdy_i) begin

			m_pi1_op_o <= PIWROP;
			m_pi1_addr_o <= dstcuraddr_curchannel[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			m_pi1_data_o <= m_pi1_data_o_forstatedo8bits;
			m_pi1_sel_o <= ({{(ARCHBITSZ/8){1'b0}}, 1'b1} << dstselidx8bits);

			if (srccuraddr_curchannel == srcendaddr_curchannel)
				srccuraddr[curchannel] <= srcstartaddr_curchannel;
			else
				srccuraddr[curchannel] <= srccuraddr_curchannel + 1;

			if (dstcuraddr_curchannel == dstendaddr_curchannel)
				dstcuraddr[curchannel] <= dststartaddr_curchannel;
			else
				dstcuraddr[curchannel] <= dstcuraddr_curchannel + 1;

			bytesleft[curchannel] <= bytesleft_curchannel - 1;

			state <= STATESTANDBY;
		end

	end else if (state == STATESTANDBY) begin

		if (s_pi1_op_i != PINOOP) begin

			if (m_pi1_rdy_i)
				m_pi1_op_o <= PINOOP;

			if (s_pi1_op_i == PIWROP) begin

				if (s_pi1_addr_i == 0) begin
					dststartaddr[selchannel] <= s_pi1_data_i;
					dstcuraddr  [selchannel] <= s_pi1_data_i;
				end

				if (s_pi1_addr_i == 1)
					dstendaddr[selchannel] <= s_pi1_data_i;

				if (s_pi1_addr_i == 2) begin
					srcstartaddr[selchannel] <= s_pi1_data_i;
					srccuraddr  [selchannel] <= s_pi1_data_i;
				end

				if (s_pi1_addr_i == 3)
					srcendaddr[selchannel] <= s_pi1_data_i;
			end

			if (s_pi1_op_i == PIRWOP) begin

				if (s_pi1_addr_i == CMDCHANSEL) begin

					selchannel <= s_pi1_data_i;

					s_pi1_data_o <= CHANNELCNT;

				end else if (s_pi1_addr_i == CMDSETXFER) begin

					if (s_pi1_data_i == 0)
						bytesleft[selchannel] <= 0;
					else if (s_pi1_data_i != -1)
						bytesleft[selchannel] <= bytesleft_selchannel + s_pi1_data_i;

					s_pi1_data_o <= bytesleft_selchannel;
				end
			end

		// The test (&& m_pi1_op_o != PIRDOP) is there to insure that PINOOP is issued
		// only after the previous PIWROP, because a wait is to occur only between complete
		// data transfer which starts with PIRDOP and finishes with PIWROP.
		end else if (wait_i && m_pi1_op_o != PIRDOP) begin

			if (m_pi1_rdy_i)
				m_pi1_op_o <= PINOOP;

		end else if (bytesleft_curchannel) begin

			if (m_pi1_rdy_i || prev_m_pi1_op_o == PINOOP) begin
				// Depending on the alignment of the source and destination addresses,
				// as well as the byte amount left to copy in the source and destination ranges,
				// a 64bits, 32bits, 16bits or 8bits memory access is done.
				if (ARCHBITSZ > 32 &&
					!srccuraddr_curchannel[2:0] && !dstcuraddr_curchannel[2:0] &&
					srcbytesleft >= 8 && dstbytesleft >= 8 &&
					bytesleft_curchannel >= 8) begin

					// Do a 64bits memory access.
					m_pi1_op_o <= PIRDOP;
					m_pi1_addr_o <= srccuraddr_curchannel[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					m_pi1_sel_o <= 8'b11111111;

					if (m_pi1_rdy_i && m_pi1_op_o == PIRDOP)
						state <= STATEDO64BITS;

				end else if (ARCHBITSZ > 16 &&
					!srccuraddr_curchannel[1:0] && !dstcuraddr_curchannel[1:0] &&
					srcbytesleft >= 4 && dstbytesleft >= 4 &&
					bytesleft_curchannel >= 4) begin

					// Do a 32bits memory access.
					m_pi1_op_o <= PIRDOP;
					m_pi1_addr_o <= srccuraddr_curchannel[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					m_pi1_sel_o <= ({{(ARCHBITSZ/8){1'b0}}, 4'b1111} << {srcselidx32bits, 2'b00});

					if (m_pi1_rdy_i && m_pi1_op_o == PIRDOP)
						state <= STATEDO32BITS;

				end else if (
					!srccuraddr_curchannel[0] && !dstcuraddr_curchannel[0] &&
					srcbytesleft >= 2 && dstbytesleft >= 2 &&
					bytesleft_curchannel >= 2) begin

					// Do a 16bits memory access.
					m_pi1_op_o <= PIRDOP;
					m_pi1_addr_o <= srccuraddr_curchannel[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					m_pi1_sel_o <= ({{(ARCHBITSZ/8){1'b0}}, 2'b11} << {srcselidx16bits, 1'b0});

					if (m_pi1_rdy_i && m_pi1_op_o == PIRDOP)
						state <= STATEDO16BITS;

				end else begin

					// Do an 8bits memory access.
					m_pi1_op_o <= PIRDOP;
					m_pi1_addr_o <= srccuraddr_curchannel[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					m_pi1_sel_o <= ({{(ARCHBITSZ/8){1'b0}}, 1'b1} << srcselidx8bits);

					if (m_pi1_rdy_i && m_pi1_op_o == PIRDOP)
						state <= STATEDO8BITS;
				end
			end

		end else if (m_pi1_rdy_i)
			m_pi1_op_o <= PINOOP;
	end

	if (rst_i)
		prev_m_pi1_op_o <= PINOOP;
	else if (m_pi1_rdy_i)
		prev_m_pi1_op_o <= m_pi1_op_o;

	// Logic that update curchannel.
	if (!bytesleft_curchannel ||
		((state == STATEDO64BITS || state == STATEDO32BITS || state == STATEDO16BITS || state == STATEDO8BITS) &&
			m_pi1_rdy_i)) begin
		if (curchannel < (CHANNELCNT - 1))
			curchannel <= curchannel + 1'd1;
		else
			curchannel <= 0;
	end

	// Sampling used for edge detection of the input intrdy_i.
	intrdy_i_sampled <= intrdy_i;

	for (gen_intrqst_o_en_idx = 0; gen_intrqst_o_en_idx < CHANNELCNT; gen_intrqst_o_en_idx = gen_intrqst_o_en_idx + 1) begin
		// Logic which set intrqst_o_en which is in turn used to compute the output intrqst_o .
		if (rst_i)
			intrqst_o_en[gen_intrqst_o_en_idx] <= 0;
		else if (intrqst_o_[gen_intrqst_o_en_idx]) begin
			if (intrdy_i_negedge)
				intrqst_o_en[gen_intrqst_o_en_idx] <= 0;
		end else if (s_pi1_rdy_o && selchannel == gen_intrqst_o_en_idx &&
			s_pi1_op_i == PIRWOP && s_pi1_addr_i == CMDSETXFER &&
				s_pi1_data_i && s_pi1_data_i != -1)
					intrqst_o_en[gen_intrqst_o_en_idx] <= 1;
	end
end

integer i;
initial begin
	m_pi1_op_o = PINOOP;
	m_pi1_addr_o = 0;
	m_pi1_data_o = 0;
	m_pi1_sel_o = 0;
	s_pi1_data_o = 0;
	curchannel = 0;
	selchannel = 0;
	for (i = 0; i < CHANNELCNT; i = i + 1) begin
		srcstartaddr[i] = 0;
		dststartaddr[i] = 0;
		srcendaddr[i] = 0;
		dstendaddr[i] = 0;
		srccuraddr[i] = 0;
		dstcuraddr[i] = 0;
		bytesleft[i] = 0;
		intrqst_o_en[i] = 0;
	end
	state = 0;
	intrdy_i_sampled = 0;
	prev_m_pi1_op_o = PINOOP;
end

endmodule
