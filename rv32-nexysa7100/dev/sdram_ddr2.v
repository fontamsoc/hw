// SPDX-License-Identifier: GPL-2.0-only
// 20261020 (c) William Fonkou Tambe

// DDR2 SDRAM peripheral of the Nexys A7: its DDR2 SDRAM of 128 MiB, an
// MT47H64M16, through litedram, which LiteX generated in
// rv32-nexysa7100/litedram/litedram.v, behind a data cache of 32 KiB when
// USECACHE is non-null; and the registers of litedram, which litedram_init()
// of rv32-nexysa7100/litedram/litedram.c uses to initialize and calibrate it.
//
// The memory interface maps the DDR2 SDRAM, which is MAPSZ bytes, and the
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
// content of the DDR2 SDRAM survives it: nothing resets litedram but its
// power-on reset, and the loss of the lock of its PLL. The accesses which the
// memory interface has accepted when "rst_i" goes high are completed, and
// their acknowledgements dropped, as lib/wb_litedram.sv describes; those of
// the control interface as lib/wb_classic.sv describes. Every other logic of
// this module is reset by "rst_i", the data cache included, which discards
// its content, dirty data included; hence, with the data cache, data meant to
// survive the reset of the system are to be written using atomic memory
// operations: the data cache carries the bus lock, and forwards to litedram
// the locked access and the access which follows it, ie: the read and the
// write of an atomic memory operation, hence it writes them through. Without
// the data cache, every write which the memory interface accepts reaches the
// DDR2 SDRAM, unless litedram is reset meanwhile, and "wb_lock_i" is unused.
//
// The user port of litedram is not gated by its initialization: litedram is
// generated with "block_until_ready" false, so it accepts an access whatever
// init_done, and completes it on the DDR2 SDRAM as it is; the control
// interface is unaffected. The SoC relies on bootldr initializing and
// calibrating the DDR2 SDRAM before any access to the memory interface:
// litedram_init() fails, setting init_error, when the read leveling finds no
// read window for a module, which stops bootldr. A reset of litedram, ie:
// after a loss of the lock of its PLL, resets the system and the bitslips of
// its PHY, which nothing calibrates again: the next accesses complete on the
// uncalibrated DDR2 SDRAM, while those which litedram and lib/wb_litedram.sv
// held are discarded, unacknowledged, their masters being reset with the
// system.
//
// The data cache is dCache of cpu/dcache.sv: direct-mapped, write-back, and
// write-allocate, with a word of 64 bits per set, which is the width of the
// user port of litedram, which it accesses one word at a time. Its 4096 sets
// make 32 KiB, in block rams which they fill: the tag, which is 13 bits for
// the 128 MiB of the DDR2 SDRAM, takes a block ram of 4096x9 and one of
// 4096x4, the valid bits of the bytes take one of 4096x9, and the data take
// eight of 4096x9; whereas 16 KiB would take a tag of 14 bits, which would
// leave 4 bits of the block ram of 2048x18 which it would take unused. The
// interfaces of this module are WORDBITSZ wide, and lib/wb_upsizr.sv adapts
// them to the user port of litedram when WORDBITSZ is 32. With the data
// cache, lib/wb_skidbuf.sv precedes lib/wb_upsizr.sv, so that the busy signal
// of the data cache, which is combinational from its tag compare, does not
// reach the interconnect; without it, neither is instantiated: the busy
// signal of the memory interface is then from registers only, those of
// lib/wb_upsizr.sv and lib/wb_litedram.sv, which hold up to DRAMMAXPENDINGACK
// accesses: 8, the depth of the command buffer of each bank of litedram, its
// "cmd_buffer_depth", which they thus never fill, so that litedram takes
// their commands as they come, but while it holds commands for another bank.
// The orphan count of lib/wb_litedram.sv keeps the acknowledgements from
// litedram, after a reset, from the data cache or the interconnect, whose
// counts of pending acknowledgements a stray one would corrupt, the data cache
// not ignoring one during the walk which invalidates its sets after a reset.

// Parameters:
//
// WORDBITSZ
// 	Width of the data bus of the memory interface in bits.
// 	Must be 32 or 64; the control interface is 32 bits wide.
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
// 	Slave memory interface, mapping the DDR2 SDRAM.
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
// ddr2_*
// 	Signals of the DDR2 SDRAM.

`include "lib/wb_skidbuf.sv"
`include "lib/wb_upsizr.sv"
`include "lib/wb_litedram.sv"
`include "lib/wb_classic.sv"
`include "cpu/dcache.sv"

`include "rv32-nexysa7100/litedram/litedram.v"

