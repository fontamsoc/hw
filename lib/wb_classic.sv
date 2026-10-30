// SPDX-License-Identifier: GPL-2.0-only
// 20261020 (c) William Fonkou Tambe

`ifndef WB_CLASSIC_V
`define WB_CLASSIC_V

// Bridge from the pipelined wishbone of the interconnect to a slave using
// the classic wishbone, ie: the control port of litedram, which maps its
// registers.
//
// A classic slave takes a request presented with "s_wb_cyc_o" and
// "s_wb_stb_o" high, its other signals stable, until the slave acknowledges
// it through "s_wb_ack_i", which it may do in the clock cycle the request is
// presented; the request is not to be withdrawn before, as the slave may
// have taken it, ie: the control port of litedram, when idle, takes a
// request in the clock cycle it finds it presented, accesses the register in
// the next clock cycle, and acknowledges the request in the clock cycle
// after, whether it is still presented or not; idle again from the next
// clock cycle, it would take a request still presented as a new one.
//
// The bridge takes one request at a time: it accepts the request of the
// master in the clock cycle "m_wb_stb_i" is high while "m_wb_bsy_o" is low,
// registers it, and presents it to the slave from the next clock cycle until
// the clock cycle which acknowledges it, "m_wb_bsy_o" being high meanwhile.
// The acknowledgement and the data read are registered toward the master,
// which gets them in the clock cycle which follows the acknowledgement of
// the slave; it is the first clock cycle in which the bridge can accept a
// new request, the slave seeing "s_wb_cyc_o" and "s_wb_stb_o" low for at
// least that clock cycle. Hence an access takes (L+2) clock cycles, where L
// is the count of clock cycles from the request being presented to the
// slave to its acknowledgement, and no combinational path goes through the
// bridge, from the master to the slave or back.
//
// The bridge is meant for a slave which is not reset with the master, ie:
// litedram, whose registers, as its memory, survive the reset of the
// system. A request presented to the slave remains so until the slave
// acknowledges it, whatever "rst_i", since the slave may have taken it, and
// would then acknowledge it regardless; its acknowledgement is dropped when
// "rst_i" was high since the request was accepted, the master which made it
// having been reset meanwhile: an acknowledgement for which the master has
// no pending request would corrupt the count of pending requests which the
// interconnect keeps, ie: lib/wb_mux.sv. While "rst_i" is high, the bridge
// accepts no request, "m_wb_bsy_o" being high; once it is low, the bridge
// accepts a new request as soon as the slave has acknowledged the request
// which was presented to it. Hence the acknowledgements which the master
// gets after a reset are those of the requests it made after that reset.

// Parameters:
//
// WORDBITSZ
// 	Width of the data bus in bits.
// 	Must be a power-of-2 and >= 32.
//
// ADDRLIMIT
// 	Address limit from which the address bus width is derived,
// 	as the other modules of lib/ do.

// Ports:
//
// rst_i
// 	Reset of the master: while high, the bridge accepts no request,
// 	and the acknowledgement of the request presented to the slave
// 	is dropped; it does not withdraw that request.
//
// clk_i
// 	Clock signal, of the master and of the slave.
//
// m_wb_stb_i
// m_wb_we_i
// m_wb_addr_i
// m_wb_sel_i
// m_wb_dat_i
// m_wb_bsy_o
// m_wb_ack_o
// m_wb_dat_o
// 	Pipelined wishbone slave interface, to which the master connects.
//
// s_wb_cyc_o
// s_wb_stb_o
// s_wb_we_o
// s_wb_addr_o
// s_wb_sel_o
// s_wb_dat_o
// s_wb_ack_i
// s_wb_dat_i
// 	Classic wishbone master interface, to which the slave connects.

module wb_classic (

	 rst_i

	,clk_i

	,m_wb_stb_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_cyc_o
	,s_wb_stb_o
	,s_wb_we_o
	,s_wb_addr_o
	,s_wb_sel_o
	,s_wb_dat_o
	,s_wb_ack_i
	,s_wb_dat_i
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;
parameter ADDRLIMIT = 'h2000;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

input  wire                               m_wb_stb_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output reg                                m_wb_ack_o = 1'b0;
output reg  [WORDBITSZ -1 : 0]            m_wb_dat_o;

output wire                               s_wb_cyc_o;
output wire                               s_wb_stb_o;
output reg                                s_wb_we_o;
output reg  [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output reg  [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output reg  [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

// True while a request is presented to the slave; "rst_i" does not reset it,
// as the request must remain presented until the slave acknowledges it.
reg busy = 1'b0;

// True when "rst_i" was high since the request presented to the slave
// was accepted, in which case its acknowledgement is dropped.
reg orphan = 1'b0;

assign m_wb_bsy_o = (busy || rst_i);

assign s_wb_cyc_o = busy;
assign s_wb_stb_o = busy;

wire done = (busy && s_wb_ack_i);

always_ff @(posedge clk_i) begin
	if (done) begin
		busy <= 1'b0;
		orphan <= 1'b0;
	end else if (busy) begin
		if (rst_i)
			orphan <= 1'b1;
	end else if (m_wb_stb_i && !rst_i) begin
		busy <= 1'b1;
		s_wb_we_o <= m_wb_we_i;
		s_wb_addr_o <= m_wb_addr_i;
		s_wb_sel_o <= m_wb_sel_i;
		s_wb_dat_o <= m_wb_dat_i;
	end
end

always_ff @(posedge clk_i) begin
	m_wb_ack_o <= (done && !orphan && !rst_i);
	m_wb_dat_o <= s_wb_dat_i;
end

`ifdef SIMULATION_MONITOR
// An acknowledgement while no request is presented would mean that the slave
// took a request which the bridge did not make, or acknowledged one twice.
always_ff @(posedge clk_i) begin
	if (s_wb_ack_i && !busy)
		$error("%m: acknowledgement while no request is presented");
end
`endif

endmodule

`endif /* WB_CLASSIC_V */
