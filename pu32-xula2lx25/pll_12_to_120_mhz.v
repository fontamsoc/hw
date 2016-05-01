
module pll_12_to_120_mhz (
  // Clock in ports
  input  wire CLK_IN1,
  // Clock out ports
  output wire CLK_OUT1,
  // Status and control signals
  input  wire RESET,
  output wire LOCKED
 );

  // Clocking primitive
  //------------------------------------

  // Instantiation of the DCM primitive
  //    * Unused inputs are tied off
  //    * Unused outputs are labeled unused
  wire [7:0] status_int;
  wire       clkfb;
  wire       clk0;
  wire       clkfx;

  DCM_SP #(
    .CLKDV_DIVIDE          (2.000),
    .CLKFX_DIVIDE          (1),
    .CLKFX_MULTIPLY        (10),
    .CLKIN_DIVIDE_BY_2     ("FALSE"),
    .CLKIN_PERIOD          (83.3333333333),
    .CLKOUT_PHASE_SHIFT    ("NONE"),
    .CLK_FEEDBACK          ("1X"),
    .DESKEW_ADJUST         ("SYSTEM_SYNCHRONOUS"),
    .PHASE_SHIFT           (0),
    .STARTUP_WAIT          ("FALSE")
  ) dcm_sp_inst (
    // Input clock
    .CLKIN                 (CLK_IN1),
    .CLKFB                 (clkfb),
    // Output clocks
    .CLK0                  (clk0),
    .CLK90                 (),
    .CLK180                (),
    .CLK270                (),
    .CLK2X                 (),
    .CLK2X180              (),
    .CLKFX                 (clkfx),
    .CLKFX180              (),
    .CLKDV                 (),
    // Ports for dynamic phase shift
    .PSCLK                 (1'b0),
    .PSEN                  (1'b0),
    .PSINCDEC              (1'b0),
    .PSDONE                (),
    // Other control and status signals
    .LOCKED                (LOCKED),
    .STATUS                (status_int),
 
    .RST                   (RESET),
    // Unused pin- tie low
    .DSSEN                 (1'b0));

  // Output buffering
  //-----------------------------------
  //BUFG clkf_buf (
  //  .O (clkfb),
  //  .I (clk0));
  assign clkfb = clk0;

  //BUFG clkout1_buf (
  //  .O   (CLK_OUT1),
  //  .I   (clkfx));
  assign CLK_OUT1 = clkfx;

endmodule
