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

reg iF0_flushed_;
wire iF0_flushed = (iF0_flushed_ || !iCache0_hit_w);
`ifdef PU2NDISSUE
wire iF1_flushed = (iF0_flushed_ || !iCache1_hit_w);
`endif

wire iF0_iD0_flushed;
wire iF0_iD0_stalled;
wire iF0_iD0_carryon;

wire iF0_carryon = (iF0_flushed || iF0_iD0_carryon);

wire iF0_en = (iF0_carryon && !halted_o);

wire                    iF0_eX0_JumpOrBranch_i;
wire [WORDBITSZ -1 : 0] iF0_eX0_JumpOrBranchAddr_i;

assign iCache_nxtway_w = iF0_eX0_JumpOrBranch_i;

assign iCache_re_w = iF0_en;

`ifdef PUPREDICTRET
reg [WORDBITSZ -1 : 0] ras0;
reg [WORDBITSZ -1 : 0] ras1;
reg [WORDBITSZ -1 : 0] ras2;
reg [WORDBITSZ -1 : 0] ras3;
reg [WORDBITSZ -1 : 0] ras4;
reg [WORDBITSZ -1 : 0] ras5;
reg [WORDBITSZ -1 : 0] ras6;
reg [WORDBITSZ -1 : 0] ras7;
reg [WORDBITSZ -1 : 0] iD0_predictRet;
`endif

`ifdef PUPREDICTJALR
// TODO: To be implemented like PUPREDICTRET using a BTB (Branch Target Buffer).
// TODO: When adding an entry to the BTB, skip RET which is "jalr x0, x1, 0",
// TODO: only add JALR for which (rs1Id != 1).
`endif

reg  [WORDBITSZ -1 : 0] iF0_pc;
wire [WORDBITSZ -1 : 0] iF0_pc_i;

assign iCache0_ridx_w = iF0_pc_i[CLOG2ICACHESETCNT+CLOG2XWORDBITSZBY8-1:CLOG2XWORDBITSZBY8];
assign iCache0_rtag_w = iF0_pc_i[WORDBITSZ-1:CLOG2ICACHESETCNT+CLOG2XWORDBITSZBY8];

`ifdef PU2NDISSUE
reg [WORDBITSZ -1 : 0] iF1_pc;
wire [WORDBITSZ -1 : 0] iF1_pc_i = (iF0_pc_i + (INSNBITSZ/8));
assign iCache1_ridx_w = iF1_pc_i[CLOG2ICACHESETCNT+CLOG2XWORDBITSZBY8-1:CLOG2XWORDBITSZBY8];
assign iCache1_rtag_w = iF1_pc_i[WORDBITSZ-1:CLOG2ICACHESETCNT+CLOG2XWORDBITSZBY8];
`endif

`ifdef PUPREDICTBRANCH
reg [2 -1 : 0] iD0_predictBranch;
localparam BHTSETCNT = 4096;
localparam CLOG2BHTSETCNT = clog2(BHTSETCNT);
reg [2 -1 : 0] bht [0 : BHTSETCNT - 1]; // Branch History Table.
reg [2 -1 : 0] bht_o;
always @ (posedge clk_i)
	bht_o <= bht[iF0_pc_i[CLOG2BHTSETCNT+CLOG2INSNBITSZBY8-1:CLOG2INSNBITSZBY8]];
`endif

always @ (posedge clk_i) begin

	`ifdef PUPREDICTBRANCH
	if (iF0_iD0_carryon)
		iD0_predictBranch <= bht_o;
	`endif

	`ifdef PUPREDICTRET
	if (iF0_iD0_carryon)
		iD0_predictRet <= ras0;
	`endif

	if (rst_i) begin
		iF0_flushed_ <= 1;
		iF0_pc <= rstaddr_i;
	end else if (iF0_en) begin
		iF0_flushed_ <= iF0_eX0_JumpOrBranch_i;
		iF0_pc <= iF0_eX0_JumpOrBranch_i ? iF0_eX0_JumpOrBranchAddr_i : iF0_pc_i;
		`ifdef PU2NDISSUE
		iF1_pc <= iF1_pc_i;
		`endif
	end
end

wire [INSNBITSZ -1 : 0] iF0_insn;
wire [XWORDBITSZ -1 : 0] iF0_insn_ = iCache0_dato_w;
generate if (XWORDBITSZ > INSNBITSZ) begin :gen_iF0_insn
assign iF0_insn = (iF0_insn_ >> (INSNBITSZ*iF0_pc[CLOG2XWORDBITSZBY8-1:CLOG2INSNBITSZBY8]));
end else begin
assign iF0_insn = iF0_insn_;
end endgenerate

wire [CLOG2GPRCNT -1 : 0] iF0_rdId  = iF0_insn[11:7];
wire [CLOG2GPRCNT -1 : 0] iF0_rs1Id = iF0_insn[19:15];
wire [CLOG2GPRCNT -1 : 0] iF0_rs2Id = iF0_insn[24:20];

