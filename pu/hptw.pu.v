// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

if (rst_i || instrbufrst_posedge) begin

	hptwistate <= HPTWSTATEPGD0;
	hptwidone <= 0;

end else if (hptwidone) begin

	if (!itlbwritten) begin
		hptwidone <= 1'b0;
		hptwistate <= HPTWSTATEPGD0;
	end

end else if (dcachemasterrdy && (hptwmemstate == HPTWMEMSTATEINSTR || hptwistate_eq_HPTWSTATEPGD1 || hptwistate_eq_HPTWSTATEPTE1)) begin

	if (hptwistate_eq_HPTWSTATEPGD1) begin
		if (dcachemasterdato[5])
			hptwipte <= {dcachemasterdato[ARCHBITSZ-1:12], 12'b0};
		else
			hptwidone <= 1'b1;
	end else if (hptwistate_eq_HPTWSTATEPTE1)
		hptwidone <= 1'b1;

	hptwistate <= hptwistate + 1'b1;
end

if (rst_i) begin

	hptwdstate <= HPTWSTATEPGD0;
	hptwddone <= 0;

end else if (hptwddone) begin

	if (!dtlbwritten) begin
		hptwddone <= 1'b0;
		hptwdstate <= HPTWSTATEPGD0;
	end

end else if (dcachemasterrdy && (hptwmemstate == HPTWMEMSTATEDATA || hptwdstate_eq_HPTWSTATEPGD1 || hptwdstate_eq_HPTWSTATEPTE1)) begin

	if (hptwdstate_eq_HPTWSTATEPGD1) begin
		if (dcachemasterdato[5])
			hptwdpte <= {dcachemasterdato[ARCHBITSZ-1:12], 12'b0};
		else
			hptwddone <= 1'b1;
	end else if (hptwdstate_eq_HPTWSTATEPTE1)
		hptwddone <= 1'b1;

	hptwdstate <= hptwdstate + 1'b1;
end
