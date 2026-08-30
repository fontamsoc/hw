// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_ARBITER_V
`define WB_ARBITER_V

`include "lib/fifo_fwft.sv"

module wb_arbiter (

	 rst_i

	,clk_i

	,m_wb_stb_i
	,m_wb_lock_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_stb_o
	,s_wb_lock_o
	,s_wb_we_o
	,s_wb_addr_o
	,s_wb_sel_o
	,s_wb_dat_o
	,s_wb_bsy_i
	,s_wb_ack_i
	,s_wb_dat_i
);

`include "lib/clog2.sv"

parameter WORDBITSZ     = 32;
parameter ADDRLIMIT     = 'h2000;
parameter MDEVCOUNT     = 1;
parameter MAXPENDINGACK = 16; // Must be non-null and a power of 2.

localparam CLOG2MDEVCOUNT = clog2(MDEVCOUNT);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

input  wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_stb_i;
input  wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_lock_i;
input  wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_we_i;
input  wire [((ADDRBITSZ-MSBSZIGN) * MDEVCOUNT) -1 : 0] m_wb_addr_i;
input  wire [((WORDBITSZ/8) * MDEVCOUNT) -1 : 0]        m_wb_sel_i;
input  wire [(WORDBITSZ * MDEVCOUNT) -1 : 0]            m_wb_dat_i;
output wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_bsy_o;
output wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_ack_o;
output wire [(WORDBITSZ * MDEVCOUNT) -1 : 0]            m_wb_dat_o;

output wire                               s_wb_stb_o;
output wire                               s_wb_lock_o;
output wire                               s_wb_we_o;
output wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output wire [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output wire [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_bsy_i;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

reg [CLOG2MDEVCOUNT -1 : 0] mstridx;

wire [CLOG2MDEVCOUNT -1 : 0] slvidx;

wire _s_wb_stb_o = (s_wb_stb_o && !s_wb_bsy_i);

wire pendingAcksFull;

generate if (MDEVCOUNT > 1) begin
fifo_fwft #(
	 .WIDTH (CLOG2MDEVCOUNT)
	,.DEPTH (MAXPENDINGACK)
) pendingAcks (
	 .rst_i (rst_i)
	,.clk_push_i (clk_i)
	,.push_i     (_s_wb_stb_o)
	,.data_i     (mstridx)
	,.full_o     (pendingAcksFull)
	,.clk_pop_i  (clk_i)
	,.pop_i      (s_wb_ack_i)
	,.data_o     (slvidx)
);
end else begin
assign pendingAcksFull = 1'b0;
assign slvidx = 0;
end endgenerate

wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] _m_wb_addr_i [MDEVCOUNT];
wire [(WORDBITSZ/8) -1 : 0]        _m_wb_sel_i  [MDEVCOUNT];
wire [WORDBITSZ -1 : 0]            _m_wb_dat_i  [MDEVCOUNT];

// Masters other than the granted one, asserting their strobe. A master held
// busy does still present its request, memctrl.pu.sv suppressing its strobe
// only on its own pending-ack throttle and never on wb_bsy_i, hence this reads
// as "another master is waiting on the grant".
wire [MDEVCOUNT -1 : 0] mstroth;

genvar gen_m_wb_idx;
generate for (
	gen_m_wb_idx = 0;
	gen_m_wb_idx < MDEVCOUNT;
	gen_m_wb_idx = gen_m_wb_idx + 1) begin :gen_m_wb

assign _m_wb_addr_i[gen_m_wb_idx] =
	m_wb_addr_i[((gen_m_wb_idx+1) * (ADDRBITSZ-MSBSZIGN)) -1 : (gen_m_wb_idx * (ADDRBITSZ-MSBSZIGN))];

assign _m_wb_sel_i[gen_m_wb_idx] =
	m_wb_sel_i[((gen_m_wb_idx+1) * (WORDBITSZ/8)) -1 : (gen_m_wb_idx * (WORDBITSZ/8))];

assign _m_wb_dat_i[gen_m_wb_idx] =
	m_wb_dat_i[((gen_m_wb_idx+1) * WORDBITSZ) -1 : (gen_m_wb_idx * WORDBITSZ)];

assign m_wb_bsy_o[gen_m_wb_idx] = ((mstridx == gen_m_wb_idx) ? (s_wb_bsy_i || pendingAcksFull) : 1'b1);

assign mstroth[gen_m_wb_idx] = ((mstridx == gen_m_wb_idx) ? 1'b0 : m_wb_stb_i[gen_m_wb_idx]);

assign m_wb_ack_o[gen_m_wb_idx] = ((slvidx == gen_m_wb_idx) ? s_wb_ack_i : 1'b0);

assign m_wb_dat_o[((gen_m_wb_idx+1) * WORDBITSZ) -1 : (gen_m_wb_idx * WORDBITSZ)] = s_wb_dat_i;

end endgenerate

wire _m_wb_stb_i = m_wb_stb_i[mstridx];

wire mstrothrqst = |mstroth;

assign s_wb_stb_o = (pendingAcksFull ? 1'b0 : _m_wb_stb_i);
assign s_wb_lock_o = m_wb_lock_i[mstridx];
assign s_wb_we_o = m_wb_we_i[mstridx];
assign s_wb_addr_o = _m_wb_addr_i[mstridx];
assign s_wb_sel_o = _m_wb_sel_i[mstridx];
assign s_wb_dat_o = _m_wb_dat_i[mstridx];

reg [CLOG2MDEVCOUNT -1 : 0] mstrlonxt;
reg [CLOG2MDEVCOUNT -1 : 0] mstrloidx;
// Compute in mstrlonxt the active master with the lowest index.
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		mstrlonxt <= 0;
		mstrloidx <= 0;
	end else if (MDEVCOUNT > 1) begin
		if (mstrloidx == (MDEVCOUNT - 1) || m_wb_stb_i[mstrloidx]) begin
			if (m_wb_stb_i[mstrloidx])
				mstrlonxt <= mstrloidx;
			mstrloidx <= 0;
		end else
			mstrloidx <= mstrloidx + 1'b1;
	end
end

reg [CLOG2MDEVCOUNT -1 : 0] mstrhinxt;
reg [CLOG2MDEVCOUNT -1 : 0] mstrhiidx;
// Compute in mstrhinxt the active master with the highest index.
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		mstrhinxt <= (MDEVCOUNT - 1);
		mstrhiidx <= (MDEVCOUNT - 1);
	end else if (MDEVCOUNT > 1) begin
		if (mstrhiidx == 0 || m_wb_stb_i[mstrhiidx]) begin
			if (m_wb_stb_i[mstrhiidx])
				mstrhinxt <= mstrhiidx;
			mstrhiidx <= (MDEVCOUNT - 1);
		end else
			mstrhiidx <= mstrhiidx - 1'b1;
	end
end

// The lock is released by the next accepted access that does not carry it, ie: the
// store-conditional's store, or the atomic memory operation's write-back. An access
// carrying it while it is already set holds it, hence an atomic's own retries hold it.
// Instruction fetches interleave inside an atomic's window and must not release it,
// which is why memctrl.pu.sv carries the lock through them rather than leaving it null.
reg wb_lock;
// What wb_lock takes at this clockedge. The rotation below reads this rather than
// wb_lock itself, so that it cannot rotate away from the master whose locked access
// is being accepted right now: that would leave the grant on another master with the
// lock set, and the write-back which releases it could never issue.
wire wb_lock_nxt = (_s_wb_stb_o ? s_wb_lock_o : wb_lock);
always_ff @(posedge clk_i) begin
	if (rst_i)
		wb_lock <= 1'b0;
	else if (MDEVCOUNT > 1)
		wb_lock <= wb_lock_nxt;
end

// Nothing else bounds how long one master holds the grant. Rotating only in a
// clockcycle for which the granted master is not requesting means a master which
// keeps its strobe asserted keeps the bus, and a master's strobe stays asserted
// until its access is accepted, which a slave is under no obligation to ever do:
// the character devices hold wb_bsy_o for as long as their receive buffer is
// empty, so a read of the data register with no byte pending holds it forever.
// Every other master is held busy meanwhile, down to its instruction fetching,
// hence one master waiting on a device would otherwise stop the whole machine.
// Rotate away from it instead, once it has held the grant this long and another
// master is waiting. Preempting it loses nothing, the request being re-presented
// until accepted, and the response carrying the master it belongs to through
// pendingAcks rather than through mstridx.
// The limit has a floor as well as a purpose, and it is the bus lock that sets it.
// Rotation is blocked while the lock is held, so a limit shorter than the interval
// between a master's accesses hands the grant away in the very clockcycle the lock
// releases, and the master it hands to takes the lock with its own next access
// before the first can issue one: the masters then pass the lock back and forth and
// none of them completes a sequence of atomics. Measured, this starves at a limit of
// four and is clean at eight, hence the value below sits well clear of it rather
// than near it.
localparam GRANTHELDLIMIT = 32;
reg [(clog2(GRANTHELDLIMIT) +1) -1 : 0] grantheldcnt;
wire granthelddone = (grantheldcnt == GRANTHELDLIMIT);

wire mstrrotate = (!wb_lock_nxt && (!_m_wb_stb_i || (granthelddone && mstrothrqst)));

always_ff @(posedge clk_i) begin
	if (rst_i)
		grantheldcnt <= 0;
	else if (MDEVCOUNT > 1) begin
		if (mstrrotate)
			grantheldcnt <= 0;
		else if (!granthelddone)
			grantheldcnt <= grantheldcnt + 1'b1;
	end
end

reg [CLOG2MDEVCOUNT -1 : 0] mstrhi;
// Logic that increments mstridx.
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		mstridx <= 0;
		mstrhi <= (MDEVCOUNT - 1);
	end else if (MDEVCOUNT > 1) begin
		if (mstrrotate) begin
			if (mstridx < mstrhi)
				mstridx <= mstridx + 1'b1;
			else begin
				mstridx <= mstrlonxt;
				mstrhi <= mstrhinxt;
			end
		end
	end
end

`ifdef SIMULATION_MONITOR
// The lock is released by the lock owner's next accepted access that does not carry
// it, and nothing bounds when that comes: an atomic sequence whose store-conditional
// is branched over or never reached holds it until that hart's next load, store or
// atomic, and a retry loop holding a load-reserved and no other data access issues
// none at all. Every other master is held busy meanwhile, down to its instruction
// fetching, so it executes nothing; there is no bus watchdog and no cycle limit,
// hence that presents as a silent run forever. Report it instead.
// Held length alone is the tell, rather than also testing that another master is
// requesting: a starved master is held busy before it can even present a request,
// so that would be missed exactly when it matters.
localparam LOCKHELDLIMIT = 4096; // Well above any load-reserved to store-conditional window.
reg [(clog2(LOCKHELDLIMIT) +1) -1 : 0] lockheldcnt;
always_ff @(posedge clk_i) begin
	if (rst_i || !wb_lock)
		lockheldcnt <= 0;
	else if (lockheldcnt != LOCKHELDLIMIT) begin
		lockheldcnt <= lockheldcnt + 1'b1;
		if (lockheldcnt == (LOCKHELDLIMIT - 1)) begin
			$display("%m: error: bus lock held %0d clockcycles by master %0d, starving the others",
				LOCKHELDLIMIT, mstridx);
			// Flushed because what this reports is a run that never ends, hence one
			// that gets killed rather than reaching $finish, and an unflushed report
			// is lost exactly when it is the only thing that was going to be printed.
			$fflush();
		end
	end
