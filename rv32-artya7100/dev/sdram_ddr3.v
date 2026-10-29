// SPDX-License-Identifier: GPL-2.0-only
// 20261028 (c) William Fonkou Tambe

// DDR3 SDRAM peripheral of the Arty A7-100T: its DDR3 SDRAM of 256 MiB, an
// MT41K128M16, through litedram, which LiteX generated in
// rv32-artya7100/litedram/litedram.v, behind a data cache of 32 KiB when
// USECACHE is non-null; and the registers of litedram, which litedram_init()
// of rv32-artya7100/litedram/litedram.c uses to initialize and calibrate it.
//
// The memory interface maps the DDR3 SDRAM, which is MAPSZ bytes, and the
// control interface maps the registers of litedram, which are CTRLMAPSZ bytes;
// the address of each interface is relative to the beginning of its mapping,
// as the interconnect gives it.
//
// litedram derives from "clk_i", using its own PLL, the clocks of its
// controller and of its PHY; the clock of its controller is "clk_o", which
// clocks both interfaces and every other logic of this module, as litedram
// makes no clock domain crossing; hence "clk_o" is meant to be the clock of
// the system. "rst_o" is high until "clk_o" is stable, and is meant to be a
// part of the reset of the system. The power-on reset of litedram, which
// resets its PLL, lasts 255 clock cycles of "clk_i" from the configuration of
// the FPGA, hence "clk_i" must be stable from then on, ie: the oscillator of
// the board.
//
// litedram is not reset by "rst_i", the reset of the system, so that the
// content of the DDR3 SDRAM survives it: nothing resets litedram but its
// power-on reset, and the loss of the lock of its PLL. A request presented to
// litedram while "rst_i" goes high is completed, and its acknowledgement is
// dropped, as lib/wb_classic.sv describes. Every other logic of this module
// is reset by "rst_i", the data cache included, which discards its content,
// dirty data included; hence, with the data cache, data meant to survive the
// reset of the system are to be written using atomic memory operations: the
// data cache carries the bus lock, and forwards to litedram the locked access
// and the access which follows it, ie: the read and the write of an atomic
// memory operation, hence it writes them through. Without the data cache,
// every write which the memory interface accepts reaches the DDR3 SDRAM, and
// "wb_lock_i" is unused.
//
// The user port of litedram is not gated by its initialization: litedram is
// generated with "block_until_ready" false, so it accepts an access whatever
// init_done, and completes it on the DDR3 SDRAM as it is; the control
// interface is unaffected. The SoC relies on bootldr initializing and
// calibrating the DDR3 SDRAM before any access to the memory interface:
// litedram_init() fails, setting init_error, when the read leveling finds no
// read window for a module, which stops bootldr. A reset of litedram, ie:
// after a loss of the lock of its PLL, resets the system, the bitslips of its
// PHY, and the DDR3 SDRAM itself, as its PHY holds the reset of the DDR3 SDRAM
// low meanwhile; nothing initializes it again: the next accesses complete on
// the uninitialized DDR3 SDRAM, whose content is then undefined.
//
// The data cache is dCache of cpu/dcache.sv: direct-mapped, write-back, and
// write-allocate, with a word of 128 bits per set, which is the width of the
// user port of litedram, which it accesses one word at a time. Its 2048 sets
// make 32 KiB, in block rams: the tag, which is 14 bits for the 256 MiB of the
// DDR3 SDRAM, takes one of 2048x18, the valid bits of the bytes one of
// 2048x18, the dirty bits one of 2048x1, and the data, which it writes a word
// at a time, fifteen of 2048x9, ie: two block rams of 36 Kb and sixteen of
// 18 Kb. The interfaces of this module are WORDBITSZ wide, and
// lib/wb_upsizr.sv adapts them to the user port of litedram when WORDBITSZ is
// 32 or 64. With the data cache, lib/wb_skidbuf.sv precedes lib/wb_upsizr.sv,
// so that the busy signal of the data cache, which is combinational from its
// tag compare, does not reach the interconnect; without it, neither is
// instantiated: the busy signal of the memory interface is then from registers
// only, those of lib/wb_upsizr.sv and lib/wb_classic.sv, which takes one
// access at a time. Without the data cache, the orphan gating of
// lib/wb_classic.sv is what keeps an acknowledgement from litedram, after a
// reset, from the interconnect; with it, the cache also ignores one during the
// walk which invalidates its sets after a reset.

