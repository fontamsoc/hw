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
//
// PUID
// 	Index of the pu when used in a multi-pu configuration,
// 	otherwise must be 0. Non-zero pu index are halted on reset
// 	waiting for an external interrupt.

// Ports:
//
// rst_i
// 	When held high at the the clock signal posedge, the pu reset.
// 	It must be held low for the pu to begin executing instructions.
// 	Non-zero pu index are halted on reset waiting for an external
// 	interrupt.
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
// wb_stb_o
// wb_lock_o
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
// irq_stb_o
// 	The signal irq_stb_i must be held high until irq_stb_o
// 	becomes high in order to request an interrupt; which is
// 	taken when irq_rdy_o is high.
//
// irq_rdy_o
// 	When this signal is high, the pu is available to take
// 	an external interrupt, which is taken when irq_stb_o is high.
//
// halted_o
// 	When this signal is high, the pu is halted.

`include "lib/fifo_fwft.sv"
`include "lib/wb_skidbuf.sv"
`include "lib/wb_upsizr.sv"

`include "./icache.sv"
`include "./dcache.sv"
`ifdef PURV32M
`include "./imul.sv"
`include "./idiv.sv"
`endif

module pu (

	 rst_i

	,clk_i
	,clk_imul_i
	,clk_idiv_i

	,wb_stb_o
	,wb_lock_o
	,wb_we_o
	,wb_addr_o
	,wb_sel_o
	,wb_dat_o
	,wb_bsy_i
	,wb_ack_i
	,wb_dat_i

	,dcache_addr_o
	,dcache_miss_i

	,dcache_coherency_en_i

	,dcache_coherency_stb_i
	,dcache_coherency_rqid_i
	,dcache_coherency_we_i
	,dcache_coherency_addr_i
	,dcache_coherency_sel_i
	,dcache_coherency_dat_i
	,dcache_coherency_shr_i
	,dcache_coherency_bsy_o

	,dcache_coherency_stb_o
	,dcache_coherency_rqid_o
	,dcache_coherency_we_o
	,dcache_coherency_addr_o
	,dcache_coherency_sel_o
	,dcache_coherency_dat_o
	,dcache_coherency_shr_o
	,dcache_coherency_bsy_i

	,irq_stb_i
	,irq_stb_o
	,irq_rdy_o
	,halted_o

	,rstaddr_i

	,spval_i
);

`include "lib/clog2.sv"

