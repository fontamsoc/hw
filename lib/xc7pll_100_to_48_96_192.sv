
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

  wire clk48mhz_w;
  xc7pll_100_to_48 pll0 (
     .clk100mhz_i (clk100mhz_i)
    ,.clk48mhz_o  (clk48mhz_w));

  wire _clk48mhz_w;
  (* BOX_TYPE = "PRIMITIVE" *)
  BUFG clkin1_bufg
   (.I (clk48mhz_w),
    .O (_clk48mhz_w));

  xc7pll_48_to_48_96_192 pll1 (
     .locked      (locked)
    ,.clk48mhz_i  (_clk48mhz_w)
    ,.clk48mhz_o  (clk48mhz_o)
    ,.clk96mhz_o  (clk96mhz_o)
    ,.clk192mhz_o (clk192mhz_o)
);

endmodule
