// SPDX-License-Identifier: GPL-2.0-only
// 20260918 (c) William Fonkou Tambe

// IS61WV5128BLL asynchronous SRAM peripheral.

// The chip is a 512K x 8 asynchronous sram with 19 address lines,
// 8 data lines and the active low pins CE#, OE# and WE#.
// A word of WORDBITSZ bits is (WORDBITSZ/8) consecutive bytes of the chip,
// the least significant byte at the lowest chip address, ie: the chip
// is a little-endian byte array which software addresses linearly.

// One access is done at a time: "wb_bsy_o" is high from the acceptance
// of a request until its acknowledgement, and derives from the state of
// the fsm alone, insuring it cannot be part of a combinational loop
// through the interconnect; the request pins are captured at the
// acceptance clockedge only, hence a master preempted while "wb_bsy_o"
// is high does no harm.

// A read fetches every byte of the word ignoring "wb_sel_i", one byte
// per RDCYCLES clockcycles: the address of a byte is launched at a
// clockedge, and the data returned by the chip is sampled RDCYCLES
// clockedges later, at which the address of the next byte is launched;
// the chip holds its data for tOHA after an address change, which is
// longer than the hold time of the pad register sampling it.

// A write touches only the bytes selected by "wb_sel_i", each in three
// steps: SETUP for one clockcycle (the address launched, WE# high, the
// data pads not driven), WEPULSE clockcycles of WE# low with the data
// driven, HOLD for one clockcycle (WE# high, the address and data held).
// OE# stays high throughout a write (a WE# controlled write, tPWE1), so
// SETUP also serves as the turnaround from a read, the chip having
// released its data pins tHZOE after OE# rose in the previous clockcycle.
// A write selecting no byte does not touch the chip and is acknowledged
// in the next clockcycle.

// The data pads are released at the clockedge which raises "wb_ack_o"
// and returns the fsm to idle, so OE# cannot fall before the following
// clockedge, ie: a read following a write costs no turnaround clockcycle.
// At 96 MHz with the default PADDELAY and WORDBITSZ 32, a word read costs
// 13 clockcycles, a word write 13 clockcycles and a byte write 4 clockcycles.

// The registers driving the chip pins hold the pin levels directly, are
// inactive at reset as well as at power-up (the chip is left untouched
// while the clock is not yet running), have no logic between them and
// the pads and no other fan-out, so that the board constraints can pack
// them in the pads; PADDELAY assumes such packing when lowered from
// its default.

// Nothing initializes the chip; its content survives a reset.

// Parameters:
//
// WORDBITSZ
// 	Must be a power-of-2 and >= 32.
// 	A word is (WORDBITSZ/8) consecutive bytes of the chip.
//
// CLKFREQ
// 	Frequency in Hz of the clock signal "clk_i";
// 	it must be at least 1000000.
//
// PADDELAY
// 	Delay in ns added to the access time of the chip, accounting
// 	for the round trip through the pads: from the clockedge launching
// 	an address to the chip, to the clockedge sampling the data returned.
// 	The default of 12 is safe for pad registers placed in the fabric;
// 	it can be lowered only after the timing report of the tool shows
// 	the pad registers packed in the pads.

// Ports:
//
// rst_i
// 	When held high at the rising edge
// 	of the clock signal, the module resets.
// 	It must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// wb_stb_i
// wb_we_i
// wb_addr_i
// wb_sel_i
// wb_dat_i
// wb_bsy_o
// wb_ack_o
// wb_dat_o
// 	Slave memory interface.
//
// sram_ce_o
// sram_oe_o
// sram_we_o
// sram_addr_o
// sram_data_io
// 	SRAM chip interface; "sram_ce_o", "sram_oe_o" and "sram_we_o"
// 	drive the active low pins CE#, OE# and WE# of the chip.

