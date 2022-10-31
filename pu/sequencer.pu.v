// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The main task of the sequencer is to compute
// the address of the next instruction to execute.

if (rst_i
	`ifdef PUHPTW
	|| (ARCHBITSZ != 32) // for now, HPTW is supported only for (ARCHBITSZ == 32).
	`endif
	) begin
	// Reset logic.

	rst_o <= 0;

	ip <= rstaddr_i;
	kip <= rstaddr_i;

	if (id_i) begin
		inusermode <= 1;
		dohalt <= 1;
	end else begin
		inusermode <= 0;
		dohalt <= 0;
	end

	instrbufrst_a <= ~instrbufrst_b;

	instrfetchfaulted_b <= instrfetchfaulted_a;

	`ifdef SIMULATION
	sequencerstate <= 0;
	`endif

end else if (gprrdyoff) begin

	`ifdef SIMULATION
	sequencerstate <= 1;
	`endif

end else if (instrbufrst) begin
	// Interrupts must not be processed until
	// resetting the instruction buffer has completed.

	// If instrfetchfaulted == 1, the instruction pagefault
	// should be ignored because it is for an instruction
	// fetched that is not going to be executed.
	instrfetchfaulted_b <= instrfetchfaulted_a;

	`ifdef SIMULATION
	sequencerstate <= 2;
	`endif

end else if (timertriggered && !isflagdistimerintr && inusermode && !oplicounter
	`ifdef PUMMU
	`ifdef PUHPTW
	&& !hptwbsy
	`endif
	`endif
	// Disable TIMERINTR if debug-stepping.
	&& !dbgen) begin
	// If I get here, I have a timer interrupt.

	faultreason <= TIMERINTR;

	sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

	dohalt <= 0;

	uip <= ip;
	ip <= kip;

	inusermode <= 0;

	instrbufrst_a <= ~instrbufrst_b;

	`ifdef SIMULATION
	sequencerstate <= 6;
	`endif

end else if (intrqst_i && !isflagdisextintr && inusermode && !oplicounter
	`ifdef PUMMU
	`ifdef PUHPTW
	&& !hptwbsy
	`endif
	`endif
	// Disable EXTINTR if debug-stepping.
	&& !dbgen) begin
	// If I get here, I have an external interrupt.

	faultreason <= EXTINTR;

	sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

	dohalt <= 0;

	uip <= ip;
	ip <= kip;

	inusermode <= 0;

	instrbufrst_a <= ~instrbufrst_b;

	`ifdef SIMULATION
	sequencerstate <= 7;
	`endif

