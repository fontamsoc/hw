// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Implementation of PerIntR which allows multiple slave devices to
// be mapped in an address space accessible by multiple master devices.
// This implementation uses registers instead of combinational logic
// to compute the slave device to index, which allows using higher
// clock frequencies.

// PerIntR stays with the same master device for as long as the
// operation to execute is not PINOOP, otherwise PerIntR select
// the next master device.
// During the period in which no PINOOP is seen from the currently
// selected master device, there can be a mix of read or write operations
// anywhere in the address space; hence, a master device must include
// PINOOP in between read or write operations that take too long,
// so as to allow PerIntR to serve other master devices; similarly,
// slave devices must not keep their output memrdy low for too long,
// so as to allow PerIntR to look at the next operation from
// the currently selected master device as soon as possible.

// The clock used by master and slave devices to connect to PerIntR
// must be the same.

// Endianness is determined by the device receiving a memory
// operation (slave device), and not by the device issuing
// the memory operation (master device).
// Hence, endianness can vary from one slave device to another,
// based on how they store the data that they receive.
// Little-endian is prefered with the RAM memory device.
// Little-endian has the property that, the same value can be read
// from memory at different lengths without using different addresses.
// For example, a 32-bit memory location with content 4a000000 can be read at
// the same address as either 8-bit (4a), 16-bit (004a), or 32-bit (0000004a).

// Parameters:
//
// MASTERCOUNT
// 	Number of master devices.
// 	It must be non-null. ei: `define MASTERCOUNT 3
//
// SLAVECOUNT
// 	Number of slave devices.
// 	It must be non-null. ei: `define SLAVECOUNT 3
//
// DEFAULTSLAVEINDEX
// 	Default slave device when a match could not
// 	be found in the address space.
// 	It must be less than SLAVECOUNT.
//
// FIRSTSLAVEADDR
// 	Byte address of slave device at index 0.

`ifndef PI1R_V
`define PI1R_V

`include "lib/addr.v"

module pi1r (

	 rst_i

	,clk_i

	,m_op_i_flat
	,m_addr_i_flat
	,m_data_i_flat
	,m_data_o_flat
	,m_sel_i_flat
	,m_rdy_o_flat

	,s_op_o_flat
	,s_addr_o_flat
	,s_data_o_flat
	,s_data_i_flat
	,s_sel_o_flat
	,s_rdy_i_flat
	,s_mapsz_i_flat
);

`include "lib/clog2.v"

parameter MASTERCOUNT       = 1;
parameter SLAVECOUNT        = 1;
parameter DEFAULTSLAVEINDEX = 0;
parameter FIRSTSLAVEADDR    = 0;

parameter ARCHBITSZ = 16;