module sdram_ddr2 (

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

	,ddr2_ck_p
	,ddr2_ck_n
	,ddr2_cke
	,ddr2_odt
	,ddr2_cs_n
	,ddr2_ras_n
	,ddr2_cas_n
	,ddr2_we_n
	,ddr2_ba
	,ddr2_addr
	,ddr2_dm
	,ddr2_dq
	,ddr2_dqs_p
	,ddr2_dqs_n
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter USECACHE = 0;

localparam MAPSZ     = 'h8000000; // The 128 MiB of the DDR2 SDRAM.
localparam CTRLMAPSZ = 'h10000;   // The registers of litedram.

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ)-1);

// The user port of litedram, which the data cache uses.
localparam DRAMWORDBITSZ = 64;
localparam CLOG2DRAMWORDBITSZBY8 = clog2(DRAMWORDBITSZ/8);
localparam DRAMADDRBITSZ = (DRAMWORDBITSZ-CLOG2DRAMWORDBITSZBY8);
localparam DRAMMSBSZIGN = (DRAMWORDBITSZ-clog2(MAPSZ)-1);

// The accesses which lib/wb_upsizr.sv and lib/wb_litedram.sv hold at most:
// the cmd_buffer_depth of litedram.
localparam DRAMMAXPENDINGACK = 8;

localparam DRAMCACHESETCNT = 4096; // 32 KiB.

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

output wire            ddr2_ck_p;
output wire            ddr2_ck_n;
output wire            ddr2_cke;
output wire            ddr2_odt;
output wire            ddr2_cs_n;
output wire            ddr2_ras_n;
output wire            ddr2_cas_n;
output wire            ddr2_we_n;
output wire [3 -1 : 0]  ddr2_ba;
output wire [13 -1 : 0] ddr2_addr;
output wire [2 -1 : 0]  ddr2_dm;
inout  wire [16 -1 : 0] ddr2_dq;
inout  wire [2 -1 : 0]  ddr2_dqs_p;
inout  wire [2 -1 : 0]  ddr2_dqs_n;

generate if (WORDBITSZ != 32 && WORDBITSZ != DRAMWORDBITSZ) begin :gen_wordbitsz_error
	$error("sdram_ddr2: WORDBITSZ must be 32 or 64, the width of the user port of litedram");
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
	,.MAXPENDINGACK (DRAMMAXPENDINGACK)
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

wire                                       bridge_stb_w;
wire                                       bridge_we_w;
wire [(DRAMADDRBITSZ-DRAMMSBSZIGN) -1 : 0] bridge_addr_w;
wire [(DRAMWORDBITSZ/8) -1 : 0]            bridge_sel_w;
wire [DRAMWORDBITSZ -1 : 0]                bridge_dat_w;
wire                                       bridge_bsy_w;
wire                                       bridge_ack_w;
wire [DRAMWORDBITSZ -1 : 0]                bridge_dat_w_;

generate if (USECACHE) begin :gen_dcache