parameter WORDBITSZ     = 32;
parameter XWORDBITSZ    = 32; // TODO: Support all the way up to 1024 ...
parameter ADDRLIMIT     = 'h2000;
parameter CLKFREQ       = 1;
parameter ICACHESETCNT  = 2;
parameter DCACHESETCNT  = 0;
parameter ICACHEWAYCNT  = 1;
parameter DCACHEWAYCNT  = 1;
parameter IMULCNT       = 2;
parameter IDIVCNT       = 2;
parameter MAXPENDINGACK = 16;
parameter PUIDBITSZ     = 1;
parameter PUID          = 0;

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

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN  = (WORDBITSZ-clog2(ADDRLIMIT)-1);
localparam XMSBSZIGN = (XWORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;
input wire clk_imul_i;
input wire clk_idiv_i;

output reg                                  wb_stb_o;  // ### comb-block-reg.
output reg                                  wb_lock_o; // ### comb-block-reg.
output reg                                  wb_we_o;   // ### comb-block-reg.
output reg  [(XADDRBITSZ-XMSBSZIGN) -1 : 0] wb_addr_o; // ### comb-block-reg.
output reg  [(XWORDBITSZ/8) -1 : 0]         wb_sel_o;  // ### comb-block-reg.
output reg  [XWORDBITSZ -1 : 0]             wb_dat_o;  // ### comb-block-reg.
input  wire                                 wb_bsy_i;
input  wire                                 wb_ack_i;
input  wire [XWORDBITSZ -1 : 0]             wb_dat_i;

output wire [(XWORDBITSZ-XMSBSZIGN) -1 : 0] dcache_addr_o;
input  wire                                 dcache_miss_i;

input wire dcache_coherency_en_i;

input  wire                                 dcache_coherency_stb_i;
input  wire [PUIDBITSZ -1 : 0]              dcache_coherency_rqid_i;
input  wire                                 dcache_coherency_we_i;
input  wire [(XADDRBITSZ-XMSBSZIGN) -1 : 0] dcache_coherency_addr_i;
input  wire [(XWORDBITSZ/8) -1 : 0]         dcache_coherency_sel_i;
input  wire [XWORDBITSZ -1 : 0]             dcache_coherency_dat_i;
input  wire                                 dcache_coherency_shr_i;
output wire                                 dcache_coherency_bsy_o;

output wire                                 dcache_coherency_stb_o;
output wire [PUIDBITSZ -1 : 0]              dcache_coherency_rqid_o;
output wire                                 dcache_coherency_we_o;
output wire [(XADDRBITSZ-XMSBSZIGN) -1 : 0] dcache_coherency_addr_o;
output wire [(XWORDBITSZ/8) -1 : 0]         dcache_coherency_sel_o;
output wire [XWORDBITSZ -1 : 0]             dcache_coherency_dat_o;
output wire                                 dcache_coherency_shr_o;
input  wire                                 dcache_coherency_bsy_i;

input  wire irq_stb_i;
output reg  irq_stb_o;
output reg  irq_rdy_o;
output reg  halted_o;

input wire [WORDBITSZ -1 : 0] rstaddr_i;

input wire [WORDBITSZ -1 : 0] spval_i;

wire _wb_bsy_i;

wire excTriggered;

////////////////////////////////////// IF (Instruction Fetch) stage /////////////////////////////////////

`include "./icache.pu.sv"

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
reg [(WORDBITSZ-2) -1 : 0] ras0;
reg [(WORDBITSZ-2) -1 : 0] ras1;
reg [(WORDBITSZ-2) -1 : 0] ras2;
reg [(WORDBITSZ-2) -1 : 0] ras3;
reg [(WORDBITSZ-2) -1 : 0] ras4;
reg [(WORDBITSZ-2) -1 : 0] ras5;
reg [(WORDBITSZ-2) -1 : 0] ras6;
reg [(WORDBITSZ-2) -1 : 0] ras7;
wire [(WORDBITSZ-2) -1 : 0] iF_predictRet = ras0;
`ifdef SIMULATION
wire [WORDBITSZ -1 : 0] _ras0 = {ras0, 2'b00};
wire [WORDBITSZ -1 : 0] _ras1 = {ras1, 2'b00};
wire [WORDBITSZ -1 : 0] _ras2 = {ras2, 2'b00};
wire [WORDBITSZ -1 : 0] _ras3 = {ras3, 2'b00};
wire [WORDBITSZ -1 : 0] _ras4 = {ras4, 2'b00};
wire [WORDBITSZ -1 : 0] _ras5 = {ras5, 2'b00};
wire [WORDBITSZ -1 : 0] _ras6 = {ras6, 2'b00};
wire [WORDBITSZ -1 : 0] _ras7 = {ras7, 2'b00};
`endif
`endif

`ifdef PUPREDICTJALR
// TODO: To be implemented like PUPREDICTRET using a BTB (Branch Target Buffer).
// TODO: When adding an entry to the BTB, skip RET which is "jalr x0, x1, 0",
// TODO: only add JALR for which (rs1Id != 1).
// TODO: Discard 2lsb of addresses so that only aligned addresses get added to the BTB.
`endif

reg  [WORDBITSZ -1 : 0] iF_pc;
wire [WORDBITSZ -1 : 0] iF_pc_i;

assign iCache_ridx_w = iF_pc_i[CLOG2ICACHESETCNT+CLOG2XWORDBITSZBY8-1:CLOG2XWORDBITSZBY8];
assign iCache_rtag_w = iF_pc_i[WORDBITSZ-1:CLOG2ICACHESETCNT+CLOG2XWORDBITSZBY8];

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		iF_flushed_ <= 1;
		iF_pc <= rstaddr_i;
	end else if (iF_en || excTriggered) begin
		iF_flushed_ <= iF_eX_JumpOrBranch_i;
		iF_pc <= iF_eX_JumpOrBranch_i ? iF_eX_JumpOrBranchAddr_i : iF_pc_i;
	end
end

wire [INSNBITSZ -1 : 0] iF_insn;
generate if (XWORDBITSZ > INSNBITSZ) begin :gen_iF_insn
assign iF_insn = (iCache_dato_w >> (INSNBITSZ*iF_pc[CLOG2XWORDBITSZBY8-1:CLOG2INSNBITSZBY8]));
end else begin
assign iF_insn = iCache_dato_w;
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

wire iF_isFence         = (iF_isMiscMem && iF_func3 == 3'b000);
wire iF_isFencei        = (iF_isMiscMem && iF_func3 == 3'b001);
wire iF_isFenceOrFencei = (iF_isMiscMem && iF_func3[2:1] == 2'b00);

wire iF_isALUregOrBranch = (iF_isALUreg || iF_isBranch);
wire iF_isJAlOrJALR = (iF_isJAL || iF_isJALR);

wire [WORDBITSZ -1 : 0] iF_addrImm = (iF_isLoad ? iF_Iimm : iF_isStore ? iF_Simm : {WORDBITSZ{1'b0}});

wire iF_isSystemAndFunc3Null = (iF_isSystem && iF_func3 == 3'b000);
wire iF_isEcall  = (iF_isSystemAndFunc3Null && iF_Iimm[11:0] == 12'd0);
wire iF_isEbreak = (iF_isSystemAndFunc3Null && iF_Iimm[11:0] == 12'd1);
wire iF_isEret   = (iF_isSystemAndFunc3Null && iF_Iimm[4:0] == 5'b00010);
wire iF_isWfi    = (iF_isSystemAndFunc3Null && iF_Iimm[11:0] == 12'b000100000101);

wire iF_isCSR = (iF_isSystem && iF_func3[1:0]);

`ifdef PURV32M
// Match the full M funct7 (not just func7[0]) so other func7[0]==1 OP encodings
// (e.g. Zbb min/max with funct7 0000101) are not misdecoded as mul/div.
wire iF_isRV32M    = (iF_isALUreg && iF_func7 == 7'b0000001);
wire iF_opImul_stb = (iF_isRV32M && !iF_func3[2] && iF_rdId);
wire iF_opIdiv_stb = (iF_isRV32M &&  iF_func3[2] && iF_rdId);
`endif

`ifdef PURV32ZBA
wire iF_isZba = (iF_isALUreg && iF_func7 == 7'b0010000); // sh1add/sh2add/sh3add; shift amount is iF_func3[2:1].
`endif

`ifdef PURV32ZBB
// Zbb decode. iF_func7 == iF_insn[31:25] == imm[11:5] for OP-IMM; iF_Iimm[11:0] is the I-immediate.
wire iF_isZbb =
	(iF_isALUreg && iF_func7 == 7'b0100000 && (iF_func3 == 3'b100 || iF_func3 == 3'b110 || iF_func3 == 3'b111)) || // xnor/orn/andn
	(iF_isALUreg && iF_func7 == 7'b0000101 && iF_func3[2])                                                      || // min/minu/max/maxu
	(iF_isALUreg && iF_func7 == 7'b0110000 && (iF_func3 == 3'b001 || iF_func3 == 3'b101))                       || // rol/ror
	(iF_isALUreg && iF_func7 == 7'b0000100 &&  iF_func3 == 3'b100 && iF_rs2Id == 5'd0)                          || // zext.h
	(iF_isALUimm && iF_func7 == 7'b0110000 &&  iF_func3 == 3'b001)                                              || // clz/ctz/cpop/sext.b/sext.h
	(iF_isALUimm && iF_func7 == 7'b0110000 &&  iF_func3 == 3'b101)                                              || // rori
	(iF_isALUimm && iF_func3 == 3'b101 && iF_Iimm[11:0] == 12'h698)                                             || // rev8
	(iF_isALUimm && iF_func3 == 3'b101 && iF_Iimm[11:0] == 12'h287);                                               // orc.b
wire iF_isZbbRol = (iF_isALUreg && iF_func3 == 3'b001); // OP-form func7=0110000 rol.
`endif

wire iF_isLr = (iF_isAMO && iF_func5 == 5'b00010);
wire iF_isSc = (iF_isAMO && iF_func5 == 5'b00011);

wire iF_isAMOwithSc = (iF_isAMO && iF_func5 != 5'b00010);

wire iF_isAMOonly = (iF_isAMOwithSc && iF_func5 != 5'b00011);

wire iF_isLoadOrLr = (iF_isLoad || iF_isLr);
wire iF_isStoreOrScOrAMO = (iF_isStore || iF_isAMOwithSc);

wire iF_ldUnit_stb = (iF_isLoad || (iF_isAMO && iF_func5 != 5'b00011));
wire iF_stUnit_stb = (iF_isStore || iF_isSc);

wire iF_cancelLr = (iF_isSystem || iF_isMiscMem || iF_isLoad || iF_isStore || iF_isAMOwithSc);

wire iF_isIllInsn = !(iF_isALUreg || iF_isALUimm || iF_isBranch || iF_isJALR || iF_isJAL ||
	iF_isAUIPC || iF_isLUI || iF_isLoad || iF_isStore || iF_isSystem || iF_isAMO || iF_isMiscMem);

wire iF_is3OprndD12 = (iF_isALUreg || iF_isAMOwithSc);
wire iF_is2OprndD1  = (iF_isALUimm || iF_isJALR || iF_ldUnit_stb || (iF_isCSR && !iF_func3[2]));
wire iF_is2Oprnd12  = (iF_isBranch || iF_isStore);
wire iF_is1OprndD   = (iF_isJAL || iF_isAUIPC || iF_isLUI || (iF_isCSR && iF_func3[2]));

wire iF_lateResultInsn = (
	`ifdef PURV32M
	iF_isRV32M ||
	`endif
	iF_ldUnit_stb);

wire iF_use_rdId = (iF_rdId && // iF_rdId is null when iF_isMiscMem true.
	!(iF_is2Oprnd12 || /*iF_isMiscMem ||*/
		(iF_isSystem && !iF_func3[1:0] /* non-CSR instructions */)));

`ifdef PUPREDICTBRANCH
localparam BPTSETCNT = 4096;
localparam CLOG2BPTSETCNT = clog2(BPTSETCNT);
reg [2 -1 : 0] bpt [BPTSETCNT]; // Branch Prediction Table.
reg [2 -1 : 0] iF_predictBranch;
always_ff @(posedge clk_i) begin
	if (iF_en)
		iF_predictBranch <= bpt[iF_pc_i[CLOG2INSNBITSZBY8+:CLOG2BPTSETCNT]];
end
`endif

wire iF_flushed_or_not_iF_iD_carryon = (iF_flushed || !iF_iD_carryon);

assign iF_pc_i = ((
	`ifdef PUPREDICTRET
	(iF_isRet && !iF_flushed_or_not_iF_iD_carryon) ? {WORDBITSZ{1'b0}} :
	`endif
	iF_pc) + (
	iF_flushed_or_not_iF_iD_carryon ? {WORDBITSZ{1'b0}} :
	`ifdef PUPREDICTBRANCH
	(iF_isBranch && iF_predictBranch[1]) ? iF_Bimm :
	`endif
	`ifdef PUPREDICTJAL
	iF_isJAL ? iF_Jimm :
	`endif
	`ifdef PUPREDICTRET
	iF_isRet ? {iF_predictRet, 2'b0} :
	`endif
	(INSNBITSZ/8)));

////////////////////////////////////// ID (Instruction Decode) stage ///////////////////////////////////////

reg [2 -1 : 0] csrCurPriv;
wire csrCurPrivIsU = (csrCurPriv == 2'b00);
wire csrCurPrivIsS = (csrCurPriv == 2'b01);
wire csrCurPrivIsM = (csrCurPriv == 2'b11);
reg [16 -1 : 0] csrMedeleg;
reg [16 -1 : 0] csrMideleg;
reg [WORDBITSZ -1 : 0] csrMstatus;
reg [16 -1 : 0] csrMip;
reg [16 -1 : 0] csrMie;
reg [64 -1 : 0] csrMtimecmp;
reg [64 -1 : 0] csrStimecmp;
reg [WORDBITSZ -1 : 0] csrMtvec;
reg [WORDBITSZ -1 : 0] csrStvec;
reg [WORDBITSZ -1 : 0] csrMepc;
reg [WORDBITSZ -1 : 0] csrSepc;
reg [WORDBITSZ -1 : 0] csrMcause;
reg [WORDBITSZ -1 : 0] csrScause;
reg [WORDBITSZ -1 : 0] csrMtval;
reg [WORDBITSZ -1 : 0] csrStval;
reg [WORDBITSZ -1 : 0] csrMtval2;
reg [WORDBITSZ -1 : 0] csrStval2;
reg [WORDBITSZ -1 : 0] csrMscratch;
reg [WORDBITSZ -1 : 0] csrSscratch;
reg [WORDBITSZ -1 : 0] csrMisa; // ### comb-block-reg.
reg [64 -1 : 0] csrCycle;
reg [64 -1 : 0] csrInstret;
reg [WORDBITSZ -1 : 0] csrClkFreq;
`ifdef _SIMULATION_PERF
`ifdef PUPREDICTBRANCH
reg [WORDBITSZ -1 : 0] csrBranchPredictHit;
reg [WORDBITSZ -1 : 0] csrBranchPredictMiss;
`endif
`ifdef PUPREDICTRET
reg [WORDBITSZ -1 : 0] csrRetPredictMiss;
`endif
`endif

reg [WORDBITSZ -1 : 0] iD_pc;
reg [INSNBITSZ -1 : 0] iD_insn;

reg [CLOG2GPRCNT -1 : 0] iD_rdId; // Get set to null if instruction will not set a GPR.
reg [CLOG2GPRCNT -1 : 0] iD_rs1Id;
reg [CLOG2GPRCNT -1 : 0] iD_rs2Id;

reg [WORDBITSZ -1 : 0] iD_Iimm;
//reg [WORDBITSZ -1 : 0] iD_Simm;
//reg [WORDBITSZ -1 : 0] iD_Bimm;
reg [WORDBITSZ -1 : 0] iD_Uimm;
//reg [WORDBITSZ -1 : 0] iD_Jimm;

reg [3 -1 : 0] iD_func3;
reg [5 -1 : 0] iD_func5;
reg [7 -1 : 0] iD_func7;

reg [WORDBITSZ -1 : 0] iD_pc_plus_INSNBITSzBy8;
reg [WORDBITSZ -1 : 0] iD_pc_plus_iD_Bimm;
reg [WORDBITSZ -1 : 0] iD_pc_plus_iD_Uimm;
`ifndef PUPREDICTJAL
reg [WORDBITSZ -1 : 0] iD_pc_plus_iD_Jimm;
`endif

reg iD_isALUreg;
//reg iD_isALUimm;
reg iD_isBranch;
reg iD_isJALR;
`ifndef PUPREDICTJAL
reg iD_isJAL;
`endif
`ifdef PUPREDICTRET
reg iD_isRet;
reg iD_isJALRnotRet;
reg iD_isCall;
`endif
reg iD_isAUIPC;
reg iD_isLUI;
//reg iD_isLoad;
reg iD_isStore;
reg iD_isSystem;
reg iD_isAMO;
`ifdef PURV32ZBA
reg iD_isZba;
`endif
`ifdef PURV32ZBB
reg iD_isZbb;
reg iD_isZbbRol;
`endif

reg iD_isFence;
reg iD_isFencei;
reg iD_isFenceOrFencei;

reg iD_isALUregOrBranch;
reg iD_isJAlOrJALR;

reg [WORDBITSZ -1 : 0] iD_addrImm;

reg iD_isEcall;
reg iD_isEbreak;
reg iD_isEret;
reg iD_isWfi;

reg iD_isCSR;

`ifdef PURV32M
reg iD_opImul_stb;
reg iD_opIdiv_stb;
`endif

reg iD_isLr;
reg iD_isSc;

reg iD_isAMOonly;

reg iD_isLoadOrLr;
reg iD_isStoreOrScOrAMO;

reg iD_ldUnit_stb;
reg iD_stUnit_stb;

reg iD_cancelLr;

reg iD_isIllInsn;

reg iD_is3OprndD12;
reg iD_is2OprndD1;
reg iD_is2Oprnd12;
reg iD_is1OprndD;

reg iD_lateResultInsn;

reg iD_use_rdId;

wire [WORDBITSZ -1 : 0] iD_rd;
wire [WORDBITSZ -1 : 0] iD_rs1;
wire [WORDBITSZ -1 : 0] iD_rs2;

wire iD_rdRdy;
wire iD_rs1Rdy;
wire iD_rs2Rdy;

reg [WORDBITSZ -1 : 0] gprDat [GPRCNT];
reg [GPRCNT    -1 : 0] gprRdy;

`ifdef PURV32M
wire iD_opImul_bsy;
wire iD_opIdiv_bsy;
`endif
wire iD_ldUnit_bsy;
wire iD_stUnit_bsy;

wire iD_eX_carryon;

wire dCache_m_pending;

wire iD_stalled = (!iD_eX_carryon ||
	(iD_isFenceOrFencei && dCache_m_pending) ||
	`ifdef PURV32M
	(iD_opImul_stb ? iD_opImul_bsy : 1'b0) ||
	(iD_opIdiv_stb ? iD_opIdiv_bsy : 1'b0) ||
	`endif
	(iD_ldUnit_stb ? iD_ldUnit_bsy : 1'b0) ||
	(iD_stUnit_stb ? iD_stUnit_bsy : 1'b0) || (
	// Stall if any of the operand is locked.
	iD_is3OprndD12 ? !(iD_rdRdy && iD_rs1Rdy && iD_rs2Rdy) :
	iD_is2OprndD1  ? !(iD_rdRdy && iD_rs1Rdy) :
	iD_is2Oprnd12  ? !(iD_rs1Rdy && iD_rs2Rdy) :
	iD_is1OprndD   ? !iD_rdRdy : 0));

assign iF_iD_stalled = iD_stalled;

reg iD_flushed;

assign iF_iD_flushed = iD_flushed;

wire iD_carryon = (iD_flushed || !iD_stalled);

assign iF_iD_carryon = iD_carryon;

wire iD_en = (iD_carryon && !halted_o);

`ifdef PUPREDICTBRANCH
reg [2 -1 : 0] iD_predictBranch;
always_ff @(posedge clk_i) begin
	if (iD_en)
		iD_predictBranch <= iF_predictBranch;
end
`endif

`ifdef PUPREDICTRET
reg [(WORDBITSZ-2) -1 : 0] iD_predictRet;
always_ff @(posedge clk_i) begin
	if (iD_en)
		iD_predictRet <= iF_predictRet;
end
`endif

wire [CLOG2GPRCNT -1 : 0] _iF_rdId  = (iD_en ? iF_rdId  : iD_rdId);
wire [CLOG2GPRCNT -1 : 0] _iF_rs1Id = (iD_en ? iF_rs1Id : iD_rs1Id);
wire [CLOG2GPRCNT -1 : 0] _iF_rs2Id = (iD_en ? iF_rs2Id : iD_rs2Id);

wire _iF_use_rdId = (iD_en ? iF_use_rdId : iD_use_rdId);

wire iD_eX_rdId_isTrue;
wire [CLOG2GPRCNT -1 : 0] iD_eX_rdId;
wire [WORDBITSZ -1 : 0]   iD_eX_rslt;

wire iD_rdId_eq_iD_eX_rdId  = ((iD_rdId  == iD_eX_rdId) && iD_eX_rdId_isTrue);
wire iD_rs1Id_eq_iD_eX_rdId = ((iD_rs1Id == iD_eX_rdId) && iD_eX_rdId_isTrue);
wire iD_rs2Id_eq_iD_eX_rdId = ((iD_rs2Id == iD_eX_rdId) && iD_eX_rdId_isTrue);

reg iD_rW_rdId_isTrue;
reg [CLOG2GPRCNT -1 : 0] iD_rW_rdId;
reg [WORDBITSZ -1 : 0]   iD_rW_rslt;

wire iD_rdId_eq_iD_rW_rdId  = ((iD_rdId  == iD_rW_rdId) && iD_rW_rdId_isTrue);
wire iD_rs1Id_eq_iD_rW_rdId = ((iD_rs1Id == iD_rW_rdId) && iD_rW_rdId_isTrue);
wire iD_rs2Id_eq_iD_rW_rdId = ((iD_rs2Id == iD_rW_rdId) && iD_rW_rdId_isTrue);

reg [WORDBITSZ -1 : 0] iD_rd_;
reg [WORDBITSZ -1 : 0] iD_rs1_;
reg [WORDBITSZ -1 : 0] iD_rs2_;
assign iD_rd = (
	iD_rdId_eq_iD_eX_rdId ? iD_eX_rslt :
	iD_rdId_eq_iD_rW_rdId ? iD_rW_rslt :
	iD_rdId ? iD_rd_ : {WORDBITSZ{1'b0}});
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

`include "./dcache.pu.sv"

`include "./memctrl.pu.sv"

wire _iF_flushed = ((iD_en ? iF_flushed : iD_flushed) || iF_eX_JumpOrBranch_i);

always_ff @(posedge clk_i) begin
	iD_rd_  <= gprDat[_iF_rdId];
	iD_rs1_ <= gprDat[_iF_rs1Id];
	iD_rs2_ <= gprDat[_iF_rs2Id];
	iD_rdRdy_  <= gprRdy[_iF_rdId];
	iD_rs1Rdy_ <= gprRdy[_iF_rs1Id];
	iD_rs2Rdy_ <= gprRdy[_iF_rs2Id];
end

always_ff @(posedge clk_i) begin
	if (iD_en)
		iD_rdRdy__ <= 1'b0;
	else if (iD_rdRdy)
		iD_rdRdy__ <= 1'b1;
end

always_ff @(posedge clk_i) begin
	if (iD_en)
		iD_rs1Rdy__ <= 1'b0;
	else if (iD_rs1Rdy)
		iD_rs1Rdy__ <= 1'b1;
end

always_ff @(posedge clk_i) begin
	if (iD_en)
		iD_rs2Rdy__ <= 1'b0;
	else if (iD_rs2Rdy)
		iD_rs2Rdy__ <= 1'b1;
end

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		iD_flushed <= 1;
	end else if (iD_en || excTriggered) begin
		iD_flushed <= (iF_flushed || iF_eX_JumpOrBranch_i);
	end
end

always_ff @(posedge clk_i) begin

	if (iD_en) begin

		iD_pc <= iF_pc;
		iD_insn <= iF_insn;

		iD_rdId  <= (iF_use_rdId ? iF_rdId : 5'd0);
		iD_rs1Id <= iF_rs1Id;
		iD_rs2Id <= iF_rs2Id;

		iD_Iimm <= iF_Iimm;
		//iD_Simm <= iF_Simm;
		//iD_Bimm <= iF_Bimm;
		iD_Uimm <= iF_Uimm;
		//iD_Jimm <= iF_Jimm;

		iD_func3 <= iF_func3;
		iD_func5 <= iF_func5;
		iD_func7 <= iF_func7;

		iD_pc_plus_INSNBITSzBy8 <= iF_pc_plus_INSNBITSzBy8;
		iD_pc_plus_iD_Bimm      <= iF_pc_plus_iF_Bimm;
		iD_pc_plus_iD_Uimm      <= iF_pc_plus_iF_Uimm;
		`ifndef PUPREDICTJAL
		iD_pc_plus_iD_Jimm      <= iF_pc_plus_iF_Jimm;
		`endif

		iD_isALUreg <= iF_isALUreg;
		//iD_isALUimm <= iF_isALUimm;
		iD_isBranch <= iF_isBranch;
		iD_isJALR   <= iF_isJALR;
		`ifndef PUPREDICTJAL
		iD_isJAL    <= iF_isJAL;
		`endif
		`ifdef PUPREDICTRET
		iD_isRet        <= iF_isRet;
		iD_isJALRnotRet <= iF_isJALRnotRet;
		iD_isCall       <= iF_isCall;
		`endif
		iD_isAUIPC  <= iF_isAUIPC;
		iD_isLUI    <= iF_isLUI;
		//iD_isLoad   <= iF_isLoad;
		iD_isStore  <= iF_isStore;
		iD_isSystem <= iF_isSystem;
		iD_isAMO    <= iF_isAMO;
		`ifdef PURV32ZBA
		iD_isZba    <= iF_isZba;
		`endif
		`ifdef PURV32ZBB
		iD_isZbb    <= iF_isZbb;
		iD_isZbbRol <= iF_isZbbRol;
		`endif

		iD_isFence         <= iF_isFence;
		iD_isFencei        <= iF_isFencei;
		iD_isFenceOrFencei <= iF_isFenceOrFencei;

		iD_isALUregOrBranch <= iF_isALUregOrBranch;
		iD_isJAlOrJALR <= iF_isJAlOrJALR;

		iD_addrImm <= iF_addrImm;

		iD_isEcall  <= iF_isEcall;
		iD_isEbreak <= iF_isEbreak;
		iD_isEret   <= iF_isEret;
		iD_isWfi    <= iF_isWfi;

		iD_isCSR <= iF_isCSR;

		`ifdef PURV32M
		iD_opImul_stb <= iF_opImul_stb;
		iD_opIdiv_stb <= iF_opIdiv_stb;
		`endif

		iD_isLr <= iF_isLr;
		iD_isSc <= iF_isSc;

		iD_isAMOonly <= iF_isAMOonly;

		iD_isLoadOrLr <= iF_isLoadOrLr;
		iD_isStoreOrScOrAMO <= iF_isStoreOrScOrAMO;

		iD_ldUnit_stb <= iF_ldUnit_stb;
		iD_stUnit_stb <= iF_stUnit_stb;

		iD_cancelLr <= iF_cancelLr;

		iD_isIllInsn <= iF_isIllInsn;

		iD_is3OprndD12 <= iF_is3OprndD12;
		iD_is2OprndD1  <= iF_is2OprndD1;
		iD_is2Oprnd12  <= iF_is2Oprnd12;
		iD_is1OprndD   <= iF_is1OprndD;

		iD_lateResultInsn <= iF_lateResultInsn;

		iD_use_rdId <= iF_use_rdId;
	end
end

////////////////////////////////////// EX (Execute) stage //////////////////////////////////////////////////

reg [WORDBITSZ -1 : 0] eX_pc;
reg [INSNBITSZ -1 : 0] eX_insn;

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
// Dedicated branch comparator: resolves BEQ/BNE/BLT/BGE/BLTU/BGEU without
// waiting on the shared subtract eX_aluMinus_i (nor its fanout), shortening the
// branch-resolution path that gates the fetch redirect and the gpr scoreboard.
wire eX_eq_i    = (eX_aluArg1_i == eX_aluArg2_i);
wire eX_brLt_i  = ($signed(eX_aluArg1_i) < $signed(eX_aluArg2_i));
wire eX_brLtu_i = (eX_aluArg1_i < eX_aluArg2_i);

function automatic bit [WORDBITSZ -1 : 0] reverseBits;
	input bit [WORDBITSZ -1 : 0] bits;
	for (int i = 0; i < WORDBITSZ; ++i)
		reverseBits[i] = bits[(WORDBITSZ -1) - i];
endfunction

wire [WORDBITSZ -1 : 0] eX_aluShift_i_ = ((iD_func3 == 3'b001) ? reverseBits(eX_aluArg1_i) : eX_aluArg1_i);
wire [WORDBITSZ -1 : 0] eX_aluShift_i = // Single shifter for left and right shifts.
	($signed({iD_func7[5] & eX_aluArg1_i[WORDBITSZ-1], eX_aluShift_i_}) >>> eX_aluArg2_i[4:0]);

`ifdef PURV32ZBA
// Zba sh1add/sh2add/sh3add: (rs1 << iD_func3[2:1]) + rs2.
wire [WORDBITSZ -1 : 0] eX_aluShadd_i = ((eX_aluArg1_i << iD_func3[2:1]) + eX_aluArg2_i);
`endif

`ifdef PURV32ZBB
function automatic bit [WORDBITSZ -1 : 0] zbb_ctz; // Count trailing zeros.
	input bit [WORDBITSZ -1 : 0] v;
	bit found;
	begin
		zbb_ctz = 0;
		found = 0;
		for (int i = 0; i < WORDBITSZ; ++i)
			if (!found) begin
				if (v[i]) found = 1'b1;
				else      zbb_ctz = zbb_ctz + 1'b1;
			end
	end
endfunction
function automatic bit [WORDBITSZ -1 : 0] zbb_cpop; // Population count.
	input bit [WORDBITSZ -1 : 0] v;
	begin
		zbb_cpop = 0;
		for (int i = 0; i < WORDBITSZ; ++i)
			zbb_cpop = zbb_cpop + v[i];
	end
endfunction
function automatic bit [WORDBITSZ -1 : 0] zbb_rev8; // Reverse byte order.
	input bit [WORDBITSZ -1 : 0] v;
	for (int i = 0; i < WORDBITSZ/8; ++i)
		zbb_rev8[i*8 +: 8] = v[(WORDBITSZ-8) - i*8 +: 8];
endfunction
function automatic bit [WORDBITSZ -1 : 0] zbb_orcb; // OR-combine within each byte.
	input bit [WORDBITSZ -1 : 0] v;
	for (int i = 0; i < WORDBITSZ/8; ++i)
		zbb_orcb[i*8 +: 8] = {8{|v[i*8 +: 8]}};
endfunction

// Rotate via a single right-shifter: ror(x,a) = ({x,x} >> a) low word, and
// rol(x,a) = ror(x, 32-a), so left-rotate just negates the 5-bit amount.
// Amount comes from rs2[4:0] for the OP form (rol/ror), iD_Iimm[4:0] for the OP-IMM form (rori).
wire [5            -1 : 0] eX_zbbRotAmt_i = (iD_isALUreg ? eX_aluArg2_i[4:0] : iD_Iimm[4:0]);
wire [5            -1 : 0] eX_zbbRorAmt_i = (iD_isZbbRol ? (5'd0 - eX_zbbRotAmt_i) : eX_zbbRotAmt_i);
wire [(2*WORDBITSZ)-1 : 0] eX_zbbDbl_i    = {eX_aluArg1_i, eX_aluArg1_i};
wire [WORDBITSZ    -1 : 0] eX_zbbRot_i    = (eX_zbbDbl_i >> eX_zbbRorAmt_i); // low word.

reg [WORDBITSZ -1 : 0] eX_zbbOut_i; // ### comb-block-reg.
always_comb begin
	if (iD_isALUreg) begin // OP-form Zbb.
		case (iD_func7)
		7'b0100000: // Logic with negate.
			case (iD_func3)
			3'b100:  eX_zbbOut_i = ~(eX_aluArg1_i ^ eX_aluArg2_i); // xnor
			3'b110:  eX_zbbOut_i =  (eX_aluArg1_i | ~eX_aluArg2_i); // orn
			default: eX_zbbOut_i =  (eX_aluArg1_i & ~eX_aluArg2_i); // andn (3'b111)
			endcase
		7'b0000101: // Integer min/max.
			case (iD_func3)
			3'b100:  eX_zbbOut_i = (eX_lt_i  ? eX_aluArg1_i : eX_aluArg2_i); // min
			3'b101:  eX_zbbOut_i = (eX_ltu_i ? eX_aluArg1_i : eX_aluArg2_i); // minu
			3'b110:  eX_zbbOut_i = (eX_lt_i  ? eX_aluArg2_i : eX_aluArg1_i); // max
			default: eX_zbbOut_i = (eX_ltu_i ? eX_aluArg2_i : eX_aluArg1_i); // maxu (3'b111)
			endcase
		7'b0110000: // Rotate.
			eX_zbbOut_i = eX_zbbRot_i; // rol/ror (eX_zbbRorAmt_i already negated for rol)
		default: // 7'b0000100: zext.h.
			eX_zbbOut_i = {{(WORDBITSZ-16){1'b0}}, eX_aluArg1_i[15:0]};
		endcase
	end else begin // OP-IMM-form Zbb.
		if (iD_func3 == 3'b001) // clz/ctz/cpop/sext.b/sext.h, selected by imm[4:0].
			case (iD_Iimm[4:0])
			5'd0:    eX_zbbOut_i = zbb_ctz(reverseBits(eX_aluArg1_i)); // clz = ctz of bit-reversed.
			5'd1:    eX_zbbOut_i = zbb_ctz(eX_aluArg1_i);
			5'd2:    eX_zbbOut_i = zbb_cpop(eX_aluArg1_i);
			5'd4:    eX_zbbOut_i = {{(WORDBITSZ-8){eX_aluArg1_i[7]}},   eX_aluArg1_i[7:0]};  // sext.b
			default: eX_zbbOut_i = {{(WORDBITSZ-16){eX_aluArg1_i[15]}}, eX_aluArg1_i[15:0]}; // sext.h (5'd5)
			endcase
		else // iD_func3 == 3'b101: rev8/orc.b/rori.
			if      (iD_Iimm[11:0] == 12'h698) eX_zbbOut_i = zbb_rev8(eX_aluArg1_i);
			else if (iD_Iimm[11:0] == 12'h287) eX_zbbOut_i = zbb_orcb(eX_aluArg1_i);
			else                               eX_zbbOut_i = eX_zbbRot_i; // rori
	end
end
`endif

reg [WORDBITSZ -1 : 0] eX_aluOut_i; // ### comb-block-reg.
always_comb begin
	unique case (iD_func3)
	3'b000: eX_aluOut_i = ((iD_isALUreg && iD_func7[5]) ? eX_aluMinus_i[WORDBITSZ-1:0] : eX_aluPlus_i);
	3'b001: eX_aluOut_i = reverseBits(eX_aluShift_i);
	3'b010: eX_aluOut_i = {{(WORDBITSZ-1){1'b0}}, eX_lt_i};
	3'b011: eX_aluOut_i = {{(WORDBITSZ-1){1'b0}}, eX_ltu_i};
	3'b100: eX_aluOut_i = (eX_aluArg1_i ^ eX_aluArg2_i);
	3'b101: eX_aluOut_i = eX_aluShift_i;
	3'b110: eX_aluOut_i = (eX_aluArg1_i | eX_aluArg2_i);
	3'b111: eX_aluOut_i = (eX_aluArg1_i & eX_aluArg2_i);
	endcase
end

reg [WORDBITSZ -1 : 0] eX_csrOut_i; // ### comb-block-reg.

wire [WORDBITSZ -1 : 0] eX_StoreCondOut_i;

reg [WORDBITSZ -1 : 0] eX_rslt_i; // ### comb-block-reg.
always_comb begin
	unique if (iD_isJAlOrJALR) eX_rslt_i = iD_pc_plus_INSNBITSzBy8;
	else   if (iD_isLUI)       eX_rslt_i = iD_Uimm;
	else   if (iD_isAUIPC)     eX_rslt_i = iD_pc_plus_iD_Uimm;
	else   if (iD_isCSR)       eX_rslt_i = eX_csrOut_i;
	else   if (iD_isSc)        eX_rslt_i = eX_StoreCondOut_i;
	`ifdef PURV32ZBA
	else   if (iD_isZba)       eX_rslt_i = eX_aluShadd_i;
	`endif
	`ifdef PURV32ZBB
	else   if (iD_isZbb)       eX_rslt_i = eX_zbbOut_i;
	`endif
	else                       eX_rslt_i = eX_aluOut_i;
end

reg eX_takeBranch_i; // ### comb-block-reg.
always_comb begin
	unique case (iD_func3)
	3'b000:  eX_takeBranch_i = eX_eq_i;
	3'b001:  eX_takeBranch_i = !eX_eq_i;
	3'b100:  eX_takeBranch_i = eX_brLt_i;
	3'b101:  eX_takeBranch_i = !eX_brLt_i;
	3'b110:  eX_takeBranch_i = eX_brLtu_i;
	3'b111:  eX_takeBranch_i = !eX_brLtu_i;
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
wire eX_predictRetMiss_i = (iD_predictRet != eX_aluPlus_i[WORDBITSZ-1:2]);
`endif

reg eX_rdId_isTrue;
reg [CLOG2GPRCNT -1 : 0] eX_rdId;
reg [WORDBITSZ -1 : 0]   eX_rslt;

wire eX_rW_stalled;
wire eX_rW_carryon;

// The Execute state does not need to stall if there is no
// RegisterWriteBack to do (ie: when eX_rdId_isTrue false).
wire eX_stalled = (!eX_rW_carryon ? eX_rdId_isTrue : 1'b0);

// Jumps or Branchs are triggered only at the iDecoded stage.
// Interrupts and exceptions set eX_flushed_i to prevent eXecution.
wire eX_flushed_i = (iD_flushed || iD_stalled);
reg eX_flushed;

wire eX_carryon = (!eX_stalled);

assign iD_eX_carryon = eX_carryon;

wire eX_en = (eX_carryon && !halted_o);

wire iD_insn_valid_ = (!eX_flushed_i && eX_en);
assign iD_insn_valid = (iD_insn_valid_ && !excTriggered);

`ifdef PUPREDICTBRANCH
reg [2 -1 : 0] bpt_i; // ### comb-block-reg.
always_comb begin
	unique case ({eX_takeBranch_i, eX_predictBranch_i})
	3'b000:  bpt_i = 2'b00;
	3'b001:  bpt_i = 2'b00;
	3'b010:  bpt_i = 2'b01;
	3'b011:  bpt_i = 2'b10;
	3'b100:  bpt_i = 2'b01;
	3'b101:  bpt_i = 2'b10;
	3'b110:  bpt_i = 2'b11;
	default: bpt_i = 2'b11;
	endcase
end
always_ff @(posedge clk_i) begin
	if (iD_isBranch && iD_insn_valid)
		bpt[iD_pc[CLOG2INSNBITSZBY8+:CLOG2BPTSETCNT]] <= bpt_i;
end
`endif

`ifdef PUPREDICTRET
always_ff @(posedge clk_i) begin
	if (iD_insn_valid) begin
		if (iD_isCall) begin
			ras0 <= iD_pc_plus_INSNBITSzBy8[WORDBITSZ-1:2];
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
`ifdef SIMULATION
			//ras7 <= {(WORDBITSZ-2){1'b0}};
`endif
		end
	end
end
`endif

wire eX_JumpOrBranch_i = (excTriggered || ((
	iD_isFencei || iD_isEret ||
	`ifndef PUPREDICTJAL
	iD_isJAL ||
	`endif
	`ifdef PUPREDICTRET
	(iD_isRet && eX_predictRetMiss_i) ||
	iD_isJALRnotRet ||
	`else
	iD_isJALR ||
	`endif
	(iD_isBranch && _eX_takeBranch_i))
	// iD_insn_valid_ (not iD_insn_valid) is used here: the outer `excTriggered ||`
	// makes the inner `&& !excTriggered` carried by iD_insn_valid redundant
	// (a || (b && !a) == a || b), so excTriggered stays off this inner AND cone
	// and only reaches the final OR. The redirect address already prioritizes
	// excTvec on excTriggered, so behaviour is unchanged.
	&& iD_insn_valid_));

assign iF_eX_JumpOrBranch_i = eX_JumpOrBranch_i;

wire [WORDBITSZ -1 : 0] excTvec;
wire [WORDBITSZ -1 : 0] eX_JumpOrBranchAddr_i = (
	excTriggered ? excTvec :
	iD_isEret ? (csrCurPrivIsS ? csrSepc : csrMepc) :
	iD_isBranch ? (eX_takeBranch_i ? iD_pc_plus_iD_Bimm : iD_pc_plus_INSNBITSzBy8) :
	`ifndef PUPREDICTJAL
	iD_isJAL ? iD_pc_plus_iD_Jimm :
	`endif
	iD_isJALR ? {eX_aluPlus_i[WORDBITSZ-1:1], 1'b0} :
	/* iD_isFencei */ iD_pc_plus_INSNBITSzBy8);

assign iF_eX_JumpOrBranchAddr_i = eX_JumpOrBranchAddr_i;

assign dCache_invd_w = (iD_isFence  && iD_insn_valid);
assign iCache_invd_w = (iD_isFencei && iD_insn_valid);

reg eX_JumpOrBranch;
always_ff @(posedge clk_i) begin
	if (rst_i || excTriggered) begin
		eX_flushed <= 1;
		eX_JumpOrBranch <= 1;
	end else if (eX_en) begin
		eX_flushed <= eX_flushed_i;
		eX_JumpOrBranch <= eX_JumpOrBranch_i;
	end
end

reg rdWasLocked;

reg eX_isExc;
reg eX_lateResultInsn;
always_ff @(posedge clk_i) begin
	if (eX_en || excTriggered) begin
		eX_pc   <= iD_pc;
		eX_insn <= iD_insn;
		eX_isExc <= excTriggered;
		eX_lateResultInsn <= iD_lateResultInsn;
		// For a lateResult instruction being interrupted by an exception,
		// eX_rdId_isTrue must be set true so that the gpr can be unlocked.
		// Also, when there is an exception and the gpr was already locked when
		// it got locked, eX_rdId_isTrue must be set null so that the gpr gets
		// unlocked by the lateResult instruction that locked it.
		if (iD_flushed || ((iD_lateResultInsn || iD_stalled) && !excTriggered) ||
			(excTriggered && rdWasLocked)) begin
			eX_rdId_isTrue <= 1'b0;
			eX_rdId <= 5'd0;
		end else begin
			eX_rdId_isTrue <= (|iD_rdId);
			eX_rdId <= iD_rdId;
		end
		// When there is an exception, eX_rslt value is taken from
		// the gpr being locked so that iD_rW_rslt can be properly set.
		eX_rslt <= (excTriggered ? iD_rd : eX_rslt_i);
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

`ifdef PUFWDALL
assign iD_eX_rdId_isTrue  = rW_we_i;
assign iD_eX_rdId         = rW_idx_i;
assign iD_eX_rslt         = rW_dat_i;
`else
assign iD_eX_rdId_isTrue  = eX_rdId_isTrue;
assign iD_eX_rdId         = eX_rdId;
assign iD_eX_rslt         = eX_rslt;
`endif

`ifdef PURV32M
reg rW_opImul_done; // ### comb-block-reg.
reg rW_opIdiv_done; // ### comb-block-reg.
`endif

`ifdef PURV32M
`include "./imul.pu.sv"
`include "./idiv.pu.sv"
`endif
`include "./lsu.pu.sv"
`include "./sys.pu.sv"

// The pipeline has WriteBack priority; load/MUL/DIV hold their result and retire
// in cycles the pipeline yields the WriteBack slot, so the pipeline never stalls
// for WriteBack (back-pressure now lives at issue: iD_op*_bsy and load max_pending).
wire rW_pipeWrites   = (eX_rdId_isTrue && !halted_o); // pipeline takes the slot this cycle.
wire rW_isMulticycle = (rW_we_i && !rW_pipeWrites);   // a multicycle result retires this cycle.

// A completed multicycle result is held: precisely gates async traps so a held result is
// not lost into the trap handler's context (it must retire before the trap). Uses the
// exact "held load result" (ldUnit_respHeld) rather than the whole load lifetime, so a
// trap is blocked only while a result is actually waiting to retire, not while a load is
// merely in flight. MUL/DIV done already mean "result held".
wire rW_multicyclePending = (
	ldUnit_respHeld
	`ifdef PURV32M
	|| opImul_done || opIdiv_done
	`endif
	);

assign eX_rW_stalled = rW_isMulticycle; // csrInstret counts a retiring multicycle result.
assign eX_rW_carryon = 1'b1;            // eX never stalls for WriteBack.

wire rW_carryon = (!rW_isMulticycle);

always_comb begin

	rW_we_i  = 0;
	rW_idx_i = 0;
	rW_dat_i = 0;

	`ifdef PURV32M
	rW_opImul_done = 0;
	rW_opIdiv_done = 0;
	`endif

	// Pipeline has priority; load/MUL/DIV retire only when the pipeline yields the
	// slot (rW_pipeWrites false). MUL/DIV hold via their ostb/ordy handshake; a
	// completed load is held in the dCache response skidbuf via dCache_m_bsy_i.
	if (rW_pipeWrites) begin
		rW_we_i  = 1;
		rW_idx_i = eX_rdId;
		rW_dat_i = eX_rslt;
	end else if (ldUnit_memAck) begin
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
	end
end

// Used to prevent jalr and jal (without PUPREDICTJAL) from writing
// their return address when they generated a misaligned exception.
wire eX_isExc0_i = (excTriggered && excCause == {1'b0, 16'd0} && eX_JumpOrBranch);
// Wherever eX_isExc0_i is used, eX_isExc is used to prevent csr and
// jal (with PUPREDICTJAL) from writing their destination register
// when they generated a misaligned exception.
// eX_isExc is raised when iD_pc was at the exception causing instruction
// when excTriggered was high.
// eX_isExc0_i is raised when iD_pc was at the instruction following
// the exception causing instruction when excTriggered was high.

always_ff @(posedge clk_i) begin
	// Mirror the WriteBack arbiter (pipeline priority): capture the pipeline result
	// when it retires, else the load/MUL/DIV result on the cycle it actually retires
	// (rW_isMulticycle), so iD_rW_* always matches what was written to gprDat.
	if (rW_pipeWrites && !eX_isExc && !eX_isExc0_i) begin
		/* Considering the instruction sequence below, the check below
		prevents the result of `add a3,a3,a1` to be forwarded to `jr a3`,
		when the result of `lw a3,0(a3)` should be used but has been deferred
		due to being from a multi-cycle instruction.
		add     a3,a3,a1
		lw      a3,0(a3)       (Multi-cycle instruction)
		jr      a3                                                        */
		if (!iD_flushed && !iD_stalled && iD_lateResultInsn && eX_rdId == iD_rdId) begin
			iD_rW_rdId_isTrue <= 1'b0;
			iD_rW_rdId <= {CLOG2GPRCNT{1'b0}};
		end else begin
			iD_rW_rdId_isTrue <= 1'b1;
			iD_rW_rdId <= eX_rdId;
		end
		iD_rW_rslt <= eX_rslt;
	end else if (rW_isMulticycle) begin
		iD_rW_rdId_isTrue <= 1'b1;
		iD_rW_rdId <= rW_idx_i;
		iD_rW_rslt <= rW_dat_i;
	end else if (halted_o) begin
	end else if (eX_isExc) begin
		// iD_rW_rdId_isTrue and iD_rW_rdId values are needed
		// to properly unlock the gpr of the interrupted instruction.
		// iD_rW_rslt is the result value of the interrupted instruction,
		// which can be needed right after the exception.
		iD_rW_rdId_isTrue <= (|eX_rdId);
		iD_rW_rdId <= eX_rdId;
		iD_rW_rslt <= eX_rslt;
	end else begin
		iD_rW_rdId_isTrue <= 1'b0;
		iD_rW_rdId <= {CLOG2GPRCNT{1'b0}};
	end
end

always_ff @(posedge clk_i) begin
	if (rst_i || (rW_we_i && (rW_isMulticycle || (!eX_isExc && !eX_isExc0_i))))
		gprDat[rst_i ? 2 : rW_idx_i] <= (rst_i ? spval_i : rW_dat_i);
end

wire gprLock = (_iF_use_rdId && !_iF_flushed);

wire gprUnlock = (
	rW_we_i && /* Do not unlock a gpr if it is about to be locked
	or if it has just been locked; note that we are at the eXecuted stage,
	hence the reason why only *_rdId from previous stages are checked. */
	!(gprLock && _iF_rdId == rW_idx_i) &&
	!(!iD_flushed && iD_rdId == rW_idx_i && !excTriggered));

always_ff @(posedge clk_i) begin
	if (rst_i)
		gprRdy <= {GPRCNT{1'b1}};
	else begin
		if (gprLock)
			gprRdy[_iF_rdId] <= 1'b0;
		if (gprUnlock)
			gprRdy[rW_idx_i] <= 1'b1;
	end
end

// Capture whether a gpr was already locked when it got locked.
always_ff @(posedge clk_i) begin
	if (iD_en && gprLock)
		rdWasLocked <= (!gprRdy[_iF_rdId] && (!rW_we_i || (_iF_rdId != rW_idx_i)));
	else if (rdWasLocked && rW_we_i && iD_rdId == rW_idx_i)
		rdWasLocked <= 1'b0;
end

`ifdef SIMULATION
always_ff @(posedge clk_i) begin
	if (rW_carryon) begin
		rW_pc   <= eX_pc;
		rW_insn <= eX_insn;
	end
end
`endif

endmodule
