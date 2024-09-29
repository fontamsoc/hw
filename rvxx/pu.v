// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Parameters:
//
// WORDBITSZ
// XWORDBITSZ
// 	TODO: Document ...
// 	TODO: XWORDBITSZ must be >= WORDBITSZ.
//
// CLKFREQ
// 	Frequency of the clock input "clk_i" in Hz.
//
// ICACHESETCNT
// 	Number of instruction cache set.
// 	Each cache set is WORDBITSZ bits.
// 	It must be at least 2, a power-of-2,
// 	and less than or equal to 2^(ADDRBITSZ-1).
//
// DCACHESETCNT
// 	Number of data cache set.
// 	Each cache set is WORDBITSZ bits.
// 	It must be at least 2, a power-of-2,
// 	and less than or equal to 2^(ADDRBITSZ-1).
//
// TLBSETCNT
// 	Number of tlb entries.
// 	It must be at least 2, a power-of-2,
// 	and less than or equal to 2^(PAGENUMBITSZ-1).
//
// ICACHEWAYCNT
// 	Number of icache ways.
// 	It must be non-null and a power-of-2.
//
// DCACHEWAYCNT
// 	Number of dcache ways.
// 	It must be non-null and a power-of-2.
//
// IMULCNT
// 	Number of units making up the imul pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal to 8.
//
// IDIVCNT
// 	Number of units making up the idiv pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal to 8.
//
// FADDFSUBCNT
// 	Number of units making up the faddfsub pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal to 2.
//
// FMULCNT
// 	Number of units making up the fmul pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal
// 	to 4 (ifdef PUFMULDSP) or 8.
//
// FDIVCNT
// 	Number of units making up the fdiv pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal to 8.
//
// MAXPENDINGACK
// 	TODO: Describe ...
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	When held high at the the clock signal posedge, the pu reset.
// 	It must be held low for the pu to begin executing instructions.
//
// clk_i
// 	Clock signal.
// clk_imul_i
// 	Clock signal used by imul.
// 	Its frequency must be a power-of-2 multiple of clk_i frequency.
// clk_idiv_i
// 	Clock signal used by idiv.
// 	Its frequency must be a power-of-2 multiple of clk_i frequency.
//
// wb_cyc_o
// wb_stb_o
// wb_we_o
// wb_addr_o
// wb_sel_o
// wb_dat_o
// wb_bsy_i
// wb_ack_i
// wb_dat_i
// 	Wishbone master memory interface.
//
// dcache_addr_o
// dcache_miss_i
// 	Signal dcache_miss_i must be combinationally set high
// 	if dcache_addr_o is an address that must not be cached.
//
// rstaddr_i
// 	Address where the pu begin executing instruction after reset.
// 	It is to be a 32bits address for which the least significant
// 	bit has been discarded.
//
// irq_stb_i
// 	When this signal is held high and the output irq_rdy_o is low,
// 	the pu execute an EXTINTR context-switch.
//
// irq_rdy_o
// 	When this signal is high, the pu is in usermode with interrupt
// 	enabled (ie: isflagdisextintr is false), and will execute
// 	an EXTINTR context-switch if the signal irq_stb_i become high.
//
// halted_o
// 	When this signal is high, the pu is halted with interrupt
// 	enabled (ie: isflagdisextintr is false), and will execute
// 	an EXTINTR context-switch if the signal irq_stb_i become high.
//
// id_i
// 	Index of the pu when used in a multi-pu configuration,
// 	otherwise must be 0.

`include "lib/fifo.v"
`include "lib/fifo_fwft.v"
`include "lib/icache.v"
`include "lib/wb_skidbuf.v"
`include "lib/dcache.v"
`include "lib/wb_upsizr.v"

`ifdef PURV32M
`include "./imul.v"
`include "./idiv.v"
`endif

module pu (

	 rst_i

	,rst_o

	,clk_i
	,clk_imul_i
	,clk_idiv_i

	,wb_cyc_o
	,wb_stb_o
	,wb_we_o
	,wb_addr_o
	,wb_sel_o
	,wb_dat_o
	,wb_bsy_i
	,wb_ack_i
	,wb_dat_i

	,dcache_addr_o
	,dcache_miss_i

	,irq_stb_i
	,irq_rdy_o
	,halted_o

	,rstaddr_i

	,id_i
);