// The data cache acknowledges its master from registers, as its acknowledgement
// is otherwise combinational from its tag compare; the acknowledgement and the
// data read from litedram are registered by lib/wb_litedram.sv. It posts its
// writes: its count of pending acknowledgements covers what the bridge holds.
dCache #(
	 .WORDBITSZ     (DRAMWORDBITSZ)
	,.ADDRLIMIT     (MAPSZ)
	,.CACHESETCNT   (DRAMCACHESETCNT)
	,.CACHEWAYCNT   (1)
	,.REGMSTOUTPUT  (1)
	,.REGSLVINPUT   (0)
	,.MAXPENDINGACK (DRAMMAXPENDINGACK)
) dcache (

	 .rst_i (rst_i)

	,.clk_i (clk_o)

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

	,.s_wb_stb_o  (bridge_stb_w)
	,.s_wb_lock_o ()
	,.s_wb_we_o   (bridge_we_w)
	,.s_wb_addr_o (bridge_addr_w)
	,.s_wb_sel_o  (bridge_sel_w)
	,.s_wb_dat_o  (bridge_dat_w)
	,.s_wb_bsy_i  (bridge_bsy_w)
	,.s_wb_ack_i  (bridge_ack_w)
	,.s_wb_dat_i  (bridge_dat_w_)

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

// lib/wb_litedram.sv straight behind lib/wb_upsizr.sv; the bus lock is unused.
assign bridge_stb_w = dcache_stb_w;
assign bridge_we_w = dcache_we_w;
assign bridge_addr_w = dcache_addr_w;
assign bridge_sel_w = dcache_sel_w;
assign bridge_dat_w = dcache_dat_w;
assign dcache_bsy_w = bridge_bsy_w;
assign dcache_ack_w = bridge_ack_w;
assign dcache_dat_w_ = bridge_dat_w_;

end endgenerate

wire                                       dram_cmd_valid_w;
wire                                       dram_cmd_ready_w;
wire                                       dram_cmd_we_w;
wire [(DRAMADDRBITSZ-DRAMMSBSZIGN) -1 : 0] dram_cmd_addr_w;
wire                                       dram_wdata_valid_w;
wire                                       dram_wdata_ready_w;
wire [(DRAMWORDBITSZ/8) -1 : 0]            dram_wdata_we_w;
wire [DRAMWORDBITSZ -1 : 0]                dram_wdata_data_w;
wire                                       dram_rdata_valid_w;
wire                                       dram_rdata_ready_w;
wire [DRAMWORDBITSZ -1 : 0]                dram_rdata_data_w;

// "rst_o", the reset of litedram, which discards the commands litedram holds,
// discards those which the bridge holds too.
wb_litedram #(
	 .WORDBITSZ     (DRAMWORDBITSZ)
	,.ADDRLIMIT     (MAPSZ)
	,.MAXPENDINGACK (DRAMMAXPENDINGACK)
) wb_litedram (

	 .rst_i   (rst_i)
	,.s_rst_i (rst_o)

	,.clk_i (clk_o)

	,.m_wb_stb_i  (bridge_stb_w)
	,.m_wb_we_i   (bridge_we_w)
	,.m_wb_addr_i (bridge_addr_w)
	,.m_wb_sel_i  (bridge_sel_w)
	,.m_wb_dat_i  (bridge_dat_w)
	,.m_wb_bsy_o  (bridge_bsy_w)
	,.m_wb_ack_o  (bridge_ack_w)
	,.m_wb_dat_o  (bridge_dat_w_)

	,.s_cmd_valid_o   (dram_cmd_valid_w)
	,.s_cmd_ready_i   (dram_cmd_ready_w)
	,.s_cmd_we_o      (dram_cmd_we_w)
	,.s_cmd_addr_o    (dram_cmd_addr_w)
	,.s_wdata_valid_o (dram_wdata_valid_w)
	,.s_wdata_ready_i (dram_wdata_ready_w)
	,.s_wdata_we_o    (dram_wdata_we_w)
	,.s_wdata_data_o  (dram_wdata_data_w)
	,.s_rdata_valid_i (dram_rdata_valid_w)
	,.s_rdata_ready_o (dram_rdata_ready_w)
	,.s_rdata_data_i  (dram_rdata_data_w)
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

	,.ddram_a       (ddr2_addr)
	,.ddram_ba      (ddr2_ba)
	,.ddram_ras_n   (ddr2_ras_n)
	,.ddram_cas_n   (ddr2_cas_n)
	,.ddram_we_n    (ddr2_we_n)
	,.ddram_cs_n    (ddr2_cs_n)
	,.ddram_dm      (ddr2_dm)
	,.ddram_dq      (ddr2_dq)
	,.ddram_dqs_p   (ddr2_dqs_p)
	,.ddram_dqs_n   (ddr2_dqs_n)
	,.ddram_clk_p   (ddr2_ck_p)
	,.ddram_clk_n   (ddr2_ck_n)
	,.ddram_cke     (ddr2_cke)
	,.ddram_odt     (ddr2_odt)
	,.ddram_reset_n ()

	,.user_clk (clk_o)
	,.user_rst (rst_o)

	,.user_port_native_0_cmd_valid   (dram_cmd_valid_w)
	,.user_port_native_0_cmd_ready   (dram_cmd_ready_w)
	,.user_port_native_0_cmd_we      (dram_cmd_we_w)
	,.user_port_native_0_cmd_addr    (dram_cmd_addr_w[24 -1 : 0])
	,.user_port_native_0_wdata_valid (dram_wdata_valid_w)
	,.user_port_native_0_wdata_ready (dram_wdata_ready_w)
	,.user_port_native_0_wdata_we    (dram_wdata_we_w)
	,.user_port_native_0_wdata_data  (dram_wdata_data_w)
	,.user_port_native_0_rdata_valid (dram_rdata_valid_w)
	,.user_port_native_0_rdata_ready (dram_rdata_ready_w)
	,.user_port_native_0_rdata_data  (dram_rdata_data_w)

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
