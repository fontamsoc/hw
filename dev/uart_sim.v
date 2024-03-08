// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Simulation version of uart_hw peripheral.
// Only writing is supported through the use of $write().
// Reading returns bogus values.

module uart_sim (

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

parameter ARCHBITSZ = 16;

parameter BUFSZ = 2;

localparam CLOG2BUFSZ = clog2(BUFSZ);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire                        wb_cyc_i;
input  wire                        wb_stb_i;
input  wire                        wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     wb_dat_i;
output wire                        wb_bsy_o;
output reg                         wb_ack_o;
output wire [ARCHBITSZ -1 : 0]     wb_dat_o;
output wire [ARCHBITSZ -1 : 0]     wb_mapsz_o;

output wire irq_stb_o;
input  wire irq_rdy_i;

assign wb_bsy_o = 1'b0;

assign wb_mapsz_o = ((128/ARCHBITSZ)*(ARCHBITSZ/8));

reg                    wb_stb_r;
reg                    wb_we_r;
reg [ADDRBITSZ -1 : 0] wb_addr_r;
reg [ARCHBITSZ -1 : 0] wb_dat_r;

wire wb_stb_r_ = (wb_cyc_i && wb_stb_i);

always @ (posedge clk_i) begin
	wb_stb_r <= wb_stb_r_ ;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_dat_r <= wb_dat_i;
	end
	wb_ack_o <= wb_stb_r;
end

localparam CMDDEVRDY         = 0;
localparam CMDGETBUFFERUSAGE = 1;
localparam CMDSETINTERRUPT   = 2;
localparam CMDSETSPEED       = 3;

reg [ARCHBITSZ -1 : 0] wb_dat_o_;

// Half the memory mapping is used to send/receive data,
// while the other half is used to issue commands.
localparam CLOG264BYARCHBITSZ = clog2(64/ARCHBITSZ);

wire iscmd = (!rst_i && wb_stb_r && wb_we_r && wb_addr_r[CLOG264BYARCHBITSZ]);

wire prevcmdisdevrdy = (wb_dat_o_[1:0] == CMDDEVRDY);

wire prevcmddone = (iscmd && prevcmdisdevrdy);

wire cmddevrdy = (iscmd && wb_dat_r[1:0] == CMDDEVRDY);
wire cmdgetbuf = (prevcmddone && wb_dat_r[1:0] == CMDGETBUFFERUSAGE);
wire cmdsetint = (prevcmddone && wb_dat_r[1:0] == CMDSETINTERRUPT);
wire cmdsetspd = (prevcmddone && wb_dat_r[1:0] == CMDSETSPEED);

wire devrd = (!rst_i && wb_stb_r && !wb_we_r && !wb_addr_r[CLOG264BYARCHBITSZ] && prevcmdisdevrdy);
wire devwr = (!rst_i && wb_stb_r &&  wb_we_r && !wb_addr_r[CLOG264BYARCHBITSZ] && prevcmdisdevrdy);

wire            rx_read_w = devrd;
wire [8 -1 : 0] rx_data_w0 = "\n";

reg [(CLOG2BUFSZ +1) -1 : 0] rx_usage_r;

reg [(ARCHBITSZ-2) -1 : 0] intrqstthresh;

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

reg [ARCHBITSZ -1 : 0] cntr = 0;

always @ (posedge clk_i) begin
	// Logic enabling/disabling interrupt.
	if (rst_i) begin
		// On reset, interrupt is disabled, and must be explicitely enabled.
		// It prevents unwanted interrupt after reset.
		intrqstthresh <= 0;
	end else if (cmdsetint) begin
		//intrqstthresh <= wb_dat_r[ARCHBITSZ-1:2]; /* ### Uncomment to generate interrupts */
	end else if (irq_rdy_i_negedge) begin
		intrqstthresh <= 0;
	end

	if (rst_i || cmddevrdy) begin
		wb_dat_o_ <= {ARCHBITSZ{1'b0}};
	end else if (cmdsetint) begin
		wb_dat_o_ <= {BUFSZ[(ARCHBITSZ-2)-1:0], wb_dat_r[1:0]};
	end else if (cmdgetbuf) begin
		wb_dat_o_ <= {
			{((ARCHBITSZ-2)-(CLOG2BUFSZ+1)){1'b0}},
			(wb_dat_r[2] ? {(CLOG2BUFSZ+1){1'b0}} : rx_usage_r),
			wb_dat_r[1:0]};
	end else if (cmdsetspd) begin
		wb_dat_o_ <= {{(ARCHBITSZ-2){1'b0}}, wb_dat_r[1:0]};
	end

	if (rst_i || cntr >= 100000000) begin
		cntr <= 0;
		rx_usage_r <= BUFSZ;
	end else if (rx_usage_r) begin
		if (devrd)
			rx_usage_r <= rx_usage_r - 1'b1;
	end else
		cntr <= cntr + 1'b1;

	if (devwr) begin
		$write("%c", wb_dat_r[8 -1 : 0]); $fflush(1);
	end

	rx_read_w_sampled <= rx_read_w;

	irq_rdy_i_r <= irq_rdy_i; // Sampling used for edge detection.
end

endmodule
