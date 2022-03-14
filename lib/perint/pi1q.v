// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Implementation of PerIntQ which is used to isolate master
// devices from a slave device, at the expense of more clock cycles
// in order to move data across.
// The isolation allows for the slave device to have its own clock
// for receiving memory operations from master devices; hence, a master
// and slave device can use different clocks.
// The slower clock between a master and slave should transition at
// the same time that the faster clock between a master and slave is
// transitioning; regardless of whether the transition of both clocks
// is in the same direction.
// All master devices must use the same clock to issue memory operations.

// Parameters:
//
// MASTERCOUNT
// 	Number of master devices.
// 	It must be greater than 1. ei: `define MASTERCOUNT 3
// 	However, inst.pi1q.v allows for PI1QMASTERCOUNT to be 1.
// 	The greater this number, the greater the minimum
// 	latency each master device will experience between
// 	memory operations.

`ifndef PI1Q_V
`define PI1Q_V

`include "lib/ram/dram.v"

module pi1q (

	 rst_i

	,m_clk_i
	,s_clk_i

	,m_op_i_flat
	,m_addr_i_flat
	,m_data_i_flat
	,m_data_o_flat
	,m_sel_i_flat
	,m_rdy_o_flat

	,s_op_o
	,s_addr_o
	,s_data_o
	,s_data_i
	,s_sel_o
	,s_rdy_i
);

`include "lib/clog2.v"

parameter MASTERCOUNT = 2;

parameter ARCHBITSZ = 16;

localparam CLOG2MASTERCOUNT = clog2(MASTERCOUNT);

