// SPDX-License-Identifier: GPL-2.0-or-later
// (c) 2015 admin@ultra-embedded.com
// (c) 2026 William Fonkou Tambe

// SDRAM memory peripheral.
// Ported from ultra-embedded.com's simple SDRAM controller:
// https://github.com/ultraembedded/cores/tree/master/sdram

// The row management strategy is to leave active rows open until a periodic
// auto refresh closes all open rows at once, or until a bank needs to open
// another row due to a read or write request.
// This IP supports one open active row per bank (4 at the default geometry).
// When accessing open rows, reads and writes can be pipelined to achieve full
// SDRAM bus utilization, however switching between reads & writes takes a few
// cycles.

// Parameters:
//
// SDRAM_MHZ
// 	Frequency in MHz of the clock signal "clk_i".
//
// SDRAM_ROW_W
// SDRAM_COL_W
// SDRAM_BANK_W
// 	Row, column and bank address width of the SDRAM chip.
//
// SDRAM_CAS_LATENCY
// 	CAS latency programmed in the SDRAM chip mode register;
// 	only the value 2 has been validated in simulation.
//
// SDRAM_TARGET
// 	"XILINX" uses ODDR2/IOBUF primitives for the pads,
// 	while any other value uses portable verilog.

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
// sdram_clk_o
// sdram_cke_o
// sdram_cs_o
// sdram_ras_o
// sdram_cas_o
// sdram_we_o
// sdram_dqm_o
// sdram_addr_o
// sdram_ba_o
// sdram_data_io
// 	SDRAM chip interface.

module wb4sdram (

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

	,sdram_clk_o
	,sdram_cke_o
	,sdram_cs_o
	,sdram_ras_o
	,sdram_cas_o
	,sdram_we_o
	,sdram_dqm_o
	,sdram_addr_o
	,sdram_ba_o
	,sdram_data_io
);