end

// The grant itself is bounded above by GRANTHELDLIMIT clockcycles plus the rotation's
// own walk over the masters which are not requesting, hence a grant held for very much
// longer than that while another master is waiting can only mean that bound is not
// doing its job. Outside a lock window, which is deliberately unbounded and which the
// report above covers instead.
// Another master requesting IS part of the condition here, unlike above: with a single
// master active the grant legitimately stays where it is forever, so held length alone
// would report every run rather than a starved one.
// That term is derived below from the master strobes rather than read off the
// mstrothrqst which gates the rotation, and deliberately so: a mistake in mstrothrqst
// does not present as a wrong report, it removes the bound outright, ie: it is exactly
// what this exists to catch, and reading it here would take the report down along with
// the bound it checks. What is checked is likewise the grant moving rather than the
// rotation asserting, the two differing by the mstrlonxt and mstrhinxt scans, which the
// bound does not touch and which this therefore covers as well. So no signal of the
// bound's is read here, and this block reports correctly against an arbiter which has
// no bound at all.
localparam GRANTHELDREPORT = 4096; // Two orders above the bound it is checking.
reg [(clog2(GRANTHELDREPORT) +1) -1 : 0] grantheldreportcnt;
reg [CLOG2MDEVCOUNT -1 : 0] mstridx_r;
wire grantheldreportoth = |(m_wb_stb_i & ~(MDEVCOUNT'(1) << mstridx));
always_ff @(posedge clk_i) begin
	mstridx_r <= mstridx;
	if (rst_i || wb_lock || !grantheldreportoth || mstridx != mstridx_r)
		grantheldreportcnt <= 0;
	else if (grantheldreportcnt != GRANTHELDREPORT) begin
		grantheldreportcnt <= grantheldreportcnt + 1'b1;
		if (grantheldreportcnt == (GRANTHELDREPORT - 1)) begin
			$display("%m: error: bus grant held %0d clockcycles by master %0d while another is requesting",
				GRANTHELDREPORT, mstridx);
			// Flushed for the same reason as above: what this reports is a run
			// which never ends, hence one which never reaches $finish.
			$fflush();
		end
	end
end
`endif

endmodule

`endif /* WB_ARBITER_V */