`include "lib/clog2.v"

parameter WORDBITSZ     = 32;
parameter XWORDBITSZ    = 32; // TODO: Support all the way up to 1024 ...
parameter CLKFREQ       = 1;
parameter ICACHESETCNT  = 2;
parameter DCACHESETCNT  = 0;
parameter ICACHEWAYCNT  = 1;
parameter DCACHEWAYCNT  = 1;
parameter IMULCNT       = 2;
parameter IDIVCNT       = 2;
parameter MAXPENDINGACK = 16;

localparam USE_DCACHE = (DCACHESETCNT > 0);

localparam CLOG2WORDBITSZ = clog2(WORDBITSZ);
localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam CLOG2WORDBITSZBY16 = clog2(WORDBITSZ/16);
localparam ADDRBITSZ = (WORDBITSZ - CLOG2WORDBITSZBY8);

localparam CLOG2XWORDBITSZ = clog2(XWORDBITSZ);
localparam CLOG2XWORDBITSZBY8 = clog2(XWORDBITSZ/8);
localparam CLOG2XWORDBITSZBY16 = clog2(XWORDBITSZ/16);
localparam XADDRBITSZ = (XWORDBITSZ - CLOG2XWORDBITSZBY8);

localparam CLOG2XWORDBITSZBY8DIFF = (CLOG2XWORDBITSZBY8 - CLOG2WORDBITSZBY8);

localparam CLOG2ICACHESETCNT = clog2(ICACHESETCNT);
localparam CLOG2DCACHESETCNT = clog2(DCACHESETCNT);
localparam CLOG2ICACHEWAYCNT = clog2(ICACHEWAYCNT);

localparam CLOG2MAXPENDINGACK = clog2(MAXPENDINGACK);

localparam GPRCNT = 32;
localparam CLOG2GPRCNT = clog2(GPRCNT);

localparam INSNBITSZ = 32;
localparam CLOG2INSNBITSZBY8 = clog2(INSNBITSZ/8);

input wire rst_i;

output reg rst_o = 0;

input wire clk_i;
input wire clk_imul_i;
input wire clk_idiv_i;

output reg                          wb_cyc_o;  // ### comb-block-reg.
output reg                          wb_stb_o;  // ### comb-block-reg.
output reg                          wb_we_o;   // ### comb-block-reg.
output reg  [XADDRBITSZ -1 : 0]     wb_addr_o; // ### comb-block-reg.
output reg  [(XWORDBITSZ/8) -1 : 0] wb_sel_o;  // ### comb-block-reg.
output reg  [XWORDBITSZ -1 : 0]     wb_dat_o;  // ### comb-block-reg.
input  wire                         wb_bsy_i;
input  wire                         wb_ack_i;
input  wire [XWORDBITSZ -1 : 0]     wb_dat_i;

output wire [XWORDBITSZ -1 : 0] dcache_addr_o;
input  wire                     dcache_miss_i;

input  wire irq_stb_i;
output wire irq_rdy_o;
output reg  halted_o;

input wire [WORDBITSZ -1 : 0] rstaddr_i;

input wire [WORDBITSZ -1 : 0] id_i;

wire _wb_bsy_i;

////////////////////////////////////// IF (Instruction Fetch) stage /////////////////////////////////////

`include "./icache.pu.v"

reg iF_flushed_;
wire iF_flushed = (iF_flushed_ || !iCache_hit_w);

wire iF_iD_flushed;
wire iF_iD_stalled;
wire iF_iD_carryon;

wire iF_carryon = (iF_flushed || iF_iD_carryon);

wire iF_en = (iF_carryon && !halted_o);

wire                    iF_eX_JumpOrBranch_i;
wire [WORDBITSZ -1 : 0] iF_eX_JumpOrBranchAddr_i;

assign iCache_nxtway_w = iF_eX_JumpOrBranch_i;

assign iCache_re_w = iF_en;

`ifdef PUPREDICTRET
reg [WORDBITSZ -1 : 0] ras0;
reg [WORDBITSZ -1 : 0] ras1;
reg [WORDBITSZ -1 : 0] ras2;
reg [WORDBITSZ -1 : 0] ras3;
reg [WORDBITSZ -1 : 0] ras4;
reg [WORDBITSZ -1 : 0] ras5;
reg [WORDBITSZ -1 : 0] ras6;
reg [WORDBITSZ -1 : 0] ras7;
reg [WORDBITSZ -1 : 0] iD_predictRet;
`endif

`ifdef PUPREDICTJALR
// TODO: To be implemented like PUPREDICTRET using a BTB (Branch Target Buffer).
// TODO: When adding an entry to the BTB, skip RET which is "jalr x0, x1, 0",
// TODO: only add JALR for which (rs1Id != 1).
`endif

reg  [WORDBITSZ -1 : 0] iF_pc;
wire [WORDBITSZ -1 : 0] iF_pc_i;

assign iCache_ridx_w = iF_pc_i[CLOG2ICACHESETCNT+CLOG2XWORDBITSZBY8-1:CLOG2XWORDBITSZBY8];
assign iCache_rtag_w = iF_pc_i[WORDBITSZ-1:CLOG2ICACHESETCNT+CLOG2XWORDBITSZBY8];

`ifdef PUPREDICTBRANCH
reg [2 -1 : 0] iD_predictBranch;
localparam BHTSETCNT = 4096;
localparam CLOG2BHTSETCNT = clog2(BHTSETCNT);
reg [2 -1 : 0] bht [0 : BHTSETCNT - 1]; // Branch History Table.
reg [2 -1 : 0] bht_o;
always @ (posedge clk_i)
	bht_o <= bht[iF_pc_i[CLOG2BHTSETCNT+CLOG2INSNBITSZBY8-1:CLOG2INSNBITSZBY8]];
`endif

`ifdef PUPREDICTBRANCH
always @ (posedge clk_i) begin
	if (iF_iD_carryon)
		iD_predictBranch <= bht_o;
end
`endif

`ifdef PUPREDICTRET
always @ (posedge clk_i) begin
	if (iF_iD_carryon)
		iD_predictRet <= ras0;
end
`endif

always @ (posedge clk_i) begin
	if (rst_i) begin
		iF_flushed_ <= 1;
		iF_pc <= rstaddr_i;
	end else if (iF_en) begin
		iF_flushed_ <= iF_eX_JumpOrBranch_i;
		iF_pc <= iF_eX_JumpOrBranch_i ? iF_eX_JumpOrBranchAddr_i : iF_pc_i;
	end
end

wire [INSNBITSZ -1 : 0] iF_insn;
wire [XWORDBITSZ -1 : 0] iF_insn_ = iCache_dato_w;
generate if (XWORDBITSZ > INSNBITSZ) begin :gen_iF_insn
assign iF_insn = (iF_insn_ >> (INSNBITSZ*iF_pc[CLOG2XWORDBITSZBY8-1:CLOG2INSNBITSZBY8]));
end else begin
assign iF_insn = iF_insn_;
end endgenerate

wire [CLOG2GPRCNT -1 : 0] iF_rdId  = iF_insn[11:7];
wire [CLOG2GPRCNT -1 : 0] iF_rs1Id = iF_insn[19:15];
wire [CLOG2GPRCNT -1 : 0] iF_rs2Id = iF_insn[24:20];

