// Copyright (c) William Fonkou Tambe
// All rights reserved.

reg inusermode;
wire inkernelmode = ~inusermode;

reg[(ARCHBITSZ-1) -1 : 0] ip;

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

wire[ARCHBITSZ -1 : 0] instrbufferip = instrbuffer[ip[CLOG2INSTRBUFFERSIZE : 1]];
wire[16 -1 : 0] instrbufferdataout =
	(ip[CLOG2ARCHBITSZBY16 -1 : 0] ? instrbufferip[31:16] : instrbufferip[15:0]);

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

reg[(CLOG2ARCHBITSZBY16 + 1) -1 : 0] oplicounter;

wire oplicountereq1 = (oplicounter == 1);

reg[(CLOG2ARCHBITSZBY16 + 1) -1 : 0] oplioffset;

wire miscrdy = !oplicounter;

wire[CLOG2GPRCNTTOTAL -1 : 0] gprindex1 = {inusermode, instrbufferdataout1[7:4]};
wire[CLOG2GPRCNTTOTAL -1 : 0] gprindex2 = {inusermode, instrbufferdataout1[3:0]};

wire[ARCHBITSZ -1 : 0] gprdata1;
wire[ARCHBITSZ -1 : 0] gprdata2;

wire gprrdy1;
wire gprrdy2;

reg[CLOG2GPRCNTTOTAL -1 : 0] gprrdyrstidx;
reg gprrdyon;
wire gprrdyoff = !gprrdyon;

reg[CLOG2GPRCNTTOTAL -1 : 0] gprindex;
reg[ARCHBITSZ -1 : 0] gprdata;
reg gprwriteenable;
reg[CLOG2GPRCNTTOTAL -1 : 0] gprrdyindex;
reg gprrdyval;
reg gprrdywriteenable;

reg[2 -1 : 0] opldfaulted;

reg[2 -1 : 0] opstfaulted;

reg[3 -1 : 0] opldstfaulted;

wire isflagdisextintr;
wire isflagdistimerintr;

