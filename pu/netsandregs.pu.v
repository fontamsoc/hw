// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

reg inusermode;
wire inkernelmode = ~inusermode;

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

wire[(ARCHBITSZ-1) -1 : 0] ipplusone = (ip + 1'b1);

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

reg dohalt;

reg[ARCHBITSZ -1 : 0] timer;
wire timertriggered = !(|timer);

reg[(ARCHBITSZ*2) -1 : 0] clkcyclecnt;

reg[ARCHBITSZ -1 : 0] instrbuffer[INSTRBUFFERSIZE -1 : 0];

reg[(CLOG2INSTRBUFFERSIZE +1) -1 : 0] instrbufferwriteindex;

wire[(CLOG2INSTRBUFFERSIZE +1) -1 : 0] instrbufferusage =
	(instrbufferwriteindex - ip[CLOG2INSTRBUFFERSIZE +1 : 1]);

wire[ARCHBITSZMAX -1 : 0] instrbufferip = instrbuffer[ip[CLOG2INSTRBUFFERSIZE : 1]];
wire[16 -1 : 0] instrbufferdataout =
	(ARCHBITSZ == 16) ? instrbufferip :
	(ARCHBITSZ == 32) ? (ip[CLOG2ARCHBITSZBY16 -1 : 0] ? instrbufferip[31:16] : instrbufferip[15:0]) : (
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 0 ? instrbufferip[15:0] :
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 1 ? instrbufferip[31:16] :
			ip[CLOG2ARCHBITSZBY16 -1 : 0] == 2 ? instrbufferip[47:32] :
							instrbufferip[63:48]);

wire[8 -1 : 0] instrbufferdataout0 = instrbufferdataout[7:0];
wire[8 -1 : 0] instrbufferdataout1 = instrbufferdataout[15:8];

wire instrbuffernotempty = |instrbufferusage;
reg instrbuffernotempty_sampled;
wire instrbuffernotempty_posedge = (!instrbuffernotempty_sampled && instrbuffernotempty);

wire instrbuffernotfull = (instrbufferusage < INSTRBUFFERSIZE);

reg instrbufferrst_a;
reg instrbufferrst_b;
wire instrbufferrst = (instrbufferrst_a ^ instrbufferrst_b);
reg instrbufferrst_sampled;
wire instrbufferrst_posedge = (!instrbufferrst_sampled && instrbufferrst);

wire itlben;
wire not_itlben_or_not_instrbufferrst_posedge = (
	!itlben || !instrbufferrst_posedge);

reg[ADDRBITSZ -1 : 0] instrfetchaddr;

wire[ADDRBITSZ -1 : 0] instrfetchnextaddr = instrbufferrst ? ip[ADDRBITSZ:1] : (instrfetchaddr+1);

reg[PAGENUMBITSZ -1 : 0] instrfetchppn;

reg instrfetchfaulted_a;
reg instrfetchfaulted_b;
wire instrfetchfaulted = (instrfetchfaulted_a ^ instrfetchfaulted_b);

reg[ARCHBITSZ -1 : 0] instrfetchfaultaddr;

reg instrfetchmemrqst;

reg instrfetchmemrqstinprogress;

wire instrfetchmemrqstdone = (instrfetchmemrqstinprogress && pi1_rdy_i && !instrbufferrst);

wire instrfetchmemaccesspending = (instrfetchmemrqst && !instrfetchmemrqstinprogress && !instrbufferrst);

reg[3 -1 : 0] oplicounter;

wire oplicountereq1 = (oplicounter == 1);

reg[3 -1 : 0] oplioffset;

wire miscrdy = !oplicounter;

wire[ARCHBITSZ -1 : 0] gprdata1;
wire[ARCHBITSZ -1 : 0] gprdata2;

reg[2 -1 : 0] dcachemasterop;
reg[ADDRBITSZ -1 : 0] dcachemasteraddr;
wire[ARCHBITSZMAX -1 : 0] dcachemasterdato;
reg[ARCHBITSZMAX -1 : 0] dcachemasterdati;
reg[(ARCHBITSZMAX/8) -1 : 0] dcachemastersel;
wire dcachemasterrdy;

wire[2 -1 : 0] dcacheslaveop;
wire[ADDRBITSZ -1 : 0] dcacheslaveaddr;
wire[ARCHBITSZ -1 : 0] dcacheslavedato;
wire[(ARCHBITSZ/8) -1 : 0] dcacheslavesel;

`ifdef PUMMU

wire inuserspace;

wire isopgettlb;
wire isopld;
wire isopst;
wire isopldst;

`ifdef PUHPTW

reg[ARCHBITSZ -1 : 0] hptwpgd;

localparam HPTWSTATEPGD0 = 0;
localparam HPTWSTATEPGD1 = 1;
localparam HPTWSTATEPTE0 = 2;
localparam HPTWSTATEPTE1 = 3;
localparam HPTWSTATEDONE = 4;

reg[3 -1 : 0] hptwistate;
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

reg[3 -1 : 0] hptwdstate;
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

reg[2 -1 : 0] hptwmemstate;

`endif
`endif

wire[CLOG2GPRCNTTOTAL -1 : 0] gprindex1 = {inusermode, instrbufferdataout1[7:4]};
wire[CLOG2GPRCNTTOTAL -1 : 0] gprindex2 = {inusermode, instrbufferdataout1[3:0]};

wire gprrdy1;
wire gprrdy2;

reg[CLOG2GPRCNTTOTAL -1 : 0] gprrdyrstidx;
reg gprrdyon;
wire gprrdyoff = !gprrdyon;

localparam GPRCTRLSTATEDONE     = 0;
localparam GPRCTRLSTATEOPLD     = 1;
localparam GPRCTRLSTATEOPLDST   = 2;
localparam GPRCTRLSTATEOPMULDIV = 3;
reg[2 -1 : 0] gprctrlstate;
reg[CLOG2GPRCNTTOTAL -1 : 0] gprindex;
reg[ARCHBITSZ -1 : 0] gprdata;
reg gprwriteenable;
reg[CLOG2GPRCNTTOTAL -1 : 0] gprrdyindex;
reg gprrdyval;
reg gprrdywriteenable;

reg[ARCHBITSZ -1 : 0] gpr13val;

`ifdef SIMULATION
reg [ARCHBITSZ -1 : 0] sequencerstate;
`endif

wire isflagdisextintr;
wire isflagdistimerintr;

wire sequencerready_ = !(
	rst_i || gprrdyoff || instrbufferrst ||
	(timertriggered && !isflagdistimerintr && inusermode && !oplicounter
	`ifdef PUMMU
	`ifdef PUHPTW
	&& !hptwbsy
	`endif
	`endif
	) ||
	(intrqst_i && !isflagdisextintr && inusermode && !oplicounter
	`ifdef PUMMU
	`ifdef PUHPTW
	&& !hptwbsy
	`endif
	`endif
	) ||
	inhalt);
wire sequencerready = sequencerready_ && instrbuffernotempty;

wire sequencerreadyandgprrdy1 = sequencerready && gprrdy1;
wire sequencerreadyandgprrdy12 = sequencerreadyandgprrdy1 && gprrdy2;

wire miscrdyandsequencerreadyandgprrdy1 = (miscrdy && sequencerreadyandgprrdy1);
wire miscrdyandsequencerreadyandgprrdy12 = (miscrdy && sequencerreadyandgprrdy12);

wire isoptype0 = (instrbufferdataout0[2:0] == 0);
wire isoptype1 = (instrbufferdataout0[2:0] == 1);
wire isoptype2 = (instrbufferdataout0[2:0] == 2);
wire isoptype3 = (instrbufferdataout0[2:0] == 3);
wire isoptype4 = (instrbufferdataout0[2:0] == 4);
wire isoptype5 = (instrbufferdataout0[2:0] == 5);
wire isoptype6 = (instrbufferdataout0[2:0] == 6);
wire isoptype7 = (instrbufferdataout0[2:0] == 7);

wire isopli8 = (instrbufferdataout0[7:4] == OPLI8A[4:1]);
wire isopinc8 = (instrbufferdataout0[7:4] == OPINC8A[4:1]);
wire isoprli8 = (instrbufferdataout0[7:4] == OPRLI8A[4:1]);
wire isopinc = (instrbufferdataout0[7:3] == OPINC);
wire isopimm = (instrbufferdataout0[7:3] == OPIMM);
wire isoprli = (isopimm && instrbufferdataout0[2]);
wire isopalu0 = (instrbufferdataout0[7:3] == OPALU0);
wire isopfloat = (instrbufferdataout0[7:3] == OPFLOAT);
wire isopalu1 = (instrbufferdataout0[7:3] == OPALU1);
wire isopalu2 = (instrbufferdataout0[7:3] == OPALU2);
wire isopj = (instrbufferdataout0[7:3] == OPJ);
wire isopswitchctx = (instrbufferdataout0[7:3] == OPSWITCHCTX);
wire isopsysret = (isopswitchctx && isoptype0);
wire isophalt = (isopswitchctx && isoptype3);
wire isopicacherst = (isopswitchctx && isoptype4);
wire isopdcacherst = (isopswitchctx && isoptype5);
wire isopcacherst = (isopicacherst || isopdcacherst);
wire isopksysret = (isopswitchctx && isoptype7);
wire isopgetsysreg = (instrbufferdataout0[7:3] == OPGETSYSREG);
wire isopgetsysopcode = (isopgetsysreg && isoptype0);
wire isopgetuip = (isopgetsysreg && isoptype1);
wire isopgetfaultaddr = (isopgetsysreg && isoptype2);
wire isopgetfaultreason = (isopgetsysreg && isoptype3);
wire isopgetclkcyclecnt = (isopgetsysreg && isoptype4);
wire isopgetclkcyclecnth = (isopgetsysreg && isoptype5);
wire isopgettlbsize = (isopgetsysreg && isoptype6);
wire isopgeticachesize = (isopgetsysreg && isoptype7);
wire isopgetsysreg1 = (instrbufferdataout0[7:3] == OPGETSYSREG1);
wire isopgetcoreid = (isopgetsysreg1 && isoptype0);
wire isopgetclkfreq = (isopgetsysreg1 && isoptype1);
wire isopgetdcachesize = (isopgetsysreg1 && isoptype2);
wire isopgetcachesize = (isopgeticachesize || isopgetdcachesize);
assign isopgettlb = (isopgetsysreg1 && isoptype3);
wire isopgetcap = (isopgetsysreg1 && isoptype4);
wire isopgetver = (isopgetsysreg1 && isoptype5);
wire isopsetsysreg = (instrbufferdataout0[7:3] == OPSETSYSREG);
wire isopsetksysopfaulthdlr = (isopsetsysreg && isoptype0);
wire isopsetksl = (isopsetsysreg && isoptype1);
wire isopsettlb = (isopsetsysreg && isoptype2);
wire isopclrtlb = (isopsetsysreg && isoptype3);
wire isopsetasid = (isopsetsysreg && isoptype4);
wire isopsetuip = (isopsetsysreg && isoptype5);
wire isopsetflags = (isopsetsysreg && isoptype6);
wire isopsettimer = (isopsetsysreg && isoptype7);
wire isopsetgpr = (instrbufferdataout0[7:3] == OPSETGPR);
wire isoploadorstore = (instrbufferdataout0[7:3] == OPLOADORSTORE);
wire isopvloadorstore = (instrbufferdataout0[7:3] == OPVLOADORSTORE);
assign isopld = ((isoploadorstore || isopvloadorstore) && instrbufferdataout0[2]);
assign isopst = ((isoploadorstore || isopvloadorstore) && !instrbufferdataout0[2]);
assign isopldst = (instrbufferdataout0[7:3] == OPLDST);
wire isopmuldiv = (instrbufferdataout0[7:3] == OPMULDIV);

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

wire istlbop = (isopsettlb || isopclrtlb || isopgettlb);
wire tlbbsy = (miscrdyandsequencerreadyandgprrdy12 && istlbop);

`ifdef PUMMU

reg[(1+12) -1 : 0] asid;

localparam CLOG2TLBSETCOUNT = clog2(TLBSETCOUNT);
localparam PAGENUMBITSZMINUSCLOG2TLBSETCOUNT = (PAGENUMBITSZ -CLOG2TLBSETCOUNT);
localparam TLBENTRYBITSZ = (12 +5 +PAGENUMBITSZ +PAGENUMBITSZMINUSCLOG2TLBSETCOUNT);

reg[ARCHBITSZ -1 : 0] ksl;

assign inuserspace = asid[12];

localparam KERNELSPACESTART = 'h1000;

wire[CLOG2TLBSETCOUNT -1 : 0] dtlbset = gprdata2[(CLOG2TLBSETCOUNT +12) -1 : 12];
wire[TLBENTRYBITSZ -1 : 0] dtlbentry;
wire[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0] dtlbtag = dtlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0];
wire[PAGENUMBITSZ -1 : 0] dtlbppn = dtlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ -1 : PAGENUMBITSZMINUSCLOG2TLBSETCOUNT];
wire dtlbwritable = dtlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +1];
wire dtlbnotwritable = ~dtlbwritable;
wire dtlbreadable = dtlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +2];
wire dtlbnotreadable = ~dtlbreadable;
wire dtlbcached = dtlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +3];
wire dtlbuser = dtlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +4];
wire dtlbnotuser = ~dtlbuser;
wire[12 -1 : 0] dtlbasid = dtlbentry[(PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +5) +12 -1 : PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +5];
wire[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0] dvpn = gprdata2[ARCHBITSZ -1 : (12 +CLOG2TLBSETCOUNT)];
wire dtlbmiss = ((inuserspace && dtlbnotuser) || (asid[12 -1 : 0] != dtlbasid) || (dvpn != dtlbtag));
wire doutofrange = (gprdata2 < KERNELSPACESTART || gprdata2 >= ksl);
wire dtlben = (!dohalt && inusermode && (inuserspace || doutofrange));
reg dtlbwritten;
reg[CLOG2TLBSETCOUNT -1 : 0] dtlbsetprev;
wire dtlbreadenable_ = (isopgettlb_or_isopclrtlb_found_posedge || dtlbwritten || (dtlben && dtlbset != dtlbsetprev));
wire dtlbreadenable = (dtlbreadenable_ || instrbufferrst);
wire itlbreadenable;
wire itlbreadenable_;
wire dtlbwriteenable = (
	`ifdef PUHPTW
	hptwdtlbwe ||
	`endif
	(miscrdyandsequencerreadyandgprrdy12 &&
	!(itlbreadenable_ || dtlbreadenable_) && (
	(isopsettlb && (inkernelmode || isflagsettlb) && (gprdata1 & 'b110)) ||
	(isopclrtlb && (inkernelmode || isflagclrtlb) && !(({dtlbtag, dtlbset, dtlbasid} ^ gprdata2) & gprdata1)))));

wire[CLOG2TLBSETCOUNT -1 : 0] itlbset = (tlbbsy ? dtlbset :
	instrfetchnextaddr[(CLOG2TLBSETCOUNT +ADDRWITHINPAGEBITSZ) -1 : ADDRWITHINPAGEBITSZ]);
wire[TLBENTRYBITSZ -1 : 0] itlbentry;
wire[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0] itlbtag = itlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0];
wire[PAGENUMBITSZ -1 : 0] itlbppn = itlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ -1 : PAGENUMBITSZMINUSCLOG2TLBSETCOUNT];
wire itlbexecutable = itlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ];
wire itlbnotexecutable = ~itlbexecutable;
wire itlbcached = itlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +3];
wire itlbuser = itlbentry[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +4];
wire itlbnotuser = ~itlbuser;
wire[12 -1 : 0] itlbasid = itlbentry[(PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +5) +12 -1 : PAGENUMBITSZMINUSCLOG2TLBSETCOUNT +PAGENUMBITSZ +5];
wire[PAGENUMBITSZMINUSCLOG2TLBSETCOUNT -1 : 0] ivpn = instrfetchnextaddr[ADDRBITSZ -1 : (ADDRWITHINPAGEBITSZ +CLOG2TLBSETCOUNT)];
wire itlbmiss = ((inuserspace && itlbnotuser) || (asid[12 -1 : 0] != itlbasid) || (ivpn != itlbtag));
wire ioutofrange = (instrfetchnextaddr < (KERNELSPACESTART >> CLOG2ARCHBITSZBY8) || (instrfetchnextaddr >= ksl[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8]));
assign itlben = (!dohalt && inusermode && (inuserspace || ioutofrange));
reg itlbwritten;
reg[CLOG2TLBSETCOUNT -1 : 0] itlbsetprev;
assign itlbreadenable_ = (isopgettlb_or_isopclrtlb_found_posedge || itlbwritten || (itlben && itlbset != itlbsetprev));
assign itlbreadenable = (itlbreadenable_ || instrbufferrst);
wire itlbwriteenable = (
	`ifdef PUHPTW
	hptwitlbwe ||
	`endif
	(miscrdyandsequencerreadyandgprrdy12 &&
	!(itlbreadenable_ || dtlbreadenable_) && (
	(isopsettlb && (inkernelmode || isflagsettlb) && (gprdata1 & 'b1)) ||
	(isopclrtlb && (inkernelmode || isflagclrtlb) && !(({itlbtag, itlbset, itlbasid} ^ gprdata2) & gprdata1)))));

wire[TLBENTRYBITSZ -1 : 0] tlbwritedata = (
	isopsettlb ? {gprdata2[12-1:0], gprdata1[4:0], gprdata1[ARCHBITSZ-1:12], dvpn} :
	`ifdef PUHPTW
	hptwitlbwe ? {asid[12-1:0], dcachemasterdato[4:3], 2'b00, dcachemasterdato[0], dcachemasterdato[ARCHBITSZ-1:12], ivpn} :
	hptwdtlbwe ? {asid[12-1:0], dcachemasterdato[4:1], 1'b0,                       dcachemasterdato[ARCHBITSZ-1:12], dvpn} :
	`endif
	             {TLBENTRYBITSZ{1'b0}});

bram #(

	 .SZ (TLBSETCOUNT)
	,.DW (TLBENTRYBITSZ)

) itlb (

	 .clk0_i  (clk_i)                 ,.clk1_i  (clk_i)
	,.en0_i   (itlbreadenable)        ,.en1_i   (1'b1)
	                                  ,.we1_i   (itlbwriteenable)
	,.addr0_i (itlbset)               ,.addr1_i (itlbset)
	                                  ,.i1      (tlbwritedata)
	,.o0      (itlbentry)             ,.o1      ()
);

bram #(

	 .SZ (TLBSETCOUNT)
	,.DW (TLBENTRYBITSZ)

) dtlb (

	 .clk0_i  (clk_i)                 ,.clk1_i  (clk_i)
	,.en0_i   (dtlbreadenable)        ,.en1_i   (1'b1)
	                                  ,.we1_i   (dtlbwriteenable)
	,.addr0_i (dtlbset)               ,.addr1_i (dtlbset)
	                                  ,.i1      (tlbwritedata)
	,.o0      (dtlbentry)             ,.o1      ()
);

wire itlbgettlbhit = ((gprdata2[12 -1 : 0] == itlbasid) && (gprdata2[(ARCHBITSZ-1) : 12 +CLOG2TLBSETCOUNT] == itlbtag));
wire dtlbgettlbhit = ((gprdata2[12 -1 : 0] == dtlbasid) && (gprdata2[(ARCHBITSZ-1) : 12 +CLOG2TLBSETCOUNT] == dtlbtag));
wire[ARCHBITSZ -1 : 0] gettlbresult = (
	(!(itlbgettlbhit | dtlbgettlbhit)) ? {ARCHBITSZ{1'b0}} :
	(itlbgettlbhit ^ dtlbgettlbhit) ?
		(itlbgettlbhit ?
			{itlbppn, {7{1'b0}}, itlbuser, itlbcached, {2{1'b0}}, itlbexecutable} :
			{dtlbppn, {7{1'b0}}, dtlbuser, dtlbcached, dtlbreadable, dtlbwritable, 1'b0}) :
	(itlbppn == dtlbppn) ?
		{dtlbppn, {7{1'b0}}, (itlbuser|dtlbuser), (itlbcached|dtlbcached), dtlbreadable, dtlbwritable, itlbexecutable} :
		{ARCHBITSZ{1'b0}});

wire[PAGENUMBITSZ -1 : 0] dppn = (dtlben ? dtlbppn : gprdata2[ARCHBITSZ-1:12]);

`else

wire dtlbreadenable = 0;
wire dtlbreadenable = 0;
wire dtlbnotwritable = 0;
wire dtlbnotreadable = 0;
wire dtlbcached = 0;
wire dtlbmiss = 0;
wire dtlben = 0;
wire itlbreadenable = 0;
wire itlbnotexecutable = 0;
wire itlbcached = 0;
wire itlbmiss = 0;
wire[PAGENUMBITSZ -1 : 0] itlbppn = 0;
wire itlben = 0;
wire[PAGENUMBITSZ -1 : 0] dppn = gprdata2[ARCHBITSZ-1:12];

`endif

wire itlb_and_instrbuffer_rdy = (((!(inusermode && tlbbsy) && instrbuffernotfull) || instrbufferrst) && (!itlbreadenable_
	`ifdef PUMMU
	`ifdef PUHPTW
	|| (hptwidone && !itlbwritten)
	`endif
	`endif
	));

wire itlbfault_ = (itlben && (itlbnotexecutable || itlbmiss));
wire itlbfault = itlbfault_;

`ifdef PUMMU
`ifdef PUHPTW
wire itlbfault__hptwidone = (!itlbfault_ || !hptwpgd || (hptwidone && !itlbwritten));
`endif
`endif

wire dtlb_rdy = (!dtlbreadenable &&
	!instrbuffernotempty_posedge);

wire alignfault =
	(ARCHBITSZ == 16) ? (instrbufferdataout0[0] && gprdata2[0]) :
	(ARCHBITSZ == 32) ? ((instrbufferdataout0[1] && gprdata2[1:0]) || (instrbufferdataout0[0] && gprdata2[0])) :
		((&instrbufferdataout0[1:0] && gprdata2[2:0]) || (instrbufferdataout0[1] && gprdata2[1:0]) || (instrbufferdataout0[0] && gprdata2[0]));

reg icacheactive;

reg icachecheck;

wire doicacherst = (rst_i || (miscrdy && sequencerready && isopicacherst));

wire[PAGENUMBITSZ -1 : 0] instrfetchnextppn = itlben ? itlbppn : instrfetchnextaddr[ADDRBITSZ-1:ADDRWITHINPAGEBITSZ];

wire[ADDRBITSZ -1 : 0] instrfetchnextppninstrfetchnextaddr = {instrfetchnextppn, instrfetchnextaddr[ADDRWITHINPAGEBITSZ-1:0]};
wire[ADDRBITSZ -1 : 0] instrfetchppninstrfetchaddr = {instrfetchppn, instrfetchaddr[ADDRWITHINPAGEBITSZ-1:0]};

wire[CLOG2ICACHESETCOUNT -1 : 0] icachenextset = instrfetchnextppninstrfetchnextaddr[CLOG2ICACHESETCOUNT-1:0];
wire[CLOG2ICACHESETCOUNT -1 : 0] icacheset = instrfetchppninstrfetchaddr[CLOG2ICACHESETCOUNT-1:0];

localparam ICACHETAGBITSIZE = (ADDRBITSZ - CLOG2ICACHESETCOUNT);

wire[ICACHETAGBITSIZE -1 : 0] icachetag = instrfetchppninstrfetchaddr[ADDRBITSZ-1:CLOG2ICACHESETCOUNT];

wire [ICACHETAGBITSIZE -1 : 0] icachetago [ICACHEWAYCOUNT -1 : 0];

wire [ICACHEWAYCOUNT -1 : 0] icachevalido;

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

wire icachehit = ((itlben ? itlbcached : !ioutofrange) && icacheactive && icachehit_);

wire icachewe = (!doicacherst && icacheactive && instrfetchmemrqstdone && !instrbufferrst);

wire icacheoff = !icacheactive;

reg [CLOG2ICACHESETCOUNT -1 : 0] icacherstidx;

wire [ARCHBITSZ -1 : 0] icachedato_ [ICACHEWAYCOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0] icachedato = icachedato_[icachewayhitidx];

reg [CLOG2ICACHESETCOUNT -1 : 0] icachewecnt;
reg [CLOG2ICACHEWAYCOUNT -1 : 0] icachewaywriteidx;
always @ (posedge clk_i[0]) begin
	if (rst_i) begin
		icachewaywriteidx <= 0;
		icachewecnt <= 0;
	end else if (icachewe) begin
		icachewecnt <= icachewecnt + 1'b1;
	end else if ((icachewecnt >= (ICACHESETCOUNT-1)) || (instrbufferrst && icachewecnt)) begin
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

	 .clk0_i  (clk_i)                      ,.clk1_i  (clk_i)
	,.en0_i   (1'b1)                       ,.en1_i   (1'b1)
	                                       ,.we1_i   (icachewe && (icachewaywriteidx == gen_icache_idx))
	,.addr0_i (icachenextset)              ,.addr1_i (icacheset)
	                                       ,.i1      (icachetag)
	,.o0      (icachetago[gen_icache_idx]) ,.o1      ()
);

bram #(

	 .SZ (ICACHESETCOUNT)
	,.DW (ARCHBITSZ)

) icachedatas (

	 .clk0_i  (clk_i)                          ,.clk1_i  (clk_i)
	,.en0_i   (1'b1)                           ,.en1_i   (1'b1)
	                                           ,.we1_i   (icachewe && (icachewaywriteidx == gen_icache_idx))
	,.addr0_i (icachenextset)                  ,.addr1_i (icacheset)
	                                           ,.i1      (pi1_data_i)
	,.o0      (icachedato_[gen_icache_idx])    ,.o1      ()
);

bram #(

	 .SZ (ICACHESETCOUNT)
	,.DW (1)

) icachevalids (

	 .clk0_i  (clk_i)                        ,.clk1_i  (clk_i)
	,.en0_i   (1'b1)                         ,.en1_i   (1'b1)
	                                         ,.we1_i   ((icachewe && (icachewaywriteidx == gen_icache_idx)) || icacheoff)
	,.addr0_i (icachenextset)                ,.addr1_i (icacheoff ? icacherstidx : icacheset)
	                                         ,.i1      (icacheactive)
	,.o0      (icachevalido[gen_icache_idx]) ,.o1      ()
);

end endgenerate

wire[ARCHBITSZ -1 : 0] opli8result = {{(ARCHBITSZ-8){instrbufferdataout0[3]}}, instrbufferdataout0[3:0], instrbufferdataout1[3:0]} +
	(isopinc8 ? gprdata1 : (isoprli8 ? {ipplusone, 1'b0} : {ARCHBITSZ{1'b0}}));

wire opli8done = (miscrdyandsequencerreadyandgprrdy1 && (isopli8 || isopinc8 || isoprli8));

reg wasopinc;

reg wasoprli;

reg[ARCHBITSZ -1 : 0] opligprdata1;

reg[2 -1 : 0] oplitype;

reg[(ARCHBITSZMAX -16) -1 : 0] oplilsb;

wire[ARCHBITSZMAX -1 : 0] opliresult = (
	(ARCHBITSZ == 16) ? ({instrbufferdataout1, instrbufferdataout0}) :
	(ARCHBITSZ == 32) ? ((oplitype == 1) ? {{(ARCHBITSZ-16){instrbufferdataout1[7]}}, instrbufferdataout1, instrbufferdataout0} :
			{instrbufferdataout1, instrbufferdataout0, oplilsb[((16*(0+1))-1):(16*(0))]}) :
		((oplitype == 1) ? {{(ARCHBITSZ-16){instrbufferdataout1[7]}}, instrbufferdataout1, instrbufferdataout0} :
		 (oplitype == 2) ? {{(ARCHBITSZ-32){instrbufferdataout1[7]}}, instrbufferdataout1, instrbufferdataout0,
					oplilsb[((16*(0+1))-1):(16*(0))]} :
				{instrbufferdataout1, instrbufferdataout0,
					oplilsb[((16*(0+1))-1):(16*(0))], oplilsb[((16*(1+1))-1):(16*(1))],
						oplilsb[((16*(2+1))-1):(16*(2))]})) +
	(wasopinc ? opligprdata1 : (wasoprli ? {ipplusone, 1'b0} : {ARCHBITSZ{1'b0}}));

reg[CLOG2GPRCNTPERCTX -1 : 0] opligpr;

reg[ARCHBITSZ -1 : 0] opalu0result;

wire opalu0done = (miscrdyandsequencerreadyandgprrdy12 && isopalu0);

reg[ARCHBITSZ -1 : 0] opalu1result;

wire opalu1done = (miscrdyandsequencerreadyandgprrdy12 && isopalu1);

reg[ARCHBITSZ -1 : 0] opalu2result;

wire opalu2done = (miscrdyandsequencerreadyandgprrdy12 && isopalu2);

localparam MULDIVTYPEBITSZ = 4;

wire opmuldiv_rdy_w;

wire opmuldiv_stb_w = (miscrdyandsequencerreadyandgprrdy12 && ((isopmuldiv
	`ifdef PUDSPMUL
	&& instrbufferdataout0[2]
	`endif
	)) && opmuldiv_rdy_w);

wire [(((ARCHBITSZ*2)+CLOG2GPRCNTTOTAL)+MULDIVTYPEBITSZ) -1 : 0] opmuldiv_data_w =
	{1'b0, instrbufferdataout0[2:0], gprindex1, gprdata1, gprdata2};

wire [ARCHBITSZ -1 : 0]        opmuldivresult;
wire [CLOG2GPRCNTTOTAL -1 : 0] opmuldivgpr;
wire                           opmuldivdone;

localparam OPMULDIVCNT = ((MULDIVCNT != 4 && MULDIVCNT != 8) ? 4 : MULDIVCNT);

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

reg [ARCHBITSZ -1 : 0] opdspmulresult;

wire opdspmuldone = (miscrdyandsequencerreadyandgprrdy12 && isopmuldiv && !instrbufferdataout0[2]);
`endif

wire opjldone = (miscrdyandsequencerreadyandgprrdy12 && isopj && isoptype2);

reg[ARCHBITSZ -1 : 0] opgetsysregresult;

wire opgetsysregdone = (miscrdyandsequencerreadyandgprrdy1 && isopgetsysreg && (
	inkernelmode ||
	((isoptype4 || isoptype5) && isflaggetclkcyclecnt) ||
	(isoptype6 && isflaggettlbsize) ||
	(isoptype7 && isflaggetcachesize)));

reg[ARCHBITSZ -1 : 0] opgetsysreg1result;

`ifdef PUMMU
`ifdef PUHPTW
wire opgettlbfault__hptwddone = (!dtlben || !hptwpgd || (hptwddone && !dtlbwritten));
`endif
`endif

wire opgettlbrdy_ = dtlb_rdy;

wire opgetsysreg1done = (miscrdyandsequencerreadyandgprrdy1 && isopgetsysreg1 &&
	(!isoptype3 ||
		(gprrdy2 && (!(itlbreadenable_ || dtlbreadenable_
		`ifdef PUMMU
		`ifdef PUHPTW
		|| hptwitlbwe
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

wire[CLOG2GPRCNTTOTAL -1 : 0] opsetgprdstidx = {instrbufferdataout0[1], instrbufferdataout1[7:4]};
wire[CLOG2GPRCNTTOTAL -1 : 0] opsetgprsrcidx = {instrbufferdataout0[0], instrbufferdataout1[3:0]};

wire[ARCHBITSZ -1 : 0] opsetgprresult;

wire opsetgprrdy1;
wire opsetgprrdy2;

wire opsetgprdone = (miscrdy && sequencerready && opsetgprrdy1 && opsetgprrdy2 && isopsetgpr && inkernelmode);

ram2clk1i5o #(

	 .SZ (GPRCNTTOTAL)
	,.DW (ARCHBITSZ)

) gpr (

	  .rst_i (rst_i)

	,.clk0_i ()
	,.clk1_i (clk_i)
	,.clk2_i (clk_i)
	,.clk3_i (clk_i)
	,.clk4_i (clk_i)

	,.we4_i (gprwriteenable)

	,.addr0_i (0)
	,.addr1_i (gprindex1)
	,.addr2_i (gprindex2)
	,.addr3_i (opsetgprsrcidx)
	,.addr4_i (gprindex)

	,.i4 (gprdata)

	,.o0 ()
	,.o1 (gprdata1)
	,.o2 (gprdata2)
	,.o3 (opsetgprresult)
	,.o4 ()
);

ram2clk1i5o #(

	 .SZ (GPRCNTTOTAL)
	,.DW (1)

) gprrdy (

	  .rst_i (rst_i)

	,.clk0_i (clk_i)
	,.clk1_i (clk_i)
	,.clk2_i (clk_i)
	,.clk3_i (clk_i)
	,.clk4_i (clk_i)

	,.we4_i (gprrdywriteenable)

	,.addr0_i (opsetgprdstidx)
	,.addr1_i (gprindex1)
	,.addr2_i (gprindex2)
	,.addr3_i (opsetgprsrcidx)
	,.addr4_i (gprrdyindex)

	,.i4 (gprrdyval)

	,.o0 (opsetgprrdy1)
	,.o1 (gprrdy1)
	,.o2 (gprrdy2)
	,.o3 (opsetgprrdy2)
	,.o4 ()
);

reg[CLOG2GPRCNTTOTAL -1 : 0] opldgpr;

reg[ARCHBITSZMAX -1 : 0] opldresult;

reg[(ARCHBITSZMAX/8) -1 : 0] opldbyteselect;

wire opldfault_ = (dtlben && (dtlbnotreadable || dtlbmiss));
wire opldfault = ((inusermode && alignfault) || opldfault_);

`ifdef PUMMU
`ifdef PUHPTW
wire opldfault__hptwddone = (!opldfault_ || !hptwpgd || (hptwddone && !dtlbwritten));
`endif
`endif

reg oplddone;

reg opldmemrqst;

wire opldrdy_ = (!(opldmemrqst || oplddone) && dtlb_rdy && (dcachemasterrdy || opldfault));
wire opldrdy = (isopld && opldrdy_ && !opldfault);

wire opstfault_ = (dtlben && (dtlbnotwritable || dtlbmiss));
wire opstfault = ((inusermode && alignfault) || opstfault_);

`ifdef PUMMU
`ifdef PUHPTW
wire opstfault__hptwddone = (!opstfault_ || !hptwpgd || (hptwddone && !dtlbwritten));
`endif
`endif

wire opstrdy_ = (dtlb_rdy && (dcachemasterrdy || opstfault));
wire opstrdy = (isopst && opstrdy_ && !opstfault);

reg[CLOG2GPRCNTTOTAL -1 : 0] opldstgpr;

reg[ARCHBITSZ -1 : 0] opldstresult;

reg[(ARCHBITSZ/8) -1 : 0] opldstbyteselect;

wire opldstfault_ = (dtlben && (dtlbnotreadable || dtlbnotwritable || dtlbmiss));
wire opldstfault = ((inusermode && alignfault) || opldstfault_);

`ifdef PUMMU
`ifdef PUHPTW
wire opldstfault__hptwddone = (!opldstfault_ || !hptwpgd || (hptwddone && !dtlbwritten));
`endif
`endif

reg opldstdone;

reg opldstmemrqst;

wire opldstrdy_ = (!(opldstmemrqst || opldstdone) && dtlb_rdy && (dcachemasterrdy || opldstfault));
wire opldstrdy = (isopldst && opldstrdy_ && !opldstfault && !instrbufferdataout0[2]);

assign dcachemasterrdy = pi1_rdy_i;
assign dcachemasterdato = pi1_data_i;

assign dcacheslaveop = dcachemasterop;
assign dcacheslaveaddr = dcachemasteraddr;
assign dcacheslavedato = dcachemasterdati;
assign dcacheslavesel = dcachemastersel;

wire multicycleoprdy = (miscrdyandsequencerreadyandgprrdy12 &&
	(opldrdy || opldstrdy || (((isopmuldiv
		`ifdef PUDSPMUL
		&& instrbufferdataout0[2]
		`endif
		)) && opmuldiv_rdy_w)));
