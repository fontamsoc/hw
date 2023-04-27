// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1Q_TO_AXI4_V
`define PI1Q_TO_AXI4_V

`include "lib/perint/pi1q.v"

`include "lib/addr.v"

module pi1q_to_axi4 (

	 axi4_rst_i

	,pi1_clk_i
	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o

	,axi4_clk_i
	// Write Address Ports
	,axi4_awid_o
	,axi4_awaddr_o
	,axi4_awlen_o
	,axi4_awsize_o
	,axi4_awburst_o
	,axi4_awlock_o
	,axi4_awcache_o
	,axi4_awprot_o
	,axi4_awqos_o
	,axi4_awvalid_o
	,axi4_awready_i
	// Write Data Ports
	,axi4_wdata_o
	,axi4_wstrb_o
	,axi4_wlast_o
	,axi4_wvalid_o
	,axi4_wready_i
	// Write Response Ports
	,axi4_bready_o
	,axi4_bid_i
	,axi4_bresp_i
	,axi4_bvalid_i
	// Read Address Ports
	,axi4_arid_o
	,axi4_araddr_o
	,axi4_arlen_o
	,axi4_arsize_o
	,axi4_arburst_o
	,axi4_arlock_o
	,axi4_arcache_o
	,axi4_arprot_o
	,axi4_arqos_o
	,axi4_arvalid_o
	,axi4_arready_i
	// Read Data Ports
	,axi4_rready_o
	,axi4_rid_i
	,axi4_rdata_i
	,axi4_rresp_i
	,axi4_rlast_i
	,axi4_rvalid_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter AXI4_ID_WIDTH = 4;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire axi4_rst_i;

input  wire                        pi1_clk_i;
input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;

input  wire                        axi4_clk_i;
// Write Address Ports
output wire [AXI4_ID_WIDTH -1 : 0] axi4_awid_o;
output reg  [ARCHBITSZ -1 : 0]     axi4_awaddr_o;
output wire [7:0]                  axi4_awlen_o;
output wire [2:0]                  axi4_awsize_o;
output wire [1:0]                  axi4_awburst_o;
output wire [0:0]                  axi4_awlock_o;
output wire [3:0]                  axi4_awcache_o;
output wire [2:0]                  axi4_awprot_o;
output wire [3:0]                  axi4_awqos_o;
output wire                        axi4_awvalid_o;
input  wire                        axi4_awready_i;
// Write Data Ports
output reg  [ARCHBITSZ -1 : 0]     axi4_wdata_o;
output reg  [(ARCHBITSZ/8) -1 : 0] axi4_wstrb_o;
output wire                        axi4_wlast_o;
output wire                        axi4_wvalid_o;
input  wire                        axi4_wready_i;
// Write Response Ports
output reg                         axi4_bready_o;
input  wire [AXI4_ID_WIDTH -1 : 0] axi4_bid_i;
input  wire [1:0]                  axi4_bresp_i;
input  wire                        axi4_bvalid_i;
// Read Address Ports
output wire [AXI4_ID_WIDTH -1 : 0] axi4_arid_o;
output reg  [ARCHBITSZ -1 : 0]     axi4_araddr_o;
output wire [7:0]                  axi4_arlen_o;
output wire [2:0]                  axi4_arsize_o;
output wire [1:0]                  axi4_arburst_o;
output wire [0:0]                  axi4_arlock_o;
output wire [3:0]                  axi4_arcache_o;
output wire [2:0]                  axi4_arprot_o;
output wire [3:0]                  axi4_arqos_o;
output wire                        axi4_arvalid_o;
input  wire                        axi4_arready_i;
// Read Data Ports
output reg                         axi4_rready_o;
input  wire [AXI4_ID_WIDTH -1 : 0] axi4_rid_i;
input  wire [ARCHBITSZ -1 : 0]     axi4_rdata_i;
input  wire [1:0]                  axi4_rresp_i;
input  wire                        axi4_rlast_i;
input  wire                        axi4_rvalid_i;

assign axi4_awid_o = {AXI4_ID_WIDTH{1'b0}};
assign axi4_awlen_o = 0; /* length 1 */
assign axi4_awsize_o = clog2(ARCHBITSZ);
assign axi4_awburst_o = 2'b01; /* INCR */
assign axi4_awlock_o = 0; /* normal access */
assign axi4_awcache_o = 4'b0000;
assign axi4_awprot_o = 3'b000; /* [2]: data access; [1]: secure access; [0]: unprivileged access */
assign axi4_awqos_o = 4'b0000; /* not participating in any QoS scheme */
assign axi4_arid_o = {AXI4_ID_WIDTH{1'b0}};
assign axi4_arlen_o = 0; /* length 1 */
assign axi4_arsize_o = clog2(ARCHBITSZ);
assign axi4_arburst_o = 2'b01; /* INCR */
assign axi4_arlock_o = 0; /* normal access */
assign axi4_arcache_o = 4'b0000;
assign axi4_arprot_o = 3'b000; /* [2]: data access; [1]: secure access; [0]: unprivileged access */
assign axi4_arqos_o = 4'b0000; /* not participating in any QoS scheme */

localparam PI1QMASTERCOUNT       = 1;
localparam PI1QARCHBITSZ         = ARCHBITSZ;
localparam CLOG2PI1QARCHBITSZBY8 = clog2(PI1QARCHBITSZ/8);
localparam PI1QADDRBITSZ         = (PI1QARCHBITSZ-CLOG2PI1QARCHBITSZBY8);

wire pi1q_rst_w = axi4_rst_i;
wire m_pi1q_clk_w = pi1_clk_i;
wire s_pi1q_clk_w = axi4_clk_i;
// PerIntQ is instantiated in a separate file to keep this file clean.
// Masters should use the following signals to plug onto PerIntQ:
// 	input  [2 -1 : 0]                 m_pi1q_op_w    [PI1QMASTERCOUNT -1 : 0];
// 	input  [PI1QADDRBITSZ -1 : 0]     m_pi1q_addr_w  [PI1QMASTERCOUNT -1 : 0];
// 	input  [PI1QARCHBITSZ -1 : 0]     m_pi1q_data_w1 [PI1QMASTERCOUNT -1 : 0];
// 	output [PI1QARCHBITSZ -1 : 0]     m_pi1q_data_w0 [PI1QMASTERCOUNT -1 : 0];
// 	input  [(PI1QARCHBITSZ/8) -1 : 0] m_pi1q_sel_w   [PI1QMASTERCOUNT -1 : 0];
// 	output                            m_pi1q_rdy_w   [PI1QMASTERCOUNT -1 : 0];
// Slave should use the following signals to plug onto PerIntQ:
// 	output [2 -1 : 0]                 s_pi1q_op_w;
// 	output [PI1QADDRBITSZ -1 : 0]     s_pi1q_addr_w;
// 	output [PI1QARCHBITSZ -1 : 0]     s_pi1q_data_w0;
// 	input  [PI1QARCHBITSZ -1 : 0]     s_pi1q_data_w1;
// 	output [(PI1QARCHBITSZ/8) -1 : 0] s_pi1q_sel_w;
// 	input                             s_pi1q_rdy_w;
`include "lib/perint/inst.pi1q.v"