// Parameters:
//
// WORDBITSZ
// 	Width of the data bus of the memory interface in bits.
// 	Must be 32, 64 or 128; the control interface is 32 bits wide.
//
// USECACHE
// 	When non-null, the data cache of 32 KiB is used, preceded by
// 	lib/wb_skidbuf.sv; otherwise neither is instantiated.

// Ports:
//
// rst_i
// 	Reset of the system: when held high at the rising edge of "clk_o",
// 	every logic of this module but litedram resets.
// 	It must be held low for normal operation.
//
// clk_i
// 	Clock from which litedram derives "clk_o"; it must be a 100 MHz
// 	clock which is stable from the configuration of the FPGA.
//
// clk_o
// 	Clock of the interfaces.
//
// rst_o
// 	High until "clk_o" is stable.
//
// wb_stb_i
// wb_lock_i
// wb_we_i
// wb_addr_i
// wb_sel_i
// wb_dat_i
// wb_bsy_o
// wb_ack_o
// wb_dat_o
// 	Slave memory interface, mapping the DDR3 SDRAM.
//
// wb_ctrl_stb_i
// wb_ctrl_we_i
// wb_ctrl_addr_i
// wb_ctrl_sel_i
// wb_ctrl_dat_i
// wb_ctrl_bsy_o
// wb_ctrl_ack_o
// wb_ctrl_dat_o
// 	Slave memory interface, mapping the registers of litedram.
//
// ddr3_*
// 	Signals of the DDR3 SDRAM.

`include "lib/wb_skidbuf.sv"
`include "lib/wb_upsizr.sv"
`include "lib/wb_classic.sv"
`include "cpu/dcache.sv"