localparam MASTERCOUNT_ = (1 << CLOG2MASTERCOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire m_clk_i;
input wire s_clk_i;

input  wire [(2 * MASTERCOUNT) -1 : 0]             m_op_i_flat;
input  wire [(ADDRBITSZ * MASTERCOUNT) -1 : 0]     m_addr_i_flat;
input  wire [(ARCHBITSZ * MASTERCOUNT) -1 : 0]     m_data_i_flat;
output wire [(ARCHBITSZ * MASTERCOUNT) -1 : 0]     m_data_o_flat;
input  wire [((ARCHBITSZ/8) * MASTERCOUNT) -1 : 0] m_sel_i_flat;
output wire [MASTERCOUNT -1 : 0]                   m_rdy_o_flat;

output wire [2 -1 : 0]             s_op_o;
output wire [ADDRBITSZ -1 : 0]     s_addr_o;
output wire [ARCHBITSZ -1 : 0]     s_data_o;
input  wire [ARCHBITSZ -1 : 0]     s_data_i;
output wire [(ARCHBITSZ/8) -1 : 0] s_sel_o;
input  wire                        s_rdy_i;

wire [2 -1 : 0] masterop [MASTERCOUNT -1 : 0];
genvar gen_masterop_idx;
generate for (gen_masterop_idx = 0; gen_masterop_idx < MASTERCOUNT; gen_masterop_idx = gen_masterop_idx + 1) begin :gen_masterop
assign masterop[gen_masterop_idx] = m_op_i_flat[((gen_masterop_idx+1) * 2) -1 : gen_masterop_idx * 2];
end endgenerate

wire [ADDRBITSZ -1 : 0] masteraddr [MASTERCOUNT -1 : 0];
genvar gen_masteraddr_idx;
generate for (gen_masteraddr_idx = 0; gen_masteraddr_idx < MASTERCOUNT; gen_masteraddr_idx = gen_masteraddr_idx + 1) begin :gen_masteraddr
assign masteraddr[gen_masteraddr_idx] = m_addr_i_flat[((gen_masteraddr_idx+1) * ADDRBITSZ) -1 : gen_masteraddr_idx * ADDRBITSZ];
end endgenerate

wire [ARCHBITSZ -1 : 0] masterdati [MASTERCOUNT -1 : 0];
genvar gen_masterdati_idx;
generate for (gen_masterdati_idx = 0; gen_masterdati_idx < MASTERCOUNT; gen_masterdati_idx = gen_masterdati_idx + 1) begin :gen_masterdati
assign masterdati[gen_masterdati_idx] = m_data_i_flat[((gen_masterdati_idx+1) * ARCHBITSZ) -1 : gen_masterdati_idx * ARCHBITSZ];
end endgenerate

reg [ARCHBITSZ -1 : 0] masterdato [MASTERCOUNT -1 : 0];
genvar gen_m_data_o_flat_idx;
generate for (gen_m_data_o_flat_idx = 0; gen_m_data_o_flat_idx < MASTERCOUNT; gen_m_data_o_flat_idx = gen_m_data_o_flat_idx + 1) begin :gen_m_data_o_flat
assign m_data_o_flat[((gen_m_data_o_flat_idx+1) * ARCHBITSZ) -1 : gen_m_data_o_flat_idx * ARCHBITSZ] = masterdato[gen_m_data_o_flat_idx];
end endgenerate

wire [(ARCHBITSZ/8) -1 : 0] masterbytsel [MASTERCOUNT -1 : 0];
genvar gen_masterbytsel_idx;
generate for (gen_masterbytsel_idx = 0; gen_masterbytsel_idx < MASTERCOUNT; gen_masterbytsel_idx = gen_masterbytsel_idx + 1) begin :gen_masterbytsel
assign masterbytsel[gen_masterbytsel_idx] = m_sel_i_flat[((gen_masterbytsel_idx+1) * (ARCHBITSZ/8)) -1 : gen_masterbytsel_idx * (ARCHBITSZ/8)];
end endgenerate

wire masterrdy [MASTERCOUNT -1 : 0];
genvar gen_m_rdy_o_flat_idx;
generate for (gen_m_rdy_o_flat_idx = 0; gen_m_rdy_o_flat_idx < MASTERCOUNT; gen_m_rdy_o_flat_idx = gen_m_rdy_o_flat_idx + 1) begin :gen_m_rdy_o_flat
assign m_rdy_o_flat[((gen_m_rdy_o_flat_idx+1) * 1) -1 : gen_m_rdy_o_flat_idx * 1] = masterrdy[gen_m_rdy_o_flat_idx];
end endgenerate

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

// Note that from each master device, the value of
// the following inputs are ignored when masterrdy is 0:
// masterop, masteraddr, masterdati, masterbytsel.
// Note also that it is the responsibility of a master
// device to immediately retrieve the value of the
// output masterdato on the next clock edge when
// the output masterrdy become 1.

// Note that the slave device consider the following
// outputs as don't-care when the input s_rdy_i is 0:
// s_op_o, s_addr_o, s_data_o, s_sel_o.

// The queue is implemented by queueop queueaddr queuedata queuebytsel.
// The number of master devices is also the size of the queue; in fact,
// each element of the queue is always used with the same master device.

// Read and write indexes within the queue.
// Only the clog2($MASTERCOUNT) lsb are used for indexing.
reg [(CLOG2MASTERCOUNT +1) -1 : 0] queuereadidx  = 0;
reg [(CLOG2MASTERCOUNT +1) -1 : 0] queuewriteidx = 0;

wire [(CLOG2MASTERCOUNT +1) -1 : 0] queueusage = (queuewriteidx - queuereadidx);

wire queuenotempty = |queueusage;

wire [2 -1 : 0] queueop_w0;

reg [2 -1 : 0] s_op_o_saved;

wire queueen = (s_rdy_i || (s_op_o_saved == PINOOP && s_op_o == PINOOP)) && queuenotempty;
wire queuewe = (masterrdy[queuewriteidx[CLOG2MASTERCOUNT -1 : 0]]);

wire [2 -1 : 0] queueop_w1;

dram #(

	 .SZ (MASTERCOUNT)
	,.DW (2)

) queueop (

	                                                   .clk1_i  (m_clk_i)
	                                                  ,.we1_i   (queuewe)
	,.addr0_i (queuereadidx[CLOG2MASTERCOUNT -1 : 0]) ,.addr1_i (queuewriteidx[CLOG2MASTERCOUNT -1 : 0])
	                                                  ,.i1      (masterop[queuewriteidx[CLOG2MASTERCOUNT -1 : 0]])
	,.o0      (queueop_w0)                            ,.o1      (queueop_w1)
);

