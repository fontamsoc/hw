// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire iD_isExcCsr_ = (
	(iD_Iimm[9:8] > csrCurPriv) ||
	(&iD_Iimm[11:10] && ( // Catch read-only CSR write.
		iD_func3[1:0] == 2'b01 ||
		(iD_func3[2] ? |iD_rs1Id : |iD_rs1))));
wire iD_isExcCsr = (iD_isCSR && iD_isExcCsr_);

wire iD_isCSRvalid = (iD_isCSR && iD_insn_valid && !iD_isExcCsr_);

wire [WORDBITSZ -1 : 0] csrIn = (iD_func3[2] ? {{(WORDBITSZ-CLOG2GPRCNT){1'b0}}, iD_rs1Id} : iD_rs1);

wire [16 -1 : 0] csrInMedelegMask = 'b1011001111111111; // Non-null bits get modified.
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMedeleg <= 0;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h302) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMedeleg <= ((csrMedeleg & ~csrInMedelegMask) | (csrIn[15:0] & csrInMedelegMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMedeleg <= (csrMedeleg | (csrIn[15:0] & csrInMedelegMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMedeleg <= (csrMedeleg & ~(csrIn[15:0] & csrInMedelegMask));
		end
	end
end

wire [16 -1 : 0] csrInMidelegMask = 'b0000100010001000; // Non-null bits get modified.
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMideleg <= 0;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h303) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMideleg <= ((csrMideleg & ~csrInMidelegMask) | (csrIn[15:0] & csrInMidelegMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMideleg <= (csrMideleg | (csrIn[15:0] & csrInMidelegMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMideleg <= (csrMideleg & ~(csrIn[15:0] & csrInMidelegMask));
		end
	end
end

wire [16 -1 : 0] csrInMipMask = // Non-null bits get modified.
	csrCurPrivIsS ? 16'b0000001000100010 : // SEIP STIP SSIP.
	                16'b0000101010101010 ; // All above plus MEIP MTIP MSIP.
reg [16 -1 : 0] csrMip__;
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMip__ <= 0;
	end else if (iD_isCSRvalid && iD_Iimm[11:10] == 2'b00 && iD_Iimm[7:0] == 8'h44) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMip__ <= ((csrMip__ & ~csrInMipMask) | (csrIn[15:0] & csrInMipMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMip__ <= (csrMip__ | (csrIn[15:0] & csrInMipMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMip__ <= (csrMip__ & ~(csrIn[15:0] & csrInMipMask));
		end
	end
end
wire irqExt = irq_stb_i;
wire irqMtimer = (csrCycle >= csrMtimecmp);
wire irqStimer = (csrCycle >= csrStimecmp);
wire [16 -1 : 0] csrMip_ = {
	4'd0,
	(csrMip__[11/*MEIP*/] || irqExt) && !csrMideleg[11/*MEI*/],
	1'b0,
	(csrMip__[9/*SEIP*/] || irqExt) && csrMideleg[11/*MEI*/],
	1'b0,
	(csrMip__[7/*MTIP*/] || irqMtimer) && !csrMideleg[7/*MTI*/],
	1'b0,
	(csrMip__[5/*STIP*/] || irqStimer) && csrMideleg[7/*MTI*/],
	1'b0,
	csrMip__[3/*MSIP*/] && !csrMideleg[3/*MSI*/],
	1'b0,
	csrMip__[1/*SSIP*/] && csrMideleg[3/*MSI*/],
	1'b0};
always @ (posedge clk_i)
	csrMip <= csrMip_;

wire [16 -1 : 0] csrInMieMask = // Non-null bits get modified.
	csrCurPrivIsS ? 16'b0000001000100010 : // SEIE STIE SSIE.
	                16'b0000101010101010 ; // All above plus MEIE MTIE MSIE.
always @ (posedge clk_i) begin
	if (rst_i) begin // If (csrMhartid != 0) reset csrMie.MEIE to 1.
		csrMie <= (csrMhartidIsNonNull ? 16'b0000100000000000 : 16'd0);
	end else if (iD_isCSRvalid && iD_Iimm[11:10] == 2'b00 && iD_Iimm[7:0] == 8'h04) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMie <= ((csrMie & ~csrInMieMask) | (csrIn[15:0] & csrInMieMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMie <= (csrMie | (csrIn[15:0] & csrInMieMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMie <= (csrMie & ~(csrIn[15:0] & csrInMieMask));
		end
	end
end

localparam h34d = 12'h34d;
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMtimecmp <= 0;
	end else if (iD_isCSRvalid && (iD_Iimm[11:5] == h34d[11:5]) && (iD_Iimm[3:0] == h34d[3:0])) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			if (iD_Iimm[4])
				csrMtimecmp[64-1:WORDBITSZ] <= csrIn;
			else
				csrMtimecmp[WORDBITSZ-1:0] <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			if (iD_Iimm[4])
				csrMtimecmp[64-1:WORDBITSZ] <= (csrMtimecmp[64-1:WORDBITSZ] | csrIn);
			else
				csrMtimecmp[WORDBITSZ-1:0] <= (csrMtimecmp[WORDBITSZ-1:0] | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			if (iD_Iimm[4])
				csrMtimecmp[64-1:WORDBITSZ] <= (csrMtimecmp[64-1:WORDBITSZ] & ~csrIn);
			else
				csrMtimecmp[WORDBITSZ-1:0] <= (csrMtimecmp[WORDBITSZ-1:0] & ~csrIn);
		end
	end
end

localparam h14d = 12'h14d;
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrStimecmp <= 0;
	end else if (iD_isCSRvalid && (iD_Iimm[11:5] == h14d[11:5]) && (iD_Iimm[3:0] == h14d[3:0])) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			if (iD_Iimm[4])
				csrStimecmp[64-1:WORDBITSZ] <= csrIn;
			else
				csrStimecmp[WORDBITSZ-1:0] <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			if (iD_Iimm[4])
				csrStimecmp[64-1:WORDBITSZ] <= (csrStimecmp[64-1:WORDBITSZ] | csrIn);
			else
				csrStimecmp[WORDBITSZ-1:0] <= (csrStimecmp[WORDBITSZ-1:0] | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			if (iD_Iimm[4])
				csrStimecmp[64-1:WORDBITSZ] <= (csrStimecmp[64-1:WORDBITSZ] & ~csrIn);
			else
				csrStimecmp[WORDBITSZ-1:0] <= (csrStimecmp[WORDBITSZ-1:0] & ~csrIn);
		end
	end
end

always @ (posedge clk_i) begin
	csrCycle <= (rst_i ? 64'd0 : (csrCycle + 1'b1));
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrInstret <= 0;
	end else if (eX_rW_stalled || (!eX_isExc && !eX_flushed && !eX_lateWritebackInsn && !halted_o)) begin
		csrInstret <= (csrInstret + 1'b1);
		`ifdef _SIMULATION
		if (!csrInstret[20:0]) begin
			$write("."); $fflush();
		end
		`endif
	end
end

always @ (posedge clk_i) begin
	csrClkFreq <= CLKFREQ;
end

`ifdef _SIMULATION_PERF
`ifdef PUPREDICTBRANCH
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrBranchPredictHit <= 0;
		csrBranchPredictMiss <= 0;
	end else if (iD_isBranch && iD_insn_valid) begin
		if (_eX_takeBranch_i)
			csrBranchPredictMiss <= csrBranchPredictMiss + 1'b1;
		else
			csrBranchPredictHit <= csrBranchPredictHit + 1'b1;
	end
end
`endif
`ifdef PUPREDICTRET
always @ (posedge clk_i) begin
	if (rst_i)
		csrRetPredictMiss <= 0;
	else if (iD_isRet && eX_predictRetMiss_i && iD_insn_valid)
		csrRetPredictMiss <= csrRetPredictMiss + 1'b1;
end
`endif
`endif

// Indefinitely halt when an exception occurs and the trap vector address is null.
wire fatalExc = (excTriggered && !excTvec);

always @ (posedge clk_i) begin
	if (rst_i)
		halted_o <= csrMhartidIsNonNull;
	else if ((iD_isWfi && iD_insn_valid) || fatalExc || halted_o)
		halted_o <= !(
			(csrMip_[11/*MEIP*/] && csrMie[11/*MEIE*/] && (csrCurPrivIsM ? csrMstatus[3/*MIE*/] : 1'b1)) ||
			(csrMip_[9/*SEIP*/] && csrMie[9/*SEIE*/] && (csrCurPrivIsS ? csrMstatus[1/*SIE*/] : csrCurPrivIsU)) ||
			(csrMip_[7/*MTIP*/] && csrMie[7/*MTIE*/] && (csrCurPrivIsM ? csrMstatus[3/*MIE*/] : 1'b1)) ||
			(csrMip_[5/*STIP*/] && csrMie[5/*STIE*/] && (csrCurPrivIsS ? csrMstatus[1/*SIE*/] : csrCurPrivIsU)));
end

`ifdef SIMULATION
reg endSimRq;
always @ (posedge clk_i) begin
	if (rst_i)
		endSimRq <= 0;
	else if (fatalExc)
		endSimRq <= 1;
end
always @ (posedge clk_i) begin
	if (endSimRq && !wb_pending_acks) begin
		`ifdef _SIMULATION_PERF
		`ifdef PUPREDICTBRANCH
		$write ("BranchPredictHit: %1.2f%%\n",
			($bitstoreal(csrBranchPredictHit * 100) / $bitstoreal(csrBranchPredictHit + csrBranchPredictMiss)));
		`endif
		`ifdef PUPREDICTRET
		$write ("RetPredictMiss: %1d\n", csrRetPredictMiss);
		`endif
		$write ("CPI: %1.2f\n", ($bitstoreal(csrCycle) / $bitstoreal(csrInstret)));
		$fflush();
		`endif
		$finish;
	end
end
`endif

wire [WORDBITSZ -1 : 0] csrInMtvecMask = {{(WORDBITSZ-2){1'b1}}, 2'b00}; // Non-null bits get modified.
always @ (posedge clk_i) begin
	if (rst_i) begin
		// When starting from halt, mtvec must be non-null (to prevent fatalExc) and valid.
		csrMtvec <= (csrMhartidIsNonNull ? rstaddr_i : {WORDBITSZ{1'b0}});
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h305) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMtvec <= ((csrMtvec & ~csrInMtvecMask) | (csrIn & csrInMtvecMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMtvec <= (csrMtvec | (csrIn & csrInMtvecMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMtvec <= (csrMtvec & ~(csrIn & csrInMtvecMask));
		end
	end
end

wire [WORDBITSZ -1 : 0] csrInStvecMask = {{(WORDBITSZ-2){1'b1}}, 2'b00}; // Non-null bits get modified.
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrStvec <= 0;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h105) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrStvec <= ((csrStvec & ~csrInStvecMask) | (csrIn & csrInStvecMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrStvec <= (csrStvec | (csrIn & csrInStvecMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrStvec <= (csrStvec & ~(csrIn & csrInStvecMask));
		end
	end
end

always @ (posedge clk_i) begin
	irq_rdy_o <= (
		(!csrMideleg[11/*MEI*/] && csrMie[11/*MEIE*/] && (csrCurPrivIsM ? csrMstatus[3/*MIE*/] : 1'b1)) ||
		(csrMideleg[11/*MEI*/] && csrMie[9/*SEIE*/] && (csrCurPrivIsS ? csrMstatus[1/*SIE*/] : csrCurPrivIsU)));
end

always @ (posedge clk_i) begin
	irq_stb_o <= (
		(csrMip_[11/*MEIP*/] && csrMie[11/*MEIE*/] && (csrCurPrivIsM ? csrMstatus[3/*MIE*/] : 1'b1)) ||
		(csrMip_[9/*SEIP*/] && csrMie[9/*SEIE*/] && (csrCurPrivIsS ? csrMstatus[1/*SIE*/] : csrCurPrivIsU)));
end

reg [16 -1 : 0] excIrq;
always @ (posedge clk_i) begin
	// Set excIrq null when non-null in order to use only the up to date value of csrMstatus.
	// Using excTriggered prevents an asynchronous exception from triggering if a synchronous
	// exception has just triggered with csrMstatus not yet updated.
	excIrq <= (excTriggered || excIrq) ? 16'd0 : {
		4'd0,
		csrMip_[11/*MEIP*/] && csrMie[11/*MEIE*/] && (csrCurPrivIsM ? csrMstatus[3/*MIE*/] : 1'b1),
		1'b0,
		csrMip_[9/*SEIP*/] && csrMie[9/*SEIE*/] && (csrCurPrivIsS ? csrMstatus[1/*SIE*/] : csrCurPrivIsU),
		1'b0,
		csrMip_[7/*MTIP*/] && csrMie[7/*MTIE*/] && (csrCurPrivIsM ? csrMstatus[3/*MIE*/] : 1'b1),
		1'b0,
		csrMip_[5/*STIP*/] && csrMie[5/*STIE*/] && (csrCurPrivIsS ? csrMstatus[1/*SIE*/] : csrCurPrivIsU),
		1'b0,
		csrMip_[3/*MSIP*/] && csrMie[3/*MSIE*/] && (csrCurPrivIsM ? csrMstatus[3/*MIE*/] : 1'b1),
		1'b0,
		csrMip_[1/*SSIP*/] && csrMie[1/*SSIE*/] && (csrCurPrivIsS ? csrMstatus[1/*SIE*/] : csrCurPrivIsU),
		1'b0};
end

reg [17 -1 : 0] excCause; // ### comb-block-reg.
reg [WORDBITSZ -1 : 0] excEpc; // ### comb-block-reg.
reg [WORDBITSZ -1 : 0] excTval; // ### comb-block-reg.
reg [WORDBITSZ -1 : 0] excTval2; // ### comb-block-reg.
reg [2 -1 : 0] excNxtPriv; // ### comb-block-reg.
// Interrupt handling is done in following decreasing
// priority order: MEI, MSI, MTI, SEI, SSI, STI.
always @* begin
	excCause = 17'd0;
	excEpc = (eX_JumpOrBranch ? iF_pc : iD_pc);
	excTval = {WORDBITSZ{1'b0}};
	excTval2 = {WORDBITSZ{1'b0}};
	excNxtPriv = 2'b00;
	if (halted_o) begin
	// Asynchronous traps are gated by rW_stalled to prevent loosing
	// pending data set in iD_eX_rdId_isTrue, iD_eX_rdId and iD_eX_rslt.
	end else if (excIrq[11/*MEI*/] && !rW_stalled) begin
		excCause = {1'b1, 16'd11};
		excNxtPriv = 2'b11;
	end else if (excIrq[9/*SEI*/] && !rW_stalled) begin
		excCause = {1'b1, 16'd9};
		excNxtPriv = 2'b01;
	end else if (excIrq[3/*MSI*/] && !rW_stalled) begin
		excCause = {1'b1, 16'd3};
		excNxtPriv = 2'b11;
	end else if (excIrq[1/*SSI*/] && !rW_stalled) begin
		excCause = {1'b1, 16'd1};
		excNxtPriv = 2'b01;
	end else if (excIrq[7/*MTI*/] && !rW_stalled) begin
		excCause = {1'b1, 16'd7};
		excNxtPriv = 2'b11;
	end else if (excIrq[5/*STI*/] && !rW_stalled) begin
		excCause = {1'b1, 16'd5};
		excNxtPriv = 2'b01;
	// Synchronous traps are handled from here.
	end else if (iF_pc[1:0]) begin // Instruction address misaligned.
		excCause = {1'b0, 16'd0};
		excEpc = (eX_JumpOrBranch ? eX_pc : iD_pc);
		excTval = iF_pc;
		excTval2 = (eX_JumpOrBranch ? eX_insn : iD_insn);
		if (csrCurPrivIsM || !csrMedeleg[0])
			excNxtPriv = 2'b11;
		else
			excNxtPriv = 2'b01;
	end else if (!iD_insn_valid_) begin
	end else if (iD_isEbreak) begin // Breakpoint.
		excCause = {1'b0, 16'd3};
		if (csrCurPrivIsM || !csrMedeleg[3])
			excNxtPriv = 2'b11;
		else
			excNxtPriv = 2'b01;
	end else if (iD_isLoadOrLr && dcache_m_addr_misaligned) begin // Load address misaligned.
		excCause = {1'b0, 16'd4};
		excTval = dCache_m_addr_i_;
		excTval2 = iD_insn;
		if (csrCurPrivIsM || !csrMedeleg[4])
			excNxtPriv = 2'b11;
		else
			excNxtPriv = 2'b01;
	end else if (iD_isStoreOrScOrAMO && dcache_m_addr_misaligned) begin // Store/AMO address misaligned.
		excCause = {1'b0, 16'd6};
		excTval = dCache_m_addr_i_;
		excTval2 = iD_insn;
		if (csrCurPrivIsM || !csrMedeleg[6])
			excNxtPriv = 2'b11;
		else
			excNxtPriv = 2'b01;
	end else if (iD_isEcall) begin // Environment call.
		if (csrCurPrivIsU)
			excCause = {1'b0, 16'd8};
		else if (csrCurPrivIsS)
			excCause = {1'b0, 16'd9};
		else if (csrCurPrivIsM)
			excCause = {1'b0, 16'd11};
		if (csrCurPrivIsM ||
			(csrCurPrivIsU && !csrMedeleg[8]) ||
			(csrCurPrivIsS && !csrMedeleg[9]))
			excNxtPriv = 2'b11;
		else
			excNxtPriv = 2'b01;
	end else if (iD_isIllInsn || (iD_isSystem && csrCurPrivIsU) || iD_isExcCsr) begin // Illegal instruction.
		excCause = {1'b0, 16'd2};
		excTval = iD_insn;
		if (csrCurPrivIsM || !csrMedeleg[2])
			excNxtPriv = 2'b11;
		else
			excNxtPriv = 2'b01;
	end
end

assign excTriggered = (|excNxtPriv);

wire excNxtPrivIsS = (excNxtPriv == 2'b01);
wire excNxtPrivIsM = (excNxtPriv == 2'b11);

assign excTvec = (excNxtPrivIsS ? csrStvec : csrMtvec);

always @ (posedge clk_i) begin
	if (rst_i)
		csrCurPriv <= 2'b11;
	else if (excTriggered)
		csrCurPriv <= excNxtPriv;
	else if (iD_isEret && iD_insn_valid)
		csrCurPriv <= (csrCurPrivIsS ? {1'b0, csrMstatus[8]} : csrMstatus[12:11]);
end

wire [WORDBITSZ -1 : 0] csrInMstatusMask = // Non-null bits get modified.
	csrCurPrivIsS ? 'b00000000000011000000000100100010 : // MXR SUM SPP SPIE SIE.
	                'b00000000000011100001100110101010 ; // All above plus MPRV MPP MPIE MIE.
always @ (posedge clk_i) begin
	if (rst_i) begin // If (csrMhartid != 0) reset csrMstatus.MIE to 1.
		csrMstatus <= (csrMhartidIsNonNull ? 'b1000 : 'd0);
	end else if (excTriggered) begin
		if (excNxtPrivIsS)
			csrMstatus <= {
				csrMstatus[WORDBITSZ-1:9],
				csrCurPriv[0], /*SPP*/
				csrMstatus[7:6],
				csrMstatus[1], /*SPIE*/
				csrMstatus[4:2],
				1'b0, /*SIE*/
				csrMstatus[0]};
		else
			csrMstatus <= {
				csrMstatus[WORDBITSZ-1:13],
				csrCurPriv, /*MPP*/
				csrMstatus[10:8],
				csrMstatus[3], /*MPIE*/
				csrMstatus[6:4],
				1'b0, /*MIE*/
				csrMstatus[2:0]};
	end else if (iD_isEret && iD_insn_valid) begin
		if (csrCurPrivIsS)
			csrMstatus <= {
				csrMstatus[WORDBITSZ-1:9],
				1'b0, /*SPP*/
				csrMstatus[7:6],
				1'b1, /*SPIE*/
				csrMstatus[4:2],
				csrMstatus[5], /*SIE*/
				csrMstatus[0]};
		else
			csrMstatus <= {
				csrMstatus[WORDBITSZ-1:13],
				2'b00, /*MPP*/
				csrMstatus[10:8],
				1'b1, /*MPIE*/
				csrMstatus[6:4],
				csrMstatus[7], /*MIE*/
				csrMstatus[2:0]};
	end else if (iD_isCSRvalid && iD_Iimm[11:10] == 2'b00 && iD_Iimm[7:0] == 8'h00) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMstatus <= ((csrMstatus & ~csrInMstatusMask) | (csrIn & csrInMstatusMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMstatus <= (csrMstatus | (csrIn & csrInMstatusMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMstatus <= (csrMstatus & ~(csrIn & csrInMstatusMask));
		end
	end
end

wire [WORDBITSZ -1 : 0] csrInMepcMask = {{(WORDBITSZ-2){1'b1}}, 2'b00}; // Non-null bits get modified.
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMepc <= 0;
	end else if (excTriggered) begin
		if (excNxtPrivIsM)
			csrMepc <= excEpc;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h341) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMepc <= ((csrMepc & ~csrInMepcMask) | (csrIn & csrInMepcMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMepc <= (csrMepc | (csrIn & csrInMepcMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMepc <= (csrMepc & ~(csrIn & csrInMepcMask));
		end
	end
end

wire [WORDBITSZ -1 : 0] csrInSepcMask = {{(WORDBITSZ-2){1'b1}}, 2'b00}; // Non-null bits get modified.
always @ (posedge clk_i) begin
	if (rst_i) begin
		csrSepc <= 0;
	end else if (excTriggered) begin
		if (excNxtPrivIsS)
			csrSepc <= excEpc;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h141) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrSepc <= ((csrSepc & ~csrInSepcMask) | (csrIn & csrInSepcMask));
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrSepc <= (csrSepc | (csrIn & csrInSepcMask));
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrSepc <= (csrSepc & ~(csrIn & csrInSepcMask));
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMcause <= 0;
	end else if (excTriggered) begin
		if (excNxtPrivIsM)
			csrMcause <= {excCause[16], {(WORDBITSZ-17){1'b0}}, excCause[15:0]};
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h342) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMcause <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMcause <= (csrMcause | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMcause <= (csrMcause & ~csrIn);
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrScause <= 0;
	end else if (excTriggered) begin
		if (excNxtPrivIsS)
			csrScause <= {excCause[16], {(WORDBITSZ-17){1'b0}}, excCause[15:0]};
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h142) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrScause <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrScause <= (csrScause | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrScause <= (csrScause & ~csrIn);
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMtval <= 0;
	end else if (excTriggered) begin
		if (excNxtPrivIsM)
			csrMtval <= excTval;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h343) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMtval <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMtval <= (csrMtval | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMtval <= (csrMtval & ~csrIn);
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrStval <= 0;
	end else if (excTriggered) begin
		if (excNxtPrivIsS)
			csrStval <= excTval;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h143) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrStval <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrStval <= (csrStval | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrStval <= (csrStval & ~csrIn);
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMtval2 <= 0;
	end else if (excTriggered) begin
		if (excNxtPrivIsM)
			csrMtval2 <= excTval2;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h34b) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMtval2 <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMtval2 <= (csrMtval2 | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMtval2 <= (csrMtval2 & ~csrIn);
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrStval2 <= 0;
	end else if (excTriggered) begin
		if (excNxtPrivIsS)
			csrStval2 <= excTval2;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h14b) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrStval2 <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrStval2 <= (csrStval2 | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrStval2 <= (csrStval2 & ~csrIn);
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrMscratch <= 0;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h340) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrMscratch <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrMscratch <= (csrMscratch | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrMscratch <= (csrMscratch & ~csrIn);
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		csrSscratch <= 0;
	end else if (iD_isCSRvalid && iD_Iimm[11:0] == 12'h140) begin
		if          (iD_func3[1:0] == 2'b01) begin // csrrw.
			csrSscratch <= csrIn;
		end else if (iD_func3[1:0] == 2'b10) begin // csrrs.
			csrSscratch <= (csrSscratch | csrIn);
		end else if (iD_func3[1:0] == 2'b11) begin // csrrc.
			csrSscratch <= (csrSscratch & ~csrIn);
		end
	end
end

always @ (posedge clk_i)
	csrMhartid <= id_i;

localparam MXL = (WORDBITSZ/32); // Valid only when WORDBITSZ == 32 or WORDBITSZ == 64.
always @*
	csrMisa = {MXL[1:0],
		{(WORDBITSZ-28){1'b0}},
		13'b0000010100000,
		`ifdef PURV32M
		1'b1,
		`else
		1'b0,
		`endif
		12'b000100000001};

generate if (WORDBITSZ == 32) begin
always @* begin
	(* parallel_case *) case (iD_Iimm[11:0])
	12'h100: eX_csrOut_i = (csrMstatus & 'b00000000000011000000000100110010);
	12'h104: eX_csrOut_i = (csrMie & 16'b0000001000100010);
	12'h105: eX_csrOut_i = csrStvec;
	12'h140: eX_csrOut_i = csrSscratch;
	12'h141: eX_csrOut_i = csrSepc;
	12'h142: eX_csrOut_i = csrScause;
	12'h143: eX_csrOut_i = csrStval;
	12'h144: eX_csrOut_i = (csrMip & 16'b0000001000100010);
	12'h14b: eX_csrOut_i = csrStval2;
	12'h14d: eX_csrOut_i = csrStimecmp;
	12'h15d: eX_csrOut_i = csrStimecmp[64-1:WORDBITSZ];
	12'h300: eX_csrOut_i = csrMstatus;
	12'h301: eX_csrOut_i = csrMisa;
	12'h302: eX_csrOut_i = csrMedeleg;
	12'h303: eX_csrOut_i = csrMideleg;
	12'h304: eX_csrOut_i = csrMie;
	12'h305: eX_csrOut_i = csrMtvec;
	12'h340: eX_csrOut_i = csrMscratch;
	12'h341: eX_csrOut_i = csrMepc;
	12'h342: eX_csrOut_i = csrMcause;
	12'h343: eX_csrOut_i = csrMtval;
	12'h344: eX_csrOut_i = csrMip;
	12'h34b: eX_csrOut_i = csrMtval2;
	12'h34d: eX_csrOut_i = csrMtimecmp;
	12'h35d: eX_csrOut_i = csrMtimecmp[64-1:WORDBITSZ];
	12'hc00: eX_csrOut_i = csrCycle[WORDBITSZ-1:0];
	12'hc01: eX_csrOut_i = csrCycle[WORDBITSZ-1:0];
	12'hc02: eX_csrOut_i = csrInstret[WORDBITSZ-1:0];
	12'hc80: eX_csrOut_i = csrCycle[64-1:WORDBITSZ];
	12'hc81: eX_csrOut_i = csrCycle[64-1:WORDBITSZ];
	12'hc82: eX_csrOut_i = csrInstret[64-1:WORDBITSZ];
	12'hcc0: eX_csrOut_i = csrClkFreq; // Using User CSRs Non-standard read-only.
	12'hf14: eX_csrOut_i = csrMhartid;
	default: eX_csrOut_i = {WORDBITSZ{1'b0}};
	endcase
end
end endgenerate
generate if (WORDBITSZ == 64) begin
always @* begin
	(* parallel_case *) case (iD_Iimm[11:0])
	12'h100: eX_csrOut_i = (csrMstatus & 'b00000000000011000000000100110010);
	12'h104: eX_csrOut_i = (csrMie & 16'b0000001000100010);
	12'h105: eX_csrOut_i = csrStvec;
	12'h140: eX_csrOut_i = csrSscratch;
	12'h141: eX_csrOut_i = csrSepc;
	12'h142: eX_csrOut_i = csrScause;
	12'h143: eX_csrOut_i = csrStval;
	12'h144: eX_csrOut_i = (csrMip & 16'b0000001000100010);
	12'h14b: eX_csrOut_i = csrStval2;
	12'h14d: eX_csrOut_i = csrStimecmp;
	12'h300: eX_csrOut_i = csrMstatus;
	12'h301: eX_csrOut_i = csrMisa;
	12'h302: eX_csrOut_i = csrMedeleg;
	12'h303: eX_csrOut_i = csrMideleg;
	12'h304: eX_csrOut_i = csrMie;
	12'h305: eX_csrOut_i = csrMtvec;
	12'h340: eX_csrOut_i = csrMscratch;
	12'h341: eX_csrOut_i = csrMepc;
	12'h342: eX_csrOut_i = csrMcause;
	12'h343: eX_csrOut_i = csrMtval;
	12'h344: eX_csrOut_i = csrMip;
	12'h34b: eX_csrOut_i = csrMtval2;
	12'h34d: eX_csrOut_i = csrMtimecmp;
	12'hc00: eX_csrOut_i = csrCycle;
	12'hc01: eX_csrOut_i = csrCycle;
	12'hc02: eX_csrOut_i = csrInstret;
	12'hcc0: eX_csrOut_i = csrClkFreq; // Using User CSRs Non-standard read-only.
	12'hf14: eX_csrOut_i = csrMhartid;
	default: eX_csrOut_i = {WORDBITSZ{1'b0}};
	endcase
end
end endgenerate