localparam CLOG2MASTERCOUNT = clog2(MASTERCOUNT);
localparam CLOG2SLAVECOUNT  = clog2(SLAVECOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [(2 * MASTERCOUNT) -1 : 0]             m_op_i_flat;
input  wire [(ADDRBITSZ * MASTERCOUNT) -1 : 0]     m_addr_i_flat;
input  wire [(ARCHBITSZ * MASTERCOUNT) -1 : 0]     m_data_i_flat;
output wire [(ARCHBITSZ * MASTERCOUNT) -1 : 0]     m_data_o_flat;
input  wire [((ARCHBITSZ/8) * MASTERCOUNT) -1 : 0] m_sel_i_flat;
output wire [MASTERCOUNT -1 : 0]                   m_rdy_o_flat;

output wire [(2 * SLAVECOUNT) -1 : 0]             s_op_o_flat;
output wire [(ADDRBITSZ * SLAVECOUNT) -1 : 0]     s_addr_o_flat;
input  wire [(ARCHBITSZ * SLAVECOUNT) -1 : 0]     s_data_i_flat;
output wire [(ARCHBITSZ * SLAVECOUNT) -1 : 0]     s_data_o_flat;
output wire [((ARCHBITSZ/8) * SLAVECOUNT) -1 : 0] s_sel_o_flat;
input  wire [SLAVECOUNT -1 : 0]                   s_rdy_i_flat;
input  wire [(ARCHBITSZ * SLAVECOUNT) -1 : 0]     s_mapsz_i_flat;

wire [2 -1 : 0] masterop [MASTERCOUNT -1 : 0];
genvar gen_masterop_idx;
generate for (gen_masterop_idx = 0; gen_masterop_idx < MASTERCOUNT; gen_masterop_idx = gen_masterop_idx + 1) begin :gen_masterop
assign masterop[gen_masterop_idx] = m_op_i_flat[((gen_masterop_idx+1) * 2) -1 : gen_masterop_idx * 2];
end endgenerate

wire [ADDRBITSZ -1 : 0] masteraddr [MASTERCOUNT -1 : 0];
genvar gen_masteraddr_idx;
generate for (gen_masteraddr_idx = 0; gen_masteraddr_idx < MASTERCOUNT; gen_masteraddr_idx = gen_masteraddr_idx + 1) begin :gen_masteraddr
assign masteraddr[gen_masteraddr_idx] = m_addr_i_flat[((gen_masteraddr_idx+1) * ADDRBITSZ) -1 : gen_masteraddr_idx * ADDRBITSZ];
end endgenerate

wire [ARCHBITSZ -1 : 0] masterdati [MASTERCOUNT -1 : 0];
genvar gen_masterdati_idx;
generate for (gen_masterdati_idx = 0; gen_masterdati_idx < MASTERCOUNT; gen_masterdati_idx = gen_masterdati_idx + 1) begin :gen_masterdati
assign masterdati[gen_masterdati_idx] = m_data_i_flat[((gen_masterdati_idx+1) * ARCHBITSZ) -1 : gen_masterdati_idx * ARCHBITSZ];
end endgenerate

wire [ARCHBITSZ -1 : 0] masterdato [MASTERCOUNT -1 : 0];
genvar gen_m_data_o_flat_idx;
generate for (gen_m_data_o_flat_idx = 0; gen_m_data_o_flat_idx < MASTERCOUNT; gen_m_data_o_flat_idx = gen_m_data_o_flat_idx + 1) begin :gen_m_data_o_flat
assign m_data_o_flat[((gen_m_data_o_flat_idx+1) * ARCHBITSZ) -1 : gen_m_data_o_flat_idx * ARCHBITSZ] = masterdato[gen_m_data_o_flat_idx];
end endgenerate

wire [(ARCHBITSZ/8) -1 : 0] masterbytsel [MASTERCOUNT -1 : 0];
genvar gen_masterbytsel_idx;
generate for (gen_masterbytsel_idx = 0; gen_masterbytsel_idx < MASTERCOUNT; gen_masterbytsel_idx = gen_masterbytsel_idx + 1) begin :gen_masterbytsel
assign masterbytsel[gen_masterbytsel_idx] = m_sel_i_flat[((gen_masterbytsel_idx+1) * (ARCHBITSZ/8)) -1 : gen_masterbytsel_idx * (ARCHBITSZ/8)];
end endgenerate

wire masterrdy [MASTERCOUNT -1 : 0];
genvar gen_m_rdy_o_flat_idx;
generate for (gen_m_rdy_o_flat_idx = 0; gen_m_rdy_o_flat_idx < MASTERCOUNT; gen_m_rdy_o_flat_idx = gen_m_rdy_o_flat_idx + 1) begin :gen_m_rdy_o_flat
assign m_rdy_o_flat[((gen_m_rdy_o_flat_idx+1) * 1) -1 : gen_m_rdy_o_flat_idx * 1] = masterrdy[gen_m_rdy_o_flat_idx];
end endgenerate

wire [2 -1 : 0] slaveop [SLAVECOUNT -1 : 0];
genvar gen_s_op_o_flat_idx;
generate for (gen_s_op_o_flat_idx = 0; gen_s_op_o_flat_idx < SLAVECOUNT; gen_s_op_o_flat_idx = gen_s_op_o_flat_idx + 1) begin :gen_s_op_o_flat
assign s_op_o_flat[((gen_s_op_o_flat_idx+1) * 2) -1 : gen_s_op_o_flat_idx * 2] = slaveop[gen_s_op_o_flat_idx];
end endgenerate

wire [ADDRBITSZ -1 : 0] slaveaddr [SLAVECOUNT -1 : 0];
genvar gen_s_addr_o_flat_idx;
generate for (gen_s_addr_o_flat_idx = 0; gen_s_addr_o_flat_idx < SLAVECOUNT; gen_s_addr_o_flat_idx = gen_s_addr_o_flat_idx + 1) begin :gen_s_addr_o_flat
assign s_addr_o_flat[((gen_s_addr_o_flat_idx+1) * ADDRBITSZ) -1 : gen_s_addr_o_flat_idx * ADDRBITSZ] = slaveaddr[gen_s_addr_o_flat_idx];
end endgenerate

wire [ARCHBITSZ -1 : 0] slavedati [SLAVECOUNT -1 : 0];
genvar gen_slavedati_idx;
generate for (gen_slavedati_idx = 0; gen_slavedati_idx < SLAVECOUNT; gen_slavedati_idx = gen_slavedati_idx + 1) begin :gen_slavedati
assign slavedati[gen_slavedati_idx] = s_data_i_flat[((gen_slavedati_idx+1) * ARCHBITSZ) -1 : gen_slavedati_idx * ARCHBITSZ];
end endgenerate

wire [ARCHBITSZ -1 : 0] slavedato [SLAVECOUNT -1 : 0];
genvar gen_s_data_o_flat_idx;
generate for (gen_s_data_o_flat_idx = 0; gen_s_data_o_flat_idx < SLAVECOUNT; gen_s_data_o_flat_idx = gen_s_data_o_flat_idx + 1) begin :gen_s_data_o_flat
assign s_data_o_flat[((gen_s_data_o_flat_idx+1) * ARCHBITSZ) -1 : gen_s_data_o_flat_idx * ARCHBITSZ] = slavedato[gen_s_data_o_flat_idx];
end endgenerate

wire [(ARCHBITSZ/8) -1 : 0] slavebytsel [SLAVECOUNT -1 : 0];
genvar gen_s_sel_o_flat_idx;
generate for (gen_s_sel_o_flat_idx = 0; gen_s_sel_o_flat_idx < SLAVECOUNT; gen_s_sel_o_flat_idx = gen_s_sel_o_flat_idx + 1) begin :gen_s_sel_o_flat
assign s_sel_o_flat[((gen_s_sel_o_flat_idx+1) * (ARCHBITSZ/8)) -1 : gen_s_sel_o_flat_idx * (ARCHBITSZ/8)] = slavebytsel[gen_s_sel_o_flat_idx];
end endgenerate

wire slaverdy [SLAVECOUNT -1 : 0];
genvar gen_slaverdy_idx;
generate for (gen_slaverdy_idx = 0; gen_slaverdy_idx < SLAVECOUNT; gen_slaverdy_idx = gen_slaverdy_idx + 1) begin :gen_slaverdy
assign slaverdy[gen_slaverdy_idx] = s_rdy_i_flat[((gen_slaverdy_idx+1) * 1) -1 : gen_slaverdy_idx * 1];
end endgenerate

wire [ARCHBITSZ -1 : 0] slavemapsz [SLAVECOUNT -1 : 0];
genvar gen_slavemapsz_idx;
generate for (gen_slavemapsz_idx = 0; gen_slavemapsz_idx < SLAVECOUNT; gen_slavemapsz_idx = gen_slavemapsz_idx + 1) begin :gen_slavemapsz
assign slavemapsz[gen_slavemapsz_idx] = s_mapsz_i_flat[((gen_slavemapsz_idx+1) * ARCHBITSZ) -1 : gen_slavemapsz_idx * ARCHBITSZ];
end endgenerate

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg [CLOG2MASTERCOUNT -1 : 0] masteridx;

reg [CLOG2MASTERCOUNT -1 : 0] mstrhinxt;
reg [CLOG2MASTERCOUNT -1 : 0] mstrhiidx;

wire masterop_mstrhiidx_not_PINOOP = (masterop[mstrhiidx] != PINOOP);
always @ (posedge clk_i) begin
	if (MASTERCOUNT > 1) begin
		if (rst_i || !mstrhiidx || masterop_mstrhiidx_not_PINOOP) begin
			if (masterop_mstrhiidx_not_PINOOP)
				mstrhinxt <= mstrhiidx;
			mstrhiidx <= (MASTERCOUNT - 1);
		end else
			mstrhiidx <= mstrhiidx - 1'b1;
	end
end

reg [CLOG2MASTERCOUNT -1 : 0] mstrhi;

wire [2 -1 : 0] masteropmasteridx = masterop[masteridx];

wire [ARCHBITSZ -1 : 0] masteraddrmasteridx;

addr #(
	.ARCHBITSZ (ARCHBITSZ)
) addr (
	 .addr_i (masteraddr[masteridx])
	,.sel_i  (masterbytsel[masteridx])
	,.addr_o (masteraddrmasteridx)
);

