// Copyright (c) William Fonkou Tambe
// All rights reserved.

integer j;

initial begin

	rst_o = 0;

	inusermode = 0;

	ip = 0;

	kip = 0;
	uip = 0;

	ksysopfaultmode = 0;
	ksysopfaulthdlr = 0;
	ksysopfaultaddr = 0;

	sysopcode = 0;
	saved_sysopcode = 0;

	faultaddr = 0;
	saved_faultaddr = 0;

	faultreason = 0;

	dohalt = 0;

	timer = 0;

	clkcyclecnt = 0;

	for (j = 0; j < INSTRBUFFERSIZE; j = j + 1)
		instrbuffer[j] = 0;

	instrbufferwriteindex = 0;

	instrbuffernotempty_sampled = 0;

	instrbufferrst_a = 0;
	instrbufferrst_b = 0;
	instrbufferrst_sampled = 0;

	instrfetchaddr = 0;

	instrfetchppn = 0;

	instrfetchfaulted_a = 0;
	instrfetchfaulted_b = 0;

	instrfetchfaultaddr = 0;

	instrfetchmemrqst = 0;

	instrfetchmemrqstinprogress = 0;

	oplicounter = 0;

	oplioffset = 0;

	gprrdyrstidx = 0;
	gprrdyon = 0;

	opldfaulted = 0;

	opstfaulted = 0;

	opldstfaulted = 0;

	flags = 0;

	icacheactive = 0;

	icachecheck = 0;

	icacherstidx = 0;

	`ifdef PUMMU

	asid = 0;

	ksl = 0;

	dtlbwritten = 1;
	dtlbsetprev = 0;

	itlbwritten = 1;
	itlbsetprev = 0;

	`endif

	wasopinc = 0;

	wasoprli = 0;

	opligprdata1 = 0;

	oplitype = 0;

	oplilsb = 0;

	opligpr = 0;

	opmuldivcumulator = 0;

	opmuldivgpr = 0;

	opmuldivcounter = 0;

	opmuldivbusy = 0;

	opmuldivstart_a = 0;
	opmuldivstart_b = 0;

	opmuldivdone_a = 0;
	opmuldivdone_b = 0;

	opmuldivfifodataout = 0;

	opmuldivprevtype = 0;
	opmuldivprevgprdata1 = 0;
	opmuldivprevgprdata2 = 0;

	isopgettlb_or_isopclrtlb_found_sampled = 0;

	opldgpr = 0;

	opldresult = 0;

	opldbyteselect = 0;

	oplddone_a = 0;
	oplddone_b = 0;

	opldmemrqst = 0;

	opldstgpr = 0;

	opldstresult = 0;

	opldstbyteselect = 0;

	opldstdone_a = 0;
	opldstdone_b = 0;

	opldstmemrqst = 0;
end