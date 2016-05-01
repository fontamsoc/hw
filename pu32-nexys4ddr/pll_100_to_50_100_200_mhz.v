
module pll_100_to_50_100_200_mhz (
  // Clock in ports
  input  wire clk_in1,
  // Clock out ports
  output wire clk_out1,
  output wire clk_out2,
  output wire clk_out3,
  // Status and control signals
  input  wire reset,
  output wire locked
);

  wire [15:0] do_unused;
  wire        drdy_unused;
  wire        psdone_unused;
  wire        locked_int;
  wire        clkfbout;
  wire        clkfbout_buf;
  wire        clkfboutb_unused;
  wire        clkout3_unused;
  wire        clkout4_unused;
  wire        clkout5_unused;
  wire        clkout6_unused;
  wire        clkfbstopped_unused;
  wire        clkinstopped_unused;
  wire        reset_high;

  (* BOX_TYPE = "PRIMITIVE" *)
  BUFG clkf_buf
   (.O (clkfbout_buf),
    .I (clkfbout));

  (* BOX_TYPE = "PRIMITIVE" *)
  PLLE2_ADV
  #(.BANDWIDTH            ("OPTIMIZED"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (1),
    .CLKFBOUT_MULT        (10),
    .CLKFBOUT_PHASE       (0.000),
    .CLKOUT0_DIVIDE       (20),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT1_DIVIDE       (10),
    .CLKOUT1_PHASE        (0.000),
    .CLKOUT1_DUTY_CYCLE   (0.500),
    .CLKOUT2_DIVIDE       (5),
    .CLKOUT2_PHASE        (0.000),
    .CLKOUT2_DUTY_CYCLE   (0.500),
    .CLKIN1_PERIOD        (10.000)
  ) plle2_adv_inst (
    // Output clocks
    .CLKFBOUT            (clkfbout),
    .CLKOUT0             (clk_out1),
    .CLKOUT1             (clk_out2),
    .CLKOUT2             (clk_out3),
    .CLKOUT3             (clkout3_unused),
    .CLKOUT4             (clkout4_unused),
    .CLKOUT5             (clkout5_unused),
    // Input clock control
    .CLKFBIN             (clkfbout_buf),
    .CLKIN1              (clk_in1),
    .CLKIN2              (1'b0),
    // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DO                  (do_unused),
    .DRDY                (drdy_unused),
    .DWE                 (1'b0),
    // Other control and status signals
    .LOCKED              (locked_int),
    .PWRDWN              (1'b0),
    .RST                 (reset_high));

  assign reset_high = reset;
  assign locked = locked_int;

endmodule
