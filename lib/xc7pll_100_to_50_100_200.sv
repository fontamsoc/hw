
module xc7pll_100_to_50_100_200 (
  // Clock in ports
  input  wire clk100mhz_i,
  // Clock out ports
  output wire clk50mhz_o,
  output wire clk100mhz_o,
  output wire clk200mhz_o,
  // Status and control signals
  output wire locked
);

  wire clkfbout;
  wire clkfbout_buf;

  (* BOX_TYPE = "PRIMITIVE" *)
  BUFG clkf_buf
   (.O (clkfbout_buf),
    .I (clkfbout));

  (* BOX_TYPE = "PRIMITIVE" *)
  PLLE2_ADV #(
    .BANDWIDTH            ("OPTIMIZED"),
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
    .CLKOUT0             (clk50mhz_o),
    .CLKOUT1             (clk100mhz_o),
    .CLKOUT2             (clk200mhz_o),
    // Input clock control
    .CLKFBIN             (clkfbout_buf),
    .CLKIN1              (clk100mhz_i),
    .CLKIN2              (1'b0),
    // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DWE                 (1'b0),
    // Other control and status signals
    .LOCKED              (locked),
    .PWRDWN              (1'b0),
    .RST                 (1'b0));

endmodule
