// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (rst_i) begin

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

	instrbufferrst_a <= ~instrbufferrst_b;

	instrfetchfaulted_b <= instrfetchfaulted_a;

end else if (gprrdyoff) begin
end else if (instrbufferrst) begin

	instrfetchfaulted_b <= instrfetchfaulted_a;

end else if (opldfaulted) begin

	faultreason <= (opldfaulted[0] ? ALIGNFAULTINTR : READFAULTINTR);

	uip <= ip;
	ip <= kip;

	inusermode <= 0;

	instrbufferrst_a <= ~instrbufferrst_b;

end else if (opstfaulted) begin

	faultreason <= (opstfaulted[0] ? ALIGNFAULTINTR : WRITEFAULTINTR);

	uip <= ip;
	ip <= kip;

	inusermode <= 0;

	instrbufferrst_a <= ~instrbufferrst_b;

end else if (opldstfaulted) begin

	faultreason <= (
		opldstfaulted[0] ? ALIGNFAULTINTR :
		opldstfaulted[2] ? READFAULTINTR  : WRITEFAULTINTR);

	uip <= ip;
	ip <= kip;

	inusermode <= 0;

	instrbufferrst_a <= ~instrbufferrst_b;

end else if (timertriggered && !isflagdistimerintr && inusermode && !oplicounter
	`ifdef PUMMU
	`ifdef PUHPTW
	&& !hptwbsy
	`endif
	`endif
	) begin

	faultreason <= TIMERINTR;

	if (instrbuffernotempty)
		sysopcode <= {instrbufferdataout1, instrbufferdataout0};
	else
		sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

	dohalt <= 0;

	uip <= ip;
	ip <= kip;

	inusermode <= 0;

	instrbufferrst_a <= ~instrbufferrst_b;

end else if (intrqst_i && !isflagdisextintr && inusermode && !oplicounter
	`ifdef PUMMU
	`ifdef PUHPTW
	&& !hptwbsy
	`endif
	`endif
	) begin

	faultreason <= EXTINTR;

	if (instrbuffernotempty)
		sysopcode <= {instrbufferdataout1, instrbufferdataout0};
	else
		sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

	dohalt <= 0;

	uip <= ip;
	ip <= kip;

	inusermode <= 0;

	instrbufferrst_a <= ~instrbufferrst_b;