wire [ADDRBITSZ -1 : 0] queueaddr_w0;

dram #(

	 .SZ (MASTERCOUNT)
	,.DW (ADDRBITSZ)

) queueaddr (

	                                                   .clk1_i  (m_clk_i)
	                                                  ,.we1_i   (queuewe)
	,.addr0_i (queuereadidx[CLOG2MASTERCOUNT -1 : 0]) ,.addr1_i (queuewriteidx[CLOG2MASTERCOUNT -1 : 0])
	                                                  ,.i1      (masteraddr[queuewriteidx[CLOG2MASTERCOUNT -1 : 0]])
	,.o0      (queueaddr_w0)                          ,.o1      ()
);

wire [ARCHBITSZ -1 : 0] queuedata_w0;

dram #(

	 .SZ (MASTERCOUNT)
	,.DW (ARCHBITSZ)

) queuedata (

	                                                   .clk1_i  (m_clk_i)
	                                                  ,.we1_i   (queuewe)
	,.addr0_i (queuereadidx[CLOG2MASTERCOUNT -1 : 0]) ,.addr1_i (queuewriteidx[CLOG2MASTERCOUNT -1 : 0])
	                                                  ,.i1      (masterdati[queuewriteidx[CLOG2MASTERCOUNT -1 : 0]])
	,.o0      (queuedata_w0)                          ,.o1      ()
);

wire [(ARCHBITSZ/8) -1 : 0] queuebytsel_w0;

dram #(

	 .SZ (MASTERCOUNT)
	,.DW (ARCHBITSZ/8)

) queuebytsel (

	                                                   .clk1_i  (m_clk_i)
	                                                  ,.we1_i   (queuewe)
	,.addr0_i (queuereadidx[CLOG2MASTERCOUNT -1 : 0]) ,.addr1_i (queuewriteidx[CLOG2MASTERCOUNT -1 : 0])
	                                                  ,.i1      (masterbytsel[queuewriteidx[CLOG2MASTERCOUNT -1 : 0]])
	,.o0      (queuebytsel_w0)                        ,.o1      ()
);

// This net is 1 when the queue is not full.
wire queuenotfull = (queueusage < MASTERCOUNT);

// This net is 1 when the queue is not almost full.
// The queue is almost full when there is one remaining
// queue element for which the result cannot yet be used
// if it was for either of the operation PIRDOP or PIRWOP;
// in fact the return value from the slave device for that
// remaining queue element would still be pending.
wire queuenotalmostfull = (queueusage < (MASTERCOUNT-1));

reg [CLOG2MASTERCOUNT -1 : 0] mstrhi;
reg [CLOG2MASTERCOUNT -1 : 0] slvhi;

// Combinational logics that set masterrdy.
// A masterrdy output is 0 when it is not being indexed
// by queuewriteidx, or when the queue is full, or when
// the queue is almost full and the remaining queue element was
// for either of the operation PIRDOP or PIRWOP, otherwise it is 1.
genvar gen_masterrdy_idx;
generate for (gen_masterrdy_idx = 0; gen_masterrdy_idx < MASTERCOUNT; gen_masterrdy_idx = gen_masterrdy_idx + 1) begin :gen_masterrdy
assign masterrdy[gen_masterrdy_idx] = (queuewriteidx[CLOG2MASTERCOUNT -1 : 0] == gen_masterrdy_idx &&
	mstrhi == slvhi && queuenotfull && (queuenotalmostfull || !queueop_w1[1]));
end endgenerate

assign s_op_o = queuenotempty ? queueop_w0 : PINOOP;

assign s_addr_o = queueaddr_w0;
assign s_data_o = queuedata_w0;
assign s_sel_o  = queuebytsel_w0;