`include "rv32-artya7100/litedram/litedram.v"

module sdram_ddr3 (

	 rst_i

	,clk_i

	,clk_o
	,rst_o

	,wb_stb_i
	,wb_lock_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,wb_ctrl_stb_i
	,wb_ctrl_we_i
	,wb_ctrl_addr_i
	,wb_ctrl_sel_i
	,wb_ctrl_dat_i
	,wb_ctrl_bsy_o
	,wb_ctrl_ack_o
	,wb_ctrl_dat_o

	,ddr3_ck_p
	,ddr3_ck_n
	,ddr3_cke
	,ddr3_odt
	,ddr3_cs_n
	,ddr3_ras_n
	,ddr3_cas_n
	,ddr3_we_n
	,ddr3_reset_n
	,ddr3_ba
	,ddr3_addr
	,ddr3_dm
	,ddr3_dq
	,ddr3_dqs_p
	,ddr3_dqs_n
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter USECACHE = 0;

localparam MAPSZ     = 'h10000000; // The 256 MiB of the DDR3 SDRAM.
localparam CTRLMAPSZ = 'h10000;    // The registers of litedram.

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ)-1);

// The user port of litedram, which the data cache uses.
localparam DRAMWORDBITSZ = 128;
localparam CLOG2DRAMWORDBITSZBY8 = clog2(DRAMWORDBITSZ/8);
localparam DRAMADDRBITSZ = (DRAMWORDBITSZ-CLOG2DRAMWORDBITSZBY8);
localparam DRAMMSBSZIGN = (DRAMWORDBITSZ-clog2(MAPSZ)-1);

localparam DRAMCACHESETCNT = 2048; // 32 KiB.

// The control interface, 32 bits wide as the registers of litedram.
localparam CTRLWORDBITSZ = 32;
localparam CLOG2CTRLWORDBITSZBY8 = clog2(CTRLWORDBITSZ/8);
localparam CTRLADDRBITSZ = (CTRLWORDBITSZ-CLOG2CTRLWORDBITSZBY8);
localparam CTRLMSBSZIGN = (CTRLWORDBITSZ-clog2(CTRLMAPSZ)-1);

input wire rst_i;

input wire clk_i;

output wire clk_o;
output wire rst_o;

input  wire                               wb_stb_i;
input  wire                               wb_lock_i;
input  wire                               wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output wire                               wb_ack_o;
output wire [WORDBITSZ -1 : 0]            wb_dat_o;

input  wire                                       wb_ctrl_stb_i;
input  wire                                       wb_ctrl_we_i;
input  wire [(CTRLADDRBITSZ-CTRLMSBSZIGN) -1 : 0] wb_ctrl_addr_i;
input  wire [(CTRLWORDBITSZ/8) -1 : 0]            wb_ctrl_sel_i;
input  wire [CTRLWORDBITSZ -1 : 0]                wb_ctrl_dat_i;
output wire                                       wb_ctrl_bsy_o;
output wire                                       wb_ctrl_ack_o;
output wire [CTRLWORDBITSZ -1 : 0]                wb_ctrl_dat_o;

output wire             ddr3_ck_p;
output wire             ddr3_ck_n;
output wire             ddr3_cke;
output wire             ddr3_odt;
output wire             ddr3_cs_n;
output wire             ddr3_ras_n;
output wire             ddr3_cas_n;
output wire             ddr3_we_n;
output wire             ddr3_reset_n;
output wire [3 -1 : 0]  ddr3_ba;
output wire [14 -1 : 0] ddr3_addr;
output wire [2 -1 : 0]  ddr3_dm;
inout  wire [16 -1 : 0] ddr3_dq;
inout  wire [2 -1 : 0]  ddr3_dqs_p;
inout  wire [2 -1 : 0]  ddr3_dqs_n;

generate if (WORDBITSZ != 32 && WORDBITSZ != 64 && WORDBITSZ != DRAMWORDBITSZ) begin :gen_wordbitsz_error
	$error("sdram_ddr3: WORDBITSZ must be 32, 64 or 128, the width of the user port of litedram");
end endgenerate

wire                               skidbuf_stb_w;
wire                               skidbuf_lock_w;
wire                               skidbuf_we_w;
wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] skidbuf_addr_w;
wire [(WORDBITSZ/8) -1 : 0]        skidbuf_sel_w;
wire [WORDBITSZ -1 : 0]            skidbuf_dat_w;
wire                               skidbuf_bsy_w;
wire                               skidbuf_ack_w;
wire [WORDBITSZ -1 : 0]            skidbuf_dat_w_;

// Without the data cache, the signals of the memory interface are those of
// lib/wb_upsizr.sv, whose busy signal is from registers.
generate if (USECACHE) begin :gen_skidbuf

wb_skidbuf #(
	 .WORDBITSZ   (WORDBITSZ)
	,.ADDRLIMIT   (MAPSZ)
	,.DEPTH       (4)
	,.USEFWFTFIFO (1)
) wb_skidbuf (

	 .rst_i (rst_i)

	,.clk_i (clk_o)

	,.m_wb_stb_i  (wb_stb_i)
	,.m_wb_lock_i (wb_lock_i)
	,.m_wb_we_i   (wb_we_i)
	,.m_wb_addr_i (wb_addr_i)
	,.m_wb_sel_i  (wb_sel_i)
	,.m_wb_dat_i  (wb_dat_i)
	,.m_wb_bsy_o  (wb_bsy_o)
	,.m_wb_ack_o  (wb_ack_o)
	,.m_wb_dat_o  (wb_dat_o)
	,.m_wb_bsy_i  (1'b0)
	,.m_wb_ack_avail_o ()

	,.s_wb_stb_o  (skidbuf_stb_w)
	,.s_wb_lock_o (skidbuf_lock_w)
	,.s_wb_we_o   (skidbuf_we_w)
	,.s_wb_addr_o (skidbuf_addr_w)
	,.s_wb_sel_o  (skidbuf_sel_w)
	,.s_wb_dat_o  (skidbuf_dat_w)
	,.s_wb_bsy_i  (skidbuf_bsy_w)
	,.s_wb_ack_i  (skidbuf_ack_w)
	,.s_wb_dat_i  (skidbuf_dat_w_)
);

end else begin :gen_noskidbuf

assign skidbuf_stb_w = wb_stb_i;
assign skidbuf_lock_w = wb_lock_i;
assign skidbuf_we_w = wb_we_i;
assign skidbuf_addr_w = wb_addr_i;
assign skidbuf_sel_w = wb_sel_i;
assign skidbuf_dat_w = wb_dat_i;
assign wb_bsy_o = skidbuf_bsy_w;
assign wb_ack_o = skidbuf_ack_w;
assign wb_dat_o = skidbuf_dat_w_;

end endgenerate

wire                                       dcache_stb_w;
wire                                       dcache_lock_w;
wire                                       dcache_we_w;
wire [(DRAMADDRBITSZ-DRAMMSBSZIGN) -1 : 0] dcache_addr_w;
wire [(DRAMWORDBITSZ/8) -1 : 0]            dcache_sel_w;
wire [DRAMWORDBITSZ -1 : 0]                dcache_dat_w;
wire                                       dcache_bsy_w;
wire                                       dcache_ack_w;
wire [DRAMWORDBITSZ -1 : 0]                dcache_dat_w_;

wb_upsizr #(
	 .MWORDBITSZ    (WORDBITSZ)
	,.SWORDBITSZ    (DRAMWORDBITSZ)
	,.ADDRLIMIT     (MAPSZ)
	,.MAXPENDINGACK (4)
	,.USEFWFTFIFO   (1)
) wb_upsizr (

	 .rst_i (rst_i)

	,.clk_i (clk_o)

	,.m_wb_stb_i  (skidbuf_stb_w)
	,.m_wb_lock_i (skidbuf_lock_w)
	,.m_wb_we_i   (skidbuf_we_w)
	,.m_wb_addr_i (skidbuf_addr_w)
	,.m_wb_sel_i  (skidbuf_sel_w)
	,.m_wb_dat_i  (skidbuf_dat_w)
	,.m_wb_bsy_o  (skidbuf_bsy_w)
	,.m_wb_ack_o  (skidbuf_ack_w)
	,.m_wb_dat_o  (skidbuf_dat_w_)

	,.s_wb_stb_o  (dcache_stb_w)
	,.s_wb_lock_o (dcache_lock_w)
	,.s_wb_we_o   (dcache_we_w)
	,.s_wb_addr_o (dcache_addr_w)
	,.s_wb_sel_o  (dcache_sel_w)
	,.s_wb_dat_o  (dcache_dat_w)
	,.s_wb_bsy_i  (dcache_bsy_w)
	,.s_wb_ack_i  (dcache_ack_w)
	,.s_wb_dat_i  (dcache_dat_w_)
);

wire                                       classic_stb_w;
wire                                       classic_we_w;
wire [(DRAMADDRBITSZ-DRAMMSBSZIGN) -1 : 0] classic_addr_w;
wire [(DRAMWORDBITSZ/8) -1 : 0]            classic_sel_w;
wire [DRAMWORDBITSZ -1 : 0]                classic_dat_w;
wire                                       classic_bsy_w;
wire                                       classic_ack_w;
wire [DRAMWORDBITSZ -1 : 0]                classic_dat_w_;

generate if (USECACHE) begin :gen_dcache

// The data cache acknowledges its master from registers, as its acknowledgement
// is otherwise combinational from its tag compare; the acknowledgement and the
// data read from litedram are registered by lib/wb_classic.sv; and it makes one
// access at a time, as lib/wb_classic.sv takes one at a time.
dCache #(
	 .WORDBITSZ     (DRAMWORDBITSZ)
	,.ADDRLIMIT     (MAPSZ)
	,.CACHESETCNT   (DRAMCACHESETCNT)
	,.CACHEWAYCNT   (1)
	,.REGMSTOUTPUT  (1)
	,.REGSLVINPUT   (0)
	,.MAXPENDINGACK (0)
) dcache (

	 .rst_i (rst_i)

	,.clk_i (clk_o)

	,.conly_i (1'b0)
	,.cmiss_i (1'b0)

	,.m_wb_stb_i  (dcache_stb_w)
	,.m_wb_lock_i (dcache_lock_w)
	,.m_wb_we_i   (dcache_we_w)
	,.m_wb_addr_i (dcache_addr_w)
	,.m_wb_sel_i  (dcache_sel_w)
	,.m_wb_dat_i  (dcache_dat_w)
	,.m_wb_bsy_o  (dcache_bsy_w)
	,.m_wb_ack_o  (dcache_ack_w)
	,.m_wb_dat_o  (dcache_dat_w_)

	,.s_wb_stb_o  (classic_stb_w)
	,.s_wb_lock_o ()
	,.s_wb_we_o   (classic_we_w)
	,.s_wb_addr_o (classic_addr_w)
	,.s_wb_sel_o  (classic_sel_w)
	,.s_wb_dat_o  (classic_dat_w)
	,.s_wb_bsy_i  (classic_bsy_w)
	,.s_wb_ack_i  (classic_ack_w)
	,.s_wb_dat_i  (classic_dat_w_)

	,.coherency_en_i (1'b0)

	,.coherency_stb_i  (1'b0)
	,.coherency_rqid_i (1'b0)
	,.coherency_we_i   (1'b0)
	,.coherency_addr_i ({(DRAMADDRBITSZ-DRAMMSBSZIGN){1'b0}})
	,.coherency_sel_i  ({(DRAMWORDBITSZ/8){1'b0}})
	,.coherency_dat_i  ({DRAMWORDBITSZ{1'b0}})
	,.coherency_shr_i  (1'b0)
	,.coherency_bsy_o  ()

	,.coherency_stb_o  ()
	,.coherency_rqid_o ()
	,.coherency_we_o   ()
	,.coherency_addr_o ()
	,.coherency_sel_o  ()
	,.coherency_dat_o  ()
	,.coherency_shr_o  ()
	,.coherency_bsy_i  (1'b0)
);

end else begin :gen_nodcache

// lib/wb_classic.sv straight behind lib/wb_upsizr.sv; the bus lock is unused.
assign classic_stb_w = dcache_stb_w;
assign classic_we_w = dcache_we_w;
assign classic_addr_w = dcache_addr_w;
assign classic_sel_w = dcache_sel_w;
assign classic_dat_w = dcache_dat_w;
assign dcache_bsy_w = classic_bsy_w;
assign dcache_ack_w = classic_ack_w;
assign dcache_dat_w_ = classic_dat_w_;

end endgenerate

wire                                       dram_cyc_w;
wire                                       dram_stb_w;
wire                                       dram_we_w;
wire [(DRAMADDRBITSZ-DRAMMSBSZIGN) -1 : 0] dram_addr_w;
wire [(DRAMWORDBITSZ/8) -1 : 0]            dram_sel_w;
wire [DRAMWORDBITSZ -1 : 0]                dram_dat_w;
wire                                       dram_ack_w;
wire [DRAMWORDBITSZ -1 : 0]                dram_dat_w_;

wb_classic #(
	 .WORDBITSZ (DRAMWORDBITSZ)
	,.ADDRLIMIT (MAPSZ)
) wb_classic (

	 .rst_i (rst_i)

	,.clk_i (clk_o)

	,.m_wb_stb_i  (classic_stb_w)
	,.m_wb_we_i   (classic_we_w)
	,.m_wb_addr_i (classic_addr_w)
	,.m_wb_sel_i  (classic_sel_w)
	,.m_wb_dat_i  (classic_dat_w)
	,.m_wb_bsy_o  (classic_bsy_w)
	,.m_wb_ack_o  (classic_ack_w)
	,.m_wb_dat_o  (classic_dat_w_)

	,.s_wb_cyc_o  (dram_cyc_w)
	,.s_wb_stb_o  (dram_stb_w)
	,.s_wb_we_o   (dram_we_w)
	,.s_wb_addr_o (dram_addr_w)
	,.s_wb_sel_o  (dram_sel_w)
	,.s_wb_dat_o  (dram_dat_w)
	,.s_wb_ack_i  (dram_ack_w)
	,.s_wb_dat_i  (dram_dat_w_)
);

wire                                       ctrl_cyc_w;
wire                                       ctrl_stb_w;
wire                                       ctrl_we_w;
wire [(CTRLADDRBITSZ-CTRLMSBSZIGN) -1 : 0] ctrl_addr_w;
wire [(CTRLWORDBITSZ/8) -1 : 0]            ctrl_sel_w;
wire [CTRLWORDBITSZ -1 : 0]                ctrl_dat_w;
wire                                       ctrl_ack_w;
wire [CTRLWORDBITSZ -1 : 0]                ctrl_dat_w_;

wb_classic #(
	 .WORDBITSZ (CTRLWORDBITSZ)
	,.ADDRLIMIT (CTRLMAPSZ)
) wb_classic_ctrl (

	 .rst_i (rst_i)

	,.clk_i (clk_o)

	,.m_wb_stb_i  (wb_ctrl_stb_i)
	,.m_wb_we_i   (wb_ctrl_we_i)
	,.m_wb_addr_i (wb_ctrl_addr_i)
	,.m_wb_sel_i  (wb_ctrl_sel_i)
	,.m_wb_dat_i  (wb_ctrl_dat_i)
	,.m_wb_bsy_o  (wb_ctrl_bsy_o)
	,.m_wb_ack_o  (wb_ctrl_ack_o)
	,.m_wb_dat_o  (wb_ctrl_dat_o)

	,.s_wb_cyc_o  (ctrl_cyc_w)
	,.s_wb_stb_o  (ctrl_stb_w)
	,.s_wb_we_o   (ctrl_we_w)
	,.s_wb_addr_o (ctrl_addr_w)
	,.s_wb_sel_o  (ctrl_sel_w)
	,.s_wb_dat_o  (ctrl_dat_w)
	,.s_wb_ack_i  (ctrl_ack_w)
	,.s_wb_dat_i  (ctrl_dat_w_)
);

// Power-on reset of litedram, high for 255 clock cycles of "clk_i" from the
// configuration of the FPGA, and never again, as "rst_i" must not reset litedram;
// litedram lengthens it through 8 registers clocked by "clk_i", which reset its
// PLL, and makes its own reset high until its PLL is locked.
reg [8 -1 : 0] litedram_rst_r = {8{1'b1}};
always_ff @(posedge clk_i) begin
	if (|litedram_rst_r)
		litedram_rst_r <= litedram_rst_r - 1'b1;
end

litedram litedram (

	 .rst (|litedram_rst_r)

	,.clk (clk_i)

	,.pll_locked ()
	,.init_done  ()
	,.init_error ()

	,.ddram_a       (ddr3_addr)
	,.ddram_ba      (ddr3_ba)
	,.ddram_ras_n   (ddr3_ras_n)
	,.ddram_cas_n   (ddr3_cas_n)
	,.ddram_we_n    (ddr3_we_n)
	,.ddram_cs_n    (ddr3_cs_n)
	,.ddram_dm      (ddr3_dm)
	,.ddram_dq      (ddr3_dq)
	,.ddram_dqs_p   (ddr3_dqs_p)
	,.ddram_dqs_n   (ddr3_dqs_n)
	,.ddram_clk_p   (ddr3_ck_p)
	,.ddram_clk_n   (ddr3_ck_n)
	,.ddram_cke     (ddr3_cke)
	,.ddram_odt     (ddr3_odt)
	,.ddram_reset_n (ddr3_reset_n)

	,.user_clk (clk_o)
	,.user_rst (rst_o)

	,.user_port_wishbone_0_cyc   (dram_cyc_w)
	,.user_port_wishbone_0_stb   (dram_stb_w)
	,.user_port_wishbone_0_we    (dram_we_w)
	,.user_port_wishbone_0_adr   (dram_addr_w[24 -1 : 0])
	,.user_port_wishbone_0_sel   (dram_sel_w)
	,.user_port_wishbone_0_dat_w (dram_dat_w)
	,.user_port_wishbone_0_ack   (dram_ack_w)
	,.user_port_wishbone_0_dat_r (dram_dat_w_)
	,.user_port_wishbone_0_err   ()

	,.wb_ctrl_cyc   (ctrl_cyc_w)
	,.wb_ctrl_stb   (ctrl_stb_w)
	,.wb_ctrl_we    (ctrl_we_w)
	,.wb_ctrl_adr   (30'(ctrl_addr_w))
	,.wb_ctrl_sel   (ctrl_sel_w)
	,.wb_ctrl_dat_w (ctrl_dat_w)
	,.wb_ctrl_ack   (ctrl_ack_w)
	,.wb_ctrl_dat_r (ctrl_dat_w_)
	,.wb_ctrl_cti   (3'b000)
	,.wb_ctrl_bte   (2'b00)
	,.wb_ctrl_err   ()
);

endmodule