wire masterrdymasteridx = masterrdy[masteridx];

reg [2 -1 : 0] masteropsaved;
always @ (posedge clk_i) begin
	if (rst_i)
		masteropsaved <= PINOOP;
	if (masterrdymasteridx)
		masteropsaved <= masteropmasteridx;
end

wire slaverdyslaveidx;

// Note also that to prevent a lock-up due to
// slaverdyslaveidx null, it is important to check
// (slaveopsaved == PINOOP) which tells whether
// slaverdyslaveidx is null from a PINOOP operation.
reg [2 -1 : 0] slaveopsaved;

wire slaveidxrdy_and_not_slaveidxinvalid;

// Logic that increments masteridx.
always @ (posedge clk_i) begin
	if (MASTERCOUNT > 1) begin
		if (rst_i)
			mstrhi <= (MASTERCOUNT - 1);
		else if (masterrdymasteridx && masteropmasteridx == PINOOP ||
			(!slaverdyslaveidx && slaveidxrdy_and_not_slaveidxinvalid && slaveopsaved == PINOOP &&
				!masteropmasteridx[1] /* this check waits for a previous PIRDOP or PIRWOP */)) begin
			// The next master device is selected when the previous
			// operation completed and the next operation is PINOOP.
			if (masteridx < mstrhi)
				masteridx <= masteridx + 1'b1;
			else begin
				masteridx <= 0;
				mstrhi <= mstrhinxt;
			end
		end
	end else
		masteridx <= 0;