module sram_is61wv5128bll (

	 rst_i

	,clk_i

	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,sram_ce_o
	,sram_oe_o
	,sram_we_o
	,sram_addr_o
	,sram_data_io
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter CLKFREQ  = 96000000;
parameter PADDELAY = 12;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// Count of bytes in a word, ie: of byte lanes.
localparam LANECNT = (WORDBITSZ/8);

// Size in bytes of the chip.
localparam MAPSZ = (512*1024);

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

// Count of address lines of the chip.
localparam SRAM_ADDRBITSZ = clog2(MAPSZ);

// Period of "clk_i" in ps, rounded down; CLKFREQ is divided by 1000
// first, so that the arithmetic fits 32bits.
localparam CLKPERIODPS = (1000000000 / (CLKFREQ/1000));

// Timings of the chip in ps, as named by its datasheet.
localparam TAA   = 10000; // Address access time.
localparam TACE  = 10000; // Chip enable access time.
localparam TDOE  = 4500;  // Output enable access time.
localparam TPWE1 = 8000;  // Write enable pulse width, OE# high.
localparam TSD   = 6000;  // Data setup to write end.

localparam PADDELAYPS = (PADDELAY*1000);

// Access time of a read: the address, CE# and OE# are launched at the
// same clockedge, hence the longest of their access times applies.
localparam TRDACCESS = ((TAA > TACE) ? ((TAA > TDOE) ? TAA : TDOE) : ((TACE > TDOE) ? TACE : TDOE));

// Count of clockcycles from the launch of an address to the sampling
// of the data returned by the chip.
localparam RDCYCLES = ((PADDELAYPS + TRDACCESS + (CLKPERIODPS-1)) / CLKPERIODPS);

// Count of clockcycles WE# is held low; the data is driven from the
// clockedge at which WE# falls, hence tSD is met by the same count.
localparam WEPULSE = ((((TPWE1 > TSD) ? TPWE1 : TSD) + (CLKPERIODPS-1)) / CLKPERIODPS);

// The down-counter holds (RDCYCLES-1) or (WEPULSE-1), whichever is larger.
localparam CNTMAX = ((RDCYCLES > WEPULSE) ? RDCYCLES : WEPULSE);
localparam CNTBITSZ = clog2(CNTMAX);

localparam STATE_IDLE    = 0;
localparam STATE_RD      = 1;
localparam STATE_WRSETUP = 2;
localparam STATE_WRPULSE = 3;
localparam STATE_WRHOLD  = 4;

input wire rst_i;

input wire clk_i;

input  wire                               wb_stb_i;
input  wire                               wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [LANECNT -1 : 0]              wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output reg                                wb_ack_o;
output wire [WORDBITSZ -1 : 0]            wb_dat_o;

// The registers driving the chip pins are initialized at declaration,
// as the clock does not run until the pll locks: the chip must see
// inactive levels from configuration on.
output reg                           sram_ce_o = 1'b1;
output reg                           sram_oe_o = 1'b1;
output reg                           sram_we_o = 1'b1;
output reg  [SRAM_ADDRBITSZ -1 : 0]  sram_addr_o;
inout  wire [8 -1 : 0]               sram_data_io;

`ifdef SIMULATION_MONITOR
// Timings of the chip in ps met structurally by the fsm rather than
// counted; declared for the configuration sanity checks below.
localparam TRC   = 10000; // Read cycle time.
localparam TWC   = 10000; // Write cycle time.
localparam TAW   = 8000;  // Address valid to write end.
localparam TSCE  = 8000;  // Chip enable to write end.
localparam THZOE = 4000;  // Output disable to output High-Z.
// Configuration sanity checks; they bound CLKFREQ and PADDELAY.
initial begin
	if (CLKFREQ < 1000000) begin
		$display("sram_is61wv5128bll: error: CLKFREQ must be at least 1000000");
		$finish;
	end
	if (PADDELAY < 6 || PADDELAY > 100) begin
		$display("sram_is61wv5128bll: error: PADDELAY must be between 6 and 100");
		$finish;
	end
	if (RDCYCLES < 1 || WEPULSE < 1 || CNTMAX < 1) begin
		$display("sram_is61wv5128bll: error: a null clockcycle count was derived");
		$finish;
	end
	// A byte is read every RDCYCLES clockcycles.
	if ((RDCYCLES * CLKPERIODPS) < TRC) begin
		$display("sram_is61wv5128bll: error: CLKFREQ too high for tRC");
		$finish;
	end
	// A byte is written every (WEPULSE+2) clockcycles: SETUP, WEPULSE, HOLD.
	if (((WEPULSE + 2) * CLKPERIODPS) < TWC) begin
		$display("sram_is61wv5128bll: error: CLKFREQ too high for tWC");
		$finish;
	end
	// The address and CE# are launched one clockcycle before WE# falls.
	if (((WEPULSE + 1) * CLKPERIODPS) < TAW) begin
		$display("sram_is61wv5128bll: error: CLKFREQ too high for tAW");
		$finish;
	end
	if (((WEPULSE + 1) * CLKPERIODPS) < TSCE) begin
		$display("sram_is61wv5128bll: error: CLKFREQ too high for tSCE");
		$finish;
	end
	// The data pads are driven at least one clockcycle after OE# rose.
	if (CLKPERIODPS < THZOE) begin
		$display("sram_is61wv5128bll: error: CLKFREQ too high for tHZOE");
		$finish;
	end
end
`endif

reg [3 -1 : 0]         state_r;
reg [CNTBITSZ -1 : 0]  cnt_r;
// Bytes of the word remaining to access, one bit per byte lane.
reg [LANECNT -1 : 0]   lanes_r;

reg [3 -1 : 0]         next_state_r;
reg [CNTBITSZ -1 : 0]  next_cnt_r;
reg [LANECNT -1 : 0]   next_lanes_r;
reg                    next_ack_r;
// Lowest byte lane set in next_lanes_r, ie: the next byte to access.
reg [CLOG2WORDBITSZBY8 -1 : 0] next_lane_r;

wire wb_stb_r_ = (wb_stb_i && !wb_bsy_o);

assign wb_bsy_o = (state_r != STATE_IDLE);

reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_r;
reg [WORDBITSZ -1 : 0]            wb_dat_r;
always_ff @(posedge clk_i) begin
	if (wb_stb_r_) begin
		wb_addr_r <= wb_addr_i;
		wb_dat_r <= wb_dat_i;
	end
end

// Word address of the access, from the request pins at the acceptance
// clockedge, from the captured request afterward.
wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] addr_n_w = (wb_stb_r_ ? wb_addr_i : wb_addr_r);

