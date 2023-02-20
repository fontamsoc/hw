// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The main task of the sequencer is to compute
// the address of the next instruction to execute.

always @* begin

	if (rst_i || instrbufrst
		`ifdef PUHPTW
		|| (ARCHBITSZ != 32) // for now, HPTW is supported only for (ARCHBITSZ == 32).
		`endif
		) begin
		// Interrupts must not be processed until
		// resetting the instruction buffer has completed.

		sequencerstate = SEQIBUFRST;

	end else if (sequencerintrtimer || sequencerintrext) begin
		// If I get here, I have a timer/external interrupt.

		sequencerstate = SEQINTR;

	end else if (!inhalt) begin

		if (instrbufnotempty) begin
			// Opcode numbers are compared according to
			// the arrangement described in opcodes.pu.v.

			if (oplicounter) begin
				sequencerstate = SEQEXEC;
			`ifdef PUDBG
			// Stall the sequencer if in a debug break.
			end else if (dbgbrk) begin
				// Stall.
				sequencerstate = SEQSTALL0;
			`endif
			end else if (instrbufdato0[7] || isoploadorstorevolatile) begin

				if (gprrdy1) begin

					if (isopimm || isopinc || isopli8 || isopinc8 || isoprli8) begin
						if (isopnop) begin // NOP instruction "inc8 %0, 0" preempt current context.
							sequencerstate = SEQINTR;
						end else begin
							sequencerstate = SEQEXEC;
						end

					end else if (gprrdy2) begin

						if (isopj) begin

							sequencerstate = SEQEXEC;

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
									sequencerstate = SEQINTR;
								end else begin
									sequencerstate = SEQEXEC;
								end

							end else begin
								// Stall.
								sequencerstate = SEQSTALL0;
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
									sequencerstate = SEQINTR;
								end else begin
									sequencerstate = SEQEXEC;
								end

							end else begin
								// Stall.
								sequencerstate = SEQSTALL0;
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
									sequencerstate = SEQINTR;

								end else if (instrbufdato0[2]) begin
									sequencerstate = SEQHCALL;
								end else begin
									sequencerstate = SEQEXEC;
								end

							end else begin
								// Stall.
								sequencerstate = SEQSTALL0;
							end

						end else if (
							`ifdef PUFADDFSUB
							isopfaddfsub ||
							`endif
							isopalu0 || isopalu1 || isopalu2 || isopmuldiv) begin

							if (
								`ifdef PUFADDFSUB
								(isopfaddfsub && !opfaddfsub_rdy_w) ||
								`endif
								((isopmuldiv
									`ifdef PUDSPMUL
									&& instrbufdato0[2]
									`endif
									) && !opmuldiv_rdy_w)
								) begin
								// Stall.
								sequencerstate = SEQSTALL0;
							end else begin
								sequencerstate = SEQEXEC;
							end

						end else if (inkernelmode ||
							isopfloat /* float traps as ksysfault if not implemented */) begin
							sequencerstate = SEQHCALL;
						end else begin
							sequencerstate = SEQINTR; // SYSOPINTR.
						end

					end else begin
						// Stall.
						sequencerstate = SEQSTALL0;
					end

				end else begin
					// Stall.
					sequencerstate = SEQSTALL0;
				end

			// Start here checking for system instructions.
			end else if (sequencerintrsysop) begin
				// I get here when in usermode.

				sequencerstate = SEQINTR; // SYSOPINTR.

			// Checks continue here when in kernelmode or for a system instruction allowed in usermode.
			end else if (isophalt || isopcacherst) begin

				sequencerstate = SEQEXEC;

			end else if (isopsysret || isopksysret) begin

				sequencerstate = SEQSRET;

			end else if (isopsetgpr) begin

				if (opsetgprrdy1 && opsetgprrdy2) begin
					sequencerstate = SEQEXEC;
				end else begin
					// Stall.
					sequencerstate = SEQSTALL0;
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
					sequencerstate = SEQEXEC;
				end else begin
					// Stall.
					sequencerstate = SEQSTALL0;
				end

			end else begin
				sequencerstate = SEQHCALL;
			end

		end else if (instrfetchfaulted) begin
			// I get here if there was a pagefault while fetching an instruction.
			// Note that the instruction fetch pagefault is checked  only when
			// the sequencer stall due to instrfetch stalling and the instruction buffer
			// becoming empty; hence insuring that instructions buffered before
			// the pagefault get sequenced, otherwise those instructions would be lost
			// when resetting the instruction buffer.
			sequencerstate = SEQINTR;

		end else begin
			// Stall.
			sequencerstate = SEQSTALL1;
		end

	end else begin
		// Stall.
		sequencerstate = SEQHALT;
	end
end

