// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

integer init_instrbuf_idx;

initial begin

	rst_o = 0;

	inusermode = 0;

	// This register hold the address of the instruction
	// currently being sequenced from the instruction buffer.
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

	// The pu gets halted by simply preventing
	// the sequencer from decoding instructions.
	dohalt = 0;

	timer = 0;

	clkcyclecnt = 0;

	// ---------- Registers and nets used for instruction buffering ----------

	for (init_instrbuf_idx = 0; init_instrbuf_idx < INSTRBUFFERSIZE; init_instrbuf_idx = init_instrbuf_idx + 1)
		instrbuf[init_instrbuf_idx] = 0;

	// Write index within the instruction buffer.
	// Only the CLOG2INSTRBUFFERSIZE lsb are used for indexing.
	instrbufwriteidx = 0;

	instrbufrst_a = 0;
	instrbufrst_b = 0;
	instrbufrst_sampled = 0;

	// ---------- Registers used by instrfetch ----------

	// Register holding the virtual address of the instruction data to fetch.
	instrfetchaddr = 0;

	// Register holding the physical page number of the instruction to fetch.
	instrfetchppn = 0;

	instrfetchfaulted_a = 0;
	instrfetchfaulted_b = 0;

	// Register holding the instruction fetch fault virtual address.
	instrfetchfaultaddr = 0;

	// Register set to 1 for a mem request.
	instrfetchmemrqst = 0;

	// Register set to 1 when the mem request has been initiated.
	instrfetchmemrqstinprogress = 0;

	// ---------- Register updated by opli ----------

	// Register used to count the number of 16 bits left to load to get the immediate value.
	oplicounter = 0;

	// Register used to count the number of 16 bits sequenced within the instruction opli.
	oplioffset = 0;

	// ---------- Registers and nets used by the debugging interface ----------

	`ifdef PUDBG
	dbgen = 0;
	dbgselected = 0;
	dbgcounter = 0;
	dbgcntren = 0;
	dbgcmd = 0;
	dbgarg = 0;
	dbgiarg = 0;
	dbg_tx_rdy_i_sampled = 0;
	`endif

	// ---------- Registers and nets used for sequencing and decoding ----------

	`ifdef SIMULATION
	sequencerstate = 0;
	`endif

	flags = 0;

	// ---------- Registers and nets used for instruction caching ----------

	// The instruction cache is enabled when the value of this register is 1.
	icacheactive = 0;

	// Register set to 1 to do an instruction cache check.
	icachecheck = 0;

	// Register used as counter during cache reset.
	icacherstidx = 0;

	icachewecnt = 0;

	// Register used to hold icache-way index to write next.
	icachewaywriteidx = 0;

	// ---------- Registers and nets used by Hardware-Page-Table-Walker ----------

	`ifdef PUMMU
	`ifdef PUHPTW

	hptwpgd = 0;

	hptwistate = 0;
	hptwipte = 0;
	hptwidone = 0;

	hptwdstate = 0;
	hptwdpte = 0;
	hptwddone = 0;

	`endif
	`endif

	// ---------- Registers and nets implementing the mmu ----------

	`ifdef PUMMU

	asid = 0;

	// Register holding KernelSpaceLimit value.
	// When in usermode and running in kernelspace,
	// a 1-to-1 mapping is always done regardless
	// of TLB entries if the memory access address
	// is >= 0x1000 and < %ksl ; when running in userspace,
	// the TLB is never ignored and this register is ignored.
	ksl = 0;

	dtlbwaywriteidx = 0;

	dtlbwritten = 1;
	dtlbsetprev = 0;

	itlbwaywriteidx = 0;

	itlbwritten = 1;
	itlbsetprev = 0;

	opgettlbresult = 0;
	opgettlbrdy_ = 0;

	`endif

	// ---------- Registers and nets used by opli ----------

	// Register which is 1 for a load immediate increment.
	wasopinc = 0;

	// Register which is 1 for a relative load immediate.
	wasoprli = 0;

	// Register used to save the value of gprdata1 when opli is sequenced.
	opligprdata1 = 0;

	// Register used to store the type of opli.
	oplitype = 0;

	// Register used to store the least significant bits of the immediate being loaded.
	oplilsb = 0;

	// Register that will hold the id of the GPR to which
	// the result will be stored.
	// Since opli will always complete within the same context,
	// there is no need to use GPRCNTTOTAL to differentiate between
	// the context GPRs to which the result will be stored.
	opligpr = 0;

	// ---------- Registers and nets used by opgetsysreg1 ----------

	isopgettlb_or_isopclrtlb_found_sampled = 0;

	// ---------- General purpose registers ----------

	gprrdy = {GPRCNTTOTAL{1'b1}};

	// ---------- Registers and nets used by opld ----------

	// Register that will hold the id of the gpr to which the result will be stored.
	opldgpr = 0;

	opldresult = 0;

	opldbyteselect = 0;

	oplddone = 0;

	// Register set to 1 for a mem request.
	opldmemrqst = 0;

	// ---------- Registers and nets used by opldst ----------

	// Register that will hold the id of the gpr to which the result will be stored.
	opldstgpr = 0;

	opldstresult = 0;

	opldstbyteselect = 0;

	opldstdone = 0;

	// Register set to 1 for a mem request.
	opldstmemrqst = 0;
end