end

reg [ARCHBITSZ -1 : 0] addrspace [SLAVECOUNT -1 : 0];
reg addrspacerdy;

reg [CLOG2SLAVECOUNT -1 : 0] slaveidx;
reg [ARCHBITSZ -1 : 0] slavemapszslaveidx;
reg [ARCHBITSZ -1 : 0] addrspaceslaveidx;
reg [ARCHBITSZ -1 : 0] addrspaceslaveidxlo; // Also used to initialize addrspace.
reg slaveidxrdy;
reg slaveidxbsy;

wire slaveidx_not_max = (slaveidx < (SLAVECOUNT-1));

// Determine whether slaveidx needs to be recomputed.
wire slaveidxinvalid = (masteropmasteridx != PINOOP &&
	masteraddrmasteridx != addrspaceslaveidxlo &&
	!(masteraddrmasteridx >= addrspaceslaveidxlo &&
	  masteraddrmasteridx <= addrspaceslaveidx));

wire [ARCHBITSZ -1 : 0] slavemapszslaveidxplusaddrspaceslaveidxlo = (slavemapszslaveidx + addrspaceslaveidxlo);

always @ (posedge clk_i) begin

	slavemapszslaveidx <= slavemapsz[slaveidx];

	addrspaceslaveidx <= addrspace[slaveidx];

	// Logic which on reset computes addrspace
	// using the size of each slave device mapping;
	// and after reset computes slaveidx using addrspace.
	if (rst_i) begin

		addrspacerdy <= 1'b0;

		slaveidx <= 0;

		slaveidxrdy <= 1'b0;

		addrspaceslaveidxlo <= FIRSTSLAVEADDR;

		slaveidxbsy <= 1'b1;

	end else if (slaveidxbsy) begin

		slaveidxbsy <= 1'b0;

	end else if (!addrspacerdy) begin

		if (slaveidx_not_max) begin

			addrspaceslaveidxlo <= slavemapszslaveidxplusaddrspaceslaveidxlo;

			slaveidx <= slaveidx + 1'b1;

			slaveidxbsy <= 1'b1;

		end else begin

			addrspaceslaveidxlo <= FIRSTSLAVEADDR;

			slaveidx <= 0;

			addrspacerdy <= 1'b1;

			slaveidxbsy <= 1'b1;

			// Next state will be for:
			// slaveidxrdy == 0 with slaveidx == 0;
			// That state will compute slaveidx as though
			// it was due to slaveidxinvalid; this state
			// set addrspaceslaveidxlo for next state.
		end

		addrspace[slaveidx] <= slavemapszslaveidxplusaddrspaceslaveidxlo - 1'b1;

	end else if (!slaveidxrdy) begin

		if (!slaveidxinvalid)
			slaveidxrdy <= 1'b1;
		else if (slaveidx_not_max) begin
			addrspaceslaveidxlo <= addrspaceslaveidx + 1'b1;
			slaveidx <= slaveidx + 1'b1;
			slaveidxbsy <= 1'b1;
		end else begin
			addrspaceslaveidxlo <= masteraddrmasteridx;
			slaveidx <= DEFAULTSLAVEINDEX;
			if (slaveidx == DEFAULTSLAVEINDEX) begin
				// Set after slaveidx has been used to compute addrspaceslaveidx.
				slaveidxrdy <= 1'b1;
			end
			slaveidxbsy <= 1'b1;
		end

	end else if (slaveidxinvalid) begin
		slaveidxrdy <= 1'b0;
		slaveidx <= 0;
		addrspaceslaveidxlo <= FIRSTSLAVEADDR;
		slaveidxbsy <= 1'b1;
	end