end else if (!inhalt) begin

	if (instrbufnotempty) begin
		// Opcode numbers are compared according to
		// the arrangement described in opcodes.pu.v.

		if (oplicounter) begin
			ip <= ipnxt;
			`ifdef SIMULATION
			sequencerstate <= 8;
			`endif
		`ifdef PUDBG
		// Stall the sequencer if in a debug break.
		end else if (dbgbrk) begin
			`ifdef SIMULATION
			sequencerstate <= 9;
			`endif
		`endif
		end else if (instrbufdato0[7] || isoploadorstorevolatile) begin

			if (gprrdy1) begin

				if (isopimm || isopinc || isopli8 || isopinc8 || isoprli8) begin
					// NOP instruction "inc8 %0, 0" preempt current context.
					if (isopinc8 && !{instrbufdato0[3:0], instrbufdato1} && !isflagdispreemptintr && inusermode
						// Disable PREEMPTINTR if debug-stepping.
						&& !dbgen) begin

						faultreason <= PREEMPTINTR;

						sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

						uip <= ipnxt;
						ip <= kip;

						inusermode <= 0;

						instrbufrst_a <= ~instrbufrst_b;

						`ifdef SIMULATION
						sequencerstate <= 10;
						`endif

					end else begin
						ip <= ipnxt;
						`ifdef SIMULATION
						sequencerstate <= 11;
						`endif
					end

				end else if (gprrdy2) begin

					if (isopj) begin

						if (isoptype2 || (|gprdata1 == instrbufdato0[0])) begin

							ip <= gprdata2[ARCHBITSZ-1:1];

							instrbufrst_a <= ~instrbufrst_b;

							`ifdef SIMULATION
							sequencerstate <= 12;
							`endif

						end else begin
							ip <= ipnxt;
							`ifdef SIMULATION
							sequencerstate <= 13;
							`endif
						end

					end else if (isopld) begin

						if (opldrdy_
							`ifdef PUMMU
							`ifdef PUHPTW
							&& opldfault__hptwddone
							`endif
							`endif
							) begin

							if (opldfault) begin
								// Note that I get in this state only when in usermode
								// because pagefault occurs only when in usermode.

								faultreason <= (alignfault ? ALIGNFAULTINTR : READFAULTINTR);

								uip <= ip;
								ip <= kip;

								inusermode <= 0;

								instrbufrst_a <= ~instrbufrst_b;

								sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

								faultaddr <= gprdata2;

								`ifdef SIMULATION
								sequencerstate <= 14;
								`endif

							end else begin
								ip <= ipnxt;
								`ifdef SIMULATION
								sequencerstate <= 15;
								`endif
							end

						end else begin
							// Stall.
							`ifdef SIMULATION
							sequencerstate <= 16;
							`endif
						end

					end else if (isopst) begin

						if (opstrdy_
							`ifdef PUMMU
							`ifdef PUHPTW
							&& opstfault__hptwddone
							`endif
							`endif
							) begin

							if (opstfault) begin
								// Note that I get in this state only when in usermode
								// because pagefault occurs only when in usermode.

								faultreason <= (alignfault ? ALIGNFAULTINTR : WRITEFAULTINTR);

								uip <= ip;
								ip <= kip;

								inusermode <= 0;

								instrbufrst_a <= ~instrbufrst_b;

								sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

								faultaddr <= gprdata2;

								`ifdef SIMULATION
								sequencerstate <= 17;
								`endif

							end else begin
								ip <= ipnxt;
								`ifdef SIMULATION
								sequencerstate <= 18;
								`endif
							end

						end else begin
							// Stall.
							`ifdef SIMULATION
							sequencerstate <= 19;
							`endif
						end

					end else if (isopldst) begin

						if (opldstrdy_
							`ifdef PUMMU
							`ifdef PUHPTW
							&& opldstfault__hptwddone
							`endif
							`endif
							) begin

							if (opldstfault) begin
								// Note that I get in this state only when in usermode
								// because pagefault occurs only when in usermode.

								faultreason <= (
									alignfault                     ? ALIGNFAULTINTR :
									dtlbmiss                       ? READFAULTINTR  :
									dtlbnotreadable[dtlbwayhitidx] ? READFAULTINTR  :/* dtlbnotwritable[dtlbwayhitidx] ? */
									                                 WRITEFAULTINTR );

								uip <= ip;
								ip <= kip;

								inusermode <= 0;

								instrbufrst_a <= ~instrbufrst_b;

								sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

								faultaddr <= gprdata2;

								`ifdef SIMULATION
								sequencerstate <= 20;
								`endif

							end else begin

								if (instrbufdato0[2]) begin

									saved_sysopcode <= sysopcode;
									saved_faultaddr <= faultaddr;

									sysopcode <= {instrbufdato1, instrbufdato0};

									faultaddr <= {dppn, gprdata2[12 -1 : 0]};

									ksysopfaultmode <= inusermode;

									rst_o <= (!ksysopfaulthdlr);

									if (inusermode)
										ip <= ksysopfaulthdlr;
									else
										ip <= ksysopfaulthdlrplustwo;

									ksysopfaultaddr <= ipnxt;

									inusermode <= 0;

									instrbufrst_a <= ~instrbufrst_b;

									`ifdef SIMULATION
									sequencerstate <= 21;
									`endif

								end else begin
									ip <= ipnxt;
									`ifdef SIMULATION
									sequencerstate <= 22;
									`endif
								end
							end

						end else begin
							// Stall.
							`ifdef SIMULATION
							sequencerstate <= 23;
							`endif
						end

					end else if (isopalu0 || isopalu1 || isopalu2 || isopmuldiv) begin

						if ((!isopmuldiv
							`ifdef PUDSPMUL
							|| !instrbufdato0[2]
							`endif
							) || opmuldiv_rdy_w) begin
							ip <= ipnxt;
							`ifdef SIMULATION
							sequencerstate <= 24;
							`endif
						end else begin
							// Stall.
							`ifdef SIMULATION
							sequencerstate <= 25;
							`endif
						end

					end else if (inkernelmode || isopfloat /* float traps as ksysfault until implemented */) begin

						saved_sysopcode <= sysopcode;
						saved_faultaddr <= faultaddr;

						sysopcode <= {instrbufdato1, instrbufdato0};

						ksysopfaultmode <= inusermode;

						rst_o <= (!ksysopfaulthdlr);

						if (inusermode)
							ip <= ksysopfaulthdlr;
						else
							ip <= ksysopfaulthdlrplustwo;

						ksysopfaultaddr <= ipnxt;

						inusermode <= 0;

						instrbufrst_a <= ~instrbufrst_b;

						`ifdef SIMULATION
						sequencerstate <= 26;
						`endif

					end else begin

						faultreason <= SYSOPINTR;

						sysopcode <= {instrbufdato1, instrbufdato0};

						faultaddr <= {ip, 1'b0};

						ip <= kip;
						uip <= ip;

						inusermode <= 0;

						instrbufrst_a <= ~instrbufrst_b;

						`ifdef SIMULATION
						sequencerstate <= 28;
						`endif
					end

				end else begin
					// Stall.
					`ifdef SIMULATION
					sequencerstate <= 29;
					`endif
				end

			end else begin
				// Stall.
				`ifdef SIMULATION
				sequencerstate <= 30;
				`endif
			end

		end else begin
			// I get here for system instructions.

			if (inusermode && (
				!(isopsetasid && isflagsetasid) &&
				!(isopsettimer && isflagsettimer) &&
				!(isopsettlb && isflagsettlb) &&
				!(isopclrtlb && isflagclrtlb) &&
				!((isopgetclkcyclecnt || isopgetclkcyclecnth) && isflaggetclkcyclecnt) &&
				!((isopgetclkfreq || isopgetcap || isopgetver) && isflaggetclkfreq) &&
				!(isopgettlbsize && isflaggettlbsize) &&
				!(isopgetcachesize && isflaggetcachesize) &&
				!(isopgetcoreid && isflaggetcoreid) &&
				!(isopcacherst && isflagcacherst) &&
				!(isopgettlb && isflaggettlb) &&
				!(isopsetflags && isflagsetflags) &&
				!(isophalt && isflaghalt))) begin
				// I get here when in usermode.

				faultreason <= SYSOPINTR;

				sysopcode <= {instrbufdato1, instrbufdato0};

				faultaddr <= {ip, 1'b0};

				ip <= kip;
				uip <= ip;

				inusermode <= 0;

				instrbufrst_a <= ~instrbufrst_b;

				`ifdef SIMULATION
				sequencerstate <= 31;
				`endif

			end else begin
				// I get here when in kernelmode or for a system instruction allowed in usermode.

				if (isophalt) begin

					dohalt <= 1;

					ip <= ipnxt;

					`ifdef SIMULATION
					sequencerstate <= 32;
					`endif

				end else if (isopsysret) begin

					kip <= ipnxt;
					ip <= uip;

					inusermode <= 1;

					instrbufrst_a <= ~instrbufrst_b;

					`ifdef SIMULATION
					sequencerstate <= 33;
					`endif

				end else if (isopksysret) begin

					sysopcode <= saved_sysopcode;
					faultaddr <= saved_faultaddr;

					ip <= ksysopfaultaddr;

					inusermode <= ksysopfaultmode;

					instrbufrst_a <= ~instrbufrst_b;

					`ifdef SIMULATION
					sequencerstate <= 34;
					`endif

				end else if (isopcacherst) begin

					ip <= ipnxt;

					`ifdef SIMULATION
					sequencerstate <= 35;
					`endif

				end else if (isopsetgpr) begin

					if (opsetgprrdy1 && opsetgprrdy2) begin
						ip <= ipnxt;
						`ifdef SIMULATION
						sequencerstate <= 36;
						`endif
					end else begin
						// Stall.
						`ifdef SIMULATION
						sequencerstate <= 37;
						`endif
					end

				end else if (isopsetsysreg || isopgetsysreg || isopgetsysreg1) begin

					if (gprrdy1 &&
						(!istlbop || (!(itlbreadenable_ || dtlbreadenable_
							`ifdef PUMMU
							`ifdef PUHPTW
							|| hptwitlbwe // There is no need to check hptwdtlbwe as istlbop will be false.
							`endif
							`endif
							) && (!isopgettlb || (opgettlbrdy_
								`ifdef PUMMU
								`ifdef PUHPTW
								&& opgettlbfault__hptwddone
								`endif
								`endif
						)))) && (gprrdy2 || (isopsetksysopfaulthdlr || isopsetksl || isopsetasid ||
							isopsetuip || isopsetflags || isopsettimer ||
							isopgetsysopcode || isopgetuip || isopgetfaultaddr ||
							isopgetfaultreason || (isopgetclkcyclecnt || isopgetclkcyclecnth) ||
							isopgettlbsize || isopgetcachesize || isopgetcoreid ||
							isopgetclkfreq))) begin
						ip <= ipnxt;
						if (isopsetuip)
							uip <= gprdata1[ARCHBITSZ-1:1];
						`ifdef SIMULATION
						sequencerstate <= 38;
						`endif
					end else begin
						// Stall.
						`ifdef SIMULATION
						sequencerstate <= 39;
						`endif
					end

				end else begin

					saved_sysopcode <= sysopcode;
					saved_faultaddr <= faultaddr;

					sysopcode <= {instrbufdato1, instrbufdato0};

					ksysopfaultmode <= inusermode;

					rst_o <= (!ksysopfaulthdlr);

					if (inusermode)
						ip <= ksysopfaulthdlr;
					else
						ip <= ksysopfaulthdlrplustwo;

					ksysopfaultaddr <= ipnxt;

					inusermode <= 0;

					instrbufrst_a <= ~instrbufrst_b;

					`ifdef SIMULATION
					sequencerstate <= 40;
					`endif
				end
			end
		end

	end else if (instrfetchfaulted) begin
		// I get here if there was a pagefault while fetching an instruction.
		// Note that the instruction fetch pagefault is checked  only when
		// the sequencer stall due to instrfetch stalling and the instruction buffer
		// becoming empty; hence insuring that instructions buffered before
		// the pagefault get sequenced, otherwise those instructions would be lost
		// when resetting the instruction buffer.

		faultreason <= EXECFAULTINTR;

		sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

		faultaddr <= instrfetchfaultaddr;

		uip <= (ip - oplioffset);
		ip <= kip;

		inusermode <= 0;

		instrbufrst_a <= ~instrbufrst_b;

		instrfetchfaulted_b <= instrfetchfaulted_a;

		`ifdef SIMULATION
		sequencerstate <= 41;
		`endif

	end else begin
		// Stall.
		`ifdef SIMULATION
		sequencerstate <= 42;
		`endif
	end
end