wire [WORDBITSZ -1 : 0] iF0_Iimm = {{21{iF0_insn[31]}}, iF0_insn[30:20]};
wire [WORDBITSZ -1 : 0] iF0_Simm = {{21{iF0_insn[31]}}, iF0_insn[30:25], iF0_insn[11:7]};
wire [WORDBITSZ -1 : 0] iF0_Bimm = {{20{iF0_insn[31]}}, iF0_insn[7], iF0_insn[30:25], iF0_insn[11:8], 1'b0};
wire [WORDBITSZ -1 : 0] iF0_Uimm = {iF0_insn[31:12], {12{1'b0}}};
wire [WORDBITSZ -1 : 0] iF0_Jimm = {{12{iF0_insn[31]}}, iF0_insn[19:12], iF0_insn[20], iF0_insn[30:21], 1'b0};

wire [3 -1 : 0] iF0_func3 = iF0_insn[14:12];
wire [5 -1 : 0] iF0_func5 = iF0_insn[31:27];
wire [7 -1 : 0] iF0_func7 = iF0_insn[31:25];

`ifdef PU2NDISSUE
wire [INSNBITSZ -1 : 0] iF1_insn;
wire [XWORDBITSZ -1 : 0] iF1_insn_ = iCache1_dato_w;
generate if (XWORDBITSZ > INSNBITSZ) begin :gen_iF1_insn
assign iF1_insn = (iF1_insn_ >> (INSNBITSZ*iF1_pc[CLOG2XWORDBITSZBY8-1:CLOG2INSNBITSZBY8]));
end else begin
assign iF1_insn = iF1_insn_;
end endgenerate

wire [CLOG2GPRCNT -1 : 0] iF1_rdId  = iF1_insn[11:7];
wire [CLOG2GPRCNT -1 : 0] iF1_rs1Id = iF1_insn[19:15];
wire [CLOG2GPRCNT -1 : 0] iF1_rs2Id = iF1_insn[24:20];

wire iF1_isALUreg = (iF1_insn[6:2] == 5'b01100 && !iF1_insn[25]);
wire iF1_isALUimm = (iF1_insn[6:2] == 5'b00100);
wire iF1_isAUIPC  = (iF1_insn[6:2] == 5'b00101);
wire iF1_isLUI    = (iF1_insn[6:2] == 5'b01101);

wire [WORDBITSZ -1 : 0] iF1_Iimm = {{21{iF1_insn[31]}}, iF1_insn[30:20]};
wire [WORDBITSZ -1 : 0] iF1_Uimm = {iF1_insn[31:12], {12{1'b0}}};

wire [3 -1 : 0] iF1_func3 = iF1_insn[14:12];
wire [7 -1 : 0] iF1_func7 = iF1_insn[31:25];

`ifdef PU2NDISSUE
wire iF1_rdId_eq_iF0_rdId  = (iF1_rdId && iF1_rdId == iF0_rdId);
wire iF1_rs1Id_eq_iF0_rdId = (iF1_rs1Id && iF1_rs1Id == iF0_rdId);
wire iF1_rs2Id_eq_iF0_rdId = (iF1_rs2Id && iF1_rs2Id == iF0_rdId);
`endif
`endif

wire [WORDBITSZ -1 : 0] iF0_pc_plus_INSNBITSzBy8 = (iF0_pc + (INSNBITSZ/8));
wire [WORDBITSZ -1 : 0] iF0_pc_plus_iF0_Bimm     = (iF0_pc + iF0_Bimm);
wire [WORDBITSZ -1 : 0] iF0_pc_plus_iF0_Uimm     = (iF0_pc + iF0_Uimm);
wire [WORDBITSZ -1 : 0] iF0_pc_plus_iF0_Jimm     = (iF0_pc + iF0_Jimm);
`ifdef PU2NDISSUE
wire [WORDBITSZ -1 : 0] iF1_pc_plus_iF1_Uimm     = (iF1_pc + iF1_Uimm);
`endif

wire iF0_isALUreg = (iF0_insn[6:2] == 5'b01100);
wire iF0_isALUimm = (iF0_insn[6:2] == 5'b00100);
wire iF0_isBranch = (iF0_insn[6:2] == 5'b11000);
wire iF0_isJALR   = (iF0_insn[6:2] == 5'b11001);
wire iF0_isJAL    = (iF0_insn[6:2] == 5'b11011);
`ifdef PUPREDICTRET
wire iF0_isRet = (iF0_isJALR && iF0_rdId == 5'd0 && iF0_rs1Id == 5'd1);
wire iF0_isJALRnotRet = (iF0_isJALR && !(iF0_rdId == 5'd0 && iF0_rs1Id == 5'd1));
wire iF0_isCall = ((iF0_isJALR || iF0_isJAL) && iF0_rdId == 5'd1);
`endif
wire iF0_isAUIPC  = (iF0_insn[6:2] == 5'b00101);
wire iF0_isLUI    = (iF0_insn[6:2] == 5'b01101);
wire iF0_isLoad   = (iF0_insn[6:2] == 5'b00000);
wire iF0_isStore  = (iF0_insn[6:2] == 5'b01000);
wire iF0_isSystem = (iF0_insn[6:2] == 5'b11100);
wire iF0_isAMO    = (iF0_insn[6:2] == 5'b01011);

wire [WORDBITSZ -1 : 0] iF0_addrImm = (iF0_isLoad ? iF0_Iimm : iF0_isStore ? iF0_Simm : {WORDBITSZ{1'b0}});

wire iF0_isSystemAndFunc3Null = (iF0_isSystem && iF0_func3 == 3'b000);
wire iF0_isEcall  = (iF0_isSystemAndFunc3Null && iF0_Iimm[11:0] == 12'd0);
wire iF0_isEbreak = (iF0_isSystemAndFunc3Null && iF0_Iimm[11:0] == 12'd1);

wire iF0_isCSR = (iF0_isSystem && iF0_func3[1:0]);

`ifdef PURV32M
wire iF0_isRV32M    = (iF0_isALUreg && iF0_func7[0]);
wire iF0_opImul_stb = (iF0_isRV32M && !iF0_func3[2] && iF0_rdId);
wire iF0_opIdiv_stb = (iF0_isRV32M &&  iF0_func3[2] && iF0_rdId);
`endif

wire iF0_ldUnit_stb = (iF0_isLoad || (iF0_isAMO && iF0_func5 != 5'b00011));
wire iF0_stUnit_stb = (iF0_isStore || (iF0_isAMO && iF0_func5 == 5'b00011));

wire iF0_isALUimmOrJALrOrLoad = (iF0_isALUimm || iF0_isJALR || iF0_isLoad);
wire iF0_isBranchOrStore = (iF0_isBranch || iF0_isStore);
wire iF0_isJAlOrAUIPcOrLUI = (iF0_isJAL || iF0_isAUIPC || iF0_isLUI);
wire iF0_isALUregOrBranch = (iF0_isALUreg || iF0_isBranch);
wire iF0_isJAlOrJALR = (iF0_isJAL || iF0_isJALR);
`ifdef PU2NDISSUE
wire iF1_isAUIPcOrLUI = (iD1_isAUIPC || iD1_isLUI);
`endif

wire iF0_multiCycleInsn = (
	`ifdef PURV32M
	iF0_isRV32M ||
	`endif
	iF0_isLoad || iF0_isStore || iF0_isAMO);

wire iF0_use_rdId = (iF0_rdId &&
	!(iF0_isBranchOrStore ||
		(iF0_isSystem && !iF0_func3[1:0] /* non-CSR instructions */)));

`ifdef SIMULATION
reg iF0_eX0_JumpOrBranch; // Used by sim.pc_w .
always @ (posedge clk_i)
	iF0_eX0_JumpOrBranch <= (rst_i ? 1'b1 : iF0_eX0_JumpOrBranch_i);
`endif

`ifdef PU2NDISSUE
wire iF1_hazard = (iF0_flushed || iF1_flushed ||
	iF0_isBranch || iF0_isJAL || iF0_isJALR ||
	!(iF1_isALUreg || iF1_isALUimm || iF1_isAUIPC || iF1_isLUI) ||
	iF1_rdId_eq_iF0_rdId || ((
		(iF1_rs1Id_eq_iF0_rdId && (iF1_isALUreg || iF1_isALUimm)) ||
		(iF1_rs2Id_eq_iF0_rdId &&  iF1_isALUreg))
			`ifdef PU2NDISSUE_
			&& ((iF0_isALUreg && iF0_insn[25]) || iF0_isLoad)
			`endif
	));
`endif

wire iF0_flushed_or_not_iF0_iD0_carryon = (iF0_flushed || !iF0_iD0_carryon);

assign iF0_pc_i = ((
	`ifdef PUPREDICTRET
	(iF0_isRet && !iF0_flushed_or_not_iF0_iD0_carryon) ? {WORDBITSZ{1'b0}} :
	`endif
	iF0_pc) + (
	iF0_flushed_or_not_iF0_iD0_carryon ? {WORDBITSZ{1'b0}} :
	`ifdef PUPREDICTBRANCH
	(iF0_isBranch && bht_o[1]) ? iF0_Bimm :
	`endif
	`ifdef PUPREDICTJAL
	iF0_isJAL ? iF0_Jimm :
	`endif
	`ifdef PUPREDICTRET
	iF0_isRet ? ras0 :
	`endif
	`ifdef PU2NDISSUE
	iF1_hazard ? (INSNBITSZ/8) : (2*(INSNBITSZ/8))
	`else
	(INSNBITSZ/8)
	`endif
	));

////////////////////////////////////// ID (Instruction Decode) stage ///////////////////////////////////////

reg [WORDBITSZ -1 : 0] iD0_pc;
`ifdef SIMULATION
reg [INSNBITSZ -1 : 0] iD0_insn;
`endif

`ifdef PU2NDISSUE
reg [WORDBITSZ -1 : 0] iD1_pc;
`ifdef SIMULATION
reg [INSNBITSZ -1 : 0] iD1_insn;
`endif
`endif

reg [CLOG2GPRCNT -1 : 0] iD0_rdId; // Get set to null if instruction will not set a GPR.
reg [CLOG2GPRCNT -1 : 0] iD0_rs1Id;
reg [CLOG2GPRCNT -1 : 0] iD0_rs2Id;

reg [WORDBITSZ -1 : 0] iD0_Iimm;
reg [WORDBITSZ -1 : 0] iD0_Simm;
reg [WORDBITSZ -1 : 0] iD0_Bimm;
reg [WORDBITSZ -1 : 0] iD0_Uimm;
reg [WORDBITSZ -1 : 0] iD0_Jimm;

reg [3 -1 : 0] iD0_func3;
reg [5 -1 : 0] iD0_func5;
reg [7 -1 : 0] iD0_func7;

`ifdef PU2NDISSUE
reg [CLOG2GPRCNT -1 : 0] iD1_rdId;
reg [CLOG2GPRCNT -1 : 0] iD1_rs1Id;
reg [CLOG2GPRCNT -1 : 0] iD1_rs2Id;

reg iD1_isALUreg;
reg iD1_isALUimm;
reg iD1_isAUIPC;
reg iD1_isLUI;

reg [WORDBITSZ -1 : 0] iD1_Iimm;
reg [WORDBITSZ -1 : 0] iD1_Uimm;

reg [3 -1 : 0] iD1_func3;
reg [7 -1 : 0] iD1_func7;

`ifdef PU2NDISSUE_
reg iD1_rs1Id_eq_iD0_rdId;
reg iD1_rs2Id_eq_iD0_rdId;
`endif
`endif

reg [WORDBITSZ -1 : 0] iD0_pc_plus_INSNBITSzBy8;
reg [WORDBITSZ -1 : 0] iD0_pc_plus_iD0_Bimm;
reg [WORDBITSZ -1 : 0] iD0_pc_plus_iD0_Uimm;
reg [WORDBITSZ -1 : 0] iD0_pc_plus_iD0_Jimm;
`ifdef PU2NDISSUE
reg [WORDBITSZ -1 : 0] iD1_pc_plus_iD1_Uimm;
`endif

reg iD0_isALUreg;
reg iD0_isALUimm;
reg iD0_isBranch;
reg iD0_isJALR;
reg iD0_isJAL;
`ifdef PUPREDICTRET
reg iD0_isRet;
reg iD0_isJALRnotRet;
reg iD0_isCall;
`endif
reg iD0_isAUIPC;
reg iD0_isLUI;
reg iD0_isLoad;
reg iD0_isStore;
reg iD0_isSystem;
reg iD0_isAMO;

reg [WORDBITSZ -1 : 0] iD0_addrImm;

reg iD0_isEcall;
reg iD0_isEbreak;

reg iD0_isCSR;

`ifdef PURV32M
reg iD0_opImul_stb;
reg iD0_opIdiv_stb;
`endif

reg iD0_ldUnit_stb;
reg iD0_stUnit_stb;

reg iD0_isALUimmOrJALrOrLoad;
reg iD0_isBranchOrStore;
reg iD0_isJAlOrAUIPcOrLUI;
reg iD0_isALUregOrBranch;
reg iD0_isJAlOrJALR;
`ifdef PU2NDISSUE
reg iD1_isAUIPcOrLUI;
`endif

reg iD0_multiCycleInsn;

reg iD0_use_rdId;

wire [WORDBITSZ -1 : 0] iD0_rs1;
wire [WORDBITSZ -1 : 0] iD0_rs2;

wire iD0_rdRdy;
wire iD0_rs1Rdy;
wire iD0_rs2Rdy;

`ifdef PU2NDISSUE
wire [WORDBITSZ -1 : 0] iD1_rs1;
wire [WORDBITSZ -1 : 0] iD1_rs2;

wire iD1_rdRdy;
wire iD1_rs1Rdy;
wire iD1_rs2Rdy;
`endif

reg [WORDBITSZ -1 : 0] gprDat [0 : GPRCNT -1];
reg [GPRCNT    -1 : 0] gprRdy;

`ifdef PURV32M
wire iD0_opImul_bsy;
wire iD0_opIdiv_bsy;
`endif
wire iD0_ldUnit_bsy;
wire iD0_stUnit_bsy;

wire iD0_eX0_flushed;
wire iD0_eX0_stalled;
wire iD0_eX0_carryon;

`ifdef PU2NDISSUE
reg iD1_flushed;
`endif

wire iD0_stalled = (!iD0_eX0_carryon ||
	`ifdef PURV32M
	(iD0_opImul_stb ? iD0_opImul_bsy : 1'b0) ||
	(iD0_opIdiv_stb ? iD0_opIdiv_bsy : 1'b0) ||
	`endif
	(iD0_ldUnit_stb ? iD0_ldUnit_bsy : 1'b0) ||
	(iD0_stUnit_stb ? iD0_stUnit_bsy : 1'b0) || (
	// Stall if any of the operand is locked.
	iD0_isALUreg ? !(iD0_rdRdy && iD0_rs1Rdy && iD0_rs2Rdy) :
	iD0_isALUimmOrJALrOrLoad ? !(iD0_rdRdy && iD0_rs1Rdy) :
	iD0_isBranchOrStore ? !(iD0_rs1Rdy && iD0_rs2Rdy) :
	iD0_isJAlOrAUIPcOrLUI ? !iD0_rdRdy : 0)
	`ifdef PU2NDISSUE
	|| (iD1_flushed ? 0 :
	iD1_isALUreg ? !(iD1_rdRdy && iD1_rs1Rdy && iD1_rs2Rdy) :
	iD1_isALUimm ? !(iD1_rdRdy && iD1_rs1Rdy) :
	iD1_isAUIPcOrLUI ? !iD1_rdRdy : 0)
	`endif
	);

assign iF0_iD0_stalled = iD0_stalled;

reg iD0_flushed;

assign iF0_iD0_flushed = iD0_flushed;

wire iD0_carryon = (iD0_flushed || !iD0_stalled);

assign iF0_iD0_carryon = iD0_carryon;

wire iD0_en = (iD0_carryon && !halted_o);

wire [CLOG2GPRCNT -1 : 0] _iF0_rdId  = (iD0_en ? iF0_rdId  : iD0_rdId);
wire [CLOG2GPRCNT -1 : 0] _iF0_rs1Id = (iD0_en ? iF0_rs1Id : iD0_rs1Id);
wire [CLOG2GPRCNT -1 : 0] _iF0_rs2Id = (iD0_en ? iF0_rs2Id : iD0_rs2Id);
`ifdef PU2NDISSUE
wire [CLOG2GPRCNT -1 : 0] _iF1_rdId  = (iD0_en ? iF1_rdId  : iD1_rdId);
wire [CLOG2GPRCNT -1 : 0] _iF1_rs1Id = (iD0_en ? iF1_rs1Id : iD1_rs1Id);
wire [CLOG2GPRCNT -1 : 0] _iF1_rs2Id = (iD0_en ? iF1_rs2Id : iD1_rs2Id);
`endif

wire _iF0_use_rdId = (iD0_en ? iF0_use_rdId : iD0_use_rdId);

reg [CLOG2GPRCNT -1 : 0] iD0_eX0_rdId;
reg [WORDBITSZ -1 : 0]   iD0_eX0_rslt;
`ifdef PU2NDISSUE
reg [CLOG2GPRCNT -1 : 0] iD1_eX1_rdId;
reg [WORDBITSZ -1 : 0]   iD1_eX1_rslt;
`endif

wire iD0_rdId_eq_iD0_eX0_rdId  = ((iD0_rdId  == iD0_eX0_rdId) && iD0_eX0_rdId);
wire iD0_rs1Id_eq_iD0_eX0_rdId = ((iD0_rs1Id == iD0_eX0_rdId) && iD0_eX0_rdId);
wire iD0_rs2Id_eq_iD0_eX0_rdId = ((iD0_rs2Id == iD0_eX0_rdId) && iD0_eX0_rdId);
`ifdef PU2NDISSUE
wire iD0_rdId_eq_iD1_eX1_rdId  = ((iD0_rdId  == iD1_eX1_rdId) && iD1_eX1_rdId);
wire iD0_rs1Id_eq_iD1_eX1_rdId = ((iD0_rs1Id == iD1_eX1_rdId) && iD1_eX1_rdId);
wire iD0_rs2Id_eq_iD1_eX1_rdId = ((iD0_rs2Id == iD1_eX1_rdId) && iD1_eX1_rdId);
`endif

reg [CLOG2GPRCNT -1 : 0] iD0_rW0_rdId;
reg [WORDBITSZ -1 : 0]   iD0_rW0_rslt;
`ifdef PU2NDISSUE
reg [CLOG2GPRCNT -1 : 0] iD1_rW1_rdId;
reg [WORDBITSZ -1 : 0]   iD1_rW1_rslt;
`endif

wire iD0_rdId_eq_iD0_rW0_rdId  = ((iD0_rdId  == iD0_rW0_rdId) && iD0_rW0_rdId);
wire iD0_rs1Id_eq_iD0_rW0_rdId = ((iD0_rs1Id == iD0_rW0_rdId) && iD0_rW0_rdId);
wire iD0_rs2Id_eq_iD0_rW0_rdId = ((iD0_rs2Id == iD0_rW0_rdId) && iD0_rW0_rdId);
`ifdef PU2NDISSUE
wire iD0_rdId_eq_iD1_rW1_rdId  = ((iD0_rdId  == iD1_rW1_rdId) && iD1_rW1_rdId);
wire iD0_rs1Id_eq_iD1_rW1_rdId = ((iD0_rs1Id == iD1_rW1_rdId) && iD1_rW1_rdId);
wire iD0_rs2Id_eq_iD1_rW1_rdId = ((iD0_rs2Id == iD1_rW1_rdId) && iD1_rW1_rdId);
`endif

`ifdef PU2NDISSUE
wire iD1_rdId_eq_iD1_eX1_rdId  = ((iD1_rdId  == iD1_eX1_rdId) && iD1_eX1_rdId);
wire iD1_rs1Id_eq_iD1_eX1_rdId = ((iD1_rs1Id == iD1_eX1_rdId) && iD1_eX1_rdId);
wire iD1_rs2Id_eq_iD1_eX1_rdId = ((iD1_rs2Id == iD1_eX1_rdId) && iD1_eX1_rdId);
wire iD1_rdId_eq_iD0_eX0_rdId  = ((iD1_rdId  == iD0_eX0_rdId) && iD0_eX0_rdId);
wire iD1_rs1Id_eq_iD0_eX0_rdId = ((iD1_rs1Id == iD0_eX0_rdId) && iD0_eX0_rdId);
wire iD1_rs2Id_eq_iD0_eX0_rdId = ((iD1_rs2Id == iD0_eX0_rdId) && iD0_eX0_rdId);

wire iD1_rdId_eq_iD1_rW1_rdId  = ((iD1_rdId  == iD1_rW1_rdId) && iD1_rW1_rdId);
wire iD1_rs1Id_eq_iD1_rW1_rdId = ((iD1_rs1Id == iD1_rW1_rdId) && iD1_rW1_rdId);
wire iD1_rs2Id_eq_iD1_rW1_rdId = ((iD1_rs2Id == iD1_rW1_rdId) && iD1_rW1_rdId);
wire iD1_rdId_eq_iD0_rW0_rdId  = ((iD1_rdId  == iD0_rW0_rdId) && iD0_rW0_rdId);
wire iD1_rs1Id_eq_iD0_rW0_rdId = ((iD1_rs1Id == iD0_rW0_rdId) && iD0_rW0_rdId);
wire iD1_rs2Id_eq_iD0_rW0_rdId = ((iD1_rs2Id == iD0_rW0_rdId) && iD0_rW0_rdId);
`endif

reg [WORDBITSZ -1 : 0] iD0_rs1_;
reg [WORDBITSZ -1 : 0] iD0_rs2_;
assign iD0_rs1 = (
	iD0_rs1Id_eq_iD0_eX0_rdId ? iD0_eX0_rslt :
	`ifdef PU2NDISSUE
	iD0_rs1Id_eq_iD1_eX1_rdId ? iD1_eX1_rslt :
	`endif
	iD0_rs1Id_eq_iD0_rW0_rdId ? iD0_rW0_rslt :
	`ifdef PU2NDISSUE
	iD0_rs1Id_eq_iD1_rW1_rdId ? iD1_rW1_rslt :
	`endif
	iD0_rs1Id ? iD0_rs1_ : {WORDBITSZ{1'b0}});
assign iD0_rs2 = (
	iD0_rs2Id_eq_iD0_eX0_rdId ? iD0_eX0_rslt :
	`ifdef PU2NDISSUE
	iD0_rs2Id_eq_iD1_eX1_rdId ? iD1_eX1_rslt :
	`endif
	iD0_rs2Id_eq_iD0_rW0_rdId ? iD0_rW0_rslt :
	`ifdef PU2NDISSUE
	iD0_rs2Id_eq_iD1_rW1_rdId ? iD1_rW1_rslt :
	`endif
	iD0_rs2Id ? iD0_rs2_ : {WORDBITSZ{1'b0}});
`ifdef PU2NDISSUE
reg [WORDBITSZ -1 : 0] iD1_rs1_;
reg [WORDBITSZ -1 : 0] iD1_rs2_;
assign iD1_rs1 = (
	iD1_rs1Id_eq_iD0_eX0_rdId ? iD0_eX0_rslt :
	iD1_rs1Id_eq_iD1_eX1_rdId ? iD1_eX1_rslt :
	iD1_rs1Id_eq_iD0_rW0_rdId ? iD0_rW0_rslt :
	iD1_rs1Id_eq_iD1_rW1_rdId ? iD1_rW1_rslt :
	iD1_rs1Id ? iD1_rs1_ : {WORDBITSZ{1'b0}});
assign iD1_rs2 = (
	iD1_rs2Id_eq_iD0_eX0_rdId ? iD0_eX0_rslt :
	iD1_rs2Id_eq_iD1_eX1_rdId ? iD1_eX1_rslt :
	iD1_rs2Id_eq_iD0_rW0_rdId ? iD0_rW0_rslt :
	iD1_rs2Id_eq_iD1_rW1_rdId ? iD1_rW1_rslt :
	iD1_rs2Id ? iD1_rs2_ : {WORDBITSZ{1'b0}});
`endif
// iD*_r*Rdy_ registers capture the availability of rd, rs1 and rs2
// registers only when an instruction enters the iDecoded stage.
// iD*_r*Rdy__ registers become true when rd, rs1 and rs2 registers become
// available while the instruction is stalled at the iDecoded stage.
reg iD0_rdRdy_,  iD0_rdRdy__;
reg iD0_rs1Rdy_, iD0_rs1Rdy__;
reg iD0_rs2Rdy_, iD0_rs2Rdy__;
assign iD0_rdRdy = ((
	iD0_rdId_eq_iD0_eX0_rdId ? 1'b1 :
	`ifdef PU2NDISSUE
	iD0_rdId_eq_iD1_eX1_rdId ? 1'b1 :
	`endif
	iD0_rdId_eq_iD0_rW0_rdId ? 1'b1 :
	`ifdef PU2NDISSUE
	iD0_rdId_eq_iD1_rW1_rdId ? 1'b1 :
	`endif
	iD0_rdRdy_) || iD0_rdRdy__);
assign iD0_rs1Rdy = ((
	iD0_rs1Id_eq_iD0_eX0_rdId ? 1'b1 :
	`ifdef PU2NDISSUE
	iD0_rs1Id_eq_iD1_eX1_rdId ? 1'b1 :
	`endif
	iD0_rs1Id_eq_iD0_rW0_rdId ? 1'b1 :
	`ifdef PU2NDISSUE
	iD0_rs1Id_eq_iD1_rW1_rdId ? 1'b1 :
	`endif
	iD0_rs1Rdy_) || iD0_rs1Rdy__);
assign iD0_rs2Rdy = ((
	iD0_rs2Id_eq_iD0_eX0_rdId ? 1'b1 :
	`ifdef PU2NDISSUE
	iD0_rs2Id_eq_iD1_eX1_rdId ? 1'b1 :
	`endif
	iD0_rs2Id_eq_iD0_rW0_rdId ? 1'b1 :
	`ifdef PU2NDISSUE
	iD0_rs2Id_eq_iD1_rW1_rdId ? 1'b1 :
	`endif
	iD0_rs2Rdy_) || iD0_rs2Rdy__);
`ifdef PU2NDISSUE
reg iD1_rdRdy_,  iD1_rdRdy__;
reg iD1_rs1Rdy_, iD1_rs1Rdy__;
reg iD1_rs2Rdy_, iD1_rs2Rdy__;
assign iD1_rdRdy = ((
	iD1_rdId_eq_iD0_eX0_rdId ? 1'b1 :
	iD1_rdId_eq_iD1_eX1_rdId ? 1'b1 :
	iD1_rdId_eq_iD0_rW0_rdId ? 1'b1 :
	iD1_rdId_eq_iD1_rW1_rdId ? 1'b1 :
	iD1_rdRdy_) || iD1_rdRdy__);
assign iD1_rs1Rdy = ((
	iD1_rs1Id_eq_iD0_eX0_rdId ? 1'b1 :
	iD1_rs1Id_eq_iD1_eX1_rdId ? 1'b1 :
	iD1_rs1Id_eq_iD0_rW0_rdId ? 1'b1 :
	iD1_rs1Id_eq_iD1_rW1_rdId ? 1'b1 :
	iD1_rs1Rdy_) || iD1_rs1Rdy__);
assign iD1_rs2Rdy = ((
	iD1_rs2Id_eq_iD0_eX0_rdId ? 1'b1 :
	iD1_rs2Id_eq_iD1_eX1_rdId ? 1'b1 :
	iD1_rs2Id_eq_iD0_rW0_rdId ? 1'b1 :
	iD1_rs2Id_eq_iD1_rW1_rdId ? 1'b1 :
	iD1_rs2Rdy_) || iD1_rs2Rdy__);
`endif

`include "./dcache.pu.v"

`include "./memctrl.pu.v"

wire iD0_eX0_JumpOrBranch_i;

wire _iF0_flushed = ((iD0_en ? iF0_flushed : iD0_flushed) || iD0_eX0_JumpOrBranch_i);
`ifdef PU2NDISSUE
wire _iF1_flushed = ((iD0_en ? iF1_hazard : iD1_flushed) || iD0_eX0_JumpOrBranch_i);
`endif

always @ (posedge clk_i) begin

	iD0_rs1_ <= gprDat[_iF0_rs1Id];
	iD0_rs2_ <= gprDat[_iF0_rs2Id];
	`ifdef PU2NDISSUE
	iD1_rs1_ <= gprDat[_iF1_rs1Id];
	iD1_rs2_ <= gprDat[_iF1_rs2Id];
	`endif

	iD0_rdRdy_  <= gprRdy[_iF0_rdId];
	iD0_rs1Rdy_ <= gprRdy[_iF0_rs1Id];
	iD0_rs2Rdy_ <= gprRdy[_iF0_rs2Id];
	`ifdef PU2NDISSUE
	iD1_rdRdy_  <= gprRdy[_iF1_rdId];
	iD1_rs1Rdy_ <= gprRdy[_iF1_rs1Id];
	iD1_rs2Rdy_ <= gprRdy[_iF1_rs2Id];
	`endif

	if (iD0_en)
		iD0_rdRdy__ <= 1'b0;
	else if (iD0_rdRdy)
		iD0_rdRdy__ <= 1'b1;

	if (iD0_en)
		iD0_rs1Rdy__ <= 1'b0;
	else if (iD0_rs1Rdy)
		iD0_rs1Rdy__ <= 1'b1;

	if (iD0_en)
		iD0_rs2Rdy__ <= 1'b0;
	else if (iD0_rs2Rdy)
		iD0_rs2Rdy__ <= 1'b1;

	`ifdef PU2NDISSUE
	if (iD0_en)
		iD1_rdRdy__ <= 1'b0;
	else if (iD1_rdRdy)
		iD1_rdRdy__ <= 1'b1;

	if (iD0_en)
		iD1_rs1Rdy__ <= 1'b0;
	else if (iD1_rs1Rdy)
		iD1_rs1Rdy__ <= 1'b1;

	if (iD0_en)
		iD1_rs2Rdy__ <= 1'b0;
	else if (iD1_rs2Rdy)
		iD1_rs2Rdy__ <= 1'b1;
	`endif

	if (rst_i) begin
		iD0_flushed <= 1;
		`ifdef PU2NDISSUE
		iD1_flushed <= 1;
		`endif
	end else if (iD0_en) begin
		iD0_flushed <= (iF0_flushed || iD0_eX0_JumpOrBranch_i);
		`ifdef PU2NDISSUE
		iD1_flushed <= (iF1_hazard || iD0_eX0_JumpOrBranch_i);
		`endif
	end

	if (iD0_en) begin

		iD0_pc <= iF0_pc;
		`ifdef SIMULATION
		iD0_insn <= iF0_insn;
		`endif

		`ifdef PU2NDISSUE
		iD1_pc <= iF1_pc;
		`ifdef SIMULATION
		iD1_insn <= iF1_insn;
		`endif
		`endif

		iD0_rdId  <= (iF0_use_rdId ? iF0_rdId : 5'd0);
		iD0_rs1Id <= iF0_rs1Id;
		iD0_rs2Id <= iF0_rs2Id;

		iD0_Iimm <= iF0_Iimm;
		iD0_Simm <= iF0_Simm;
		iD0_Bimm <= iF0_Bimm;
		iD0_Uimm <= iF0_Uimm;
		iD0_Jimm <= iF0_Jimm;

		iD0_func3 <= iF0_func3;
		iD0_func5 <= iF0_func5;
		iD0_func7 <= iF0_func7;

		`ifdef PU2NDISSUE
		iD1_rdId  <= iF1_rdId;
		iD1_rs1Id <= iF1_rs1Id;
		iD1_rs2Id <= iF1_rs2Id;

		iD1_isALUreg <= iF1_isALUreg;
		iD1_isALUimm <= iF1_isALUimm;
		iD1_isAUIPC  <= iF1_isAUIPC;
		iD1_isLUI    <= iF1_isLUI;

		iD1_Iimm <= iF1_Iimm;
		iD1_Uimm <= iF1_Uimm;

		iD1_func3 <= iF1_func3;
		iD1_func7 <= iF1_func7;

		`ifdef PU2NDISSUE_
		iD1_rs1Id_eq_iD0_rdId <= iF1_rs1Id_eq_iF0_rdId;
		iD1_rs2Id_eq_iD0_rdId <= iF1_rs2Id_eq_iF0_rdId;
		`endif
		`endif

		iD0_pc_plus_INSNBITSzBy8 <= iF0_pc_plus_INSNBITSzBy8;
		iD0_pc_plus_iD0_Bimm     <= iF0_pc_plus_iF0_Bimm;
		iD0_pc_plus_iD0_Uimm     <= iF0_pc_plus_iF0_Uimm;
		iD0_pc_plus_iD0_Jimm     <= iF0_pc_plus_iF0_Jimm;
		`ifdef PU2NDISSUE
		iD1_pc_plus_iD1_Uimm <= iF1_pc_plus_iF1_Uimm;
		`endif

		iD0_isALUreg <= iF0_isALUreg;
		iD0_isALUimm <= iF0_isALUimm;
		iD0_isBranch <= iF0_isBranch;
		iD0_isJALR   <= iF0_isJALR;
		iD0_isJAL    <= iF0_isJAL;
		`ifdef PUPREDICTRET
		iD0_isRet        <= iF0_isRet;
		iD0_isJALRnotRet <= iF0_isJALRnotRet;
		iD0_isCall       <= iF0_isCall;
		`endif
		iD0_isAUIPC  <= iF0_isAUIPC;
		iD0_isLUI    <= iF0_isLUI;
		iD0_isLoad   <= iF0_isLoad;
		iD0_isStore  <= iF0_isStore;
		iD0_isSystem <= iF0_isSystem;
		iD0_isAMO    <= iF0_isAMO;

		iD0_addrImm <= iF0_addrImm;

		iD0_isEcall  <= iF0_isEcall;
		iD0_isEbreak <= iF0_isEbreak;

		iD0_isCSR <= iF0_isCSR;

		`ifdef PURV32M
		iD0_opImul_stb <= iF0_opImul_stb;
		iD0_opIdiv_stb <= iF0_opIdiv_stb;
		`endif

		iD0_ldUnit_stb <= iF0_ldUnit_stb;
		iD0_stUnit_stb <= iF0_stUnit_stb;

		iD0_isALUimmOrJALrOrLoad <= iF0_isALUimmOrJALrOrLoad;
		iD0_isBranchOrStore      <= iF0_isBranchOrStore;
		iD0_isJAlOrAUIPcOrLUI    <= iF0_isJAlOrAUIPcOrLUI;
		iD0_isALUregOrBranch     <= iF0_isALUregOrBranch;
		iD0_isJAlOrJALR          <= iF0_isJAlOrJALR;
		`ifdef PU2NDISSUE
		iD1_isAUIPcOrLUI <= iF1_isAUIPcOrLUI;
		`endif

		iD0_multiCycleInsn <= iF0_multiCycleInsn;

		iD0_use_rdId <= iF0_use_rdId;
	end
end

////////////////////////////////////// EX (Execute) stage //////////////////////////////////////////////////

`ifdef SIMULATION
reg [WORDBITSZ -1 : 0] eX0_pc;
reg [INSNBITSZ -1 : 0] eX0_insn;
`endif

wire [WORDBITSZ -1 : 0] eX0_aluArg1_i = iD0_rs1;
wire [WORDBITSZ -1 : 0] eX0_aluArg2_i = (iD0_isALUregOrBranch ? iD0_rs2 : iD0_Iimm);

// The adder is used by both arithmetic instructions and JALR.
wire [WORDBITSZ -1 : 0] eX0_aluPlus_i = (eX0_aluArg1_i + eX0_aluArg2_i);

// Use a single (WORDBITSZ+1) bits subtract to do subtraction and all comparisons.
wire [(WORDBITSZ+1) -1 : 0] eX0_aluMinus_i = (({1'b1, ~eX0_aluArg2_i} + {1'b0, eX0_aluArg1_i}) + 1'b1);
wire eX0_lt_i = (
	(eX0_aluArg1_i[WORDBITSZ-1] ^ eX0_aluArg2_i[WORDBITSZ-1]) ?
		eX0_aluArg1_i[WORDBITSZ-1] : eX0_aluMinus_i[WORDBITSZ]);
wire eX0_ltu_i = eX0_aluMinus_i[WORDBITSZ];
wire eX0_eq_i = (eX0_aluMinus_i[WORDBITSZ-1:0] == {WORDBITSZ{1'b0}});

wire [(WORDBITSZ+1) -1 : 0] _eX0_aluArg1_i = {iD0_func7[5] & eX0_aluArg1_i[WORDBITSZ-1], eX0_aluArg1_i};

reg [WORDBITSZ -1 : 0] eX0_aluOut_i; // ### comb-block-reg.
always @* begin
	case(iD0_func3)
	3'b000: eX0_aluOut_i = ((iD0_isALUreg && iD0_func7[5]) ? eX0_aluMinus_i[WORDBITSZ-1:0] : eX0_aluPlus_i);
	3'b001: eX0_aluOut_i = (eX0_aluArg1_i << eX0_aluArg2_i[4:0]);
	3'b010: eX0_aluOut_i = {{(WORDBITSZ-1){1'b0}}, eX0_lt_i};
	3'b011: eX0_aluOut_i = {{(WORDBITSZ-1){1'b0}}, eX0_ltu_i};
	3'b100: eX0_aluOut_i = (eX0_aluArg1_i ^ eX0_aluArg2_i);
	3'b101: eX0_aluOut_i = ($signed(_eX0_aluArg1_i) >>> eX0_aluArg2_i[4:0]);
	3'b110: eX0_aluOut_i = (eX0_aluArg1_i | eX0_aluArg2_i);
	3'b111: eX0_aluOut_i = (eX0_aluArg1_i & eX0_aluArg2_i);
	endcase
end

reg [WORDBITSZ -1 : 0] eX0_csrOut_i; // ### comb-block-reg.

wire [WORDBITSZ -1 : 0] eX0_rslt_i = (
	iD0_isJAlOrJALR ? (iD0_pc_plus_INSNBITSzBy8) :
	iD0_isLUI       ? iD0_Uimm                   :
	iD0_isAUIPC     ? iD0_pc_plus_iD0_Uimm       :
	iD0_isCSR       ? eX0_csrOut_i               :
	                  eX0_aluOut_i              );

`ifdef PU2NDISSUE
`ifdef SIMULATION
reg [WORDBITSZ -1 : 0] eX1_pc;
reg [INSNBITSZ -1 : 0] eX1_insn;
`endif

`ifdef PU2NDISSUE_
wire [WORDBITSZ -1 : 0] eX1_aluArg1_i = (iD1_rs1Id_eq_iD0_rdId ? eX0_rslt_i : iD1_rs1);
wire [WORDBITSZ -1 : 0] eX1_aluArg2_i = (
	iD1_isALUreg ? (iD1_rs2Id_eq_iD0_rdId ? eX0_rslt_i : iD1_rs2) : iD1_Iimm);
`else
wire [WORDBITSZ -1 : 0] eX1_aluArg1_i = iD1_rs1;
wire [WORDBITSZ -1 : 0] eX1_aluArg2_i = (iD1_isALUreg ? iD1_rs2 : iD1_Iimm);
`endif

wire [WORDBITSZ -1 : 0] eX1_aluPlus_i = (eX1_aluArg1_i + eX1_aluArg2_i);

// Use a single (WORDBITSZ+1) bits subtract to do subtraction and all comparisons.
wire [(WORDBITSZ+1) -1 : 0] eX1_aluMinus_i = (({1'b1, ~eX1_aluArg2_i} + {1'b0, eX1_aluArg1_i}) + 1'b1);
wire eX1_lt_i = (
	(eX1_aluArg1_i[WORDBITSZ-1] ^ eX1_aluArg2_i[WORDBITSZ-1]) ?
		eX1_aluArg1_i[WORDBITSZ-1] : eX1_aluMinus_i[WORDBITSZ]);
wire eX1_ltu_i = eX1_aluMinus_i[WORDBITSZ];

wire [(WORDBITSZ+1) -1 : 0] _eX1_aluArg1_i = {iD1_func7[5] & eX1_aluArg1_i[WORDBITSZ-1], eX1_aluArg1_i};

reg [WORDBITSZ -1 : 0] eX1_aluOut_i; // ### comb-block-reg.
always @* begin
	case(iD1_func3)
	3'b000: eX1_aluOut_i = ((iD1_isALUreg && iD1_func7[5]) ? eX1_aluMinus_i[WORDBITSZ-1:0] : eX1_aluPlus_i);
	3'b001: eX1_aluOut_i = (eX1_aluArg1_i << eX1_aluArg2_i[4:0]);
	3'b010: eX1_aluOut_i = {{(WORDBITSZ-1){1'b0}}, eX1_lt_i};
	3'b011: eX1_aluOut_i = {{(WORDBITSZ-1){1'b0}}, eX1_ltu_i};
	3'b100: eX1_aluOut_i = (eX1_aluArg1_i ^ eX1_aluArg2_i);
	3'b101: eX1_aluOut_i = ($signed(_eX1_aluArg1_i) >>> eX1_aluArg2_i[4:0]);
	3'b110: eX1_aluOut_i = (eX1_aluArg1_i | eX1_aluArg2_i);
	3'b111: eX1_aluOut_i = (eX1_aluArg1_i & eX1_aluArg2_i);
	endcase
end
`endif

reg eX0_takeBranch_i; // ### comb-block-reg.
always @* begin
	case (iD0_func3)
	3'b000:  eX0_takeBranch_i = eX0_eq_i;
	3'b001:  eX0_takeBranch_i = !eX0_eq_i;
	3'b100:  eX0_takeBranch_i = eX0_lt_i;
	3'b101:  eX0_takeBranch_i = !eX0_lt_i;
	3'b110:  eX0_takeBranch_i = eX0_ltu_i;
	3'b111:  eX0_takeBranch_i = !eX0_ltu_i;
	default: eX0_takeBranch_i = 1'b0;
	endcase
end

`ifdef PUPREDICTBRANCH
wire [2 -1 : 0] eX0_predictBranch_i = iD0_predictBranch;
`else
wire [2 -1 : 0] eX0_predictBranch_i = 2'b00;
`endif
wire _eX0_takeBranch_i = (eX0_takeBranch_i ^ eX0_predictBranch_i[1]);

`ifdef PUPREDICTRET
wire eX0_predictRetMiss_i = (iD0_predictRet != {eX0_aluPlus_i[WORDBITSZ-1:1], 1'b0});
`endif

wire eX0_rW0_flushed;
wire eX0_rW0_stalled;
wire eX0_rW0_carryon;

wire eX0_stalled = !eX0_rW0_carryon;

assign iD0_eX0_stalled = eX0_stalled;

// Jumps or Branchs are triggered only at the iDecoded stage.
// Interrupts and exceptions set eX0_flushed_i to prevent eXecution.
wire eX0_flushed_i = (iD0_flushed || iD0_stalled);
reg eX0_flushed;
`ifdef PU2NDISSUE
wire eX1_flushed_i = (iD1_flushed || iD0_stalled);
reg eX1_flushed;
`endif

assign iD0_eX0_flushed = eX0_flushed;

wire eX0_carryon = (eX0_flushed || !eX0_stalled);

assign iD0_eX0_carryon = eX0_carryon;

wire eX0_en = (eX0_carryon && !halted_o);

wire eX0_insn_valid_i = (!eX0_flushed_i && eX0_en);

`ifdef PUPREDICTBRANCH
wire [2 -1 : 0] bht_i = (
	{eX0_takeBranch_i, eX0_predictBranch_i} == 3'b000 ? 2'b00 :
	{eX0_takeBranch_i, eX0_predictBranch_i} == 3'b001 ? 2'b00 :
	{eX0_takeBranch_i, eX0_predictBranch_i} == 3'b010 ? 2'b01 :
	{eX0_takeBranch_i, eX0_predictBranch_i} == 3'b011 ? 2'b10 :
	{eX0_takeBranch_i, eX0_predictBranch_i} == 3'b100 ? 2'b01 :
	{eX0_takeBranch_i, eX0_predictBranch_i} == 3'b101 ? 2'b10 :
	{eX0_takeBranch_i, eX0_predictBranch_i} == 3'b110 ? 2'b11 :
	                                                    2'b11 );
always @ (posedge clk_i) begin
	if (iD0_isBranch && eX0_insn_valid_i)
		bht[iD0_pc[CLOG2BHTSETCNT+CLOG2INSNBITSZBY8-1:CLOG2INSNBITSZBY8]] <= bht_i;
end
`endif

`ifdef PUPREDICTRET
always @ (posedge clk_i) begin
	if (eX0_insn_valid_i) begin
		if (iD0_isCall) begin
			ras0 <= iD0_pc_plus_INSNBITSzBy8;
			ras1 <= ras0;
			ras2 <= ras1;
			ras3 <= ras2;
			ras4 <= ras3;
			ras5 <= ras4;
			ras6 <= ras5;
			ras7 <= ras6;
		end else if (iD0_isRet) begin
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
wire eX0_JumpOrBranch_i = ((
	`ifndef PUPREDICTJAL
	iD0_isJAL ||
	`endif
	`ifdef PUPREDICTRET
	(iD0_isRet && eX0_predictRetMiss_i) ||
	iD0_isJALRnotRet ||
	`else
	iD0_isJALR ||
	`endif
	(iD0_isBranch && _eX0_takeBranch_i)) && eX0_insn_valid_i);

assign iF0_eX0_JumpOrBranch_i = eX0_JumpOrBranch_i;
assign iD0_eX0_JumpOrBranch_i = eX0_JumpOrBranch_i;

// TODO: Use irq and exc signals ...
wire [WORDBITSZ -1 : 0] eX0_JumpOrBranchAddr_i = (
	iD0_isBranch ? (eX0_takeBranch_i ? iD0_pc_plus_iD0_Bimm : iD0_pc_plus_INSNBITSzBy8) :
	`ifndef PUPREDICTJAL
	iD0_isJAL ? iD0_pc_plus_iD0_Jimm :
	`endif
	/* iD0_isJALR */ {eX0_aluPlus_i[WORDBITSZ-1:1], 1'b0});

assign iF0_eX0_JumpOrBranchAddr_i = eX0_JumpOrBranchAddr_i;

`ifdef PU2NDISSUE
wire [WORDBITSZ -1 : 0] eX1_rslt_i = (
	iD1_isLUI   ? iD1_Uimm             :
	iD1_isAUIPC ? iD1_pc_plus_iD1_Uimm :
	              eX1_aluOut_i        );
`endif

reg eX0_multiCycleInsn;

always @ (posedge clk_i) begin

	if (rst_i) begin
		eX0_flushed <= 1;
		`ifdef PU2NDISSUE
		eX1_flushed <= 1;
		`endif
		eX0_multiCycleInsn <= 1;
	end else if (eX0_en) begin
		eX0_flushed <= eX0_flushed_i;
		`ifdef PU2NDISSUE
		eX1_flushed <= eX1_flushed_i;
		`endif
		eX0_multiCycleInsn <= iD0_multiCycleInsn;
	end

	if (eX0_en) begin
		`ifdef SIMULATION
		eX0_pc   <= iD0_pc;
		eX0_insn <= iD0_insn;
		`endif
		iD0_eX0_rdId <= ((iD0_multiCycleInsn || eX0_flushed_i) ? 5'd0 : iD0_rdId);
		iD0_eX0_rslt <= eX0_rslt_i;
		`ifdef PU2NDISSUE
		`ifdef SIMULATION
		eX1_pc   <= iD1_pc;
		eX1_insn <= iD1_insn;
		`endif
		iD1_eX1_rdId <= (eX1_flushed_i ? 5'd0 : iD1_rdId);
		iD1_eX1_rslt <= eX1_rslt_i;
		`endif
	end
end

////////////////////////////////////// RWB (Register WriteBack) stage //////////////////////////////////////

`ifdef SIMULATION
reg [WORDBITSZ -1 : 0] rW0_pc;
reg [INSNBITSZ -1 : 0] rW0_insn;
`endif

reg                      rW0_we_i;  // ### comb-block-reg.
reg [CLOG2GPRCNT -1 : 0] rW0_idx_i; // ### comb-block-reg.
reg [WORDBITSZ -1 : 0]   rW0_dat_i; // ### comb-block-reg.

`ifdef PURV32M
reg rW0_opImul_done; // ### comb-block-reg.
reg rW0_opIdiv_done; // ### comb-block-reg.
`endif

`ifdef PURV32M
`include "./imul.pu.v"
`include "./idiv.pu.v"
`endif
`include "./lsu.pu.v"
`include "./sys.pu.v"

wire rW0_stalled = (
	ldUnit_memAck
	`ifdef PURV32M
	|| opImul_done || opIdiv_done
	`endif
	);

assign eX0_rW0_stalled = rW0_stalled;

reg rW0_flushed;
always @ (posedge clk_i)
	rW0_flushed <= (eX0_flushed || eX0_stalled);

assign eX0_rW0_flushed = (rW0_flushed && !rW0_stalled);

assign eX0_rW0_carryon = (eX0_rW0_flushed || !eX0_rW0_stalled);

always @* begin

	rW0_we_i  = 0;
	rW0_idx_i = 0;
	rW0_dat_i = 0;

	`ifdef PURV32M
	rW0_opImul_done = 0;
	rW0_opIdiv_done = 0;
	`endif

	if (ldUnit_memAck) begin
		rW0_we_i  = 1;
		rW0_idx_i = ldUnit_rqsts_rIdx;
		rW0_dat_i = ldUnit_rqsts_dato;
	`ifdef PURV32M
	end else if (opImul_done) begin
		rW0_we_i  = 1;
		rW0_idx_i = opImul_rIdx;
		rW0_dat_i = opImul_rslt;
		rW0_opImul_done = 1;
	end else if (opIdiv_done) begin
		rW0_we_i  = 1;
		rW0_idx_i = opIdiv_rIdx;
		rW0_dat_i = opIdiv_rslt;
		rW0_opIdiv_done = 1;
	`endif
	end else if (halted_o) begin
	end else if (iD0_eX0_rdId /*&& !eX0_flushed*/) begin
		rW0_we_i  = 1;
		rW0_idx_i = iD0_eX0_rdId;
		rW0_dat_i = iD0_eX0_rslt;
	end
end

always @ (posedge clk_i) begin

	if (ldUnit_memAck) begin
		iD0_rW0_rdId <= ldUnit_rqsts_rIdx;
		iD0_rW0_rslt <= ldUnit_rqsts_dato;
	`ifdef PURV32M
	end else if (opImul_done) begin
		iD0_rW0_rdId <= opImul_rIdx;
		iD0_rW0_rslt <= opImul_rslt;
	end else if (opIdiv_done) begin
		iD0_rW0_rdId <= opIdiv_rIdx;
		iD0_rW0_rslt <= opIdiv_rslt;
	`endif
	end else if (halted_o) begin
	end else if (iD0_eX0_rdId /*&& !eX0_flushed*/) begin
		iD0_rW0_rdId <= (
			(!iD0_flushed && iD0_multiCycleInsn && iD0_eX0_rdId == iD0_rdId) ?
			/* Considering the instruction sequence below, this above check
			prevents the result of `add a3,a3,a1` to be forwarded to `jr a3`,
			when the result of `lw a3,0(a3)` should be used but has been deferred
			due to being from a multi-cycle instruction.
			add     a3,a3,a1
			lw      a3,0(a3)       (Multi-cycle instruction)
			jr      a3                                                        */
			{CLOG2GPRCNT{1'b0}} : iD0_eX0_rdId);
		iD0_rW0_rslt <= iD0_eX0_rslt;
	end else
		iD0_rW0_rdId <= 0;
end

`ifdef PU2NDISSUE
`ifdef SIMULATION
reg [WORDBITSZ -1 : 0] rW1_pc;
reg [INSNBITSZ -1 : 0] rW1_insn;
`endif

reg                      rW1_we_i;  // ### comb-block-reg.
reg [CLOG2GPRCNT -1 : 0] rW1_idx_i; // ### comb-block-reg.
reg [WORDBITSZ -1 : 0]   rW1_dat_i; // ### comb-block-reg.

always @* begin

	rW1_we_i  = 0;
	rW1_idx_i = 0;
	rW1_dat_i = 0;

	if (halted_o);
	else if (iD1_eX1_rdId /*&& !eX1_flushed*/) begin
		rW1_we_i  = 1;
		rW1_idx_i = iD1_eX1_rdId;
		rW1_dat_i = iD1_eX1_rslt;
	end
end

always @ (posedge clk_i) begin
	if (halted_o) begin
		iD1_rW1_rdId <= 0;
	end else if (iD1_eX1_rdId /*&& !eX1_flushed*/) begin
		iD1_rW1_rdId <= (
			// Note that iD0_rdId is used instead of iD1_rdId
			// because it is the one for iD0_multiCycleInsn.
			(!iD0_flushed && iD0_multiCycleInsn && iD1_eX1_rdId == iD0_rdId) ?
			/* Considering the instruction sequence below, this above check
			prevents the result of `add a3,a3,a1` to be forwarded to `jr a3`,
			when the result of `lw a3,0(a3)` should be used but has been deferred
			due to being from a multi-cycle instruction.
			add     a3,a3,a1
			lw      a3,0(a3)       (Multi-cycle instruction)
			jr      a3                                                        */
			{CLOG2GPRCNT{1'b0}} : iD1_eX1_rdId);
		iD1_rW1_rslt <= iD1_eX1_rslt;
	end else
		iD1_rW1_rdId <= 0;
end
`endif

always @ (posedge clk_i) begin
	if (rW0_we_i)
		gprDat[rW0_idx_i] <= rW0_dat_i;
	`ifdef PU2NDISSUE
	if (rW1_we_i)
		gprDat[rW1_idx_i] <= rW1_dat_i;
	`endif
end

wire gprRdy0Lock = (_iF0_use_rdId && !_iF0_flushed);
`ifdef PU2NDISSUE
wire gprRdy1Lock = (_iF1_rdId && !_iF1_flushed);
`endif

wire gprRdy0Unlock = (
	rW0_we_i && /* Do not unlock a gpr if it is about to be locked
	or if it has just been locked; note that we are at the eXecuted stage,
	hence the reason why only *_rdId from previous stages are checked. */
	!(gprRdy0Lock && _iF0_rdId == rW0_idx_i) &&
	`ifdef PU2NDISSUE
	!(gprRdy1Lock && _iF1_rdId == rW0_idx_i) &&
	`endif
	!(!iD0_flushed && iD0_rdId == rW0_idx_i));
`ifdef PU2NDISSUE
wire gprRdy1Unlock = (
	rW1_we_i && /* Do not unlock a gpr if it is about to be locked
	or if it has just been locked; note that we are at the eXecuted stage,
	hence the reason why only *_rdId from previous stages are checked. */
	!(gprRdy0Lock && _iF0_rdId == rW1_idx_i) &&
	!(gprRdy1Lock && _iF1_rdId == rW1_idx_i) &&
	!(!iD0_flushed && iD0_rdId == rW1_idx_i));
`endif

always @ (posedge clk_i) begin
	if (rst_i)
		gprRdy <= {GPRCNT{1'b1}};
	else begin
		if (gprRdy0Lock)
			gprRdy[_iF0_rdId] <= 1'b0;
		if (gprRdy0Unlock)
			gprRdy[rW0_idx_i] <= 1'b1;
		`ifdef PU2NDISSUE
		if (gprRdy1Lock)
			gprRdy[_iF1_rdId] <= 1'b0;
		if (gprRdy1Unlock)
			gprRdy[rW1_idx_i] <= 1'b1;
		`endif
	end
end

`ifdef SIMULATION
always @ (posedge clk_i) begin
	rW0_pc   <= eX0_pc;
	rW0_insn <= eX0_insn;
end
`ifdef PU2NDISSUE
always @ (posedge clk_i) begin
	rW1_pc   <= eX1_pc;
	rW1_insn <= eX1_insn;
end
`endif
`endif

endmodule
