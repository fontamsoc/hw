// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

reg inusermode;
wire inkernelmode = ~inusermode;

// This register hold the address of the instruction
// currently being sequenced from the instruction buffer.
reg[(ARCHBITSZ-1) -1 : 0] ip;

`ifdef SIMULATION
assign pc_o = ({1'b0, ip} << 1'b1);
reg [ARCHBITSZ -1 : 0] pc_o_saved = 0;
`endif

reg[(ARCHBITSZ-1) -1 : 0] kip;
reg[(ARCHBITSZ-1) -1 : 0] uip;

reg ksysopfaultmode;
reg[(ARCHBITSZ-1) -1 : 0] ksysopfaulthdlr;
reg[(ARCHBITSZ-1) -1 : 0] ksysopfaultaddr;
wire[(ARCHBITSZ-1) -1 : 0] ksysopfaulthdlrplustwo = (ksysopfaulthdlr + 'h2);

wire[(ARCHBITSZ-1) -1 : 0] ipnxt = (ip + 1'b1);

reg[16 -1 : 0] sysopcode;
reg[16 -1 : 0] saved_sysopcode;

reg[ARCHBITSZ -1 : 0] faultaddr;
reg[ARCHBITSZ -1 : 0] saved_faultaddr;

localparam READFAULTINTR	= 3'd0;
localparam WRITEFAULTINTR	= 3'd1;
localparam EXECFAULTINTR	= 3'd2;
localparam ALIGNFAULTINTR	= 3'd3;
localparam EXTINTR		= 3'd4;
localparam SYSOPINTR		= 3'd5;
localparam TIMERINTR		= 3'd6;
localparam PREEMPTINTR		= 3'd7;
reg[3 -1 : 0] faultreason;

// The pu gets halted by simply preventing
// the sequencer from decoding instructions.
reg dohalt;

reg[ARCHBITSZ -1 : 0] timer;
wire timertriggered = !(|timer);

reg[(ARCHBITSZ*2) -1 : 0] clkcyclecnt;

// ---------- Registers and nets used for instruction buffering ----------

reg[ARCHBITSZ -1 : 0] instrbuf_[INSTRBUFFERSIZE -1 : 0];

wire instrbufwe;

wire[ARCHBITSZ -1 : 0] instrbufi;

// Write index within the instruction buffer.
// Only the CLOG2INSTRBUFFERSIZE lsb are used for indexing.
reg[(CLOG2INSTRBUFFERSIZE +1) -1 : 0] instrbufwriteidx;

// Net set to the space used in the instrbuf.
wire[(CLOG2INSTRBUFFERSIZE +1) -1 : 0] instrbufusage =
	(instrbufwriteidx - ip[CLOG2INSTRBUFFERSIZE +1 : 1]);
wire[(CLOG2INSTRBUFFERSIZE +1) -1 : 0] instrbufusagenxt =
	(instrbufwriteidx - ipnxt[CLOG2INSTRBUFFERSIZE +1 : 1]);

reg[16 -1 : 0] instrbufdato;
wire[ARCHBITSZMAX -1 : 0] instrbufip = instrbuf_[ip[CLOG2INSTRBUFFERSIZE : 1]];
wire[16 -1 : 0] instrbufdato_ =
	(ARCHBITSZ == 16) ? instrbufip :
	(ARCHBITSZ == 32) ? (ip[CLOG2ARCHBITSZBY16 -1 : 0] ? instrbufip[31:16] : instrbufip[15:0]) : (
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 0 ? instrbufip[15:0] :
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 1 ? instrbufip[31:16] :
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 2 ? instrbufip[47:32] :
							instrbufip[63:48]);

wire[8 -1 : 0] instrbufdato0 = instrbufdato[7:0];
wire[8 -1 : 0] instrbufdato1 = instrbufdato[15:8];

wire instrbufnotempty = |instrbufusage;

wire instrbufnotemptynxt = |instrbufusagenxt;

// This net indicates whether the instruction buffer is full.
wire instrbufnotfull = (instrbufusage < INSTRBUFFERSIZE);

wire[ARCHBITSZMAX -1 : 0] instrbufipnxt = (instrbufnotemptynxt ? instrbuf_[ipnxt[CLOG2INSTRBUFFERSIZE : 1]] : instrbufi);
wire[16 -1 : 0] instrbufipnxtdato =
	(ARCHBITSZ == 16) ? instrbufipnxt :
	(ARCHBITSZ == 32) ? (ipnxt[CLOG2ARCHBITSZBY16 -1 : 0] ? instrbufipnxt[31:16] : instrbufipnxt[15:0]) : (
			ipnxt[CLOG2ARCHBITSZBY16 -1 : 0] == 0 ? instrbufipnxt[15:0] :
			ipnxt[CLOG2ARCHBITSZBY16 -1 : 0] == 1 ? instrbufipnxt[31:16] :
			ipnxt[CLOG2ARCHBITSZBY16 -1 : 0] == 2 ? instrbufipnxt[47:32] :
							instrbufipnxt[63:48]);

wire[ARCHBITSZMAX -1 : 0] _instrbufi = instrbufi;
wire[16 -1 : 0] instrbufidato =
	(ARCHBITSZ == 16) ? _instrbufi :
	(ARCHBITSZ == 32) ? (ip[CLOG2ARCHBITSZBY16 -1 : 0] ? _instrbufi[31:16] : _instrbufi[15:0]) : (
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 0 ? _instrbufi[15:0] :
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 1 ? _instrbufi[31:16] :
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 2 ? _instrbufi[47:32] :
							_instrbufi[63:48]);

reg instrbufrst_a;
reg instrbufrst_b;
// This wire becomes 1 whenever a branching occur.
wire instrbufrst = (instrbufrst_a ^ instrbufrst_b);
reg instrbufrst_sampled;
wire instrbufrst_posedge = (!instrbufrst_sampled && instrbufrst);

wire itlben;
wire not_itlben_or_not_instrbufrst_posedge = (
	!itlben || !instrbufrst_posedge/* Insures instrbufrst get reset after reading itlbentry has completed */);

// ---------- Registers used by instrfetch ----------

// Register holding the virtual address of the instruction data to fetch.
reg[ADDRBITSZ -1 : 0] instrfetchaddr;

// Net set to the next value of instrfetchaddr.
wire[ADDRBITSZ -1 : 0] instrfetchnextaddr = instrbufrst ? ip[ADDRBITSZ:1] : (instrfetchaddr+1);

// Register holding the physical page number of the instruction to fetch.
reg[PAGENUMBITSZ -1 : 0] instrfetchppn;

reg instrfetchfaulted_a;
reg instrfetchfaulted_b;
// Wire set to 1 when in usermode and the memory access was a pagefault.
wire instrfetchfaulted = (instrfetchfaulted_a ^ instrfetchfaulted_b);

// Register holding the instruction fetch fault virtual address.
reg[ARCHBITSZ -1 : 0] instrfetchfaultaddr;

// Register set to 1 for a mem request.
reg instrfetchmemrqst;

// Register set to 1 when the mem request is in progress.
reg instrfetchmemrqstinprogress;

// Net set to 1 when the mem request has completed.
// This signal is 1 only for 1 clock cycle, and pi1_data_i
// should be read as soon as this signal 1.
wire instrfetchmemrqstdone = (instrfetchmemrqstinprogress && pi1_rdy_i && !instrbufrst);

// This net is 1 when a memory request was made,
// but the actual memory access is pending execution.
wire instrfetchmemaccesspending = (instrfetchmemrqst && !instrfetchmemrqstinprogress && !instrbufrst);

// ---------- Registers and nets used by opli ----------

// Register used to count the number of 16 bits left to load to get the immediate value.
reg[3 -1 : 0] oplicounter;

wire oplicountereq1 = (oplicounter == 1);

// Register used to count the number of 16 bits sequenced within the instruction opli.
reg[3 -1 : 0] oplioffset;

// ---------- Registers and nets used by the debugging interface ----------

`ifdef PUDBG
// Debug interface commands.
localparam DBGCMDSELECT		= 0;
localparam DBGCMDSTEP		= 1;
localparam DBGCMDGETOPCODE	= 2;
localparam DBGCMDGETIP		= 3;
localparam DBGCMDGETGPR		= 4;
localparam DBGCMDSETGPR		= 5;
localparam DBGCMDLOADIARG	= 6;
// Debug interface arguments for DBGCMDSTEP.
localparam DBGARGSTEPDISABLE	= 0;
localparam DBGARGSTEPSTOP	= 1;
localparam DBGARGSTEPONCE	= 2;
localparam DBGARGSTEPTILL	= 3;
// Debug interface registers and nets.
reg dbgen;
reg dbgselected;
reg[(CLOG2ARCHBITSZBY8+1) -1 : 0] dbgcounter;
wire[(CLOG2ARCHBITSZBY8+1) -1 : 0] dbgcounterminusone = (dbgcounter - 1'b1);
reg dbgcntren;
reg[3 -1 : 0] dbgcmd;
reg[5 -1 : 0] dbgarg;
reg[ARCHBITSZ -1 : 0] dbgiarg;
wire dbgiargeqip = (dbgiarg == {ip, 1'b0});
wire dbgcmdsteptilldone = (dbgcmd == DBGCMDSTEP && (
	(dbgarg == DBGARGSTEPONCE && ((!dbgiargeqip && !oplicounter) || instrbufrst)) ||
	(dbgarg == DBGARGSTEPTILL && dbgiargeqip)));
wire dbgbrk = (dbgen && (dbgcmd != DBGCMDSTEP || dbgcmdsteptilldone || dbgarg == DBGARGSTEPSTOP));
wire[ARCHBITSZ -1 : 0] dbggprdata;
`else
wire dbgen = 1'b0;
wire[5 -1 : 0] dbgarg = 5'b00000;
wire[ARCHBITSZ -1 : 0] dbggprdata;
`endif

// Net set to 1, when other miscellaneous logic are
// in a state that allows sequencing a new instruction.
`ifdef PUDBG
wire miscrdy = !dbgbrk && !oplicounter;
`else
wire miscrdy = !oplicounter;
`endif

`ifdef PUDBG
// (sequencerready && !oplicounter) should have been checked
// before setting dbgcounter so that a response gets transmitted
// only if the next instruction is available for sequencing;
// it insures that the debug commands will always return the correct
// value if the pu is not fast enough compared to the phy interface.
// Additional commands will not be accepted until the response
// of the current command has been transmited.
// ###: (&gprrdy) should be taken into account, but since it needs to be indexed,
// ###: workaround could be for debugger to wait sufficiently long-enough; ie: 1sec.
assign dbg_tx_stb_o  = (dbgcounter && dbg_tx_rdy_i);
assign dbg_tx_data_o = dbgiarg[8 -1 : 0];
// Register used to detect a negedge of dbgxterphy.dataneeded.
reg  dbg_tx_rdy_i_sampled;
wire dbg_tx_rdy_i_negedge = (!dbg_tx_rdy_i && dbg_tx_rdy_i_sampled);
`endif

// ---------- Registers and nets used by Hardware-Page-Table-Walker ----------

wire[ARCHBITSZ -1 : 0] gprdata1;
wire[ARCHBITSZ -1 : 0] gprdata2;

reg[2 -1 : 0] dcachemasterop; // ### declared as reg so as to be usable by verilog within the always block.
reg[ADDRBITSZ -1 : 0] dcachemasteraddr; // ### declared as reg so as to be usable by verilog within the always block.
wire[ARCHBITSZMAX -1 : 0] dcachemasterdato;
reg[ARCHBITSZMAX -1 : 0] dcachemasterdati; // ### declared as reg so as to be usable by verilog within the always block.
reg[(ARCHBITSZMAX/8) -1 : 0] dcachemastersel; // ### declared as reg so as to be usable by verilog within the always block.
wire dcachemasterrdy;

wire[2 -1 : 0] dcacheslaveop;
wire[ADDRBITSZ -1 : 0] dcacheslaveaddr;
wire[ARCHBITSZ -1 : 0] dcacheslavedato;
wire[(ARCHBITSZ/8) -1 : 0] dcacheslavesel;

wire isopgettlb;
wire isopld;
wire isopst;
wire isopldst;

`ifdef PUMMU

wire inuserspace;

`ifdef PUHPTW

reg[ARCHBITSZ -1 : 0] hptwpgd;

localparam HPTWSTATEPGD0 = 0;
localparam HPTWSTATEPGD1 = 1;
localparam HPTWSTATEPTE0 = 2;
localparam HPTWSTATEPTE1 = 3;
localparam HPTWSTATEDONE = 4;

reg[3 -1 : 0] hptwistate; // Must have enough bits such that it can be used with the sequencer to determine whether in use.
wire hptwistate_eq_HPTWSTATEPGD0 = (hptwistate == HPTWSTATEPGD0);
wire hptwistate_eq_HPTWSTATEPGD1 = (hptwistate == HPTWSTATEPGD1);
wire hptwistate_eq_HPTWSTATEPTE0 = (hptwistate == HPTWSTATEPTE0);
wire hptwistate_eq_HPTWSTATEPTE1 = (hptwistate == HPTWSTATEPTE1);
wire hptwistate_eq_HPTWSTATEDONE = (hptwistate == HPTWSTATEDONE);
wire hptwitlbwe = (dcachemasterrdy &&
	dcachemasterdato[5] && (inuserspace ? dcachemasterdato[4] : 1'b1) &&
		dcachemasterdato[0]                                       &&
	hptwistate_eq_HPTWSTATEPTE1);
wire[10 -1 : 0] hptwipgdoffset = instrfetchnextaddr[ADDRBITSZ -1 : ADDRBITSZ -10];
wire[ARCHBITSZ -1 : 0] hptwpgd_plus_hptwipgdoffset = (hptwpgd + {hptwipgdoffset, {CLOG2ARCHBITSZBY8{1'b0}}});
reg[ARCHBITSZ -1 : 0] hptwipte;
wire[10 -1 : 0] hptwipteoffset = instrfetchnextaddr[(ADDRBITSZ -10) -1 : (ADDRBITSZ -10) -10];
wire[ARCHBITSZ -1 : 0] hptwipte_plus_hptwipteoffset = (hptwipte + {hptwipteoffset, {CLOG2ARCHBITSZBY8{1'b0}}});
reg hptwidone;

reg[3 -1 : 0] hptwdstate; // Must have enough bits such that it can be used with the sequencer to determine whether in use.
wire hptwdstate_eq_HPTWSTATEPGD0 = (hptwdstate == HPTWSTATEPGD0);
wire hptwdstate_eq_HPTWSTATEPGD1 = (hptwdstate == HPTWSTATEPGD1);
wire hptwdstate_eq_HPTWSTATEPTE0 = (hptwdstate == HPTWSTATEPTE0);
wire hptwdstate_eq_HPTWSTATEPTE1 = (hptwdstate == HPTWSTATEPTE1);
wire hptwdstate_eq_HPTWSTATEDONE = (hptwdstate == HPTWSTATEDONE);
wire hptwdtlbwe = (dcachemasterrdy &&
	dcachemasterdato[5] && (inuserspace ? dcachemasterdato[4] : 1'b1) && (
		isopgettlb                                                ||
		(isopld     && dcachemasterdato[2])                       ||
		(isopst     && dcachemasterdato[1])                       ||
		(isopldst   && (|dcachemasterdato[2:1])))                 &&
	hptwdstate_eq_HPTWSTATEPTE1);
wire[10 -1 : 0] hptwdpgdoffset = gprdata2[ARCHBITSZ -1 : ARCHBITSZ -10];
wire[ARCHBITSZ -1 : 0] hptwpgd_plus_hptwdpgdoffset = (hptwpgd + {hptwdpgdoffset, {CLOG2ARCHBITSZBY8{1'b0}}});
reg[ARCHBITSZ -1 : 0] hptwdpte;
wire[10 -1 : 0] hptwdpteoffset = gprdata2[(ARCHBITSZ -10) -1 : (ARCHBITSZ -10) -10];
wire[ARCHBITSZ -1 : 0] hptwdpte_plus_hptwdpteoffset = (hptwdpte + {hptwdpteoffset, {CLOG2ARCHBITSZBY8{1'b0}}});
reg hptwddone;

wire hptwbsy = (hptwistate || hptwdstate);

localparam HPTWMEMSTATENONE  = 0;
localparam HPTWMEMSTATEINSTR = 1;
localparam HPTWMEMSTATEDATA  = 2;

reg[2 -1 : 0] hptwmemstate; // ### declared as reg so as to be usable by verilog within the always block.

`endif
`endif

// ---------- Registers and nets used for sequencing and decoding ----------

wire[CLOG2GPRCNTTOTAL -1 : 0] gpridx1 = {inusermode, instrbufdato1[7:4]};
wire[CLOG2GPRCNTTOTAL -1 : 0] gpridx2 = {inusermode, instrbufdato1[3:0]};

// These nets will respectively hold the busy state
// of the first and second gpr operand of an instruction
// being sequenced.
wire gprrdy1;
wire gprrdy2;

reg[CLOG2GPRCNTTOTAL -1 : 0] gprrdyrstidx;
reg gprrdyon;
wire gprrdyoff = !gprrdyon;

// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
localparam GPRCTRLSTATEDONE     = 0;
localparam GPRCTRLSTATEOPLD     = 1;
localparam GPRCTRLSTATEOPLDST   = 2;
localparam GPRCTRLSTATEOPMULDIV = 3;
reg[2 -1 : 0] gprctrlstate;
reg[CLOG2GPRCNTTOTAL -1 : 0] gpridx;
reg[ARCHBITSZ -1 : 0] gprdata;
reg gprwe;
reg[CLOG2GPRCNTTOTAL -1 : 0] gprrdyidx;
reg gprrdyval;
reg gprrdywe;

reg[ARCHBITSZ -1 : 0] gpr13val;

`ifdef SIMULATION
reg [ARCHBITSZ -1 : 0] sequencerstate;
`endif

wire isflagdisextintr;
wire isflagdistimerintr;

wire sequencerready_ = !(
	rst_i || gprrdyoff || instrbufrst ||
	(timertriggered && !isflagdistimerintr && inusermode && !oplicounter && !dbgen
	`ifdef PUMMU
	`ifdef PUHPTW
	&& !hptwbsy
	`endif
	`endif
	) ||
	(intrqst_i && !isflagdisextintr && inusermode && !oplicounter && !dbgen
	`ifdef PUMMU
	`ifdef PUHPTW
	&& !hptwbsy
	`endif
	`endif
	) ||
	inhalt);
// When this net is 1, the sequencer is ready.
wire sequencerready = sequencerready_ && instrbufnotempty;

// Nets set to 1 when sequencerready is 1 and the appropriate gpr is not busy.
wire sequencerreadyandgprrdy1 = sequencerready && gprrdy1;
wire sequencerreadyandgprrdy12 = sequencerreadyandgprrdy1 && gprrdy2;

wire miscrdyandsequencerreadyandgprrdy1 = (miscrdy && sequencerreadyandgprrdy1);
wire miscrdyandsequencerreadyandgprrdy12 = (miscrdy && sequencerreadyandgprrdy12);

// Nets used during decoding to determine the type of the opcode set in instrbufdato0[7:3].
wire isoptype0 = (instrbufdato0[2:0] == 0);
wire isoptype1 = (instrbufdato0[2:0] == 1);
wire isoptype2 = (instrbufdato0[2:0] == 2);
wire isoptype3 = (instrbufdato0[2:0] == 3);
wire isoptype4 = (instrbufdato0[2:0] == 4);
wire isoptype5 = (instrbufdato0[2:0] == 5);
wire isoptype6 = (instrbufdato0[2:0] == 6);
wire isoptype7 = (instrbufdato0[2:0] == 7);

// Nets used during decoding to determine the opcode.
wire isopli8 = (instrbufdato0[7:4] == OPLI8A[4:1]);
wire isopinc8 = (instrbufdato0[7:4] == OPINC8A[4:1]);
wire isoprli8 = (instrbufdato0[7:4] == OPRLI8A[4:1]);
wire isopinc = (instrbufdato0[7:3] == OPINC);
wire isopimm = (instrbufdato0[7:3] == OPIMM);
//wire isopli = (isopimm && !instrbufdato0[2]);
wire isoprli = (isopimm && instrbufdato0[2]);
wire isopalu0 = (instrbufdato0[7:3] == OPALU0);
wire isopfloat = (instrbufdato0[7:3] == OPFLOAT);
wire isopalu1 = (instrbufdato0[7:3] == OPALU1);
wire isopalu2 = (instrbufdato0[7:3] == OPALU2);
wire isopj = (instrbufdato0[7:3] == OPJ);
wire isopswitchctx = (instrbufdato0[7:3] == OPSWITCHCTX);
wire isopsysret = (isopswitchctx && isoptype0);
wire isophalt = (isopswitchctx && isoptype3);
wire isopicacherst = (isopswitchctx && isoptype4);
wire isopdcacherst = (isopswitchctx && isoptype5);
wire isopcacherst = (isopicacherst || isopdcacherst);
wire isopksysret = (isopswitchctx && isoptype7);
wire isopgetsysreg = (instrbufdato0[7:3] == OPGETSYSREG);
wire isopgetsysopcode = (isopgetsysreg && isoptype0);
wire isopgetuip = (isopgetsysreg && isoptype1);
wire isopgetfaultaddr = (isopgetsysreg && isoptype2);
wire isopgetfaultreason = (isopgetsysreg && isoptype3);
wire isopgetclkcyclecnt = (isopgetsysreg && isoptype4);
wire isopgetclkcyclecnth = (isopgetsysreg && isoptype5);
wire isopgettlbsize = (isopgetsysreg && isoptype6);
wire isopgeticachesize = (isopgetsysreg && isoptype7);
wire isopgetsysreg1 = (instrbufdato0[7:3] == OPGETSYSREG1);
wire isopgetcoreid = (isopgetsysreg1 && isoptype0);
wire isopgetclkfreq = (isopgetsysreg1 && isoptype1);
wire isopgetdcachesize = (isopgetsysreg1 && isoptype2);
wire isopgetcachesize = (isopgeticachesize || isopgetdcachesize);
assign isopgettlb = (isopgetsysreg1 && isoptype3);
wire isopgetcap = (isopgetsysreg1 && isoptype4);
wire isopgetver = (isopgetsysreg1 && isoptype5);
wire isopsetsysreg = (instrbufdato0[7:3] == OPSETSYSREG);
wire isopsetksysopfaulthdlr = (isopsetsysreg && isoptype0);
wire isopsetksl = (isopsetsysreg && isoptype1);
wire isopsettlb = (isopsetsysreg && isoptype2);
wire isopclrtlb = (isopsetsysreg && isoptype3);
wire isopsetasid = (isopsetsysreg && isoptype4);
wire isopsetuip = (isopsetsysreg && isoptype5);
wire isopsetflags = (isopsetsysreg && isoptype6);
wire isopsettimer = (isopsetsysreg && isoptype7);
wire isopsetgpr = (instrbufdato0[7:3] == OPSETGPR);
wire isoploadorstore = (instrbufdato0[7:3] == OPLOADORSTORE);
wire isopvloadorstore = (instrbufdato0[7:3] == OPVLOADORSTORE);
assign isopld = ((isoploadorstore || isopvloadorstore) && instrbufdato0[2]);
assign isopst = ((isoploadorstore || isopvloadorstore) && !instrbufdato0[2]);
assign isopldst = (instrbufdato0[7:3] == OPLDST);
wire isopmuldiv = (instrbufdato0[7:3] == OPMULDIV);

reg[16 -1 : 0] flags;
wire isflagsetasid = flags[0];
wire isflagsettimer = flags[1];
wire isflagsettlb = flags[2];
wire isflagclrtlb = flags[3];
wire isflaggetclkcyclecnt = flags[4];
wire isflaggetclkfreq = flags[5];
wire isflaggettlbsize = flags[6];
wire isflaggetcachesize = flags[7];
wire isflaggetcoreid = flags[8];
wire isflagcacherst = flags[9];
wire isflaggettlb = flags[10];
wire isflagsetflags = flags[11];
assign isflagdisextintr = flags[12];
assign isflagdistimerintr = flags[13];
wire isflagdispreemptintr = flags[14];
wire isflaghalt = flags[15];

wire isopgettlb_or_isopclrtlb_found_posedge;

// ---------- Registers and nets implementing the mmu ----------

wire istlbop = (isopsettlb || isopclrtlb || isopgettlb);
wire tlbbsy = (miscrdyandsequencerreadyandgprrdy12 && istlbop);

// Register holding KernelSpaceLimit value.
// When in usermode and running in kernelspace,
// a 1-to-1 mapping is always done regardless
// of TLB entries if the memory access address
// is >= 0x1000 and < %ksl ; when running in userspace,
// the TLB is never ignored and this register is ignored.
reg[ARCHBITSZ -1 : 0] ksl;

wire ioutofrange;
wire doutofrange;

`ifdef PUMMU

reg[(1+12) -1 : 0] asid;

localparam CLOG2TLBSETCOUNT = clog2(TLBSETCOUNT);
localparam PAGENUMBITSZMINUSCLOG2TLBSETCOUNT = (PAGENUMBITSZ -CLOG2TLBSETCOUNT);
localparam TLBENTRYBITSZ = (12 +5 +PAGENUMBITSZ +PAGENUMBITSZMINUSCLOG2TLBSETCOUNT);

// TLB (Translation Lookaside Buffer).
// Bit format of a single TLB entry:
// |asid: 12|user: 1|cached: 1|readable: 1|writable: 1|executable: 1|ppn: PAGENUMBITSZ|vpn: PAGENUMBITSZMINUSCLOG2TLBSETCOUNT|

assign inuserspace = asid[12];

reg [CLOG2TLBWAYCOUNT -1 : 0] dtlbwayhitidx; // ### Nets declared as reg so as to be useable by verilog within the always block.
reg [CLOG2TLBWAYCOUNT -1 : 0] dtlbwaywriteidx; // Register used to hold dtlb-way index to write next.
// Nets implementing checking the tlb for data loading/storing.
wire[CLOG2TLBSETCOUNT -1 : 0] dtlbset = gprdata2[(CLOG2TLBSETCOUNT +12) -1 : 12];
wire[TLBENTRYBITSZ -1 : 0] dtlbentry [TLBWAYCOUNT -1 : 0];
wire[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0] dtlbtag [TLBWAYCOUNT -1 : 0];
wire[PAGENUMBITSZ -1 : 0] dtlbppn [TLBWAYCOUNT -1 : 0];
wire dtlbwritable [TLBWAYCOUNT -1 : 0];
wire dtlbnotwritable [TLBWAYCOUNT -1 : 0];
wire dtlbreadable [TLBWAYCOUNT -1 : 0];
wire dtlbnotreadable [TLBWAYCOUNT -1 : 0];
wire dtlbcached [TLBWAYCOUNT -1 : 0];
//wire dtlbnotcached [TLBWAYCOUNT -1 : 0];
wire dtlbuser [TLBWAYCOUNT -1 : 0];
wire dtlbnotuser [TLBWAYCOUNT -1 : 0];
wire[12 -1 : 0] dtlbasid [TLBWAYCOUNT -1 : 0];
wire[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0] dvpn = gprdata2[ARCHBITSZ -1 : (12 +CLOG2TLBSETCOUNT)];
wire dtlbmiss_ [TLBWAYCOUNT -1 : 0];
wire dtlben = (!dohalt && inusermode && (inuserspace || doutofrange));
reg dtlbwritten;
reg[CLOG2TLBSETCOUNT -1 : 0] dtlbsetprev;
wire dtlbreadenable_ = (isopgettlb_or_isopclrtlb_found_posedge || dtlbwritten || (dtlben && dtlbset != dtlbsetprev));
wire dtlbreadenable = (dtlbreadenable_);
wire itlbreadenable;
wire itlbreadenable_;
wire dtlbwe = (
	`ifdef PUHPTW
	hptwdtlbwe ||
	`endif
	(miscrdyandsequencerreadyandgprrdy12 &&
	!(itlbreadenable_ || dtlbreadenable_) && (
	(isopsettlb && (inkernelmode || isflagsettlb) && (gprdata1 & 'b110)) ||
	(isopclrtlb && (inkernelmode || isflagclrtlb) && !(({dtlbtag[dtlbwayhitidx], dtlbset, dtlbasid[dtlbwayhitidx]} ^ gprdata2) & gprdata1)))));

reg [CLOG2TLBWAYCOUNT -1 : 0] itlbwayhitidx; // ### Nets declared as reg so as to be useable by verilog within the always block.
reg [CLOG2TLBWAYCOUNT -1 : 0] itlbwaywriteidx; // Register used to hold itlb-way index to write next.
// Nets implementing checking the tlb for instruction fetching.
wire[CLOG2TLBSETCOUNT -1 : 0] itlbset = (tlbbsy ? dtlbset :
	instrfetchnextaddr[(CLOG2TLBSETCOUNT +ADDRWITHINPAGEBITSZ) -1 : ADDRWITHINPAGEBITSZ]);
wire[TLBENTRYBITSZ -1 : 0] itlbentry [TLBWAYCOUNT -1 : 0];
wire[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0] itlbtag [TLBWAYCOUNT -1 : 0];
wire[PAGENUMBITSZ -1 : 0] itlbppn [TLBWAYCOUNT -1 : 0];
wire itlbexecutable [TLBWAYCOUNT -1 : 0];
wire itlbnotexecutable [TLBWAYCOUNT -1 : 0];
wire itlbcached [TLBWAYCOUNT -1 : 0];
//wire itlbnotcached [TLBWAYCOUNT -1 : 0];
wire itlbuser [TLBWAYCOUNT -1 : 0];
wire itlbnotuser [TLBWAYCOUNT -1 : 0];
wire[12 -1 : 0] itlbasid [TLBWAYCOUNT -1 : 0];
wire[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0] ivpn = instrfetchnextaddr[ADDRBITSZ -1 : (ADDRWITHINPAGEBITSZ +CLOG2TLBSETCOUNT)];
wire itlbmiss_ [TLBWAYCOUNT -1 : 0];
assign itlben = (!dohalt && inusermode && (inuserspace || ioutofrange));
reg itlbwritten;
reg[CLOG2TLBSETCOUNT -1 : 0] itlbsetprev;
assign itlbreadenable_ = (isopgettlb_or_isopclrtlb_found_posedge || itlbwritten || (itlben && itlbset != itlbsetprev));
assign itlbreadenable = (itlbreadenable_);
wire itlbwe = (
	`ifdef PUHPTW
	hptwitlbwe ||
	`endif
	(miscrdyandsequencerreadyandgprrdy12 &&
	!(itlbreadenable_ || dtlbreadenable_) && (
	(isopsettlb && (inkernelmode || isflagsettlb) && (gprdata1 & 'b1)) ||
	(isopclrtlb && (inkernelmode || isflagclrtlb) && !(({itlbtag[itlbwayhitidx], itlbset, itlbasid[itlbwayhitidx]} ^ gprdata2) & gprdata1)))));

// Net used to write itlb and dtlb.
wire[TLBENTRYBITSZ -1 : 0] tlbwritedata = (
	isopsettlb ? {gprdata2[12-1:0], gprdata1[4:0], gprdata1[ARCHBITSZ-1:12], dvpn} :
	`ifdef PUHPTW
	hptwitlbwe ? {asid[12-1:0], dcachemasterdato[4:3], 2'b00, dcachemasterdato[0], dcachemasterdato[ARCHBITSZ-1:12], ivpn} :
	hptwdtlbwe ? {asid[12-1:0], dcachemasterdato[4:1], 1'b0,                       dcachemasterdato[ARCHBITSZ-1:12], dvpn} :
	`endif
	             {TLBENTRYBITSZ{1'b0}});

reg itlbmiss; // ### Nets declared as reg so as to be useable by verilog within the always block.
integer gen_itlbhit_idx;
always @* begin
	itlbmiss = 1;
	itlbwayhitidx = 0;
	for (gen_itlbhit_idx = 0; gen_itlbhit_idx < TLBWAYCOUNT; gen_itlbhit_idx = gen_itlbhit_idx + 1) begin
		if (itlbmiss && !itlbmiss_[gen_itlbhit_idx]) begin
			itlbmiss = 0;
			itlbwayhitidx = gen_itlbhit_idx;
		end
	end
end

reg dtlbmiss; // ### Nets declared as reg so as to be useable by verilog within the always block.
integer gen_dtlbhit_idx;
always @* begin
	dtlbmiss = 1;
	dtlbwayhitidx = 0;
	for (gen_dtlbhit_idx = 0; gen_dtlbhit_idx < TLBWAYCOUNT; gen_dtlbhit_idx = gen_dtlbhit_idx + 1) begin
		if (dtlbmiss && !dtlbmiss_[gen_dtlbhit_idx]) begin
			dtlbmiss = 0;
			dtlbwayhitidx = gen_dtlbhit_idx;
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i)
		itlbwaywriteidx <= 0;
	else if (itlbwe && !isopclrtlb) begin
		if (itlbwaywriteidx >= (TLBWAYCOUNT-1))
			itlbwaywriteidx <= 0;
		else
			itlbwaywriteidx <= itlbwaywriteidx + 1'b1;
	end
end

always @ (posedge clk_i) begin
	if (rst_i)
		dtlbwaywriteidx <= 0;
	else if (dtlbwe && !isopclrtlb) begin
		if (dtlbwaywriteidx >= (TLBWAYCOUNT-1))
			dtlbwaywriteidx <= 0;
		else
			dtlbwaywriteidx <= dtlbwaywriteidx + 1'b1;
	end
end

genvar gen_tlb_idx;
generate for (gen_tlb_idx = 0; gen_tlb_idx < TLBWAYCOUNT; gen_tlb_idx = gen_tlb_idx + 1) begin :gen_tlb

bram #(

	 .SZ (TLBSETCOUNT)
	,.DW (TLBENTRYBITSZ)

) itlb (

	 .clk0_i  (clk_i)                  ,.clk1_i  (clk_i)
	,.en0_i   (itlbreadenable)         ,.en1_i   (1'b1)
	                                   ,.we1_i   (itlbwe && ((itlbwaywriteidx == gen_tlb_idx) || isopclrtlb))
	,.addr0_i (itlbset)                ,.addr1_i (itlbset)
	                                   ,.i1      (tlbwritedata)
	,.o0      (itlbentry[gen_tlb_idx]) ,.o1      ()
);

bram #(

	 .SZ (TLBSETCOUNT)
	,.DW (TLBENTRYBITSZ)

) dtlb (

	 .clk0_i  (clk_i)                  ,.clk1_i  (clk_i)
	,.en0_i   (dtlbreadenable)         ,.en1_i   (1'b1)
	                                   ,.we1_i   (dtlbwe && ((dtlbwaywriteidx == gen_tlb_idx) || isopclrtlb))
	,.addr0_i (dtlbset)                ,.addr1_i (dtlbset)
	                                   ,.i1      (tlbwritedata)
	,.o0      (dtlbentry[gen_tlb_idx]) ,.o1      ()
);

assign itlbtag[gen_tlb_idx] = itlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0];
assign itlbppn[gen_tlb_idx] = itlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ -1 : PAGENUMBITSZMINUSCLOG2TLBSETCOUNT];
assign itlbexecutable[gen_tlb_idx] = itlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ];
assign itlbnotexecutable[gen_tlb_idx] = ~itlbexecutable[gen_tlb_idx];
assign itlbcached[gen_tlb_idx] = itlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +3];
//assign itlbnotcached[gen_tlb_idx] = ~itlbcached[gen_tlb_idx];
assign itlbuser[gen_tlb_idx] = itlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +4];
assign itlbnotuser[gen_tlb_idx] = ~itlbuser[gen_tlb_idx];
assign itlbasid[gen_tlb_idx] = itlbentry[gen_tlb_idx][(PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +5) +12 -1 : PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +5];
assign itlbmiss_[gen_tlb_idx] = ((inuserspace && itlbnotuser[gen_tlb_idx]) || (asid[12 -1 : 0] != itlbasid[gen_tlb_idx]) || (ivpn != itlbtag[gen_tlb_idx]));

assign dtlbtag[gen_tlb_idx] = dtlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0];
assign dtlbppn[gen_tlb_idx] = dtlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ -1 : PAGENUMBITSZMINUSCLOG2TLBSETCOUNT];
assign dtlbwritable[gen_tlb_idx] = dtlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +1];
assign dtlbnotwritable[gen_tlb_idx] = ~dtlbwritable[gen_tlb_idx];
assign dtlbreadable[gen_tlb_idx] = dtlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +2];
assign dtlbnotreadable[gen_tlb_idx] = ~dtlbreadable[gen_tlb_idx];
assign dtlbcached[gen_tlb_idx] = dtlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +3];
//assign dtlbnotcached[gen_tlb_idx] = ~dtlbcached[gen_tlb_idx];
assign dtlbuser[gen_tlb_idx] = dtlbentry[gen_tlb_idx][PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +4];
assign dtlbnotuser[gen_tlb_idx] = ~dtlbuser[gen_tlb_idx];
assign dtlbasid[gen_tlb_idx] = dtlbentry[gen_tlb_idx][(PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +5) +12 -1 : PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +5];
assign dtlbmiss_[gen_tlb_idx] = ((inuserspace && dtlbnotuser[gen_tlb_idx]) || (asid[12 -1 : 0] != dtlbasid[gen_tlb_idx]) || (dvpn != dtlbtag[gen_tlb_idx]));

end endgenerate

// Nets used by gettlb.
wire itlbgettlbhit = ((gprdata2[12 -1 : 0] == itlbasid[itlbwayhitidx]) && (gprdata2[(ARCHBITSZ-1) : 12 +CLOG2TLBSETCOUNT] == itlbtag[itlbwayhitidx]));
wire dtlbgettlbhit = ((gprdata2[12 -1 : 0] == dtlbasid[dtlbwayhitidx]) && (gprdata2[(ARCHBITSZ-1) : 12 +CLOG2TLBSETCOUNT] == dtlbtag[dtlbwayhitidx]));
wire[ARCHBITSZ -1 : 0] gettlbresult = (
	(!(itlbgettlbhit | dtlbgettlbhit)) ? {ARCHBITSZ{1'b0}} :
	(itlbgettlbhit ^ dtlbgettlbhit) ?
		(itlbgettlbhit ?
			{itlbppn[itlbwayhitidx], {7{1'b0}}, itlbuser[itlbwayhitidx], itlbcached[itlbwayhitidx], {2{1'b0}}, itlbexecutable[itlbwayhitidx]} :
			{dtlbppn[dtlbwayhitidx], {7{1'b0}}, dtlbuser[dtlbwayhitidx], dtlbcached[dtlbwayhitidx], dtlbreadable[dtlbwayhitidx], dtlbwritable[dtlbwayhitidx], 1'b0}) :
	(itlbppn[itlbwayhitidx] == dtlbppn[dtlbwayhitidx]) ?
		{dtlbppn[dtlbwayhitidx], {7{1'b0}}, (itlbuser[itlbwayhitidx]|dtlbuser[dtlbwayhitidx]), (itlbcached[itlbwayhitidx]|dtlbcached[dtlbwayhitidx]), dtlbreadable[dtlbwayhitidx], dtlbwritable[dtlbwayhitidx], itlbexecutable[itlbwayhitidx]} :
		{ARCHBITSZ{1'b0}});

// Net used by opld opst opldst and the sequencer.
wire[PAGENUMBITSZ -1 : 0] dppn = (dtlben ? dtlbppn[dtlbwayhitidx] : gprdata2[ARCHBITSZ-1:12]);

`else

wire [CLOG2TLBWAYCOUNT -1 : 0] dtlbwayhitidx = 0;
wire dtlbreadenable = 0;
wire dtlbreadenable_ = 0;
wire [TLBWAYCOUNT -1 : 0] dtlbnotwritable = 0;
wire [TLBWAYCOUNT -1 : 0] dtlbnotreadable = 0;
wire [TLBWAYCOUNT -1 : 0] dtlbcached = 0;
wire dtlbmiss = 0;
wire dtlben = 0;
wire [CLOG2TLBWAYCOUNT -1 : 0] itlbwayhitidx = 0;
wire itlbreadenable = 0;
wire itlbreadenable_ = 0;
wire [TLBWAYCOUNT -1 : 0] itlbnotexecutable = 0;
wire [TLBWAYCOUNT -1 : 0] itlbcached = 0;
wire itlbmiss = 0;
genvar gen_tlb_idx;
wire[PAGENUMBITSZ -1 : 0] itlbppn [TLBWAYCOUNT -1 : 0];
generate for (gen_tlb_idx = 0; gen_tlb_idx < TLBWAYCOUNT; gen_tlb_idx = gen_tlb_idx + 1) begin :gen_tlb
assign itlbppn[gen_tlb_idx] = 0;
end endgenerate
assign itlben = 0;
wire[PAGENUMBITSZ -1 : 0] dppn = gprdata2[ARCHBITSZ-1:12];

`endif

localparam KERNELSPACESTART = 'h1000;
assign ioutofrange = (instrfetchnextaddr < (KERNELSPACESTART >> CLOG2ARCHBITSZBY8) || (instrfetchnextaddr >= ksl[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8]));
assign doutofrange = (gprdata2 < KERNELSPACESTART || gprdata2 >= ksl);

wire itlb_and_instrbuf_rdy = (((!(inusermode && tlbbsy) && instrbufnotfull) || instrbufrst) && (!itlbreadenable_
	`ifdef PUMMU
	`ifdef PUHPTW
	|| (hptwidone && !itlbwritten)
	`endif
	`endif
	));

`ifdef PUMMU
wire itlbfault_ = (itlben && (itlbnotexecutable[itlbwayhitidx] || itlbmiss));
wire itlbfault = itlbfault_;
`ifdef PUHPTW
wire itlbfault__hptwidone = (!itlbfault_ || !hptwpgd || (hptwidone && !itlbwritten));
`endif
`else
wire itlbfault = 0;
`endif

wire dtlb_rdy = (!dtlbreadenable);

// ---------- Net used to detect unaligned data memory access ----------

wire alignfault =
	(ARCHBITSZ == 16) ? (instrbufdato0[0] && gprdata2[0]) :
	(ARCHBITSZ == 32) ? ((instrbufdato0[1] && gprdata2[1:0]) || (instrbufdato0[0] && gprdata2[0])) :
		((&instrbufdato0[1:0] && gprdata2[2:0]) || (instrbufdato0[1] && gprdata2[1:0]) || (instrbufdato0[0] && gprdata2[0]));

// ---------- Registers and nets used for instruction caching ----------

// The instruction cache is active when the value of this register is 1.
reg icacheactive;

// Register set to 1 to do an instruction cache check.
reg icachecheck;

// Net set to 1 to do an instruction cache reset.
wire doicacherst = (rst_i || (miscrdy && sequencerready && isopicacherst));

wire[PAGENUMBITSZ -1 : 0] instrfetchnextppn =
	(itlben ? itlbppn[itlbwayhitidx] : instrfetchnextaddr[ADDRBITSZ-1:ADDRWITHINPAGEBITSZ]);

// ### Used because of verilog syntax limitation.
wire[ADDRBITSZ -1 : 0] instrfetchnextppninstrfetchnextaddr = {instrfetchnextppn, instrfetchnextaddr[ADDRWITHINPAGEBITSZ-1:0]};
wire[ADDRBITSZ -1 : 0] instrfetchppninstrfetchaddr = {instrfetchppn, instrfetchaddr[ADDRWITHINPAGEBITSZ-1:0]};

wire[CLOG2ICACHESETCOUNT -1 : 0] icachenextset = instrfetchnextppninstrfetchnextaddr[CLOG2ICACHESETCOUNT-1:0];
wire[CLOG2ICACHESETCOUNT -1 : 0] icacheset = instrfetchppninstrfetchaddr[CLOG2ICACHESETCOUNT-1:0];

// Bitsize of an icache tag.
localparam ICACHETAGBITSIZE = (ADDRBITSZ - CLOG2ICACHESETCOUNT);

// Net set to the tag value being compared for an instruction cache hit.
wire[ICACHETAGBITSIZE -1 : 0] icachetag = instrfetchppninstrfetchaddr[ADDRBITSZ-1:CLOG2ICACHESETCOUNT];

wire [ICACHETAGBITSIZE -1 : 0] icachetago [ICACHEWAYCOUNT -1 : 0];

wire [ICACHEWAYCOUNT -1 : 0] icachevalido;

// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg [CLOG2ICACHEWAYCOUNT -1 : 0] icachewayhitidx;
reg icachehit_;
integer gen_icachehit_idx;
always @* begin
	icachehit_ = 0;
	icachewayhitidx = 0;
	for (gen_icachehit_idx = 0; gen_icachehit_idx < ICACHEWAYCOUNT; gen_icachehit_idx = gen_icachehit_idx + 1) begin
		if (!icachehit_ && (icachevalido[gen_icachehit_idx] && (icachetag == icachetago[gen_icachehit_idx]))) begin
			icachehit_ = 1;
			icachewayhitidx = gen_icachehit_idx;
		end
	end
end

// Net set to 1, when a hit is found in the cache.
wire icachehit = ((
	`ifdef PUMMU
	itlben ? itlbcached[itlbwayhitidx] :
	`endif
		!ioutofrange) && icacheactive && icachehit_);

wire icachewe = (!doicacherst && icacheactive && instrfetchmemrqstdone && !instrbufrst);

wire icacheoff = !icacheactive;

// Register used as counter during the instruction cache reset.
reg [CLOG2ICACHESETCOUNT -1 : 0] icacherstidx;

wire [ARCHBITSZ -1 : 0] icachedato_ [ICACHEWAYCOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0] icachedato = icachedato_[icachewayhitidx];

reg [CLOG2ICACHESETCOUNT -1 : 0] icachewecnt;
// Register used to hold icache-way index to write next.
reg [CLOG2ICACHEWAYCOUNT -1 : 0] icachewaywriteidx;
always @ (posedge clk_i) begin
	if (rst_i) begin
		icachewaywriteidx <= 0;
		icachewecnt <= 0;
	end else if (icachewe) begin
		icachewecnt <= icachewecnt + 1'b1;
	end else if ((icachewecnt >= (ICACHESETCOUNT-1)) || (instrbufrst && icachewecnt)) begin
		if (icachewaywriteidx >= (ICACHEWAYCOUNT-1))
			icachewaywriteidx <= 0;
		else
			icachewaywriteidx <= icachewaywriteidx + 1'b1;
		icachewecnt <= 0;
	end
end

genvar gen_icache_idx;
generate for (gen_icache_idx = 0; gen_icache_idx < ICACHEWAYCOUNT; gen_icache_idx = gen_icache_idx + 1) begin :gen_icache

bram #(

	 .SZ (ICACHESETCOUNT)
	,.DW (ICACHETAGBITSIZE)

) icachetags (

	 .clk0_i  (clk_i)                          ,.clk1_i  (clk_i)
	,.en0_i   (!icachecheck || instrbufrst) ,.en1_i   (1'b1)
	                                           ,.we1_i   (icachewe && (icachewaywriteidx == gen_icache_idx))
	,.addr0_i (icachenextset)                  ,.addr1_i (icacheset)
	                                           ,.i1      (icachetag)
	,.o0      (icachetago[gen_icache_idx])     ,.o1      ()
);

bram #(

	 .SZ (ICACHESETCOUNT)
	,.DW (ARCHBITSZ)

) icachedatas (

	 .clk0_i  (clk_i)                          ,.clk1_i  (clk_i)
	,.en0_i   (!icachecheck || instrbufrst) ,.en1_i   (1'b1)
	                                           ,.we1_i   (icachewe && (icachewaywriteidx == gen_icache_idx))
	,.addr0_i (icachenextset)                  ,.addr1_i (icacheset)
	                                           ,.i1      (pi1_data_i)
	,.o0      (icachedato_[gen_icache_idx])    ,.o1      ()
);

bram #(

	 .SZ (ICACHESETCOUNT)
	,.DW (1)

) icachevalids (

	 .clk0_i  (clk_i)                          ,.clk1_i  (clk_i)
	,.en0_i   (!icachecheck || instrbufrst) ,.en1_i   (1'b1)
	                                           ,.we1_i   ((icachewe && (icachewaywriteidx == gen_icache_idx)) || icacheoff)
	,.addr0_i (icachenextset)                  ,.addr1_i (icacheoff ? icacherstidx : icacheset)
	                                           ,.i1      (icacheactive)
	,.o0      (icachevalido[gen_icache_idx])   ,.o1      ()
);

end endgenerate

assign instrbufwe = ((instrfetchmemrqstdone || (icachecheck && icachehit)) && !instrbufrst);

assign instrbufi = (instrfetchmemrqstdone ? pi1_data_i : icachedato);

// ---------- Nets used by opali8 ----------

wire[ARCHBITSZ -1 : 0] opli8result = {{(ARCHBITSZ-8){instrbufdato0[3]}}, instrbufdato0[3:0], instrbufdato1[3:0]} +
	(isopinc8 ? gprdata1 : (isoprli8 ? {ipnxt, 1'b0} : {ARCHBITSZ{1'b0}}));

wire opli8done = (miscrdyandsequencerreadyandgprrdy1 && (isopli8 || isopinc8 || isoprli8));

// ---------- Registers and nets used by opli ----------

// Register which is 1 for a load immediate increment.
reg wasopinc;

// Register which is 1 for a relative load immediate.
reg wasoprli;

// Register used to save the value of gprdata1 when opli is sequenced.
reg[ARCHBITSZ -1 : 0] opligprdata1;

// Register used to store the type of opli.
reg[2 -1 : 0] oplitype;

// Register used to store the least significant bits of the immediate being loaded.
reg[(ARCHBITSZMAX -16) -1 : 0] oplilsb;

// Net that get set to the immediate loaded.
wire[ARCHBITSZMAX -1 : 0] opliresult = (
	(ARCHBITSZ == 16) ? ({instrbufdato1, instrbufdato0}) :
	(ARCHBITSZ == 32) ? ((oplitype == 1) ? {{(ARCHBITSZ-16){instrbufdato1[7]}}, instrbufdato1, instrbufdato0} :
			{instrbufdato1, instrbufdato0, oplilsb[((16*(0+1))-1):(16*(0))]}) :
		((oplitype == 1) ? {{(ARCHBITSZ-16){instrbufdato1[7]}}, instrbufdato1, instrbufdato0} :
		 (oplitype == 2) ? {{(ARCHBITSZ-32){instrbufdato1[7]}}, instrbufdato1, instrbufdato0,
					oplilsb[((16*(0+1))-1):(16*(0))]} :
				{instrbufdato1, instrbufdato0,
					oplilsb[((16*(0+1))-1):(16*(0))], oplilsb[((16*(1+1))-1):(16*(1))],
						oplilsb[((16*(2+1))-1):(16*(2))]})) +
	(wasopinc ? opligprdata1 : (wasoprli ? {ipnxt, 1'b0} : {ARCHBITSZ{1'b0}}));

// Register that will hold the id of the GPR to which
// the result will be stored.
// Since opli will always complete within the same context,
// there is no need to use GPRCNTTOTAL to differentiate between
// the context GPRs to which the result will be stored.
reg[CLOG2GPRCNTPERCTX -1 : 0] opligpr;

// ---------- Nets used by opalu ----------

// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg[ARCHBITSZ -1 : 0] opalu0result;

wire opalu0done = (miscrdyandsequencerreadyandgprrdy12 && isopalu0);

// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg[ARCHBITSZ -1 : 0] opalu1result;

wire opalu1done = (miscrdyandsequencerreadyandgprrdy12 && isopalu1);

// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg[ARCHBITSZ -1 : 0] opalu2result;

wire opalu2done = (miscrdyandsequencerreadyandgprrdy12 && isopalu2);

// ---------- Registers and nets used by opmuldiv ----------

// Significance of each bit in the field within opmuldiv_data_w
// storing the type of multiplication or division to perform.
// [3]: 0/1 mean integer/floating-point computation.
// [2]: 0/1 mean multiplication/division or fadd/fsub depending on [1].
// [1]: When doing integer multiplication/division,
// 	0/1 mean unsigned/signed computation.
// 	When doing floating-point computation,
// 	0/1 mean fmul/fdiv when [2] is 0,
// 	and mean fadd/fsub when [2] is 1.
// [0]: When doing multiplication, 0/1 mean ARCHBITSZ lsb/msb of result.
// 	When doing division, 0/1 mean quotient/remainder of result.
// 	Ignored when doing floating-point multiplication/division.
localparam MULDIVTYPEBITSZ = 4;

wire opmuldiv_rdy_w;

wire opmuldiv_stb_w = (miscrdyandsequencerreadyandgprrdy12 && ((isopmuldiv
	`ifdef PUDSPMUL
	&& instrbufdato0[2]
	`endif
	) /*|| isopfloat*/) && opmuldiv_rdy_w);

wire [(((ARCHBITSZ*2)+CLOG2GPRCNTTOTAL)+MULDIVTYPEBITSZ) -1 : 0] opmuldiv_data_w =
	//isopfloat ? // TODO: Fix value to add when isopfloat is true ...
	//	{1'b1, instrbufdato0[0], {2{1'b0}}, gpridx1, gprdata1, gprdata2} :
		{1'b0, instrbufdato0[2:0], gpridx1, gprdata1, gprdata2};

wire [ARCHBITSZ -1 : 0]        opmuldivresult;
wire [CLOG2GPRCNTTOTAL -1 : 0] opmuldivgpr;
wire                           opmuldivdone;

localparam OPMULDIVCNT = ((MULDIVCNT != 4 && MULDIVCNT != 8) ? 4 : MULDIVCNT); // ((GPRCNTPERCTX/4) || (GPRCNTPERCTX/2)).

opmuldiv #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.GPRCNT    (GPRCNTTOTAL)
	,.DEPTH     (OPMULDIVCNT)

) opmuldiv (

	 .rst_i (rst_i)

	,.clk_i        (clk_i)
	,.clk_muldiv_i (clk_muldiv_i)

	,.stb_i  (opmuldiv_stb_w)
	,.data_i (opmuldiv_data_w)
	,.rdy_o  (opmuldiv_rdy_w)

	,.ostb_i  (gprctrlstate == GPRCTRLSTATEOPMULDIV)
	,.data_o  (opmuldivresult)
	,.gprid_o (opmuldivgpr)
	,.ordy_o  (opmuldivdone)
);

`ifdef PUDSPMUL
wire [(ARCHBITSZ*2) -1 : 0] opdspmulresult_unsigned = (gprdata1 * gprdata2);
wire [(ARCHBITSZ*2) -1 : 0] opdspmulresult_signed   = ($signed(gprdata1) * $signed(gprdata2));

// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg [ARCHBITSZ -1 : 0] opdspmulresult;

wire opdspmuldone = (miscrdyandsequencerreadyandgprrdy12 && isopmuldiv && !instrbufdato0[2]);
`endif

// ---------- Nets used by opjl ----------

wire opjldone = (miscrdyandsequencerreadyandgprrdy12 && isopj && isoptype2);

// ---------- Nets used by opgetsysreg ----------

// ### Nets declared as reg so as to be useable by verilog within the always block.
reg[ARCHBITSZ -1 : 0] opgetsysregresult;

wire opgetsysregdone = (miscrdyandsequencerreadyandgprrdy1 && isopgetsysreg && (
	inkernelmode ||
	((isoptype4 || isoptype5) && isflaggetclkcyclecnt) ||
	(isoptype6 && isflaggettlbsize) ||
	(isoptype7 && isflaggetcachesize)));

// ---------- Registers and nets used by opgetsysreg1 ----------

// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg[ARCHBITSZ -1 : 0] opgetsysreg1result;

`ifdef PUMMU
`ifdef PUHPTW
wire opgettlbfault__hptwddone = (!dtlben || !hptwpgd || (hptwddone && !dtlbwritten));
`endif
`endif

wire opgettlbrdy_ = dtlb_rdy;
//wire opgettlbrdy = (isopgettlb && opgettlbrdy_);

wire opgetsysreg1done = (miscrdyandsequencerreadyandgprrdy1 && isopgetsysreg1 &&
	(!(isoptype3/*isopgettlb*/) ||
		(gprrdy2 && (!(itlbreadenable_ || dtlbreadenable_
		`ifdef PUMMU
		`ifdef PUHPTW
		|| hptwitlbwe // There is no need to check hptwdtlbwe as istlbop will be false.
		`endif
		`endif
		) && (opgettlbrdy_
			`ifdef PUMMU
			`ifdef PUHPTW
			&& opgettlbfault__hptwddone
			`endif
			`endif
	)))) && (inkernelmode ||
	(isoptype0 && isflaggetcoreid) ||
	((isoptype1 || isoptype4 || isoptype5) && isflaggetclkfreq) ||
	(isoptype2 && isflaggetcachesize) ||
	(isoptype3 && isflaggettlb)));

wire isopgettlb_or_isopclrtlb_found = (miscrdyandsequencerreadyandgprrdy12 && (
	(isopgettlb && (inkernelmode || isflaggettlb)) || (isopclrtlb && (inkernelmode || isflagclrtlb))));
reg isopgettlb_or_isopclrtlb_found_sampled;
assign isopgettlb_or_isopclrtlb_found_posedge = (!isopgettlb_or_isopclrtlb_found_sampled && isopgettlb_or_isopclrtlb_found);

// ---------- Nets used by opsetgpr ----------

wire[CLOG2GPRCNTTOTAL -1 : 0] opsetgprdstidx = {instrbufdato0[1], instrbufdato1[7:4]};
wire[CLOG2GPRCNTTOTAL -1 : 0] opsetgprsrcidx = {instrbufdato0[0], instrbufdato1[3:0]};

wire[ARCHBITSZ -1 : 0] opsetgprresult;

// These nets will respectively hold the busy state of the first
// and second gpr operand to be used with opsetgpr.
wire opsetgprrdy1;
wire opsetgprrdy2;

wire opsetgprdone = (miscrdy && sequencerready && opsetgprrdy1 && opsetgprrdy2 && isopsetgpr && inkernelmode);

// ---------- General purpose registers ----------

ram1i5o #(

	 .SZ (GPRCNTTOTAL)
	,.DW (ARCHBITSZ)

) gpr (

	  .rst_i (rst_i)

	,.clk0_i (clk_i)
	,.clk1_i (clk_i)
	,.clk2_i (clk_i)
	,.clk3_i (clk_i)
	,.clk4_i (clk_i)

	,.we4_i (gprwe)

	,.addr0_i (
		`ifdef PUDBG
		{inusermode, dbg_rx_data_i[3:0]}
		`else
		0
		`endif
		)
	,.addr1_i (gpridx1)
	,.addr2_i (gpridx2)
	,.addr3_i (opsetgprsrcidx)
	,.addr4_i (gpridx)

	,.i4 (gprdata)

	,.o0 (dbggprdata)
	,.o1 (gprdata1)
	,.o2 (gprdata2)
	,.o3 (opsetgprresult)
	,.o4 ()
);

ram1i5o #(

	 .SZ (GPRCNTTOTAL)
	,.DW (1)

) gprrdy (

	  .rst_i (rst_i)

	,.clk0_i (clk_i)
	,.clk1_i (clk_i)
	,.clk2_i (clk_i)
	,.clk3_i (clk_i)
	,.clk4_i (clk_i)

	,.we4_i (gprrdywe)

	,.addr0_i (opsetgprdstidx)
	,.addr1_i (gpridx1)
	,.addr2_i (gpridx2)
	,.addr3_i (opsetgprsrcidx)
	,.addr4_i (gprrdyidx)

	,.i4 (gprrdyval)

	,.o0 (opsetgprrdy1)
	,.o1 (gprrdy1)
	,.o2 (gprrdy2)
	,.o3 (opsetgprrdy2)
	,.o4 ()
);

// ---------- Registers and nets used by opld ----------

// Register that will hold the id of the gpr to which the result will be stored.
reg[CLOG2GPRCNTTOTAL -1 : 0] opldgpr;

reg[ARCHBITSZMAX -1 : 0] opldresult;

reg[(ARCHBITSZMAX/8) -1 : 0] opldbyteselect;

`ifdef PUMMU
wire opldfault_ = (dtlben && (dtlbnotreadable[dtlbwayhitidx] || dtlbmiss));
wire opldfault = ((inusermode && alignfault) || opldfault_);
`ifdef PUHPTW
wire opldfault__hptwddone = (!opldfault_ || !hptwpgd || (hptwddone && !dtlbwritten));
`endif
`else
wire opldfault = 0;
`endif

reg oplddone;

// Register set to 1 for a mem request.
reg opldmemrqst;

wire opldrdy_ = (!(opldmemrqst || oplddone) && dtlb_rdy && (dcachemasterrdy || opldfault));
wire opldrdy = (isopld && (
	opldrdy_
		`ifdef PUMMU
		`ifdef PUHPTW
		&& opldfault__hptwddone
		`endif
		`endif
	) && !opldfault);

// ---------- Registers and nets used by opst ----------

`ifdef PUMMU
wire opstfault_ = (dtlben && (dtlbnotwritable[dtlbwayhitidx] || dtlbmiss));
wire opstfault = ((inusermode && alignfault) || opstfault_);
`ifdef PUHPTW
wire opstfault__hptwddone = (!opstfault_ || !hptwpgd || (hptwddone && !dtlbwritten));
`endif
`else
wire opstfault = 0;
`endif

wire opstrdy_ = (dtlb_rdy && (dcachemasterrdy || opstfault));
wire opstrdy = (isopst && (
	opstrdy_
		`ifdef PUMMU
		`ifdef PUHPTW
		&& opstfault__hptwddone
		`endif
		`endif
	) && !opstfault);

// ---------- Registers and nets used by opldst ----------

// Register that will hold the id of the gpr to which the result will be stored.
reg[CLOG2GPRCNTTOTAL -1 : 0] opldstgpr;

reg[ARCHBITSZ -1 : 0] opldstresult;

reg[(ARCHBITSZ/8) -1 : 0] opldstbyteselect;

`ifdef PUMMU
wire opldstfault_ = (dtlben && (dtlbnotreadable[dtlbwayhitidx] || dtlbnotwritable[dtlbwayhitidx] || dtlbmiss));
wire opldstfault = ((inusermode && alignfault) || opldstfault_);
`ifdef PUHPTW
wire opldstfault__hptwddone = (!opldstfault_ || !hptwpgd || (hptwddone && !dtlbwritten));
`endif
`else
wire opldstfault = 0;
`endif

reg opldstdone;

// Register set to 1 for a mem request.
reg opldstmemrqst;

wire opldstrdy_ = (!(opldstmemrqst || opldstdone) && dtlb_rdy && (dcachemasterrdy || opldstfault));
wire opldstrdy = (isopldst && (
	opldstrdy_
		`ifdef PUMMU
		`ifdef PUHPTW
		&& opldstfault__hptwddone
		`endif
		`endif
	) && !opldstfault && !instrbufdato0[2]);

// ---------- Registers and nets used for data caching ----------

`ifdef PUDCACHE

pi1_dcache #(

	 .ARCHBITSZ     (ARCHBITSZ)
	,.CACHESETCOUNT (DCACHESETCOUNT)
	,.CACHEWAYCOUNT (DCACHEWAYCOUNT)

) dcache (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.crst_i (rst_i || (miscrdy && sequencerready && isopdcacherst))

	,.cenable_i (
		`ifdef PUMMU
		`ifdef PUHPTW
		(hptwmemstate == HPTWMEMSTATENONE) &&
		`endif
		`endif
		(dtlben ? dtlbcached[dtlbwayhitidx] : !doutofrange))

	,.cmiss_i (miscrdyandsequencerreadyandgprrdy12 && isopvloadorstore /* volatile load/store */)

	,.conly_i (1'b0)

	,.m_pi1_op_i   (dcachemasterop)
	,.m_pi1_addr_i (dcachemasteraddr)
	,.m_pi1_data_i (dcachemasterdati)
	,.m_pi1_data_o (dcachemasterdato)
	,.m_pi1_sel_i  (dcachemastersel)
	,.m_pi1_rdy_o  (dcachemasterrdy)

	,.s_pi1_op_o   (dcacheslaveop)
	,.s_pi1_addr_o (dcacheslaveaddr)
	,.s_pi1_data_o (dcacheslavedato)
	,.s_pi1_data_i (pi1_data_i)
	,.s_pi1_sel_o  (dcacheslavesel)
	,.s_pi1_rdy_i  (pi1_rdy_i)
);

`else

assign dcachemasterrdy = pi1_rdy_i;
assign dcachemasterdato = pi1_data_i;

assign dcacheslaveop = dcachemasterop;
assign dcacheslaveaddr = dcachemasteraddr;
assign dcacheslavedato = dcachemasterdati;
assign dcacheslavesel = dcachemastersel;

`endif

// --------------------------------------------------

// Net which is 1 for a 2-inputs 1-output multicycle instruction that is about to be sequenced.
wire multicycleoprdy = (miscrdyandsequencerreadyandgprrdy12 &&
	(opldrdy || opldstrdy || (((isopmuldiv
		`ifdef PUDSPMUL
		&& instrbufdato0[2]
		`endif
		) /*|| isopfloat*/) && opmuldiv_rdy_w)));