// lanes_r with its lowest set bit cleared, and whether it was the last one.
wire [LANECNT -1 : 0] lanes_adv_w  = (lanes_r & (lanes_r - 1'b1));
wire                  lanes_last_w = !(|lanes_adv_w);

always_comb begin
	next_state_r = state_r;
	next_cnt_r   = cnt_r;
	next_lanes_r = lanes_r;
	next_ack_r   = 1'b0;
	case (state_r)
	STATE_IDLE: begin
		if (wb_stb_r_) begin
			if (!wb_we_i) begin
				next_state_r = STATE_RD;
				next_cnt_r   = (RDCYCLES-1);
				next_lanes_r = {LANECNT{1'b1}};
			end else if (|wb_sel_i) begin
				next_state_r = STATE_WRSETUP;
				next_lanes_r = wb_sel_i;
			end else
				next_ack_r = 1'b1;
		end
	end
	STATE_RD: begin
		if (cnt_r != 0)
			next_cnt_r = (cnt_r - 1'b1);
		else begin
			next_lanes_r = lanes_adv_w;
			next_cnt_r   = (RDCYCLES-1);
			if (lanes_last_w) begin
				next_state_r = STATE_IDLE;
				next_ack_r   = 1'b1;
			end
		end
	end
	STATE_WRSETUP: begin
		next_state_r = STATE_WRPULSE;
		next_cnt_r   = (WEPULSE-1);
	end
	STATE_WRPULSE: begin
		if (cnt_r != 0)
			next_cnt_r = (cnt_r - 1'b1);
		else
			next_state_r = STATE_WRHOLD;
	end
	STATE_WRHOLD: begin
		next_lanes_r = lanes_adv_w;
		if (lanes_last_w) begin
			next_state_r = STATE_IDLE;
			next_ack_r   = 1'b1;
		end else
			next_state_r = STATE_WRSETUP;
	end
	default: begin
		next_state_r = STATE_IDLE;
	end
	endcase
end

// Priority pick of the lowest set byte lane.
always_comb begin
	next_lane_r = 0;
	for (int i = (LANECNT-1); i >= 0; --i)
		if (next_lanes_r[i])
			next_lane_r = i;
end

// Set when the clockedge sampled a byte returned by the chip.
reg rd_capture_r;

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		state_r      <= STATE_IDLE;
		cnt_r        <= 0;
		lanes_r      <= 0;
		rd_capture_r <= 1'b0;
		wb_ack_o     <= 1'b0;
	end else begin
		state_r      <= next_state_r;
		cnt_r        <= next_cnt_r;
		lanes_r      <= next_lanes_r;
		rd_capture_r <= (state_r == STATE_RD && cnt_r == 0);
		wb_ack_o     <= next_ack_r;
	end
end

// Register sampling the data pins of the chip at every clockedge.
reg [8 -1 : 0] sram_data_in_r;
wire [8 -1 : 0] sram_data_in_w;
always_ff @(posedge clk_i)
	sram_data_in_r <= sram_data_in_w;

// Shift register receiving the bytes read, the least significant first;
// the last byte, the most significant, is in sram_data_in_r when
// "wb_ack_o" is high.
reg [(WORDBITSZ-8) -1 : 0] rddata_r;
always_ff @(posedge clk_i) begin
	if (rd_capture_r)
		rddata_r <= {sram_data_in_r, rddata_r[(WORDBITSZ-8) -1 : 8]};
end

assign wb_dat_o = {sram_data_in_r, rddata_r};

// Registers driving the data pins of the chip, and their tristate
// sense, one bit per pad so that each pad has its own register.
reg [8 -1 : 0] sram_data_r;
reg [8 -1 : 0] sram_data_rd_en_r = {8{1'b1}};

// The chip pins are set from the next state, ie: they change at the
// clockedge which enters a state.
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		sram_ce_o         <= 1'b1;
		sram_oe_o         <= 1'b1;
		sram_we_o         <= 1'b1;
		sram_data_rd_en_r <= {8{1'b1}};
		sram_data_r       <= {8{1'b0}};
	end else begin
		sram_ce_o         <= (next_state_r == STATE_IDLE);
		sram_oe_o         <= (next_state_r != STATE_RD);
		sram_we_o         <= (next_state_r != STATE_WRPULSE);
		sram_data_rd_en_r <= {8{!(next_state_r == STATE_WRPULSE || next_state_r == STATE_WRHOLD)}};
		sram_data_r       <= wb_dat_r[next_lane_r*8 +: 8];
	end
end

always_ff @(posedge clk_i)
	sram_addr_o <= {addr_n_w, next_lane_r};

// Tristate per pad; a single ternary on the vector would reduce the
// sense to one bit.
genvar i;
generate for (i = 0; i < 8; i = i + 1) begin :gen_sram_data_io
	assign sram_data_io[i] = (sram_data_rd_en_r[i] ? 1'bz : sram_data_r[i]);
end endgenerate
assign sram_data_in_w = sram_data_io;

`ifdef SIMULATION_MONITOR
// Run-time checks of the pin sequencing; they read the registers driving
// the chip pins, which nothing synthesized does: this block is never
// synthesized.
reg            monitor_oe_r;
reg [8 -1 : 0] monitor_rd_en_r;
always_ff @(posedge clk_i) begin
	monitor_oe_r    <= sram_oe_o;
	monitor_rd_en_r <= sram_data_rd_en_r;
	if (!rst_i) begin
		if (!(&sram_data_rd_en_r) && (!sram_oe_o || !monitor_oe_r)) begin
			$display("sram_is61wv5128bll: error: data pins driven while OE# is or was just low");
			$finish;
		end
		if (!sram_oe_o && !(&monitor_rd_en_r)) begin
			$display("sram_is61wv5128bll: error: OE# low within a clockcycle of the data pins release");
			$finish;
		end
		if (!sram_we_o && !sram_oe_o) begin
			$display("sram_is61wv5128bll: error: WE# and OE# low together");
			$finish;
		end
		if (wb_ack_o && wb_bsy_o) begin
			$display("sram_is61wv5128bll: error: acknowledgement while busy");
			$finish;
		end
	end
end
`endif

endmodule