reg [CLOG2MASTERCOUNT -1 : 0] mstrhinxt;
reg [CLOG2MASTERCOUNT -1 : 0] mstrhiidx;
wire masterop_mstrhiidx_not_PINOOP = (masterop[mstrhiidx] != PINOOP);
always @ (posedge m_clk_i) begin
	if (rst_i || !mstrhiidx || masterop_mstrhiidx_not_PINOOP) begin
		if (masterop_mstrhiidx_not_PINOOP)
			mstrhinxt <= ((mstrhiidx > 0) ? mstrhiidx :
				{{(CLOG2MASTERCOUNT-1){1'b0}}, 1'b1}); // mstrhinxt must be > 0.
		mstrhiidx <= (MASTERCOUNT - 1);
	end else
		mstrhiidx <= mstrhiidx - 1'b1;
end

wire [(CLOG2MASTERCOUNT +1) -1 : 0] MASTERCOUNT__less_mstrhi = (MASTERCOUNT_ - mstrhi);
reg  [(CLOG2MASTERCOUNT +1) -1 : 0] MASTERCOUNT__less_mstrhi_hold;

always @ (posedge m_clk_i) begin
	if (rst_i) begin
		// Reset logic.
		// Setting queuewriteidx using queuereadidx makes the queue empty.
		// Driving the reset logic using s_clk_i and setting queuereadidx
		// using queuewriteidx would not have yielded the correct behavior
		// because queuewriteidx would have incremented even when rst_i is 1
		// unless the combinational logic that set masterrdy took rst_i into account,
		// but that would require more logic.
		queuewriteidx <= queuereadidx;
		mstrhi <= (MASTERCOUNT - 1);
	end else if (queuewe) begin
		// Queue the memory operation and increment queuewriteidx
		// to the next master device from which an operation
		// for the slave device will be taken for queueing.
		if (queuewriteidx[CLOG2MASTERCOUNT -1 : 0] < mstrhi)
			queuewriteidx <= queuewriteidx + 1'b1;
		else begin
			MASTERCOUNT__less_mstrhi_hold <= MASTERCOUNT__less_mstrhi;
			queuewriteidx <= (queuewriteidx + MASTERCOUNT__less_mstrhi);
			mstrhi <= mstrhinxt;
		end
	end
end

reg [CLOG2MASTERCOUNT -1 : 0] prevqueuereadidx;

always @ (posedge s_clk_i) begin
	if (rst_i) begin
		s_op_o_saved <= PINOOP;
		slvhi <= (MASTERCOUNT - 1);
		prevqueuereadidx <= 0;
	end else if (queueen) begin
		s_op_o_saved <= s_op_o;
		// I increment queuereadidx to the memory operation
		// to execute when the current memory operation indexed
		// by queuereadidx complete.
		masterdato[prevqueuereadidx[CLOG2MASTERCOUNT -1 : 0]] <= s_data_i;
		prevqueuereadidx <= queuereadidx[CLOG2MASTERCOUNT -1 : 0];
		if (queuereadidx[CLOG2MASTERCOUNT -1 : 0] < slvhi)
			queuereadidx <= queuereadidx + 1'b1;
		else begin
			queuereadidx <= (queuereadidx + MASTERCOUNT__less_mstrhi_hold);
			slvhi <= mstrhi;
		end
	end
end

`ifdef SIMULATION
integer init_masterdato_idx;
initial begin
	for (init_masterdato_idx = 0; init_masterdato_idx < MASTERCOUNT; init_masterdato_idx = init_masterdato_idx + 1)
		masterdato[init_masterdato_idx] = 0;
	queuereadidx = 0;
	queuewriteidx = 0;
	s_op_o_saved = PINOOP;
	mstrhi = (MASTERCOUNT - 1);
	slvhi = (MASTERCOUNT - 1);
	mstrhinxt = (MASTERCOUNT - 1);
	mstrhiidx = (MASTERCOUNT - 1);
	MASTERCOUNT__less_mstrhi_hold = 1;
	prevqueuereadidx = 0;
end
`endif

endmodule

`endif /* PI1Q_V */