end

// slaveidxsaved is used so as to be able to retrieve
// a result from a previous memory read operation or wait
// that a previous read memory operation complete.
reg [CLOG2SLAVECOUNT -1 : 0] slaveidxsaved;
// Register which becomes true when a previous memory read operation
// is pending slaverdy[slaveidxsaved] becoming true so that
// the value of slavedati[slaveidxsaved], which is valid for
// a single clock cycle, can be captured.
reg slaverdyslaveidxreadoppending;
reg [ARCHBITSZ -1 : 0] masterdatomasteridx;

wire slaverdyslaveidxsaved = slaverdy[slaveidxsaved];

wire slaverdyslaveidxsaved_and_slaverdyslaveidxreadoppending = (slaverdyslaveidxsaved && slaverdyslaveidxreadoppending);

wire [ARCHBITSZ -1 : 0] slavedatislaveidxsaved = slavedati[slaveidxsaved];

wire readoprdy = (masterrdymasteridx && (masteropmasteridx == PIRDOP || masteropmasteridx == PIRWOP));

assign slaverdyslaveidx = slaverdy[slaveidx];

assign slaveidxrdy_and_not_slaveidxinvalid = (!slaveidxbsy && slaveidxrdy && !slaveidxinvalid);

// Logic updating slaveidxsaved, slaverdyslaveidxreadoppending and masterdatomasteridx.
always @ (posedge clk_i) begin

	if (rst_i) begin

		slaverdyslaveidxreadoppending <= 1'b0;

	end else if (slaverdyslaveidxsaved_and_slaverdyslaveidxreadoppending) begin

		masterdatomasteridx <= slavedatislaveidxsaved;

		if (readoprdy)
			slaveidxsaved <= slaveidx;
		else
			slaverdyslaveidxreadoppending <= 1'b0;

	end else if (readoprdy) begin
		slaveidxsaved <= slaveidx;
		slaverdyslaveidxreadoppending <= 1'b1;
	end
end

always @ (posedge clk_i) begin
	if (rst_i)
		slaveopsaved <= PIWROP;
	else if (slaveidxrdy_and_not_slaveidxinvalid && slaverdyslaveidx)
		slaveopsaved <= slaveop[slaveidx];
end

// A new memory operation from the indexed master
// device executes only if the previous memory
// read operation completed.
wire nextoprdy = ((slaverdyslaveidxsaved_and_slaverdyslaveidxreadoppending || !slaverdyslaveidxreadoppending) &&
	slaveidxrdy_and_not_slaveidxinvalid && slaverdyslaveidx);

// Combinational logics that set the masters outputs.