`include "lib/clog2.sv"

parameter SDRAM_MHZ         = 50;
parameter SDRAM_ROW_W       = 13;
parameter SDRAM_COL_W       = 9;
parameter SDRAM_BANK_W      = 2;
parameter SDRAM_CAS_LATENCY = 2;
parameter SDRAM_TARGET      = "XILINX";

// The wishbone interface is inherently 32bits and the data mask width must
// be 2: a wishbone word maps onto two consecutive 16bits sdram columns,
// which a BL=2 burst covers in a single command; hence a localparam.
localparam SDRAM_DQM_W = 2;

localparam SDRAM_ADDR_W         = (SDRAM_ROW_W + SDRAM_COL_W + SDRAM_BANK_W);
localparam SDRAM_BANKS          = (2 ** SDRAM_BANK_W);
localparam SDRAM_REFRESH_CNT    = (2 ** SDRAM_ROW_W);
localparam SDRAM_START_DELAY    = (100000 / (1000 / SDRAM_MHZ)); // 100uS
// tREFI: maximum interval between AUTO REFRESH commands, insuring the 64ms
// refresh period is spread across all rows.
localparam SDRAM_TREFI_CYCLES   = ((64000 * SDRAM_MHZ) / SDRAM_REFRESH_CNT);

localparam CMD_W         = 4;
localparam CMD_NOP       = 4'b0111;
localparam CMD_ACTIVE    = 4'b0011;
localparam CMD_READ      = 4'b0101;
localparam CMD_WRITE     = 4'b0100;
localparam CMD_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE = 4'b0010;
localparam CMD_REFRESH   = 4'b0001;
localparam CMD_LOAD_MODE = 4'b0000;

// Mode: Burst Length = 4 bytes.
localparam MODE_REG = {3'b000,1'b0,2'b00,3'(SDRAM_CAS_LATENCY),1'b0,3'b001};

// SM states.
localparam STATE_W         = 4;
localparam STATE_INIT      = 4'd0;
localparam STATE_DELAY     = 4'd1;
localparam STATE_IDLE      = 4'd2;
localparam STATE_ACTIVATE  = 4'd3;
localparam STATE_READ      = 4'd4;
localparam STATE_READ_WAIT = 4'd5;
localparam STATE_WRITE0    = 4'd6;
localparam STATE_WRITE1    = 4'd7;
localparam STATE_PRECHARGE = 4'd8;
localparam STATE_REFRESH   = 4'd9;

localparam AUTO_PRECHARGE = 10;
localparam ALL_BANKS      = 10;

localparam SDRAM_DATA_W = (SDRAM_DQM_W * 8);

localparam CYCLE_TIME_NS = (1000 / SDRAM_MHZ);

// SDRAM timing.
localparam SDRAM_TRCD_CYCLES = ((20 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS);
localparam SDRAM_TRP_CYCLES  = ((20 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS);
localparam SDRAM_TRFC_CYCLES = ((60 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS);

// Inherently 32bits, like the sdram side; hence a localparam.
localparam WORDBITSZ = 32;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = ((2 ** SDRAM_ADDR_W) * (SDRAM_DATA_W/8));

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;

input  wire                               wb_stb_i;
input  wire                               wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output reg                                wb_ack_o;
output wire [WORDBITSZ -1 : 0]            wb_dat_o;

output wire                    sdram_clk_o;
output wire                    sdram_cke_o;
output wire                    sdram_cs_o;
output wire                    sdram_ras_o;
output wire                    sdram_cas_o;
output wire                    sdram_we_o;
output wire [SDRAM_DQM_W-1:0]  sdram_dqm_o;
output wire [SDRAM_ROW_W-1:0]  sdram_addr_o;
output wire [SDRAM_BANK_W-1:0] sdram_ba_o;
inout  wire [SDRAM_DATA_W-1:0] sdram_data_io;

`ifdef SIMULATION_MONITOR
// tWR (in ns) and tMRD (specified in clockcycles) are met structurally by
// the fsm rather than counted; declared for the SIMULATION_MONITOR configuration
// sanity checks below the port declarations.
localparam SDRAM_TWR_CYCLES  = ((15 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS);
localparam SDRAM_TMRD_CYCLES = 2;
// Configuration sanity checks for the timings the fsm meets structurally
// rather than counted; they bound how high SDRAM_MHZ can go.
initial begin
	// The earliest PRECHARGE after a WRITE is 2 clockcycles after its
	// last data beat (WRITE1 -> IDLE -> PRECHARGE).
	if (SDRAM_TWR_CYCLES > 2) begin
		$display("wb4sdram: error: SDRAM_MHZ too high for tWR");
		$finish;
	end
	// STATE_INIT spaces its commands 10 clockcycles apart.
	if (SDRAM_TRFC_CYCLES > 10 || SDRAM_TMRD_CYCLES > 10) begin
		$display("wb4sdram: error: SDRAM_MHZ too high for the init sequence command spacing");
		$finish;
	end
end
`endif

// Xilinx placement pragmas:
//synthesis attribute IOB of command_q is "TRUE"
//synthesis attribute IOB of addr_q is "TRUE"
//synthesis attribute IOB of dqm_q is "TRUE"
//synthesis attribute IOB of cke_q is "TRUE"
//synthesis attribute IOB of bank_q is "TRUE"
//synthesis attribute IOB of data_q is "TRUE"

reg [CMD_W-1:0]        command_q;
reg [SDRAM_ROW_W-1:0]  addr_q;
reg [SDRAM_DATA_W-1:0] data_q;
reg                    data_rd_en_q;
reg [SDRAM_DQM_W-1:0]  dqm_q;
reg                    cke_q;
reg [SDRAM_BANK_W-1:0] bank_q;

// Buffer half word during read and write commands.
reg [SDRAM_DATA_W-1:0] data_buffer_q;
reg [SDRAM_DQM_W-1:0]  dqm_buffer_q;

wire [SDRAM_DATA_W-1:0] sdram_data_in_w;

reg refresh_q;

reg [SDRAM_BANKS-1:0] row_open_q;
reg [SDRAM_ROW_W-1:0] active_row_q[0:SDRAM_BANKS-1];

reg [STATE_W-1:0] state_q;
reg [STATE_W-1:0] next_state_r;
reg [STATE_W-1:0] target_state_r;
reg [STATE_W-1:0] target_state_q;
reg [STATE_W-1:0] delay_state_q;

// Address bits.
// wb_addr_i is a device relative 32bits-word address, while the sdram is
// 16bits wide and each access bursts two columns (BL=2); the column address
// is therefore the word index shifted up by one with a null lsb, while the
// bank and row fields sit directly above that word index.
wire [SDRAM_ROW_W-1:0]  addr_col_w  = {{(SDRAM_ROW_W-SDRAM_COL_W){1'b0}}, wb_addr_i[0 +: (SDRAM_COL_W-1)], 1'b0};
wire [SDRAM_ROW_W-1:0]  addr_row_w  = wb_addr_i[((SDRAM_COL_W-1)+SDRAM_BANK_W) +: SDRAM_ROW_W];
wire [SDRAM_BANK_W-1:0] addr_bank_w = wb_addr_i[(SDRAM_COL_W-1) +: SDRAM_BANK_W];

// Live row-hit validation of the request being presented; a request is
// only accepted in STATE_READ/STATE_WRITE0 when it still matches an open
// row and the expected direction, which makes it safe for a master to be
// preempted while "wb_bsy_o" is high; a request which no longer matches
// gets redispatched from STATE_IDLE.
wire rqst_hit_w = (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w]);

// Target captured when STATE_IDLE commits to a dispatch; STATE_PRECHARGE
// and STATE_ACTIVATE must use it instead of the live request, otherwise a
// preemption mid-dispatch could aim CMD_ACTIVE at an already-open bank,
// which is illegal for the sdram chip.
reg [SDRAM_ROW_W-1:0]  dispatch_row_q;
reg [SDRAM_BANK_W-1:0] dispatch_bank_q;
wire rd_rqst_w  = ((state_q == STATE_READ)   && !wb_we_i && rqst_hit_w);
// A write may only be accepted once no read is in flight: the redispatch
// path can otherwise place STATE_WRITE0 in the very clockcycle in which
// rd_q completes a read, which would clobber data_buffer_q, and at odd
// SDRAM_CAS_LATENCY values merge the two acks into one. Every normally
// dispatched write reaches STATE_WRITE0 with rd_q already null, so this
// only delays a write swapped in behind an in-flight read.
wire rd_inflight_w; // (|rd_q), assigned where rd_q is declared
wire wr_rqst_w  = ((state_q == STATE_WRITE0) &&  wb_we_i && rqst_hit_w && !rd_inflight_w);
wire rd_issue_w = (rd_rqst_w && wb_stb_i);
wire wr_issue_w = (wr_rqst_w && wb_stb_i);

// SDRAM State Machine.
always_comb begin
    next_state_r   = state_q;
    target_state_r = target_state_q;
    case (state_q)
    STATE_INIT : begin
        if (refresh_q)
            next_state_r = STATE_IDLE;
    end
    STATE_IDLE: begin
        // Pending refresh.
        // Note: tRAS (open row time) cannot be exceeded due to periodic
        //        auto refreshes.
        if (refresh_q) begin
            // Close open rows, then refresh.
            if (|row_open_q)
                next_state_r = STATE_PRECHARGE;
            else
                next_state_r = STATE_REFRESH;

            target_state_r = STATE_REFRESH;
        end
        // Access request.
        else if (wb_stb_i) begin
            // Open row hit.
            if (rqst_hit_w) begin
                if (wb_we_i)
                    next_state_r = STATE_WRITE0;
                else
                    next_state_r = STATE_READ;
            end
            // Row miss, close row, open new row.
            else if (row_open_q[addr_bank_w]) begin
                next_state_r = STATE_PRECHARGE;
                if (wb_we_i)
                    target_state_r = STATE_WRITE0;
                else
                    target_state_r = STATE_READ;
            end
            // No open row, open row.
            else begin
                next_state_r   = STATE_ACTIVATE;
                if (wb_we_i)
                    target_state_r = STATE_WRITE0;
                else
                    target_state_r = STATE_READ;
            end
        end
    end
    STATE_ACTIVATE: begin
        // Proceed to read or write state.
        next_state_r = target_state_r;
    end
    STATE_READ: begin
        // Do not wait for read data when the request was
        // preempted or no longer matches; instead redispatch.
        if (rd_issue_w)
            next_state_r = STATE_READ_WAIT;
        else
            next_state_r = STATE_IDLE;
    end
    STATE_READ_WAIT: begin
        next_state_r = STATE_IDLE;
        // Another pending read request (with no refresh pending).
        if (!refresh_q && wb_stb_i && !wb_we_i) begin
            // Open row hit.
            if (rqst_hit_w)
                next_state_r = STATE_READ;
        end
    end
    STATE_WRITE0: begin
        // Do not continue the write burst when the request was
        // preempted or no longer matches; instead redispatch.
        if (wr_issue_w)
            next_state_r = STATE_WRITE1;
        else
            next_state_r = STATE_IDLE;
    end
    STATE_WRITE1: begin
        next_state_r = STATE_IDLE;
        // Another pending write request (with no refresh pending).
        if (!refresh_q && wb_stb_i && wb_we_i) begin
            // Open row hit.
            if (rqst_hit_w)
                next_state_r = STATE_WRITE0;
        end
    end
    STATE_PRECHARGE: begin
        // Closing row to perform refresh.
        if (target_state_r == STATE_REFRESH)
            next_state_r = STATE_REFRESH;
        // Must be closing row to open another.
        else
            next_state_r = STATE_ACTIVATE;
    end
    STATE_REFRESH: begin
        next_state_r = STATE_IDLE;
    end
    STATE_DELAY: begin
        next_state_r = delay_state_q;
    end
    default:;
    endcase
end

localparam DELAY_W = 4;

reg [DELAY_W-1:0] delay_q;
reg [DELAY_W-1:0] delay_r;

always_comb begin
    case (state_q)
    STATE_ACTIVATE: begin
        // tRCD (ACTIVATE -> READ / WRITE)
        delay_r = SDRAM_TRCD_CYCLES;
    end
    STATE_READ_WAIT: begin
        delay_r = SDRAM_CAS_LATENCY;
        // Another pending read request (with no refresh pending)
        if (!refresh_q && wb_stb_i && !wb_we_i) begin
            // Open row hit
            if (rqst_hit_w)
                delay_r = 4'd0;
        end
    end
    STATE_PRECHARGE: begin
        // tRP (PRECHARGE -> ACTIVATE)
        delay_r = SDRAM_TRP_CYCLES;
    end
    STATE_REFRESH: begin
        // tRFC
        delay_r = SDRAM_TRFC_CYCLES;
    end
    STATE_DELAY: begin
        delay_r = delay_q - 4'd1;
    end
    default: begin
        delay_r = {DELAY_W{1'b0}};
    end
    endcase
end

// Record target state.
always_ff @(posedge clk_i)
if (rst_i)
    target_state_q <= STATE_IDLE;
else
    target_state_q <= target_state_r;

// Record the dispatch target when STATE_IDLE commits to an access.
always_ff @(posedge clk_i)
if (state_q == STATE_IDLE && !refresh_q && wb_stb_i) begin
    dispatch_row_q  <= addr_row_w;
    dispatch_bank_q <= addr_bank_w;
end

// Record delayed state.
always_ff @(posedge clk_i)
if (rst_i)
    delay_state_q <= STATE_IDLE;
// On entering into delay state, record intended next state.
else if (state_q != STATE_DELAY && delay_r != {DELAY_W{1'b0}})
    delay_state_q <= next_state_r;

// Update actual state.
always_ff @(posedge clk_i)
if (rst_i)
    state_q <= STATE_INIT;
// Delaying.
else if (delay_r != {DELAY_W{1'b0}})
    state_q <= STATE_DELAY;
else
    state_q <= next_state_r;

// Update delay flops.
always_ff @(posedge clk_i)
if (rst_i)
    delay_q <= {DELAY_W{1'b0}};
else
    delay_q <= delay_r;

localparam REFRESH_CNT_W = 17;
// Refresh counter.
reg [REFRESH_CNT_W-1:0] refresh_timer_q;
always_ff @(posedge clk_i)
if (rst_i)
    refresh_timer_q <= SDRAM_START_DELAY + 100;
else if (refresh_timer_q == {REFRESH_CNT_W{1'b0}})
    refresh_timer_q <= (SDRAM_TREFI_CYCLES - 1);
else
    refresh_timer_q <= refresh_timer_q - 1;

always_ff @(posedge clk_i)
if (rst_i)
    refresh_q <= 1'b0;
else if (refresh_timer_q == {REFRESH_CNT_W{1'b0}})
    refresh_q <= 1'b1;
else if (state_q == STATE_REFRESH)
    refresh_q <= 1'b0;

reg [SDRAM_DATA_W-1:0] sample_data0_q;
always_ff @(posedge clk_i)
if (rst_i)
    sample_data0_q <= {SDRAM_DATA_W{1'b0}};
else
    sample_data0_q <= sdram_data_in_w;

reg [SDRAM_DATA_W-1:0] sample_data_q;
always_ff @(posedge clk_i)
if (rst_i)
    sample_data_q <= {SDRAM_DATA_W{1'b0}};
else
    sample_data_q <= sample_data0_q;

integer idx;

always_ff @(posedge clk_i)
if (rst_i) begin

    command_q       <= CMD_NOP;
    data_q          <= {SDRAM_DATA_W{1'b0}};
    addr_q          <= {SDRAM_ROW_W{1'b0}};
    bank_q          <= {SDRAM_BANK_W{1'b0}};
    cke_q           <= 1'b0;
    dqm_q           <= {SDRAM_DQM_W{1'b0}};
    data_rd_en_q    <= 1'b1;
    dqm_buffer_q    <= {SDRAM_DQM_W{1'b0}};

    for (idx=0;idx<SDRAM_BANKS;idx=idx+1)
        active_row_q[idx] <= {SDRAM_ROW_W{1'b0}};

    row_open_q      <= {SDRAM_BANKS{1'b0}};

end else begin

    case (state_q)
    default: begin
        command_q    <= CMD_NOP;
        addr_q       <= {SDRAM_ROW_W{1'b0}};
        bank_q       <= {SDRAM_BANK_W{1'b0}};
        data_rd_en_q <= 1'b1;
    end
    STATE_INIT:
    begin
        // The commands below are spaced 10 clockcycles apart, which meets
        // tMRD and tRFC; checked against SDRAM_TMRD_CYCLES and
        // SDRAM_TRFC_CYCLES under SIMULATION_MONITOR.
        // Assert CKE.
        if (refresh_timer_q == 50) begin
            // Assert CKE after 100uS.
            cke_q <= 1'b1;
        end
        // PRECHARGE.
        else if (refresh_timer_q == 40) begin
            // Precharge all banks.
            command_q           <= CMD_PRECHARGE;
            addr_q[ALL_BANKS]   <= 1'b1;
        end
        // 2 x REFRESH (with at least tREF wait).
        else if (refresh_timer_q == 20 || refresh_timer_q == 30) begin
            command_q <= CMD_REFRESH;
        end
        // Load mode register.
        else if (refresh_timer_q == 10) begin
            command_q <= CMD_LOAD_MODE;
            addr_q    <= MODE_REG;
        end
        // Other cycles during init - just NOP.
        else begin
            command_q   <= CMD_NOP;
            addr_q      <= {SDRAM_ROW_W{1'b0}};
            bank_q      <= {SDRAM_BANK_W{1'b0}};
        end
    end
    STATE_ACTIVATE: begin
        // Select a row and activate it.
        command_q <= CMD_ACTIVE;
        addr_q    <= dispatch_row_q;
        bank_q    <= dispatch_bank_q;

        active_row_q[dispatch_bank_q] <= dispatch_row_q;
        row_open_q[dispatch_bank_q]   <= 1'b1;
    end
    STATE_PRECHARGE: begin
        // tWR is met structurally: the earliest PRECHARGE after a WRITE is
        // 2 clockcycles after its last data beat (WRITE1 -> IDLE -> STATE_PRECHARGE);
        // checked against SDRAM_TWR_CYCLES under SIMULATION_MONITOR.
        // Precharge due to refresh, close all banks.
        if (target_state_r == STATE_REFRESH) begin
            // Precharge all banks.
            command_q         <= CMD_PRECHARGE;
            addr_q[ALL_BANKS] <= 1'b1;
            row_open_q        <= {SDRAM_BANKS{1'b0}};
        end else begin
            // Precharge specific banks.
            command_q         <= CMD_PRECHARGE;
            addr_q[ALL_BANKS] <= 1'b0;
            bank_q            <= dispatch_bank_q;

            row_open_q[dispatch_bank_q] <= 1'b0;
        end
    end
    STATE_REFRESH: begin
        // Auto refresh.
        command_q <= CMD_REFRESH;
        addr_q    <= {SDRAM_ROW_W{1'b0}};
        bank_q    <= {SDRAM_BANK_W{1'b0}};
    end
    STATE_READ: begin
        // Issue no command when the request was preempted or no longer matches.
        if (rd_issue_w) begin
            command_q <= CMD_READ;
            addr_q    <= addr_col_w;
            bank_q    <= addr_bank_w;

            // Disable auto precharge (auto close of row).
            addr_q[AUTO_PRECHARGE] <= 1'b0;

            // Read mask (all bytes in burst).
            dqm_q <= {SDRAM_DQM_W{1'b0}};
        end else begin
            command_q    <= CMD_NOP;
            addr_q       <= {SDRAM_ROW_W{1'b0}};
            bank_q       <= {SDRAM_BANK_W{1'b0}};
            data_rd_en_q <= 1'b1;
        end
    end
    STATE_WRITE0: begin
        // Issue no command when the request was preempted or no longer matches.
        if (wr_issue_w) begin
            command_q <= CMD_WRITE;
            addr_q    <= addr_col_w;
            bank_q    <= addr_bank_w;
            data_q    <= wb_dat_i[15:0];

            // Disable auto precharge (auto close of row).
            addr_q[AUTO_PRECHARGE] <= 1'b0;

            // Write mask.
            dqm_q        <= ~wb_sel_i[1:0];
            dqm_buffer_q <= ~wb_sel_i[3:2];

            data_rd_en_q <= 1'b0;
        end else begin
            command_q    <= CMD_NOP;
            addr_q       <= {SDRAM_ROW_W{1'b0}};
            bank_q       <= {SDRAM_BANK_W{1'b0}};
            data_rd_en_q <= 1'b1;
        end
    end
    STATE_WRITE1: begin
        // Burst continuation.
        command_q <= CMD_NOP;

        data_q <= data_buffer_q;

        // Disable auto precharge (auto close of row).
        addr_q[AUTO_PRECHARGE] <= 1'b0;

        // Write mask.
        dqm_q <= dqm_buffer_q;
    end
    endcase
end

reg [SDRAM_CAS_LATENCY+1:0] rd_q;

assign rd_inflight_w = (|rd_q);
// Record read events.
always_ff @(posedge clk_i)
if (rst_i)
    rd_q <= {(SDRAM_CAS_LATENCY+2){1'b0}};
else
    rd_q <= {rd_q[SDRAM_CAS_LATENCY:0], rd_issue_w};

// Buffer upper 16-bits of write data so write command can be accepted
// in WRITE0. Also buffer lower 16-bits of read data.
always_ff @(posedge clk_i)
if (rst_i)
    data_buffer_q <= {SDRAM_DATA_W{1'b0}};
else if (wr_issue_w)
    data_buffer_q <= wb_dat_i[31:16];
else if (rd_q[SDRAM_CAS_LATENCY+1])
    data_buffer_q <= sample_data_q;

// Read data output.
assign wb_dat_o = {sample_data_q, data_buffer_q};

// Wishbone ACK.
always_ff @(posedge clk_i)
if (rst_i)
    wb_ack_o <= 1'b0;
else begin
    if (state_q == STATE_WRITE1)
        wb_ack_o <= 1'b1;
    else if (rd_q[SDRAM_CAS_LATENCY+1])
        wb_ack_o <= 1'b1;
    else
        wb_ack_o <= 1'b0;
end

// Accept wishbone command in READ or WRITE0 states, and only when the
// request being presented still matches; "wb_stb_i" is deliberately not
// a term, insuring "wb_bsy_o" cannot be part of a combinational loop
// through the interconnect.
assign wb_bsy_o = ~(rd_rqst_w || wr_rqst_w);

genvar i;
// SDRAM I/O.
generate if (SDRAM_TARGET == "XILINX") begin :gen_pads_xilinx
    // 180 degree phase delayed sdram clock output.
    ODDR2 #(
        .DDR_ALIGNMENT("NONE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_clock_delay (
        .Q(sdram_clk_o),
        .C0(clk_i),
        .C1(~clk_i),
        .CE(1'b1),
        .R(1'b0),
        .S(1'b0),
        .D0(1'b0),
        .D1(1'b1));

    for (i = 0; i < SDRAM_DATA_W; i = i + 1) begin :gen_data_buf
      IOBUF u_data_buf (
        .O(sdram_data_in_w[i]),
        .IO(sdram_data_io[i]),
        .I(data_q[i]),
        .T(data_rd_en_q));
    end
end else begin :gen_pads
    assign sdram_clk_o     = ~clk_i;
    assign sdram_data_io   = data_rd_en_q ? {SDRAM_DATA_W{1'bz}} : data_q;
    assign sdram_data_in_w = sdram_data_io;
end
endgenerate

assign sdram_cke_o  = cke_q;
assign sdram_cs_o   = command_q[3];
assign sdram_ras_o  = command_q[2];
assign sdram_cas_o  = command_q[1];
assign sdram_we_o   = command_q[0];
assign sdram_dqm_o  = dqm_q;
assign sdram_ba_o   = bank_q;
assign sdram_addr_o = addr_q;

endmodule
