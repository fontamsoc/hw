// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

reg [64 -1 : 0] csrCycle;
always @ (posedge clk_i) begin
	csrCycle <= (rst_i ? 64'd0 : (csrCycle + 1'b1));
end

reg [64 -1 : 0] csrInstret;
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrInstret <= 0;
	end else if (
		ldUnit_memAck
		`ifdef PURV32M
		|| opImul_done || opIdiv_done
		`endif
		|| (!eX_flushed && !eX_multiCycleInsn && !halted_o)
		) begin
		csrInstret <= (csrInstret + 1'b1);
		`ifdef _SIMULATION
		if (!csrInstret[20:0]) begin
			$write("."); $fflush();
		end
		`endif
	end
end

reg [WORDBITSZ -1 : 0] csrClkFreq;
always @ (posedge clk_i) begin
	csrClkFreq <= CLKFREQ;
end

`ifdef SIMULATION
`ifdef PUPREDICTBRANCH
reg [WORDBITSZ -1 : 0] csrBranchPredictHit;
reg [WORDBITSZ -1 : 0] csrBranchPredictMiss;
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrBranchPredictHit <= 0;
		csrBranchPredictMiss <= 0;
	end else if (iD_isBranch && eX_insn_valid_i) begin
		if (_eX_takeBranch_i)
			csrBranchPredictMiss <= csrBranchPredictMiss + 1'b1;
		else
			csrBranchPredictHit <= csrBranchPredictHit + 1'b1;
	end
end
`endif
`ifdef PUPREDICTRET
reg [WORDBITSZ -1 : 0] csrRetPredictMiss;
always @ (posedge clk_i) begin
	if (rst_i)
		csrRetPredictMiss <= 0;
	else if (iD_isRet && eX_predictRetMiss_i && eX_insn_valid_i)
		csrRetPredictMiss <= csrRetPredictMiss + 1'b1;
end
`endif
`endif

always @ (posedge clk_i) begin
	if (rst_i)
		halted_o <= 0;
	else if (iD_isEbreak && eX_insn_valid_i)
		halted_o <= 1;
	`ifdef SIMULATION
	if (halted_o && !wb_pending_acks) begin
		`ifdef PUPREDICTBRANCH
		$write ("BranchPredictHit: %1.2f%%\n",
			($bitstoreal(csrBranchPredictHit * 100) / $bitstoreal(csrBranchPredictHit + csrBranchPredictMiss)));
		`endif
		`ifdef PUPREDICTRET
		$write ("RetPredictMiss: %1d\n", csrRetPredictMiss);
		`endif
		$write ("CPI: %1.2f\n", ($bitstoreal(csrCycle) / $bitstoreal(csrInstret)));
		$fflush();
		$finish;
	end
	`endif
end

generate if (WORDBITSZ == 32) begin
always @* begin
	case (iD_Iimm[11:0])
	12'hc00: eX_csrOut_i = csrCycle[WORDBITSZ-1:0];
	12'hc01: eX_csrOut_i = csrCycle[WORDBITSZ-1:0]; // TODO: return CSR time lsb instead.
	12'hc02: eX_csrOut_i = csrInstret[WORDBITSZ-1:0];
	12'hc80: eX_csrOut_i = csrCycle[64-1:WORDBITSZ];
	12'hc81: eX_csrOut_i = csrCycle[64-1:WORDBITSZ]; // TODO: return CSR time msb instead.
	12'hc82: eX_csrOut_i = csrInstret[64-1:WORDBITSZ];
	12'hcc0: eX_csrOut_i = csrClkFreq; // Using User CSRs Non-standard read-only.
	default: eX_csrOut_i = {WORDBITSZ{1'b0}};
	endcase
end
end endgenerate
generate if (WORDBITSZ == 64) begin
always @* begin
	case (iD_Iimm[11:0])
	12'hc00: eX_csrOut_i = csrCycle;
	12'hc01: eX_csrOut_i = csrCycle; // TODO: return CSR time lsb instead.
	12'hc02: eX_csrOut_i = csrInstret;
	12'hcc0: eX_csrOut_i = csrClkFreq; // Using User CSRs Non-standard read-only.
	default: eX_csrOut_i = {WORDBITSZ{1'b0}};
	endcase
end
end endgenerate
