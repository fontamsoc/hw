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

		sequencerstate = 3'd0;

	end else if (sequencerintrtimer || sequencerintrext) begin
		// If I get here, I have a timer/external interrupt.

		sequencerstate = 3'd1;

	end else if (!inhalt) begin

		if (instrbufnotempty) begin
			// Opcode numbers are compared according to
			// the arrangement described in opcodes.pu.v.

			if (oplicounter) begin
				sequencerstate = 3'd2;
			`ifdef PUDBG
			// Stall the sequencer if in a debug break.
			end else if (dbgbrk) begin
				// Stall.
				sequencerstate = 3'd3;
			`endif
			end else if (instrbufdato0[7] || isoploadorstorevolatile) begin

				if (gprrdy1) begin

					if (isopimm || isopinc || isopli8 || isopinc8 || isoprli8) begin
						if (isopnop) begin // NOP instruction "inc8 %0, 0" preempt current context.
							sequencerstate = 3'd1;
						end else begin
							sequencerstate = 3'd2;
						end

					end else if (gprrdy2) begin

						if (isopj) begin

							sequencerstate = 3'd2;

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
									sequencerstate = 3'd1;
								end else begin
									sequencerstate = 3'd2;
								end

							end else begin
								// Stall.
								sequencerstate = 3'd3;
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
									sequencerstate = 3'd1;
								end else begin
									sequencerstate = 3'd2;
								end

							end else begin
								// Stall.
								sequencerstate = 3'd3;
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
									sequencerstate = 3'd1;

								end else if (instrbufdato0[2]) begin
									sequencerstate = 3'd5;
								end else begin
									sequencerstate = 3'd2;
								end

							end else begin
								// Stall.
								sequencerstate = 3'd3;
							end

						end else if (isopalu0 || isopalu1 || isopalu2 || isopmuldiv) begin

							if ((!isopmuldiv
								`ifdef PUDSPMUL
								|| !instrbufdato0[2]
								`endif
								) || opmuldiv_rdy_w) begin
								sequencerstate = 3'd2;
							end else begin
								// Stall.
								sequencerstate = 3'd3;
							end

						end else if (inkernelmode || isopfloat /* float traps as ksysfault until implemented */) begin
							sequencerstate = 3'd5;
						end else begin
							sequencerstate = 3'd1; // SYSOPINTR.
						end

					end else begin
						// Stall.
						sequencerstate = 3'd3;
					end

				end else begin
					// Stall.
					sequencerstate = 3'd3;
				end

			// Start here checking for system instructions.
			end else if (sequencerintrsysop) begin
				// I get here when in usermode.

				sequencerstate = 3'd1; // SYSOPINTR.

			// Checks continue here when in kernelmode or for a system instruction allowed in usermode.
			end else if (isophalt || isopcacherst) begin

				sequencerstate = 3'd2;

			end else if (isopsysret || isopksysret) begin

				sequencerstate = 3'd7;

			end else if (isopsetgpr) begin

				if (opsetgprrdy1 && opsetgprrdy2) begin
					sequencerstate = 3'd2;
				end else begin
					// Stall.
					sequencerstate = 3'd3;
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
					sequencerstate = 3'd2;
				end else begin
					// Stall.
					sequencerstate = 3'd3;
				end

			end else begin
				sequencerstate = 3'd5;
			end

		end else if (instrfetchfaulted) begin
			// I get here if there was a pagefault while fetching an instruction.
			// Note that the instruction fetch pagefault is checked  only when
			// the sequencer stall due to instrfetch stalling and the instruction buffer
			// becoming empty; hence insuring that instructions buffered before
			// the pagefault get sequenced, otherwise those instructions would be lost
			// when resetting the instruction buffer.
			sequencerstate = 3'd1;

		end else begin
			// Stall.
			sequencerstate = 3'd4;
		end

	end else begin
		// Stall.
		sequencerstate = 3'd6;
	end
end

always @ (posedge clk_i) begin

	case (sequencerstate)

		3'd0: begin

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

		3'd1: begin

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

		3'd2: begin

			dohalt <= ((!oplicounter && isophalt) ? 1 : dohalt);

			uip <= ((!oplicounter && isopsetuip) ? gprdata1[ARCHBITSZ-1:1] : uip);

			ip <= ((!oplicounter && isopjtrue) ? gprdata2[ARCHBITSZ-1:1] : ipnxt);

			instrbufdato <= (|instrbufusage2 ? _instrbufipnxt : _instrbufi2);

			instrbufrst_a <= ((!oplicounter && isopjtrue) ? ~instrbufrst_b : instrbufrst_a);
		end

		3'd4: begin

			instrbufdato <= _instrbufi;
		end

		3'd5: begin

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

		3'd7: begin

			kip <= (isopsysret ? ipnxt : kip);

			ip <= (isopsysret ? uip : ksysopfaultaddr);

			inusermode <= (isopsysret ? 1'b1 : ksysopfaultmode);

			sysopcode <= (isopsysret ? sysopcode : saved_sysopcode);
			faultaddr <= (isopsysret ? faultaddr : saved_faultaddr);

			instrbufrst_a <= ~instrbufrst_b;
		end
	endcase
end