end else if (!inhalt) begin

	if (instrbuffernotempty) begin

		if (oplicounter) begin
			ip <= ipplusone;
		end else if (instrbufferdataout0[7]) begin

			if (gprrdy1) begin

				if (isopimm || isopinc || isopli8 || isopinc8 || isoprli8) begin
					if (isopinc8 && !{instrbufferdataout0[3:0], instrbufferdataout1} && !isflagdispreemptintr && inusermode) begin

						faultreason <= PREEMPTINTR;

						sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

						uip <= ipplusone;
						ip <= kip;

						inusermode <= 0;

						instrbufferrst_a <= ~instrbufferrst_b;

					end else begin
						ip <= ipplusone;
					end

				end else if (gprrdy2) begin

					if (isopj) begin

						if (isoptype2 || (|gprdata1 == instrbufferdataout0[0])) begin

							ip <= gprdata2[ARCHBITSZ-1:1];

							instrbufferrst_a <= ~instrbufferrst_b;

						end else begin
							ip <= ipplusone;
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

								sysopcode <= {instrbufferdataout1, instrbufferdataout0};

								faultaddr <= gprdata2;

							end else begin
								ip <= ipplusone;
							end
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

								sysopcode <= {instrbufferdataout1, instrbufferdataout0};

								faultaddr <= gprdata2;

							end else begin
								ip <= ipplusone;
							end
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

								sysopcode <= {instrbufferdataout1, instrbufferdataout0};

								faultaddr <= gprdata2;

							end else begin

								if (instrbufferdataout0[2]) begin

									saved_sysopcode <= sysopcode;
									saved_faultaddr <= faultaddr;

									sysopcode <= {instrbufferdataout1, instrbufferdataout0};

									faultaddr <= {dppn, gprdata2[12 -1 : 0]};

									ksysopfaultmode <= inusermode;

									rst_o <= (!ksysopfaulthdlr);

									if (inusermode)
										ip <= ksysopfaulthdlr;
									else
										ip <= ksysopfaulthdlrplustwo;

									ksysopfaultaddr <= ipplusone;

									inusermode <= 0;

									instrbufferrst_a <= ~instrbufferrst_b;

								end else begin
									ip <= ipplusone;
								end
							end
						end

					end else if (isopalu0 || isopalu1 || isopalu2 || isopmuldiv) begin

						if (!isopmuldiv || opmuldiv_rdy_w) begin
							ip <= ipplusone;
						end

					end else if (inkernelmode || isopfloat) begin

						if (!isopfloat || opmuldiv_rdy_w) begin

							saved_sysopcode <= sysopcode;
							saved_faultaddr <= faultaddr;

							sysopcode <= {instrbufferdataout1, instrbufferdataout0};

							ksysopfaultmode <= inusermode;

							rst_o <= (!ksysopfaulthdlr);

							if (inusermode)
								ip <= ksysopfaulthdlr;
							else
								ip <= ksysopfaulthdlrplustwo;

							ksysopfaultaddr <= ipplusone;

							inusermode <= 0;

							instrbufferrst_a <= ~instrbufferrst_b;
						end

					end else begin

						faultreason <= SYSOPINTR;

						sysopcode <= {instrbufferdataout1, instrbufferdataout0};

						faultaddr <= {ip, 1'b0};

						ip <= kip;
						uip <= ip;

						inusermode <= 0;

						instrbufferrst_a <= ~instrbufferrst_b;
					end
				end
			end

		end else begin

			if (inusermode && (
				!(isopsetasid && isflagsetasid) &&
				!(isopsettimer && isflagsettimer) &&
				!(isopsettlb && isflagsettlb) &&
				!(isopclrtlb && isflagclrtlb) &&
				!((isopgetclkcyclecnt || isopgetclkcyclecnth) && isflaggetclkcyclecnt) &&
				!((isopgetclkfreq || isopgetcap) && isflaggetclkfreq) &&
				!(isopgettlbsize && isflaggettlbsize) &&
				!(isopgetcachesize && isflaggetcachesize) &&
				!(isopgetcoreid && isflaggetcoreid) &&
				!(isopcacherst && isflagcacherst) &&
				!(isopgettlb && isflaggettlb) &&
				!(isopsetflags && isflagsetflags) &&
				!(isophalt && isflaghalt))) begin

				faultreason <= SYSOPINTR;

				sysopcode <= {instrbufferdataout1, instrbufferdataout0};

				faultaddr <= {ip, 1'b0};

				ip <= kip;
				uip <= ip;

				inusermode <= 0;

				instrbufferrst_a <= ~instrbufferrst_b;

			end else begin

				if (isophalt) begin

					dohalt <= 1;

					ip <= ipplusone;

				end else if (isopsysret) begin

					kip <= ipplusone;
					ip <= uip;

					inusermode <= 1;

					instrbufferrst_a <= ~instrbufferrst_b;

				end else if (isopksysret) begin

					sysopcode <= saved_sysopcode;
					faultaddr <= saved_faultaddr;

					ip <= ksysopfaultaddr;

					inusermode <= ksysopfaultmode;

					instrbufferrst_a <= ~instrbufferrst_b;

				end else if (isopcacherst) begin

					ip <= ipplusone;

				end else if (isopsetgpr) begin

					if (opsetgprrdy1 && opsetgprrdy2) begin
						ip <= ipplusone;
					end

				end else if (isopsetsysreg || isopgetsysreg || isopgetsysreg1) begin

					if (gprrdy1 && (!istlbop || !(itlbreadenable_ || dtlbreadenable_
						`ifdef PUMMU
						`ifdef PUHPTW
						|| hptwitlbwe // There is no need to check hptwdtlbwe as istlbop will be false.
						`endif
						`endif
						)) && (gprrdy2 || (isopsetksysopfaulthdlr || isopsetksl || isopsetasid ||
							isopsetuip || isopsetflags || isopsettimer ||
							isopgetsysopcode || isopgetuip || isopgetfaultaddr ||
							isopgetfaultreason || (isopgetclkcyclecnt || isopgetclkcyclecnth) ||
							isopgettlbsize || isopgetcachesize || isopgetcoreid ||
							isopgetclkfreq))) begin
						ip <= ipplusone;
						if (isopsetuip)
							uip <= gprdata1[ARCHBITSZ-1:1];
					end

				end else begin

					saved_sysopcode <= sysopcode;
					saved_faultaddr <= faultaddr;

					sysopcode <= {instrbufferdataout1, instrbufferdataout0};

					ksysopfaultmode <= inusermode;

					rst_o <= (!ksysopfaulthdlr);

					if (inusermode)
						ip <= ksysopfaulthdlr;
					else
						ip <= ksysopfaulthdlrplustwo;

					ksysopfaultaddr <= ipplusone;

					inusermode <= 0;

					instrbufferrst_a <= ~instrbufferrst_b;
				end
			end
		end

	end else if (instrfetchfaulted) begin

		faultreason <= EXECFAULTINTR;

		sysopcode <= {8'h00, OPNOTAVAIL[4:0], 3'b000};

		faultaddr <= instrfetchfaultaddr;

		uip <= (ip - oplioffset);
		ip <= kip;

		inusermode <= 0;

		instrbufferrst_a <= ~instrbufferrst_b;

		instrfetchfaulted_b <= instrfetchfaulted_a;
	end
end
