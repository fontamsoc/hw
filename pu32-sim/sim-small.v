// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`define SIMULATION

`include "lib/wb_arbiter.v"
`include "lib/wb_mux.v"
`include "lib/wb_dnsizr.v"

`include "pu/cpu.v"

`include "dev/uart_sim.v"

`include "dev/sram.v"

module sim (
	 rst_i
	,clk_i
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;
input wire clk_i;

localparam CLK1XFREQ = (100000000) /* 100 Mhz */; // Frequency of clk_1x_w.

wire clk_1x_w = clk_i;

wire rst_w = rst_i;

localparam M_WBPI_CPU        = 0;
localparam M_WBPI_LAST       = M_WBPI_CPU;
localparam S_WBPI_UART     = 0;
localparam S_WBPI_RAM        = (S_WBPI_UART + 1);
localparam S_WBPI_INVALIDDEV = (S_WBPI_RAM + 1);

localparam WBPI_MASTERCOUNT       = (M_WBPI_LAST + 1);
localparam WBPI_SLAVECOUNT        = (S_WBPI_INVALIDDEV + 1);
localparam WBPI_DEFAULTSLAVEINDEX = S_WBPI_INVALIDDEV;
localparam WBPI_FIRSTSLAVEADDR    = /* set so memory starts at 0x1000*/ ('h1000 - (16/*UART_MAPSZ*/));
localparam WBPI_DNSIZR            = 3'b001;
localparam WBPI_ARCHBITSZ         = ARCHBITSZ;
localparam WBPI_CLOG2ARCHBITSZBY8 = clog2(WBPI_ARCHBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_ARCHBITSZ - WBPI_CLOG2ARCHBITSZBY8);
localparam WBPI_CLKFREQ           = CLK1XFREQ;
wire wbpi_rst_w = rst_w;
wire wbpi_clk_w = clk_1x_w;
// The peripheral interconnect is instantiated in a separate file to keep this file clean.
// Master devices must use the following signals to plug onto the peripheral interconnect:
// 	input                              m_wbpi_cyc_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input                              m_wbpi_stb_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input                              m_wbpi_we_w   [WBPI_MASTERCOUNT -1 : 0];
// 	input  [WBPI_ADDRBITSZ -1 : 0]     m_wbpi_addr_w [WBPI_MASTERCOUNT -1 : 0];
// 	input  [(WBPI_ARCHBITSZ/8) -1 : 0] m_wbpi_sel_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input  [WBPI_ARCHBITSZ -1 : 0]     m_wbpi_dati_w [WBPI_MASTERCOUNT -1 : 0];
// 	output                             m_wbpi_bsy_w  [WBPI_MASTERCOUNT -1 : 0];
// 	output                             m_wbpi_ack_w  [WBPI_MASTERCOUNT -1 : 0];
// 	output [WBPI_ARCHBITSZ -1 : 0]     m_wbpi_dato_w [WBPI_MASTERCOUNT -1 : 0];
// Slave devices must use the following signals to plug onto the peripheral interconnect:
// 	output                             s_wbpi_cyc_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output                             s_wbpi_stb_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output                             s_wbpi_we_w    [WBPI_SLAVECOUNT -1 : 0];
// 	output [WBPI_ADDRBITSZ -1 : 0]     s_wbpi_addr_w  [WBPI_SLAVECOUNT -1 : 0];
// 	output [(WBPI_ARCHBITSZ/8) -1 : 0] s_wbpi_sel_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output [WBPI_ARCHBITSZ -1 : 0]     s_wbpi_dato_w  [WBPI_SLAVECOUNT -1 : 0];
// 	input                              s_wbpi_bsy_w   [WBPI_SLAVECOUNT -1 : 0];
// 	input                              s_wbpi_ack_w   [WBPI_SLAVECOUNT -1 : 0];
// 	input  [WBPI_ARCHBITSZ -1 : 0]     s_wbpi_dati_w  [WBPI_SLAVECOUNT -1 : 0];
// 	input  [ARCHBITSZ -1 : 0]          s_wbpi_mapsz_w [WBPI_SLAVECOUNT -1 : 0];
// If "dev/devtbl.v" was included, slave devices must also use following signals:
// 	input  [ARCHBITSZ -1 : 0]          dev_id_w       [WBPI_SLAVECOUNT -1 : 0];
// 	input                              dev_useirq_w   [WBPI_SLAVECOUNT -1 : 0];
`include "lib/wbpi_inst.v"

localparam ICACHESZ = 64;
localparam DCACHESZ = 32;
localparam TLBSZ    = 8;

localparam ICACHEWAYCOUNT = 2;
localparam DCACHEWAYCOUNT = 2;
localparam TLBWAYCOUNT    = 1;

cpu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.XARCHBITSZ     (WBPI_ARCHBITSZ)
	,.CLKFREQ        (WBPI_CLKFREQ)
	,.ICACHESETCOUNT ((1024/(WBPI_ARCHBITSZ/8))*(ICACHESZ/ICACHEWAYCOUNT))
	,.DCACHESETCOUNT ((1024/(WBPI_ARCHBITSZ/8))*(DCACHESZ/DCACHEWAYCOUNT))
	,.TLBSETCOUNT    (TLBSZ/TLBWAYCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.DCACHEWAYCOUNT (DCACHEWAYCOUNT)
	,.TLBWAYCOUNT    (TLBWAYCOUNT)

) cpu (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_o  (m_wbpi_cyc_w[M_WBPI_CPU])
	,.wb_stb_o  (m_wbpi_stb_w[M_WBPI_CPU])
	,.wb_we_o   (m_wbpi_we_w[M_WBPI_CPU])
	,.wb_addr_o (m_wbpi_addr_w[M_WBPI_CPU])
	,.wb_sel_o  (m_wbpi_sel_w[M_WBPI_CPU])
	,.wb_dat_o  (m_wbpi_dati_w[M_WBPI_CPU])
	,.wb_bsy_i  (m_wbpi_bsy_w[M_WBPI_CPU])
	,.wb_ack_i  (m_wbpi_ack_w[M_WBPI_CPU])
	,.wb_dat_i  (m_wbpi_dato_w[M_WBPI_CPU])

	,.rstaddr_i (('h1000)>>1)
);

uart_sim #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.BUFSZ     (2)

) uart (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_UART])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_UART])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_UART])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_UART])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_UART])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_UART])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_UART])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_UART])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_UART])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_UART])
);

localparam SRAM_SRCFILE =
	WBPI_ARCHBITSZ == 32 ? "sram32.hex" :
	WBPI_ARCHBITSZ == 64 ? "sram64.hex" :
	WBPI_ARCHBITSZ == 128 ? "sram128.hex" :
	WBPI_ARCHBITSZ == 256 ? "sram256.hex" : "";

sram #(

	 .ARCHBITSZ (WBPI_ARCHBITSZ)
	,.SIZE      ((4/*KB*/)*(1024/(WBPI_ARCHBITSZ/8)))
	,.SRCFILE   (SRAM_SRCFILE)

) sram (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_RAM])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_RAM])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_RAM])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_RAM])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_RAM])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_RAM])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_RAM])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_RAM])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_RAM])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_RAM])
);

// WBPI_DEFAULTSLAVEINDEX to catch invalid physical address space access.
assign s_wbpi_bsy_w[S_WBPI_INVALIDDEV] = 0;
assign s_wbpi_ack_w[S_WBPI_INVALIDDEV] = 0;
assign s_wbpi_mapsz_w[S_WBPI_INVALIDDEV] = ('h1000/* 4KB */);
always @ (posedge wbpi_clk_w) begin
	if (!wbpi_rst_w && s_wbpi_cyc_w[S_WBPI_INVALIDDEV]) begin
		$write("!!! s_wbpi_addr_w[S_WBPI_INVALIDDEV] == 0x%x\n",
			{{WBPI_CLOG2ARCHBITSZBY8{1'b0}}, s_wbpi_addr_w[S_WBPI_INVALIDDEV]}<<WBPI_CLOG2ARCHBITSZBY8);
		$fflush(1);
		$finish;
	end
end

endmodule
