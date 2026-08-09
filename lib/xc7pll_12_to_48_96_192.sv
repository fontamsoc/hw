
module xc7pll_12_to_48_96_192 (
  // Clock in ports
  input  wire clk12mhz_i,
  // Clock out ports
  output wire clk48mhz_o,
  output wire clk96mhz_o,
  output wire clk192mhz_o,
  // Status and control signals
  output wire locked
);

  wire clkfbout;
  wire clkfbout_buf;

  (* BOX_TYPE = "PRIMITIVE" *)
  BUFG clkf_buf
   (.O (clkfbout_buf),
    .I (clkfbout));

  // MMCME2_ADV is used as opposed to PLLE2_ADV because a PLLE2 cannot lock
  // from a 12MHz reference: its minimum input frequency is 19MHz, and its
  // 800MHz VCO minimum is unreachable since the largest feedback multiplier
  // 64 gives 12*64 == 768MHz; an MMCME2 accepts a 10MHz minimum input, and
  // 12*64 == 768MHz sits within its 600MHz to 1200MHz VCO range, which
  // insures that the integer divides 16, 8 and 4 yield exactly 48MHz,
  // 96MHz and 192MHz.
  (* BOX_TYPE = "PRIMITIVE" *)
  MMCME2_ADV #(
    .BANDWIDTH            ("OPTIMIZED"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (1),
    .CLKFBOUT_MULT_F      (64.000),
    .CLKFBOUT_PHASE       (0.000),
    .CLKOUT0_DIVIDE_F     (16.000),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT1_DIVIDE       (8),
    .CLKOUT1_PHASE        (0.000),
    .CLKOUT1_DUTY_CYCLE   (0.500),
    .CLKOUT2_DIVIDE       (4),
    .CLKOUT2_PHASE        (0.000),
    .CLKOUT2_DUTY_CYCLE   (0.500),
    .CLKIN1_PERIOD        (83.333)
  ) mmcme2_adv_inst (
    // Output clocks
    .CLKFBOUT            (clkfbout),
    .CLKOUT0             (clk48mhz_o),
    .CLKOUT1             (clk96mhz_o),
    .CLKOUT2             (clk192mhz_o),
    // Input clock control
    .CLKFBIN             (clkfbout_buf),
    .CLKIN1              (clk12mhz_i),
    .CLKIN2              (1'b0),
    // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DWE                 (1'b0),
    // Ports for dynamic phase shift
    .PSCLK               (1'b0),
    .PSEN                (1'b0),
    .PSINCDEC            (1'b0),
    // Other control and status signals
    .LOCKED              (locked),
    .PWRDWN              (1'b0),
    .RST                 (1'b0));

endmodule
