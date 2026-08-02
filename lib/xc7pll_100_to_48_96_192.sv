
`include "lib/xc7pll_100_to_48.sv"
`include "lib/xc7pll_48_to_48_96_192.sv"

module xc7pll_100_to_48_96_192 (
  // Clock in ports
  input  wire clk100mhz_i,
  // Clock out ports
  output wire clk48mhz_o,
  output wire clk96mhz_o,
  output wire clk192mhz_o,
  // Status and control signals
  output wire locked
);

  wire pll0_locked_w;
  wire clk48mhz_w;
  xc7pll_100_to_48 pll0 (
     .locked      (pll0_locked_w)
    ,.clk100mhz_i (clk100mhz_i)
    ,.clk48mhz_o  (clk48mhz_w));

  wire _clk48mhz_w;
  (* BOX_TYPE = "PRIMITIVE" *)
  BUFG clkin1_bufg
   (.I (clk48mhz_w),
    .O (_clk48mhz_w));

  // pll1 reference is pll0 output as opposed to a clock coming from a pad,
  // hence pll1 is held in reset until pll0 has locked, which insures that
  // its reference has settled before it starts acquiring. pll1 alone then
  // reports the lock of the whole cascade, as it cannot lock before pll0,
  // and pll0 losing lock puts it back in reset.
  xc7pll_48_to_48_96_192 pll1 (
     .rst_i       (~pll0_locked_w)
    ,.locked      (locked)
    ,.clk48mhz_i  (_clk48mhz_w)
    ,.clk48mhz_o  (clk48mhz_o)
    ,.clk96mhz_o  (clk96mhz_o)
    ,.clk192mhz_o (clk192mhz_o)
);

endmodule
