// SPDX-License-Identifier: GPL-2.0-only
// 20261030 (c) William Fonkou Tambe

`ifndef WB_LITEDRAM_V
`define WB_LITEDRAM_V

// Bridge from the pipelined wishbone of the interconnect to the native user
// port of litedram, as LiteX generates it for a user port of type "native".
//
// litedram takes a command, "s_cmd_we_o" and "s_cmd_addr_o", in the clock
// cycle in which "s_cmd_valid_o" and "s_cmd_ready_i" are high, where
// "s_cmd_ready_i" depends on the bank which "s_cmd_addr_o" selects and on
// the commands which litedram holds, not on "s_cmd_valid_o". It completes a
// write by taking "s_wdata_we_o" and "s_wdata_data_o" in the clock cycle in
// which it sets "s_wdata_ready_i" high, whatever "s_wdata_valid_o", and a
// read by giving "s_rdata_data_i" in the clock cycle in which it sets
// "s_rdata_valid_i" high, whatever "s_rdata_ready_o"; hence the write data
// of a write are to be presented by then, and the read data of a read are to
// be taken then. litedram completes the commands of its port in the order in
// which it takes them, at most one per clock cycle, as long as that port is
// its only user port: it holds the commands of a port in one bank at a time,
// completing them in the order it took them, and lets the latency of its
// reads elapse before turning from reads to writes.
//
// The bridge accepts the request of the master in the clock cycle in which
// "m_wb_stb_i" is high while "m_wb_bsy_o" is low; it holds up to
// MAXPENDINGACK requests which litedram has not completed, "m_wb_bsy_o"
// being high while it holds that many. It queues the command and the write
// data of a request in fifos, from which it presents them to litedram from
// the next clock cycle, the command until litedram takes it, the write data
// until litedram takes them; and it acknowledges each request in the clock
// cycle which follows its completion, in the order of the requests, with the
// read data registered. Hence an access takes (L+2) clock cycles, where L is
// the count of clock cycles from its command being presented to litedram to
// its completion; the accesses which follow it overlap with it; and no
// combinational path goes through the bridge, from the master to litedram or
// back, "m_wb_bsy_o" being from registers and "rst_i" only.
//
// litedram is not reset with the master, so that its DDR SDRAM keeps its
// content across the reset of the system. While "rst_i", the reset of the
// master, is high, the bridge accepts no request, "m_wb_bsy_o" being high;
// the requests which it accepted earlier are presented to litedram
// nonetheless, and completed, whatever "rst_i": litedram may have taken the
// command of a write and not yet its write data, and every write which the
// bridge accepts thus reaches the DDR SDRAM. Their acknowledgements are
// dropped, the master which made them having been reset: an acknowledgement
// for which the master has no pending request would corrupt the count of
// pending requests which the interconnect keeps, ie: lib/wb_mux.sv. Hence
// the acknowledgements which the master gets after a reset are those of the
// requests it made after that reset, which the bridge accepts as soon as
// "rst_i" is low, while it holds fewer than MAXPENDINGACK requests.
//
// A reset of litedram, ie: its "user_rst", which is "s_rst_i", resets its
// controller, which then never completes the commands it had taken; the
// bridge then discards every request it holds, acknowledging none of them.
// Hence "rst_i" must be high whenever "s_rst_i" is, so that the masters of
// those requests are reset too, ie: the reset of litedram is to be a part of
// the reset of the system.

// Parameters:
//
// WORDBITSZ
// 	Width of the data bus in bits, ie: of the user port of litedram.
// 	Must be a power-of-2 and >= 32.
//
// ADDRLIMIT
// 	Address limit from which the address bus width is derived,
// 	as the other modules of lib/ do.
//
// MAXPENDINGACK
// 	Count of requests which the bridge holds at most, ie: accepted,
// 	and not yet completed by litedram.
// 	Must be a power-of-2 and >= 2.

// Ports:
//
// rst_i
// 	Reset of the master: while high, the bridge accepts no request,
// 	and the acknowledgements of the requests accepted earlier are
// 	dropped; it does not withdraw them from litedram.
//
// s_rst_i
// 	Reset of litedram, ie: its "user_rst": when high at the rising edge
// 	of "clk_i", the bridge discards every request it holds; "rst_i" must
// 	be high whenever it is.
//
// clk_i
// 	Clock signal, of the master and of litedram, ie: its "user_clk".
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
// s_cmd_valid_o
// s_cmd_ready_i
// s_cmd_we_o
// s_cmd_addr_o
// s_wdata_valid_o
// s_wdata_ready_i
// s_wdata_we_o
// s_wdata_data_o
// s_rdata_valid_i
// s_rdata_ready_o
// s_rdata_data_i
// 	Native user port of litedram, whose signals of the same names
// 	connect to these, ie: "user_port_native_0_cmd_valid" etc.; litedram
// 	reads neither "s_wdata_valid_o" nor "s_rdata_ready_o".

`include "lib/fifo_fwft.sv"

module wb_litedram (

	 rst_i
	,s_rst_i

	,clk_i

	,m_wb_stb_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_cmd_valid_o
	,s_cmd_ready_i
	,s_cmd_we_o
	,s_cmd_addr_o
	,s_wdata_valid_o
	,s_wdata_ready_i
	,s_wdata_we_o
	,s_wdata_data_o
	,s_rdata_valid_i
	,s_rdata_ready_o
	,s_rdata_data_i
);

`include "lib/clog2.sv"

parameter WORDBITSZ     = 64;
parameter ADDRLIMIT     = 'h2000;
parameter MAXPENDINGACK = 8;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

localparam CLOG2MAXPENDINGACK = clog2(MAXPENDINGACK);

input wire rst_i;
input wire s_rst_i;

input wire clk_i;