always @ (posedge clk_i) begin

	case (sequencerstate)

		SEQIBUFRST: begin

			rst_o <= rst_i ? 0 : rst_o;

			kip <= rst_i ? rstaddr_i : kip;
			ip  <= rst_i ? rstaddr_i : ip;

			inusermode <= rst_i ? |id_i : inusermode;
			dohalt     <= rst_i ? |id_i : dohalt;

			instrbufrst_a <= rst_i ? ~instrbufrst_b : instrbufrst_a;

			// If instrfetchfaulted == 1, the instruction pagefault
			// should be ignored because it is for an instruction
			// fetched that is not going to be executed.
			instrfetchfaulted_b <= instrfetchfaulted_a;
		end

		SEQINTR: begin

			faultreason <= (
				sequencerintrtimer ? TIMERINTR :
				sequencerintrext   ? EXTINTR :
				sequencerintrexec  ? EXECFAULTINTR : // Must be checked before instruction faults.
				isopnop            ? PREEMPTINTR :
				isopld             ? (alignfault                     ? ALIGNFAULTINTR : READFAULTINTR) :
				isopst             ? (alignfault                     ? ALIGNFAULTINTR : WRITEFAULTINTR) :
				isopldst           ? (alignfault                     ? ALIGNFAULTINTR :
					              dtlbmiss                       ? READFAULTINTR  :
					              dtlbnotreadable[dtlbwayhitidx] ? READFAULTINTR  :
					           /* dtlbnotwritable[dtlbwayhitidx] ? */WRITEFAULTINTR ) :
					             SYSOPINTR);

			faultaddr <= (
				sequencerintrexec              ? instrfetchfaultaddr : // Must be checked before instruction faults.
				(isopld || isopst || isopldst) ? gprdata2 :
				                                 {ip, 1'b0});

			sysopcode <= (instrbufnotempty ? {instrbufdato1, instrbufdato0} : {8'h00, OPNOTAVAIL[4:0], 3'b000});

			dohalt <= 0;

			uip <= (sequencerintrexec ? (ip - oplioffset) : ip);
			ip  <= kip;

			inusermode <= 0;

			instrfetchfaulted_b <= (sequencerintrexec ? instrfetchfaulted_a : instrfetchfaulted_b);

			instrbufrst_a <= ~instrbufrst_b;
		end

		SEQEXEC: begin

			dohalt <= ((!oplicounter && isophalt) ? 1 : dohalt);

			uip <= ((!oplicounter && isopsetuip) ? gprdata1[ARCHBITSZ-1:1] : uip);

			ip <= (
				`ifdef PUSC2
				sc2exec ? (sc2isopjtrue ? sc2gprdata2[ARCHBITSZ-1:1] : sc2ipnxt) :
				`endif
				((!oplicounter && isopjtrue) ? gprdata2[ARCHBITSZ-1:1] : ipnxt));

			instrbufdato <= (
				`ifdef PUSC2
				sc2exec ? sc2insn2 :
				`endif
				sc1insn2);
			`ifdef PUSC2
			sc2instrbufdato <= (sc2exec ? sc2insn3 : sc2insn2);
			`endif

			instrbufrst_a <= ((
				`ifdef PUSC2
				sc2exec ? sc2isopjtrue :
				`endif
					(!oplicounter && isopjtrue)) ?
						~instrbufrst_b : instrbufrst_a);
		end

		SEQSTALL0: begin

			`ifdef PUSC2
			sc2instrbufdato <= sc1insn2;
			`endif
		end

		SEQSTALL1: begin

			instrbufdato <= _instrbufi;
			`ifdef PUSC2
			sc2instrbufdato <= _sc2instrbufi;
			`endif
		end

		SEQHCALL: begin

			saved_sysopcode <= sysopcode;
			saved_faultaddr <= faultaddr;

			faultaddr <= (isopldst ? {dppn, gprdata2[12 -1 : 0]} : faultaddr);

			sysopcode <= {instrbufdato1, instrbufdato0};

			ksysopfaultmode <= inusermode;

			rst_o <= (!ksysopfaulthdlr);

			ip <= (inusermode ? ksysopfaulthdlr : ksysopfaulthdlrplustwo);

			ksysopfaultaddr <= ipnxt;

			inusermode <= 0;

			instrbufrst_a <= ~instrbufrst_b;
		end

		`ifdef SIMULATION
		SEQHALT: begin
			$display("0x%x: halt %d\n", pc_o, clkcyclecnt);
			$finish;
		end
		`endif

		SEQSRET: begin

			kip <= (isopsysret ? ipnxt : kip);

			ip <= (isopsysret ? uip : ksysopfaultaddr);

			inusermode <= (isopsysret ? 1'b1 : ksysopfaultmode);

			sysopcode <= (isopsysret ? sysopcode : saved_sysopcode);
			faultaddr <= (isopsysret ? faultaddr : saved_faultaddr);

			instrbufrst_a <= ~instrbufrst_b;
		end
	endcase
end