wire [WORDBITSZ -1 : 0] iF_Iimm = {{21{iF_insn[31]}}, iF_insn[30:20]};
wire [WORDBITSZ -1 : 0] iF_Simm = {{21{iF_insn[31]}}, iF_insn[30:25], iF_insn[11:7]};
wire [WORDBITSZ -1 : 0] iF_Bimm = {{20{iF_insn[31]}}, iF_insn[7], iF_insn[30:25], iF_insn[11:8], 1'b0};
wire [WORDBITSZ -1 : 0] iF_Uimm = {iF_insn[31:12], {12{1'b0}}};
wire [WORDBITSZ -1 : 0] iF_Jimm = {{12{iF_insn[31]}}, iF_insn[19:12], iF_insn[20], iF_insn[30:21], 1'b0};

wire [3 -1 : 0] iF_func3 = iF_insn[14:12];
wire [5 -1 : 0] iF_func5 = iF_insn[31:27];
wire [7 -1 : 0] iF_func7 = iF_insn[31:25];

wire [WORDBITSZ -1 : 0] iF_pc_plus_INSNBITSzBy8 = (iF_pc + (INSNBITSZ/8));
wire [WORDBITSZ -1 : 0] iF_pc_plus_iF_Bimm      = (iF_pc + iF_Bimm);
wire [WORDBITSZ -1 : 0] iF_pc_plus_iF_Uimm      = (iF_pc + iF_Uimm);
wire [WORDBITSZ -1 : 0] iF_pc_plus_iF_Jimm      = (iF_pc + iF_Jimm);

wire iF_isALUreg = (iF_insn[6:2] == 5'b01100);
wire iF_isALUimm = (iF_insn[6:2] == 5'b00100);
wire iF_isBranch = (iF_insn[6:2] == 5'b11000);
wire iF_isJALR   = (iF_insn[6:2] == 5'b11001);
wire iF_isJAL    = (iF_insn[6:2] == 5'b11011);
`ifdef PUPREDICTRET
wire iF_isRet = (iF_isJALR && iF_rdId == 5'd0 && iF_rs1Id == 5'd1);
wire iF_isJALRnotRet = (iF_isJALR && !(iF_rdId == 5'd0 && iF_rs1Id == 5'd1));
wire iF_isCall = ((iF_isJALR || iF_isJAL) && iF_rdId == 5'd1);
`endif
wire iF_isAUIPC  = (iF_insn[6:2] == 5'b00101);
wire iF_isLUI    = (iF_insn[6:2] == 5'b01101);
wire iF_isLoad   = (iF_insn[6:2] == 5'b00000);
wire iF_isStore  = (iF_insn[6:2] == 5'b01000);
wire iF_isSystem = (iF_insn[6:2] == 5'b11100);
wire iF_isAMO    = (iF_insn[6:2] == 5'b01011);

wire iF_isMiscMem = (iF_insn[6:2] == 5'b00011);

wire [WORDBITSZ -1 : 0] iF_addrImm = (iF_isLoad ? iF_Iimm : iF_isStore ? iF_Simm : {WORDBITSZ{1'b0}});

wire iF_isSystemAndFunc3Null = (iF_isSystem && iF_func3 == 3'b000);
wire iF_isEcall  = (iF_isSystemAndFunc3Null && iF_Iimm[11:0] == 12'd0);
wire iF_isEbreak = (iF_isSystemAndFunc3Null && iF_Iimm[11:0] == 12'd1);

wire iF_isCSR = (iF_isSystem && iF_func3[1:0]);

`ifdef PURV32M
wire iF_isRV32M    = (iF_isALUreg && iF_func7[0]);
wire iF_opImul_stb = (iF_isRV32M && !iF_func3[2] && iF_rdId);
wire iF_opIdiv_stb = (iF_isRV32M &&  iF_func3[2] && iF_rdId);
`endif

wire iF_isLr = (iF_isAMO && iF_func5 == 5'b00010);
wire iF_isSc = (iF_isAMO && iF_func5 == 5'b00011);

wire iF_ldUnit_stb = (iF_isLoad || (iF_isAMO && iF_func5 != 5'b00011));
wire iF_stUnit_stb = (iF_isStore || iF_isSc);

wire iF_isAMOandSc = (iF_isAMO && iF_func5 != 5'b00010);

wire iF_cancelLr = (iF_isSystem || iF_isMiscMem || iF_isLoad || iF_isStore || iF_isAMOandSc);

wire iF_isALUimmOrJALrOrLoad = (iF_isALUimm || iF_isJALR || iF_ldUnit_stb);
wire iF_isBranchOrStore = (iF_isBranch || iF_isStore);
wire iF_isJAlOrAUIPcOrLUI = (iF_isJAL || iF_isAUIPC || iF_isLUI);
wire iF_isALUregOrBranch = (iF_isALUreg || iF_isBranch);
wire iF_isALUregOrAMOandSc = (iF_isALUreg || iF_isAMOandSc);
wire iF_isJAlOrJALR = (iF_isJAL || iF_isJALR);

// iF_isSc is also a multiCycleInsn like iF_isStore,
// but it is not included in this logic because it uses
// early register writeback.
wire iF_multiCycleInsn = (
	`ifdef PURV32M
	iF_isRV32M ||
	`endif
	iF_ldUnit_stb || iF_isStore);

wire iF_use_rdId = (iF_rdId && // iF_rdId is null when iF_isMiscMem true.
	!(iF_isBranchOrStore || /*iF_isMiscMem ||*/
		(iF_isSystem && !iF_func3[1:0] /* non-CSR instructions */)));

`ifdef SIMULATION
reg iF_eX_JumpOrBranch; // Used by sim.pc_w .
always @ (posedge clk_i)
	iF_eX_JumpOrBranch <= (rst_i ? 1'b1 : iF_eX_JumpOrBranch_i);
`endif

wire iF_flushed_or_not_iF_iD_carryon = (iF_flushed || !iF_iD_carryon);

assign iF_pc_i = ((
	`ifdef PUPREDICTRET
	(iF_isRet && !iF_flushed_or_not_iF_iD_carryon) ? {WORDBITSZ{1'b0}} :
	`endif
	iF_pc) + (
	iF_flushed_or_not_iF_iD_carryon ? {WORDBITSZ{1'b0}} :
	`ifdef PUPREDICTBRANCH
	(iF_isBranch && bht_o[1]) ? iF_Bimm :
	`endif
	`ifdef PUPREDICTJAL
	iF_isJAL ? iF_Jimm :
	`endif
	`ifdef PUPREDICTRET
	iF_isRet ? ras0 :
	`endif
	(INSNBITSZ/8)));

////////////////////////////////////// ID (Instruction Decode) stage ///////////////////////////////////////

reg [WORDBITSZ -1 : 0] iD_pc;
`ifdef SIMULATION
reg [INSNBITSZ -1 : 0] iD_insn;
`endif

reg [CLOG2GPRCNT -1 : 0] iD_rdId; // Get set to null if instruction will not set a GPR.
reg [CLOG2GPRCNT -1 : 0] iD_rs1Id;
reg [CLOG2GPRCNT -1 : 0] iD_rs2Id;

reg [WORDBITSZ -1 : 0] iD_Iimm;
reg [WORDBITSZ -1 : 0] iD_Simm;
reg [WORDBITSZ -1 : 0] iD_Bimm;
reg [WORDBITSZ -1 : 0] iD_Uimm;
reg [WORDBITSZ -1 : 0] iD_Jimm;

reg [3 -1 : 0] iD_func3;
reg [5 -1 : 0] iD_func5;
reg [7 -1 : 0] iD_func7;

reg [WORDBITSZ -1 : 0] iD_pc_plus_INSNBITSzBy8;
reg [WORDBITSZ -1 : 0] iD_pc_plus_iD_Bimm;
reg [WORDBITSZ -1 : 0] iD_pc_plus_iD_Uimm;
reg [WORDBITSZ -1 : 0] iD_pc_plus_iD_Jimm;

reg iD_isALUreg;
reg iD_isALUimm;
reg iD_isBranch;
reg iD_isJALR;
reg iD_isJAL;
`ifdef PUPREDICTRET
reg iD_isRet;
reg iD_isJALRnotRet;
reg iD_isCall;
`endif
reg iD_isAUIPC;
reg iD_isLUI;
reg iD_isLoad;
reg iD_isStore;
reg iD_isSystem;
reg iD_isAMO;

reg [WORDBITSZ -1 : 0] iD_addrImm;

reg iD_isEcall;
reg iD_isEbreak;

reg iD_isCSR;

`ifdef PURV32M
reg iD_opImul_stb;
reg iD_opIdiv_stb;
`endif

reg iD_isLr;
reg iD_isSc;

reg iD_ldUnit_stb;
reg iD_stUnit_stb;

reg iD_cancelLr;

reg iD_isALUimmOrJALrOrLoad;
reg iD_isBranchOrStore;
reg iD_isJAlOrAUIPcOrLUI;
reg iD_isALUregOrBranch;
reg iD_isALUregOrAMOandSc;
reg iD_isJAlOrJALR;

reg iD_multiCycleInsn;

reg iD_use_rdId;

wire [WORDBITSZ -1 : 0] iD_rs1;
wire [WORDBITSZ -1 : 0] iD_rs2;

wire iD_rdRdy;
wire iD_rs1Rdy;
wire iD_rs2Rdy;

reg [WORDBITSZ -1 : 0] gprDat [0 : GPRCNT -1];
reg [GPRCNT    -1 : 0] gprRdy;

`ifdef PURV32M
wire iD_opImul_bsy;
wire iD_opIdiv_bsy;
`endif
wire iD_ldUnit_bsy;
wire iD_stUnit_bsy;

wire iD_eX_flushed;
wire iD_eX_stalled;
wire iD_eX_carryon;

wire iD_stalled = (!iD_eX_carryon ||
	`ifdef PURV32M
	(iD_opImul_stb ? iD_opImul_bsy : 1'b0) ||
	(iD_opIdiv_stb ? iD_opIdiv_bsy : 1'b0) ||
	`endif
	(iD_ldUnit_stb ? iD_ldUnit_bsy : 1'b0) ||
	(iD_stUnit_stb ? iD_stUnit_bsy : 1'b0) || (
	// Stall if any of the operand is locked.
	iD_isALUregOrAMOandSc ? !(iD_rdRdy && iD_rs1Rdy && iD_rs2Rdy) :
	iD_isALUimmOrJALrOrLoad ? !(iD_rdRdy && iD_rs1Rdy) :
	iD_isBranchOrStore ? !(iD_rs1Rdy && iD_rs2Rdy) :
	iD_isJAlOrAUIPcOrLUI ? !iD_rdRdy : 0));

assign iF_iD_stalled = iD_stalled;

reg iD_flushed;

assign iF_iD_flushed = iD_flushed;

wire iD_carryon = (iD_flushed || !iD_stalled);

assign iF_iD_carryon = iD_carryon;

wire iD_en = (iD_carryon && !halted_o);

wire [CLOG2GPRCNT -1 : 0] _iF_rdId  = (iD_en ? iF_rdId  : iD_rdId);
wire [CLOG2GPRCNT -1 : 0] _iF_rs1Id = (iD_en ? iF_rs1Id : iD_rs1Id);
wire [CLOG2GPRCNT -1 : 0] _iF_rs2Id = (iD_en ? iF_rs2Id : iD_rs2Id);

wire _iF_use_rdId = (iD_en ? iF_use_rdId : iD_use_rdId);

reg iD_eX_rdId_isTrue;
reg [CLOG2GPRCNT -1 : 0] iD_eX_rdId;
reg [WORDBITSZ -1 : 0]   iD_eX_rslt;

wire iD_rdId_eq_iD_eX_rdId  = ((iD_rdId  == iD_eX_rdId) && iD_eX_rdId_isTrue);
wire iD_rs1Id_eq_iD_eX_rdId = ((iD_rs1Id == iD_eX_rdId) && iD_eX_rdId_isTrue);
wire iD_rs2Id_eq_iD_eX_rdId = ((iD_rs2Id == iD_eX_rdId) && iD_eX_rdId_isTrue);

reg iD_rW_rdId_isTrue;
reg [CLOG2GPRCNT -1 : 0] iD_rW_rdId;
reg [WORDBITSZ -1 : 0]   iD_rW_rslt;

wire iD_rdId_eq_iD_rW_rdId  = ((iD_rdId  == iD_rW_rdId) && iD_rW_rdId_isTrue);
wire iD_rs1Id_eq_iD_rW_rdId = ((iD_rs1Id == iD_rW_rdId) && iD_rW_rdId_isTrue);
wire iD_rs2Id_eq_iD_rW_rdId = ((iD_rs2Id == iD_rW_rdId) && iD_rW_rdId_isTrue);

reg [WORDBITSZ -1 : 0] iD_rs1_;
reg [WORDBITSZ -1 : 0] iD_rs2_;
assign iD_rs1 = (
	iD_rs1Id_eq_iD_eX_rdId ? iD_eX_rslt :
	iD_rs1Id_eq_iD_rW_rdId ? iD_rW_rslt :
	iD_rs1Id ? iD_rs1_ : {WORDBITSZ{1'b0}});
assign iD_rs2 = (
	iD_rs2Id_eq_iD_eX_rdId ? iD_eX_rslt :
	iD_rs2Id_eq_iD_rW_rdId ? iD_rW_rslt :
	iD_rs2Id ? iD_rs2_ : {WORDBITSZ{1'b0}});
// iD*_r*Rdy_ registers capture the availability of rd, rs1 and rs2
// registers only when an instruction enters the iDecoded stage.
// iD*_r*Rdy__ registers become true when rd, rs1 and rs2 registers become
// available while the instruction is stalled at the iDecoded stage.
reg iD_rdRdy_,  iD_rdRdy__;
reg iD_rs1Rdy_, iD_rs1Rdy__;
reg iD_rs2Rdy_, iD_rs2Rdy__;
assign iD_rdRdy = ((
	iD_rdId_eq_iD_eX_rdId ? 1'b1 :
	iD_rdId_eq_iD_rW_rdId ? 1'b1 :
	iD_rdRdy_) || iD_rdRdy__);
assign iD_rs1Rdy = ((
	iD_rs1Id_eq_iD_eX_rdId ? 1'b1 :
	iD_rs1Id_eq_iD_rW_rdId ? 1'b1 :
	iD_rs1Rdy_) || iD_rs1Rdy__);
assign iD_rs2Rdy = ((
	iD_rs2Id_eq_iD_eX_rdId ? 1'b1 :
	iD_rs2Id_eq_iD_rW_rdId ? 1'b1 :
	iD_rs2Rdy_) || iD_rs2Rdy__);

wire iD_insn_valid;

`include "./dcache.pu.v"

`include "./memctrl.pu.v"

wire iD_eX_JumpOrBranch_i;

wire _iF_flushed = ((iD_en ? iF_flushed : iD_flushed) || iD_eX_JumpOrBranch_i);

always @ (posedge clk_i) begin
	iD_rs1_ <= gprDat[_iF_rs1Id];
	iD_rs2_ <= gprDat[_iF_rs2Id];
	iD_rdRdy_  <= gprRdy[_iF_rdId];
	iD_rs1Rdy_ <= gprRdy[_iF_rs1Id];
	iD_rs2Rdy_ <= gprRdy[_iF_rs2Id];
end

always @ (posedge clk_i) begin
	if (iD_en)
		iD_rdRdy__ <= 1'b0;
	else if (iD_rdRdy)
		iD_rdRdy__ <= 1'b1;
end

always @ (posedge clk_i) begin
	if (iD_en)
		iD_rs1Rdy__ <= 1'b0;
	else if (iD_rs1Rdy)
		iD_rs1Rdy__ <= 1'b1;
end

always @ (posedge clk_i) begin
	if (iD_en)
		iD_rs2Rdy__ <= 1'b0;
	else if (iD_rs2Rdy)
		iD_rs2Rdy__ <= 1'b1;
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		iD_flushed <= 1;
	end else if (iD_en) begin
		iD_flushed <= (iF_flushed || iD_eX_JumpOrBranch_i);
	end
end

always @ (posedge clk_i) begin

	if (iD_en) begin

		iD_pc <= iF_pc;
		`ifdef SIMULATION
		iD_insn <= iF_insn;
		`endif

		iD_rdId  <= (iF_use_rdId ? iF_rdId : 5'd0);
		iD_rs1Id <= iF_rs1Id;
		iD_rs2Id <= iF_rs2Id;

		iD_Iimm <= iF_Iimm;
		iD_Simm <= iF_Simm;
		iD_Bimm <= iF_Bimm;
		iD_Uimm <= iF_Uimm;
		iD_Jimm <= iF_Jimm;

		iD_func3 <= iF_func3;
		iD_func5 <= iF_func5;
		iD_func7 <= iF_func7;

		iD_pc_plus_INSNBITSzBy8 <= iF_pc_plus_INSNBITSzBy8;
		iD_pc_plus_iD_Bimm      <= iF_pc_plus_iF_Bimm;
		iD_pc_plus_iD_Uimm      <= iF_pc_plus_iF_Uimm;
		iD_pc_plus_iD_Jimm      <= iF_pc_plus_iF_Jimm;

		iD_isALUreg <= iF_isALUreg;
		iD_isALUimm <= iF_isALUimm;
		iD_isBranch <= iF_isBranch;
		iD_isJALR   <= iF_isJALR;
		iD_isJAL    <= iF_isJAL;
		`ifdef PUPREDICTRET
		iD_isRet        <= iF_isRet;
		iD_isJALRnotRet <= iF_isJALRnotRet;
		iD_isCall       <= iF_isCall;
		`endif
		iD_isAUIPC  <= iF_isAUIPC;
		iD_isLUI    <= iF_isLUI;
		iD_isLoad   <= iF_isLoad;
		iD_isStore  <= iF_isStore;
		iD_isSystem <= iF_isSystem;
		iD_isAMO    <= iF_isAMO;

		iD_addrImm <= iF_addrImm;

		iD_isEcall  <= iF_isEcall;
		iD_isEbreak <= iF_isEbreak;

		iD_isCSR <= iF_isCSR;

		`ifdef PURV32M
		iD_opImul_stb <= iF_opImul_stb;
		iD_opIdiv_stb <= iF_opIdiv_stb;
		`endif

		iD_isLr <= iF_isLr;
		iD_isSc <= iF_isSc;

		iD_ldUnit_stb <= iF_ldUnit_stb;
		iD_stUnit_stb <= iF_stUnit_stb;

		iD_cancelLr <= iF_cancelLr;

		iD_isALUimmOrJALrOrLoad <= iF_isALUimmOrJALrOrLoad;
		iD_isBranchOrStore      <= iF_isBranchOrStore;
		iD_isJAlOrAUIPcOrLUI    <= iF_isJAlOrAUIPcOrLUI;
		iD_isALUregOrBranch     <= iF_isALUregOrBranch;
		iD_isALUregOrAMOandSc   <= iF_isALUregOrAMOandSc;
		iD_isJAlOrJALR          <= iF_isJAlOrJALR;

		iD_multiCycleInsn <= iF_multiCycleInsn;

		iD_use_rdId <= iF_use_rdId;
	end
end

////////////////////////////////////// EX (Execute) stage //////////////////////////////////////////////////

`ifdef SIMULATION
reg [WORDBITSZ -1 : 0] eX_pc;
reg [INSNBITSZ -1 : 0] eX_insn;
`endif

wire [WORDBITSZ -1 : 0] eX_aluArg1_i = iD_rs1;
wire [WORDBITSZ -1 : 0] eX_aluArg2_i = (iD_isALUregOrBranch ? iD_rs2 : iD_Iimm);

// The adder is used by both arithmetic instructions and JALR.
wire [WORDBITSZ -1 : 0] eX_aluPlus_i = (eX_aluArg1_i + eX_aluArg2_i);

// Use a single (WORDBITSZ+1) bits subtract to do subtraction and all comparisons.
wire [(WORDBITSZ+1) -1 : 0] eX_aluMinus_i = (({1'b1, ~eX_aluArg2_i} + {1'b0, eX_aluArg1_i}) + 1'b1);
wire eX_lt_i = (
	(eX_aluArg1_i[WORDBITSZ-1] ^ eX_aluArg2_i[WORDBITSZ-1]) ?
		eX_aluArg1_i[WORDBITSZ-1] : eX_aluMinus_i[WORDBITSZ]);
wire eX_ltu_i = eX_aluMinus_i[WORDBITSZ];
wire eX_eq_i = (eX_aluMinus_i[WORDBITSZ-1:0] == {WORDBITSZ{1'b0}});

wire [(WORDBITSZ+1) -1 : 0] _eX_aluArg1_i = {iD_func7[5] & eX_aluArg1_i[WORDBITSZ-1], eX_aluArg1_i};

reg [WORDBITSZ -1 : 0] eX_aluOut_i; // ### comb-block-reg.
always @* begin
	case(iD_func3)
	3'b000: eX_aluOut_i = ((iD_isALUreg && iD_func7[5]) ? eX_aluMinus_i[WORDBITSZ-1:0] : eX_aluPlus_i);
	3'b001: eX_aluOut_i = (eX_aluArg1_i << eX_aluArg2_i[4:0]);
	3'b010: eX_aluOut_i = {{(WORDBITSZ-1){1'b0}}, eX_lt_i};
	3'b011: eX_aluOut_i = {{(WORDBITSZ-1){1'b0}}, eX_ltu_i};
	3'b100: eX_aluOut_i = (eX_aluArg1_i ^ eX_aluArg2_i);
	3'b101: eX_aluOut_i = ($signed(_eX_aluArg1_i) >>> eX_aluArg2_i[4:0]);
	3'b110: eX_aluOut_i = (eX_aluArg1_i | eX_aluArg2_i);
	3'b111: eX_aluOut_i = (eX_aluArg1_i & eX_aluArg2_i);
	endcase
end

reg [WORDBITSZ -1 : 0] eX_csrOut_i; // ### comb-block-reg.

wire [WORDBITSZ -1 : 0] eX_StoreCondOut_i;

wire [WORDBITSZ -1 : 0] eX_rslt_i = (
	iD_isJAlOrJALR ? (iD_pc_plus_INSNBITSzBy8) :
	iD_isLUI       ? iD_Uimm                   :
	iD_isAUIPC     ? iD_pc_plus_iD_Uimm        :
	iD_isCSR       ? eX_csrOut_i               :
	iD_isSc        ? eX_StoreCondOut_i         :
	                 eX_aluOut_i              );

reg eX_takeBranch_i; // ### comb-block-reg.
always @* begin
	case (iD_func3)
	3'b000:  eX_takeBranch_i = eX_eq_i;
	3'b001:  eX_takeBranch_i = !eX_eq_i;
	3'b100:  eX_takeBranch_i = eX_lt_i;
	3'b101:  eX_takeBranch_i = !eX_lt_i;
	3'b110:  eX_takeBranch_i = eX_ltu_i;
	3'b111:  eX_takeBranch_i = !eX_ltu_i;
	default: eX_takeBranch_i = 1'b0;
	endcase
end

`ifdef PUPREDICTBRANCH
wire [2 -1 : 0] eX_predictBranch_i = iD_predictBranch;
`else
wire [2 -1 : 0] eX_predictBranch_i = 2'b00;
`endif
wire _eX_takeBranch_i = (eX_takeBranch_i ^ eX_predictBranch_i[1]);

`ifdef PUPREDICTRET
wire eX_predictRetMiss_i = (iD_predictRet != {eX_aluPlus_i[WORDBITSZ-1:1], 1'b0});
`endif

wire eX_rW_flushed;
wire eX_rW_stalled;
wire eX_rW_carryon;

wire eX_stalled = !eX_rW_carryon;

assign iD_eX_stalled = eX_stalled;

// Jumps or Branchs are triggered only at the iDecoded stage.
// Interrupts and exceptions set eX_flushed_i to prevent eXecution.
wire eX_flushed_i = (iD_flushed || iD_stalled);
reg eX_flushed;

assign iD_eX_flushed = eX_flushed;

wire eX_carryon = (eX_flushed || !eX_stalled);

assign iD_eX_carryon = eX_carryon;

wire eX_en = (eX_carryon && !halted_o);

assign iD_insn_valid = (!eX_flushed_i && eX_en);

`ifdef PUPREDICTBRANCH
wire [2 -1 : 0] bht_i = (
	{eX_takeBranch_i, eX_predictBranch_i} == 3'b000 ? 2'b00 :
	{eX_takeBranch_i, eX_predictBranch_i} == 3'b001 ? 2'b00 :
	{eX_takeBranch_i, eX_predictBranch_i} == 3'b010 ? 2'b01 :
	{eX_takeBranch_i, eX_predictBranch_i} == 3'b011 ? 2'b10 :
	{eX_takeBranch_i, eX_predictBranch_i} == 3'b100 ? 2'b01 :
	{eX_takeBranch_i, eX_predictBranch_i} == 3'b101 ? 2'b10 :
	{eX_takeBranch_i, eX_predictBranch_i} == 3'b110 ? 2'b11 :
	                                                  2'b11 );
always @ (posedge clk_i) begin
	if (iD_isBranch && iD_insn_valid)
		bht[iD_pc[CLOG2BHTSETCNT+CLOG2INSNBITSZBY8-1:CLOG2INSNBITSZBY8]] <= bht_i;
end
`endif

`ifdef PUPREDICTRET
always @ (posedge clk_i) begin
	if (iD_insn_valid) begin
		if (iD_isCall) begin
			ras0 <= iD_pc_plus_INSNBITSzBy8;
			ras1 <= ras0;
			ras2 <= ras1;
			ras3 <= ras2;
			ras4 <= ras3;
			ras5 <= ras4;
			ras6 <= ras5;
			ras7 <= ras6;
		end else if (iD_isRet) begin
			ras0 <= ras1;
			ras1 <= ras2;
			ras2 <= ras3;
			ras3 <= ras4;
			ras4 <= ras5;
			ras5 <= ras6;
			ras6 <= ras7;
			//ras7 <= {WORDBITSZ{1'b0}};
		end
	end
end
`endif

// TODO: Use irq and exc signals ...
wire eX_JumpOrBranch_i = ((
	`ifndef PUPREDICTJAL
	iD_isJAL ||
	`endif
	`ifdef PUPREDICTRET
	(iD_isRet && eX_predictRetMiss_i) ||
	iD_isJALRnotRet ||
	`else
	iD_isJALR ||
	`endif
	(iD_isBranch && _eX_takeBranch_i)) && iD_insn_valid);

assign iF_eX_JumpOrBranch_i = eX_JumpOrBranch_i;
assign iD_eX_JumpOrBranch_i = eX_JumpOrBranch_i;

// TODO: Use irq and exc signals ...
wire [WORDBITSZ -1 : 0] eX_JumpOrBranchAddr_i = (
	iD_isBranch ? (eX_takeBranch_i ? iD_pc_plus_iD_Bimm : iD_pc_plus_INSNBITSzBy8) :
	`ifndef PUPREDICTJAL
	iD_isJAL ? iD_pc_plus_iD_Jimm :
	`endif
	/* iD_isJALR */ {eX_aluPlus_i[WORDBITSZ-1:1], 1'b0});

assign iF_eX_JumpOrBranchAddr_i = eX_JumpOrBranchAddr_i;

reg eX_JumpOrBranch;
always @ (posedge clk_i) begin
	if (rst_i) begin
		eX_flushed <= 1;
		eX_JumpOrBranch <= 1;
	end else if (eX_en) begin
		eX_flushed <= eX_flushed_i;
		eX_JumpOrBranch <= eX_JumpOrBranch_i;
	end
end

reg eX_multiCycleInsn;

always @ (posedge clk_i) begin
	if (eX_en) begin
		`ifdef SIMULATION
		eX_pc   <= iD_pc;
		eX_insn <= iD_insn;
		`endif
		eX_multiCycleInsn <= iD_multiCycleInsn;
		if (iD_multiCycleInsn || eX_flushed_i) begin
			iD_eX_rdId_isTrue <= 1'b0;
			iD_eX_rdId <= 5'd0;
		end else begin
			iD_eX_rdId_isTrue <= (|iD_rdId);
			iD_eX_rdId <= iD_rdId;
		end
		iD_eX_rslt <= eX_rslt_i;
	end
end

////////////////////////////////////// RWB (Register WriteBack) stage //////////////////////////////////////

`ifdef SIMULATION
reg [WORDBITSZ -1 : 0] rW_pc;
reg [INSNBITSZ -1 : 0] rW_insn;
`endif

reg                      rW_we_i;  // ### comb-block-reg.
reg [CLOG2GPRCNT -1 : 0] rW_idx_i; // ### comb-block-reg.
reg [WORDBITSZ -1 : 0]   rW_dat_i; // ### comb-block-reg.

`ifdef PURV32M
reg rW_opImul_done; // ### comb-block-reg.
reg rW_opIdiv_done; // ### comb-block-reg.
`endif

`ifdef PURV32M
`include "./imul.pu.v"
`include "./idiv.pu.v"
`endif
`include "./lsu.pu.v"
`include "./sys.pu.v"

wire rW_stalled = (
	ldUnit_memAck
	`ifdef PURV32M
	|| opImul_done || opIdiv_done
	`endif
	);

assign eX_rW_stalled = rW_stalled;

reg rW_flushed;
always @ (posedge clk_i)
	rW_flushed <= (eX_flushed || eX_stalled);

assign eX_rW_flushed = (rW_flushed && !rW_stalled);

assign eX_rW_carryon = (eX_rW_flushed || !eX_rW_stalled);

always @* begin

	rW_we_i  = 0;
	rW_idx_i = 0;
	rW_dat_i = 0;

	`ifdef PURV32M
	rW_opImul_done = 0;
	rW_opIdiv_done = 0;
	`endif

	if (ldUnit_memAck) begin
		rW_we_i  = 1;
		rW_idx_i = ldUnit_rqsts_rIdx;
		rW_dat_i = ldUnit_rqsts_dato;
	`ifdef PURV32M
	end else if (opImul_done) begin
		rW_we_i  = 1;
		rW_idx_i = opImul_rIdx;
		rW_dat_i = opImul_rslt;
		rW_opImul_done = 1;
	end else if (opIdiv_done) begin
		rW_we_i  = 1;
		rW_idx_i = opIdiv_rIdx;
		rW_dat_i = opIdiv_rslt;
		rW_opIdiv_done = 1;
	`endif
	end else if (halted_o) begin
	end else if (iD_eX_rdId_isTrue /*&& !eX_flushed*/) begin
		rW_we_i  = 1;
		rW_idx_i = iD_eX_rdId;
		rW_dat_i = iD_eX_rslt;
	end
end

always @ (posedge clk_i) begin
	if (ldUnit_memAck) begin
		iD_rW_rdId_isTrue <= (|ldUnit_rqsts_rIdx);
		iD_rW_rdId <= ldUnit_rqsts_rIdx;
		iD_rW_rslt <= ldUnit_rqsts_dato;
	`ifdef PURV32M
	end else if (opImul_done) begin
		iD_rW_rdId_isTrue <= (|opImul_rIdx);
		iD_rW_rdId <= opImul_rIdx;
		iD_rW_rslt <= opImul_rslt;
	end else if (opIdiv_done) begin
		iD_rW_rdId_isTrue <= (|opIdiv_rIdx);
		iD_rW_rdId <= opIdiv_rIdx;
		iD_rW_rslt <= opIdiv_rslt;
	`endif
	end else if (halted_o) begin
	end else if (iD_eX_rdId_isTrue /*&& !eX_flushed*/) begin
		/* Considering the instruction sequence below, the check below
		prevents the result of `add a3,a3,a1` to be forwarded to `jr a3`,
		when the result of `lw a3,0(a3)` should be used but has been deferred
		due to being from a multi-cycle instruction.
		add     a3,a3,a1
		lw      a3,0(a3)       (Multi-cycle instruction)
		jr      a3                                                        */
		if (!iD_flushed && iD_multiCycleInsn && iD_eX_rdId == iD_rdId) begin
			iD_rW_rdId_isTrue <= 1'b0;
			iD_rW_rdId <= {CLOG2GPRCNT{1'b0}};
		end else begin
			iD_rW_rdId_isTrue <= (|iD_eX_rdId);
			iD_rW_rdId <= iD_eX_rdId;
		end
		iD_rW_rslt <= iD_eX_rslt;
	end else begin
		iD_rW_rdId_isTrue <= 1'b0;
		iD_rW_rdId <= {CLOG2GPRCNT{1'b0}};
	end
end

always @ (posedge clk_i) begin
	if (rW_we_i)
		gprDat[rW_idx_i] <= rW_dat_i;
end

wire gprLock = (_iF_use_rdId && !_iF_flushed);

wire gprUnlock = (
	rW_we_i && /* Do not unlock a gpr if it is about to be locked
	or if it has just been locked; note that we are at the eXecuted stage,
	hence the reason why only *_rdId from previous stages are checked. */
	!(gprLock && _iF_rdId == rW_idx_i) &&
	!(!iD_flushed && iD_rdId == rW_idx_i));

always @ (posedge clk_i) begin
	if (rst_i)
		gprRdy <= {GPRCNT{1'b1}};
	else begin
		if (gprLock)
			gprRdy[_iF_rdId] <= 1'b0;
		if (gprUnlock)
			gprRdy[rW_idx_i] <= 1'b1;
	end
end

`ifdef SIMULATION
always @ (posedge clk_i) begin
	rW_pc   <= eX_pc;
	rW_insn <= eX_insn;
end
`endif

endmodule