input  wire                               m_wb_stb_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output reg                                m_wb_ack_o = 1'b0;
output reg  [WORDBITSZ -1 : 0]            m_wb_dat_o;

output wire                               s_cmd_valid_o;
input  wire                               s_cmd_ready_i;
output wire                               s_cmd_we_o;
output wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_cmd_addr_o;
output wire                               s_wdata_valid_o;
input  wire                               s_wdata_ready_i;
output wire [(WORDBITSZ/8) -1 : 0]        s_wdata_we_o;
output wire [WORDBITSZ -1 : 0]            s_wdata_data_o;
input  wire                               s_rdata_valid_i;
output wire                               s_rdata_ready_o;
input  wire [WORDBITSZ -1 : 0]            s_rdata_data_i;

// Count of the requests which the bridge holds, ie: accepted, and not yet
// completed by litedram; "rst_i" does not reset it, as those requests are
// completed whatever "rst_i".
reg [(CLOG2MAXPENDINGACK +1) -1 : 0] pending = 0;

// Count of the oldest of those requests, accepted before "rst_i" was last
// high, whose acknowledgements are dropped.
reg [(CLOG2MAXPENDINGACK +1) -1 : 0] orphans = 0;

assign m_wb_bsy_o = (rst_i || pending[CLOG2MAXPENDINGACK]);

wire accept = (m_wb_stb_i && !m_wb_bsy_o);

// Completion of the oldest command which litedram has taken.
wire done = (s_wdata_ready_i || s_rdata_valid_i);

always_ff @(posedge clk_i) begin
	if (s_rst_i) begin
		pending <= 0;
		orphans <= 0;
	end else begin
		if (accept != done)
			pending <= (accept ? (pending + 1'b1) : (pending - 1'b1));
		if (rst_i)
			orphans <= (pending - done);
		else if (done && orphans)
			orphans <= (orphans - 1'b1);
	end
end

always_ff @(posedge clk_i) begin
	m_wb_ack_o <= (done && !orphans && !rst_i);
	m_wb_dat_o <= s_rdata_data_i;
end

// The usage and full signals of the fifos are only read by the
// SIMULATION_MONITOR guards below; pruned in synthesis.
wire [(CLOG2MAXPENDINGACK +1) -1 : 0] rqst_usage_w;
wire                                  rqst_full_w;
wire                                  rqst_empty_w;

// Commands of the requests held, until litedram takes them.
fifo_fwft #(
	 .WIDTH (1 + (ADDRBITSZ-MSBSZIGN))
	,.DEPTH (MAXPENDINGACK)
) rqst (

	 .rst_i (s_rst_i)

	,.usage_o (rqst_usage_w)

	,.clk_push_i (clk_i)
	,.push_i     (accept)
	,.data_i     ({m_wb_we_i, m_wb_addr_i})
	,.full_o     (rqst_full_w)

	,.clk_pop_i (clk_i)
	,.pop_i     (s_cmd_ready_i)
	,.data_o    ({s_cmd_we_o, s_cmd_addr_o})
	,.empty_o   (rqst_empty_w)
);

assign s_cmd_valid_o = !rqst_empty_w;

wire wdat_full_w;
wire wdat_empty_w;

// Write data of the writes held, until litedram takes them.
fifo_fwft #(
	 .WIDTH ((WORDBITSZ/8) + WORDBITSZ)
	,.DEPTH (MAXPENDINGACK)
) wdat (

	 .rst_i (s_rst_i)

	,.clk_push_i (clk_i)
	,.push_i     (accept && m_wb_we_i)
	,.data_i     ({m_wb_sel_i, m_wb_dat_i})
	,.full_o     (wdat_full_w)

	,.clk_pop_i (clk_i)
	,.pop_i     (s_wdata_ready_i)
	,.data_o    ({s_wdata_we_o, s_wdata_data_o})
	,.empty_o   (wdat_empty_w)
);

assign s_wdata_valid_o = !wdat_empty_w;

assign s_rdata_ready_o = 1'b1;

`ifdef SIMULATION_MONITOR
// Kind of the commands which litedram has taken and not yet completed,
// oldest first, high for a write: litedram is to complete them in that order.
wire [(CLOG2MAXPENDINGACK +1) -1 : 0] inflight_w;
wire                                  inflight_we_w;
fifo_fwft #(
	 .WIDTH (1)
	,.DEPTH (MAXPENDINGACK)
) inflight (

	 .rst_i (s_rst_i)

	,.usage_o (inflight_w)

	,.clk_push_i (clk_i)
	,.push_i     (s_cmd_valid_o && s_cmd_ready_i)
	,.data_i     (s_cmd_we_o)

	,.clk_pop_i (clk_i)
	,.pop_i     (done)
	,.data_o    (inflight_we_w)
);
always_ff @(posedge clk_i) begin
	if (s_rst_i && !rst_i)
		$error("%m: reset of litedram without the reset of the master");
	if (!s_rst_i) begin
		if (accept && rqst_full_w)
			$error("%m: command fifo overflow: request dropped");
		if (accept && m_wb_we_i && wdat_full_w)
			$error("%m: write data fifo overflow: request dropped");
		if (s_wdata_ready_i && s_rdata_valid_i)
			$error("%m: write data taken and read data given in one clock cycle");
		else if (done && !inflight_w)
			$error("%m: completion while no command is in flight");
		else if (done && (inflight_we_w != s_wdata_ready_i))
			$error("%m: completion out of the order of the commands");
		if (pending != ({1'b0, rqst_usage_w} + inflight_w))
			$error("%m: count of the requests held unlike the fifos");
		if (orphans > pending)
			$error("%m: more orphans than requests held");
	end
end
`endif

endmodule

`endif /* WB_LITEDRAM_V */
