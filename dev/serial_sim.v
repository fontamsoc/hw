// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Simulation version of serial_uart peripheral.
// Only writing is supported through the use of $write().
// Reading returns bogus values.

module serial_sim (

	 rst_i

	,clk_i

	,wb_cyc_i
	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o
	,wb_mapsz_o

	,irq_stb_o
	,irq_rdy_i
);

`include "lib/clog2.v"

parameter WORDBITSZ = 32;

parameter BUFSZ = 2;

localparam CLOG2BUFSZ = clog2(BUFSZ);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire                        wb_cyc_i;
input  wire                        wb_stb_i;
input  wire                        wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0] wb_sel_i;
input  wire [WORDBITSZ -1 : 0]     wb_dat_i;
output wire                        wb_bsy_o;
output reg                         wb_ack_o;
output wire [WORDBITSZ -1 : 0]     wb_dat_o;
output wire [WORDBITSZ -1 : 0]     wb_mapsz_o;

output wire irq_stb_o;
input  wire irq_rdy_i;

// By convention, devices mapsz must be aligned to 128 bytes (1024 bits).
localparam MAPSZ = 128;
assign wb_mapsz_o = MAPSZ;

reg                    wb_stb_r;
reg                    wb_we_r;
reg [ADDRBITSZ -1 : 0] wb_addr_r;
reg [WORDBITSZ -1 : 0] wb_dat_r;

wire wb_stb_r_ = (wb_cyc_i && wb_stb_i && !wb_bsy_o);

always @ (posedge clk_i) begin
	wb_stb_r <= wb_stb_r_ ;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_dat_r <= wb_dat_i;
	end
end

always @ (posedge clk_i) begin
	wb_ack_o <= wb_stb_r;
end

localparam CMDDEVRDY         = 0;
localparam CMDGETBUFFERUSAGE = 1;
localparam CMDSETINTERRUPT   = 2;
localparam CMDSETSPEED       = 3;

reg [WORDBITSZ -1 : 0] wb_dat_o_;

// Half the memory mapping is used to send/receive data,
// while the other half is used to issue commands.
localparam ISCMDBIT = (clog2(MAPSZ/2) - CLOG2WORDBITSZBY8);

wire iscmd = (!rst_i && wb_stb_r && wb_we_r && wb_addr_r[ISCMDBIT]);

wire prevcmdisdevrdy = (wb_dat_o_[1:0] == CMDDEVRDY);

wire prevcmddone = (iscmd && prevcmdisdevrdy);

wire cmddevrdy = (iscmd && wb_dat_r[1:0] == CMDDEVRDY);
wire cmdgetbuf = (prevcmddone && wb_dat_r[1:0] == CMDGETBUFFERUSAGE);
wire cmdsetint = (prevcmddone && wb_dat_r[1:0] == CMDSETINTERRUPT);
wire cmdsetspd = (prevcmddone && wb_dat_r[1:0] == CMDSETSPEED);

wire devrd = (!rst_i && wb_stb_r && !wb_we_r && !wb_addr_r[ISCMDBIT] && prevcmdisdevrdy);
wire devwr = (!rst_i && wb_stb_r &&  wb_we_r && !wb_addr_r[ISCMDBIT] && prevcmdisdevrdy);

wire            rx_read_w = devrd;
reg  [8 -1 : 0] rx_data_w0;

reg [(CLOG2BUFSZ +1) -1 : 0] rx_usage_r;

assign wb_bsy_o = (!wb_addr_i[ISCMDBIT] && (wb_we_i ? 1'b0 : (rx_usage_r == 0)));

reg [(WORDBITSZ-2) -1 : 0] intrqstthresh;

assign irq_stb_o = (|intrqstthresh && (rx_usage_r >= intrqstthresh) &&
	// Raise intrqst only when the device is ready for the next command,
	// otherwise an interrupt would cause software to send the device a new
	// command while it is not ready, waiting indefinitely for it to be ready.
	prevcmdisdevrdy);

// Register used to detect a falling edge on "irq_rdy_i".
reg  irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

reg rx_read_w_sampled;

assign wb_dat_o = (rx_read_w_sampled ? rx_data_w0 : wb_dat_o_);

always @ (posedge clk_i) begin
	// Logic enabling/disabling interrupt.
	if (rst_i) begin
		// On reset, interrupt is disabled, and must be explicitely enabled.
		// It prevents unwanted interrupt after reset.
		intrqstthresh <= 0;
	end else if (cmdsetint) begin
		intrqstthresh <= wb_dat_r[WORDBITSZ-1:2];
	end else if (irq_rdy_i_negedge) begin
		intrqstthresh <= 0;
	end
end

always @ (posedge clk_i) begin
	if (rst_i || cmddevrdy) begin
		wb_dat_o_ <= {WORDBITSZ{1'b0}};
	end else if (cmdsetint) begin
		wb_dat_o_ <= {BUFSZ[(WORDBITSZ-2)-1:0], wb_dat_r[1:0]};
	end else if (cmdgetbuf) begin
		wb_dat_o_ <= {
			{((WORDBITSZ-2)-(CLOG2BUFSZ+1)){1'b0}},
			(wb_dat_r[2] ? {(CLOG2BUFSZ+1){1'b0}} : rx_usage_r),
			wb_dat_r[1:0]};
	end else if (cmdsetspd) begin
		wb_dat_o_ <= {{(WORDBITSZ-2){1'b0}}, wb_dat_r[1:0]};
	end
end

reg [WORDBITSZ -1 : 0] cntr = 0;
always @ (posedge clk_i) begin
	if (rst_i || cntr >= 1000) begin
		cntr <= 0;
		rx_usage_r <= !$feof(0);
	end else if (rx_usage_r) begin
		if (devrd)
			rx_usage_r <= rx_usage_r - 1'b1;
	end else
		cntr <= cntr + 1'b1;
end

always @ (posedge clk_i) begin
	if (devrd && rx_data_w0) begin
		$fread(rx_data_w0, 0);
	end
end

always @ (posedge clk_i) begin
	if (devwr) begin
		$fwrite(1, "%c", wb_dat_r[8 -1 : 0]); $fflush(1);
	end
end

always @ (posedge clk_i) begin
	rx_read_w_sampled <= rx_read_w;
	irq_rdy_i_r <= irq_rdy_i; // Sampling used for edge detection.
end

endmodule