wire [ARCHBITSZ -1 : 0] masterdatoi = (slaverdyslaveidxsaved_and_slaverdyslaveidxreadoppending ? slavedatislaveidxsaved : masterdatomasteridx);
genvar gen_masterdato_idx;
generate for (gen_masterdato_idx = 0; gen_masterdato_idx < MASTERCOUNT; gen_masterdato_idx = gen_masterdato_idx + 1) begin :gen_masterdato
// Combinational logic that set masterdato.
// Note that signals of masterdato are
// don't-care when there are not being indexed.
// The indexed masterdato is set to the result
// from the previously executed memory operation.
assign masterdato[gen_masterdato_idx] = masterdatoi;
end endgenerate

genvar gen_masterrdy_idx;
generate for (gen_masterrdy_idx = 0; gen_masterrdy_idx < MASTERCOUNT; gen_masterrdy_idx = gen_masterrdy_idx + 1) begin :gen_masterrdy
// Combinational logic that sets masterrdy.
// Note that signals of masterrdy become null
// when there are not being indexed by masteridx.
assign masterrdy[gen_masterrdy_idx] = (masteridx == gen_masterrdy_idx && nextoprdy) ? 1'b1 : 1'b0;
end endgenerate

// Combinational logics that set the slaves outputs.

genvar gen_slaveop_idx;
generate for (gen_slaveop_idx = 0; gen_slaveop_idx < SLAVECOUNT; gen_slaveop_idx = gen_slaveop_idx + 1) begin :gen_slaveop
// Combinational logic that set slaveop.
// Note that signals of slaveop become null when
// there are not being indexed by slaveidx.
assign slaveop[gen_slaveop_idx] = (slaveidx == gen_slaveop_idx && nextoprdy) ? masteropmasteridx : PINOOP;
end endgenerate

wire [ARCHBITSZ -1 : 0] slaveaddri = (masteraddrmasteridx-((addrspaceslaveidx+1'b1)-slavemapszslaveidx));
genvar gen_slaveaddr_idx;
generate for (gen_slaveaddr_idx = 0; gen_slaveaddr_idx < SLAVECOUNT; gen_slaveaddr_idx = gen_slaveaddr_idx + 1) begin :gen_slaveaddr
// Combinational logic that set slaveaddr.
// Note that signals of slaveaddr are don't-care
// when there are not being indexed by slaveidx.
assign slaveaddr[gen_slaveaddr_idx] = slaveaddri[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
end endgenerate

wire [ARCHBITSZ -1 : 0] masterdatimasteridx = masterdati[masteridx];
genvar gen_slavedato_idx;
generate for (gen_slavedato_idx = 0; gen_slavedato_idx < SLAVECOUNT; gen_slavedato_idx = gen_slavedato_idx + 1) begin :gen_slavedato
// Combinational logic that set slavedato.
// Note that signals of slavedato are don't-care
// when there are not being indexed by slaveidx.
assign slavedato[gen_slavedato_idx] = masterdatimasteridx;
end endgenerate

wire [(ARCHBITSZ/8) -1 : 0] masterbytselmasteridx = masterbytsel[masteridx];
genvar gen_slavebytsel_idx;
generate for (gen_slavebytsel_idx = 0; gen_slavebytsel_idx < SLAVECOUNT; gen_slavebytsel_idx = gen_slavebytsel_idx + 1) begin :gen_slavebytsel
// Combinational logic that set slavebytsel.
// Note that signals of slavebytsel are don't-care
// when there are not being indexed by slaveidx.
assign slavebytsel[gen_slavebytsel_idx] = masterbytselmasteridx;
end endgenerate

integer genaddrspace_idx;
initial begin
	masteridx = 0;
	mstrhinxt = (MASTERCOUNT - 1);
	mstrhiidx = (MASTERCOUNT - 1);
	mstrhi = (MASTERCOUNT - 1);
	masteropsaved = PINOOP;
	slaveopsaved = PIWROP;
	for (genaddrspace_idx = 0; genaddrspace_idx < SLAVECOUNT; genaddrspace_idx = genaddrspace_idx + 1) begin
		addrspace[genaddrspace_idx] = 0;
	end
	addrspacerdy = 0;
	slaveidx = 0;
	slavemapszslaveidx = 0;
	addrspaceslaveidx = 0;
	addrspaceslaveidxlo = 0;
	slaveidxrdy = 0;
	slaveidxbsy = 0;
	slaveidxsaved = 0;
	slaverdyslaveidxreadoppending = 0;
	masterdatomasteridx = 0;
end

endmodule

`endif /* PI1R_V */