assign m_pi1q_op_w[0] = pi1_op_i;
assign m_pi1q_addr_w[0] = pi1_addr_i;
assign m_pi1q_data_w1[0] = pi1_data_i;
assign pi1_data_o = m_pi1q_data_w0[0];
assign m_pi1q_sel_w[0] = pi1_sel_i;
assign pi1_rdy_o = m_pi1q_rdy_w[0];

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg wrpending;

reg [2 -1 : 0]         s_pi1q_op_w_hold;
reg [ARCHBITSZ -1 : 0] axi4_rdata_hold;

reg we;

wire ack = (we ? axi4_bvalid_i : axi4_rvalid_i);

wire not_wrpending_and_ack = (!wrpending && ack);

assign s_pi1q_data_w1 = /*not_wrpending_and_ack ?*/
	((s_pi1q_op_w_hold == PIRWOP) ? axi4_rdata_hold : axi4_rdata_i)/*:
	{ARCHBITSZ{1'b0}}*/;

reg cyc;

assign s_pi1q_rdy_w = (/*!axi4_rst_i &&*/(!cyc || not_wrpending_and_ack));

wire [ARCHBITSZ -1 : 0] axi4_axaddr_w;

addr #(
	.ARCHBITSZ (ARCHBITSZ)
) addr (
	 .addr_i (s_pi1q_addr_w)
	,.sel_i  (s_pi1q_sel_w)
	,.addr_o (axi4_axaddr_w)
);

wire stall_n = (we ? (axi4_awready_i & axi4_wready_i) : axi4_arready_i);

reg axi4_awvalid_o_;
assign axi4_awvalid_o = (stall_n && axi4_awvalid_o_);

reg axi4_wvalid_o_;
assign axi4_wvalid_o = (stall_n && axi4_wvalid_o_);
assign axi4_wlast_o = axi4_wvalid_o_;

reg axi4_arvalid_o_;
assign axi4_arvalid_o = (stall_n && axi4_arvalid_o_);

always @ (posedge axi4_clk_i) begin

	if (axi4_rst_i) begin

		cyc <= 0;
		wrpending <= 0;
		axi4_awvalid_o_ <= 0;
		axi4_wvalid_o_ <= 0;
		axi4_arvalid_o_ <= 0;
		axi4_bready_o <= 0;
		axi4_rready_o <= 0;

	end else if (s_pi1q_rdy_w) begin

		s_pi1q_op_w_hold <= s_pi1q_op_w;
		axi4_wdata_o <= s_pi1q_data_w0;
		axi4_wstrb_o <= s_pi1q_sel_w;

		if (s_pi1q_op_w == PIRDOP) begin

			cyc <= 1;
			we <= 0;
			axi4_araddr_o <= axi4_axaddr_w;
			axi4_arvalid_o_ <= 1;
			axi4_rready_o <= 1;

		end else if (s_pi1q_op_w == PIWROP) begin

			cyc <= 1;
			we <= 1;
			axi4_awaddr_o <= axi4_axaddr_w;
			axi4_awvalid_o_ <= 1;
			axi4_wvalid_o_ <= 1;
			axi4_bready_o <= 1;

		end else if (s_pi1q_op_w == PIRWOP) begin

			cyc <= 1;
			we <= 0;
			wrpending <= 1;
			axi4_araddr_o <= axi4_axaddr_w;
			axi4_arvalid_o_ <= 1;
			axi4_rready_o <= 1;

		end else begin

			cyc <= 0;
			we <= 0;
			axi4_bready_o <= 0;
		end

	end else if (wrpending && ack) begin

		axi4_rdata_hold <= axi4_rdata_i;

		we <= 1;
		wrpending <= 0;
		axi4_awaddr_o <= axi4_araddr_o;
		axi4_awvalid_o_ <= 1;
		axi4_wvalid_o_ <= 1;
		axi4_bready_o <= 1;

	end else if (stall_n) begin
		// Request accepted.
		axi4_awvalid_o_ <= 0;
		axi4_wvalid_o_ <= 0;
		axi4_arvalid_o_ <= 0;
		axi4_rready_o <= 0;
	end
end

endmodule

`endif /* PI1Q_TO_AXI4_V */
