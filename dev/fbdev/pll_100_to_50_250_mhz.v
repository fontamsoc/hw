
module pll_100_to_50_250_mhz (
    // Inputs
     input wire  clk_in1
    // Outputs
    ,output wire clk_out1
    ,output wire clk_out2
    // Status and control signals
    ,input  wire reset
    ,output wire locked
);

wire clkfbout_w;
wire clkfbout_buffered_w;

// Clocking primitive
PLLE2_BASE
#(
    .BANDWIDTH("OPTIMIZED"),      // OPTIMIZED, HIGH, LOW
    .CLKFBOUT_PHASE(0.0),         // Phase offset in degrees of CLKFB, (-360-360)
    .CLKIN1_PERIOD(10.0),         // Input clock period in ns resolution
    .CLKFBOUT_MULT(10),     // VCO=1000MHz

    // CLKOUTx_DIVIDE: Divide amount for each CLKOUT(1-128)
    .CLKOUT0_DIVIDE(20), // CLK0=50MHz
    .CLKOUT1_DIVIDE(4), // CLK1=250MHz

    // CLKOUTx_DUTY_CYCLE: Duty cycle for each CLKOUT
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT3_DUTY_CYCLE(0.5),

    // CLKOUTx_PHASE: Phase offset for each CLKOUT
    .CLKOUT0_PHASE(0.0),
    .CLKOUT1_PHASE(0.0),
    .CLKOUT2_PHASE(0.0),
    .CLKOUT3_PHASE(0.0),

    .DIVCLK_DIVIDE(1),            // Master division value (1-56)
    .REF_JITTER1(0.0),            // Ref. input jitter in UI (0.000-0.999)
    .STARTUP_WAIT("TRUE")         // Delay DONE until PLL Locks ("TRUE"/"FALSE")
)
u_pll
(
    .CLKFBOUT(clkfbout_w),
    .CLKOUT0(clk_out1),
    .CLKOUT1(clk_out2),
    .CLKOUT2(),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .LOCKED(locked),
    .PWRDWN(1'b0),
    .RST(reset),
    .CLKIN1(clk_in1),
    .CLKFBIN(clkfbout_buffered_w)
);

BUFH u_clkfb_buf
(
    .I(clkfbout_w),
    .O(clkfbout_buffered_w)
);

endmodule