wire sequencerready_ = !(
	rst_i || gprrdyoff || instrbufferrst || opldfaulted || opstfaulted || opldstfaulted ||
	(timertriggered && !isflagdistimerintr && inusermode && !oplicounter) ||
	(intrqst_i && !isflagdisextintr && inusermode && !oplicounter) ||
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
wire isopgettlb = (isopgetsysreg1 && isoptype3);
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
wire isopld = (isoploadorstore && instrbufferdataout0[2]);
wire isopst = (isoploadorstore && !instrbufferdataout0[2]);
wire isopldst = (instrbufferdataout0[7:3] == OPLDST);
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

wire inuserspace = asid[12];

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
wire dtlben = (inusermode && (inuserspace || doutofrange));
reg dtlbwritten;
reg[CLOG2TLBSETCOUNT -1 : 0] dtlbsetprev;
wire dtlbreadenable = (isopgettlb_or_isopclrtlb_found_posedge || dtlbwritten || (dtlben && dtlbset != dtlbsetprev) || instrbufferrst);
wire itlbreadenable;
wire dtlbwriteenable = (miscrdyandsequencerreadyandgprrdy12 &&
	!(itlbreadenable || dtlbreadenable) && (
	(isopsettlb && (inkernelmode || isflagsettlb) && (gprdata1 & 'b110)) ||
	(isopclrtlb && (inkernelmode || isflagclrtlb) && !(({dtlbtag, dtlbset, dtlbasid} ^ gprdata2) & gprdata1))));

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
assign itlben = (inusermode && (inuserspace || ioutofrange));
reg itlbwritten;
reg[CLOG2TLBSETCOUNT -1 : 0] itlbsetprev;
assign itlbreadenable = (isopgettlb_or_isopclrtlb_found_posedge || itlbwritten || (itlben && itlbset != itlbsetprev) || instrbufferrst);
wire itlbwriteenable = (miscrdyandsequencerreadyandgprrdy12 &&
	!(itlbreadenable || dtlbreadenable) && (
	(isopsettlb && (inkernelmode || isflagsettlb) && (gprdata1 & 'b1)) ||
	(isopclrtlb && (inkernelmode || isflagclrtlb) && !(({itlbtag, itlbset, itlbasid} ^ gprdata2) & gprdata1))));

wire[TLBENTRYBITSZ -1 : 0] tlbwritedata = (isopsettlb ?
	{gprdata2[12-1:0], gprdata1[4:0], gprdata1[ARCHBITSZ-1:12], dvpn} :
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

wire itlb_and_instrbuffer_rdy = ((!(inusermode && tlbbsy) && !itlbreadenable && instrbuffernotfull) || instrbufferrst);

wire itlbfault = (itlben && (itlbnotexecutable || itlbmiss));

wire alignfault = ((instrbufferdataout0[1] && gprdata2[1:0]) || (instrbufferdataout0[0] && gprdata2[0]));

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

wire [ICACHETAGBITSIZE -1 : 0] icachetago;

wire icachevalido;

wire icachehit = ((itlben ? itlbcached : !ioutofrange) && icacheactive && icachevalido && (icachetag == icachetago));

wire icachewe = (!doicacherst && icacheactive && instrfetchmemrqstdone && !instrbufferrst);

bram #(

	 .SZ (ICACHESETCOUNT)
	,.DW (ICACHETAGBITSIZE)

) icachetags (

	 .clk0_i  (clk_i)         ,.clk1_i  (clk_i)
	,.en0_i   (1'b1)          ,.en1_i   (1'b1)
	                          ,.we1_i   (icachewe)
	,.addr0_i (icachenextset) ,.addr1_i (icacheset)
	                          ,.i1      (icachetag)
	,.o0      (icachetago)    ,.o1      ()
);

wire [ARCHBITSZ -1 : 0] icachedato;

bram #(

	 .SZ (ICACHESETCOUNT)
	,.DW (ARCHBITSZ)

) icachedatas (

	 .clk0_i  (clk_i)             ,.clk1_i  (clk_i)
	,.en0_i   (1'b1)              ,.en1_i   (1'b1)
	                              ,.we1_i   (icachewe)
	,.addr0_i (icachenextset)     ,.addr1_i (icacheset)
	                              ,.i1      (pi1_data_i)
	,.o0      (icachedato)        ,.o1      ()
);

wire icacheoff = !icacheactive;

reg [CLOG2ICACHESETCOUNT -1 : 0] icacherstidx;

bram #(

	 .SZ (ICACHESETCOUNT)
	,.DW (1)

) icachevalids (

	 .clk0_i  (clk_i)         ,.clk1_i  (clk_i)
	,.en0_i   (1'b1)          ,.en1_i   (1'b1)
	                          ,.we1_i   (icachewe || icacheoff)
	,.addr0_i (icachenextset) ,.addr1_i (icacheoff ? icacherstidx : icacheset)
	                          ,.i1      (icacheactive)
	,.o0      (icachevalido)  ,.o1      ()
);

wire[ARCHBITSZ -1 : 0] opli8result = {{(ARCHBITSZ-8){instrbufferdataout0[3]}}, instrbufferdataout0[3:0], instrbufferdataout1[3:0]} +
	(isopinc8 ? gprdata1 : (isoprli8 ? {ipplusone, 1'b0} : {ARCHBITSZ{1'b0}}));

wire opli8done = (miscrdyandsequencerreadyandgprrdy1 && (isopli8 || isopinc8 || isoprli8));

reg wasopinc;

reg wasoprli;

reg[ARCHBITSZ -1 : 0] opligprdata1;

reg[2 -1 : 0] oplitype;

reg[(ARCHBITSZ -16) -1 : 0] oplilsb;

wire[ARCHBITSZ -1 : 0] opliresult =
	((oplitype == 1) ? {{(ARCHBITSZ-16){instrbufferdataout1[7]}}, instrbufferdataout1, instrbufferdataout0} :
	                   {instrbufferdataout1, instrbufferdataout0, oplilsb[((16*(0+1))-1):(16*(0))]}) +
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

wire opmuldiv_stb_w = (miscrdyandsequencerreadyandgprrdy12 && isopmuldiv && opmuldiv_rdy_w);

wire [(((ARCHBITSZ*2)+CLOG2GPRCNTTOTAL)+MULDIVTYPEBITSZ) -1 : 0] opmuldiv_data_w =
	{1'b0, instrbufferdataout0[2:0], gprindex1, gprdata1, gprdata2};

wire [ARCHBITSZ -1 : 0]        opmuldivresult;
wire [CLOG2GPRCNTTOTAL -1 : 0] opmuldivgpr;
wire                           opmuldivdone;

opmuldiv #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.GPRCNT    (GPRCNTTOTAL)
	,.DEPTH     (GPRCNTPERCTX/4)

) opmuldiv (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i  (opmuldiv_stb_w)
	,.data_i (opmuldiv_data_w)
	,.rdy_o  (opmuldiv_rdy_w)

	,.ostb_i  (gprwriteenable && opmuldivdone && gprindex == opmuldivgpr)
	,.data_o  (opmuldivresult)
	,.gprid_o (opmuldivgpr)
	,.ordy_o  (opmuldivdone)
);

wire opjldone = (miscrdyandsequencerreadyandgprrdy12 && isopj && isoptype2);

reg[ARCHBITSZ -1 : 0] opgetsysregresult;

wire opgetsysregdone = (miscrdyandsequencerreadyandgprrdy1 && isopgetsysreg && (
	inkernelmode ||
	((isoptype4 || isoptype5) && isflaggetclkcyclecnt) ||
	(isoptype6 && isflaggettlbsize) ||
	(isoptype7 && isflaggetcachesize)));

reg[ARCHBITSZ -1 : 0] opgetsysreg1result;

wire opgetsysreg1done = (miscrdyandsequencerreadyandgprrdy1 && isopgetsysreg1 &&
	(!isoptype3 || (gprrdy2 && !(itlbreadenable || dtlbreadenable))) && (
	inkernelmode ||
	(isoptype0 && isflaggetcoreid) ||
	(isoptype1 && isflaggetclkfreq) ||
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

wire dcachemasterrdy;

wire dtlb_and_dcache_rdy = (!dtlbreadenable && dcachemasterrdy &&
	!instrbuffernotempty_posedge);

reg[CLOG2GPRCNTTOTAL -1 : 0] opldgpr;

reg[ARCHBITSZ -1 : 0] opldresult;

reg[(ARCHBITSZ/8) -1 : 0] opldbyteselect;

wire opldfault = ((inusermode && alignfault) || (dtlben && (dtlbnotreadable || dtlbmiss)));

reg oplddone_a;
reg oplddone_b;
wire oplddone = (oplddone_a ^ oplddone_b);

reg opldmemrqst;

wire opldrdy_ = (!(opldmemrqst || oplddone) && dtlb_and_dcache_rdy);
wire opldrdy = (isopld && opldrdy_ && !opldfault);

wire opstfault = ((inusermode && alignfault) || (dtlben && (dtlbnotwritable || dtlbmiss)));

wire opstrdy_ = (dtlb_and_dcache_rdy);
wire opstrdy = (isopst && opstrdy_ && !opstfault);

reg[CLOG2GPRCNTTOTAL -1 : 0] opldstgpr;

reg[ARCHBITSZ -1 : 0] opldstresult;

reg[(ARCHBITSZ/8) -1 : 0] opldstbyteselect;

wire opldstfault = ((inusermode && alignfault) || (dtlben && (dtlbnotreadable || dtlbnotwritable || dtlbmiss)));

reg opldstdone_a;
reg opldstdone_b;
wire opldstdone = (opldstdone_a ^ opldstdone_b);

reg opldstmemrqst;

wire opldstrdy_ = (!(opldstmemrqst || opldstdone) && dtlb_and_dcache_rdy);
wire opldstrdy = (isopldst && opldstrdy_ && !opldstfault && !instrbufferdataout0[2]);

reg[2 -1 : 0] dcachemasterop;
reg[ADDRBITSZ -1 : 0] dcachemasteraddr;
wire[ARCHBITSZ -1 : 0] dcachemasterdato = pi1_data_i;
reg[ARCHBITSZ -1 : 0] dcachemasterdati;
reg[(ARCHBITSZ/8) -1 : 0] dcachemastersel;
assign dcachemasterrdy = pi1_rdy_i;

wire[2 -1 : 0] dcacheslaveop = dcachemasterop;
wire[ADDRBITSZ -1 : 0] dcacheslaveaddr = dcachemasteraddr;
wire[ARCHBITSZ -1 : 0] dcacheslavedato = dcachemasterdati;
wire[(ARCHBITSZ/8) -1 : 0] dcacheslavesel = dcachemastersel;

wire multicycleoprdy = (miscrdyandsequencerreadyandgprrdy12 &&
	(opldrdy || opldstrdy || (isopmuldiv && opmuldiv_rdy_w)));
