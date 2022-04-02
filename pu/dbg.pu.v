// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The format of a request is as follow:
// |cmd: 3bits|arg: 5bits|
// The data returned is always (ARCHBITSZ/8) bytes in little-endian.
// The valid cmd values are:
// - DBGCMDSELECT:
//  Select the pu which must receive subsequent commands.
//  arg is the index of the pu.
//  No data is returned.
// - DBGCMDSTEP:
//  When arg is DBGARGSTEPDISABLE, the debug interface
//  gets disabled and the pu resumes executing instructions.
//  When arg is DBGARGSTEPSTOP, the debug interface gets
//  enabled and the pu stops executing instructions.
//  When arg is DBGARGSTEPONCE, the debug interface gets
//  enabled and the pu executes a single instruction.
//  When arg is DBGARGSTEPTILL, the debug interface gets
//  enabled and the pu executes instructions until
//  the address from the instruction pointer register is
//  the same as the value loaded through DBGCMDLOADIARG,
//  or until a command other than DBGCMDSTEP(DBGARGSTEPTILL)
//  is issued.
//  The instruction pointer register is returned if arg was
//  DBGARGSTEPONCE or DBGARGSTEPTILL, otherwise no data is returned.
// - DBGCMDGETOPCODE:
//  arg is meaningless.
//  The two bytes opcode of the next instruction to execute
//  are set in the two least significant bytes of the (ARCHBITSZ/8)
//  bytes returned.
// - DBGCMDGETIP:
//  arg is meaningless.
//  The value of the instruction pointer register is returned.
// - DBGCMDGETGPR:
//  The value of the GPR indexed by arg is returned.
// - DBGCMDSETGPR:
//  The value of the GPR indexed by arg is set using the value
//  loaded through DBGCMDLOADIARG.
//  No data is returned.
// - DBGCMDLOADIARG;
//  The 4lsb of arg are shifted in the 4msb of an internal register
//  used as argument; to load all ARCHBITSZ bits of that register,
//  this commands must be issued (ARCHBITSZ/4) times.
//  No data is returned.

// Logic that set dbgselected.
if (rst_i)
	dbgselected <= 0;
else begin
	// Note that dbgrcvrphy.received is high for a single clock cycle.
	if (dbg_rx_rcvd_i && dbg_rx_data_i[7:5] == DBGCMDSELECT)
		dbgselected <= (dbg_rx_data_i[4:0] == id_i);
end

// Logic that set dbgen.
if (rst_i)
	dbgen <= brkonrst_i;
else begin
	// Note that dbgrcvrphy.received is high for a single clock cycle.
	if (dbg_rx_rcvd_i && dbg_rx_data_i[7:5] == DBGCMDSTEP && dbgselected)
		dbgen <= (dbg_rx_data_i[4:0] != DBGARGSTEPDISABLE);
end

if (rst_i) begin
	dbgcmd <= DBGCMDSTEP;
	dbgarg <= DBGARGSTEPSTOP;
	dbgcounter <= 0;
	dbgcntren <= 0;
end else if (dbgcounter && dbgcntren) begin
	// Decrement dbgcounter for each byte transmitted.
	if (dbg_tx_rdy_i_negedge) begin
		dbgiarg <= {{8{1'b0}}, dbgiarg[ARCHBITSZ-1:8]};
		dbgcounter <= dbgcounterminusone;
		dbgcntren <= |dbgcounterminusone;
	end
end else if (dbgcmdsteptilldone &&
	(sequencerready && !oplicounter)) begin
	dbgcmd <= DBGCMDSTEP;
	dbgarg <= DBGARGSTEPSTOP;
	dbgiarg <= {ip, 1'b0};
	dbgcounter <= (ARCHBITSZ/8);
	dbgcntren <= 1;
// Note that dbgrcvrphy.received is high for a single clock cycle.
end else if (dbg_rx_rcvd_i && dbgselected) begin
	if (dbg_rx_data_i[7:5] == DBGCMDSTEP &&
		dbg_rx_data_i[4:0] == DBGARGSTEPONCE &&
		(sequencerready && !oplicounter)) begin
		dbgcmd <= dbg_rx_data_i[7:5];
		dbgarg <= dbg_rx_data_i[4:0];
		dbgiarg <= {ip, 1'b0};
	end else if (dbg_rx_data_i[7:5] == DBGCMDSTEP &&
		dbg_rx_data_i[4:0] == DBGARGSTEPTILL &&
		(sequencerready && !oplicounter)) begin
		dbgcmd <= dbg_rx_data_i[7:5];
		dbgarg <= dbg_rx_data_i[4:0];
	end else if (dbg_rx_data_i[7:5] == DBGCMDLOADIARG) begin
		dbgcmd <= dbg_rx_data_i[7:5];
		dbgarg <= dbg_rx_data_i[4:0];
		dbgiarg <= {dbg_rx_data_i[3:0], dbgiarg[ARCHBITSZ-1:4]};
	end else if (dbg_rx_data_i[7:5] == DBGCMDGETOPCODE &&
		(sequencerready && !oplicounter)) begin
		dbgcmd <= dbg_rx_data_i[7:5];
		dbgarg <= dbg_rx_data_i[4:0];
		dbgiarg <= {{(ARCHBITSZ-16){1'b0}}, instrbufdato0, instrbufdato1};
		dbgcounter <= (ARCHBITSZ/8);
		dbgcntren <= 1;
	end else if (dbg_rx_data_i[7:5] == DBGCMDGETIP &&
		(sequencerready && !oplicounter)) begin
		dbgcmd <= dbg_rx_data_i[7:5];
		dbgarg <= dbg_rx_data_i[4:0];
		dbgiarg <= {ip, 1'b0};
		dbgcounter <= (ARCHBITSZ/8);
		dbgcntren <= 1;
	end else if (dbg_rx_data_i[7:5] == DBGCMDGETGPR &&
		(sequencerready && !oplicounter)) begin
		dbgcmd <= dbg_rx_data_i[7:5];
		dbgarg <= dbg_rx_data_i[4:0];
		dbgiarg <= dbggprdata;
		dbgcounter <= (ARCHBITSZ/8);
		dbgcntren <= 1;
	end
end

// Sampling used for negedge detection.
dbg_tx_rdy_i_sampled <= dbg_tx_rdy_i;
