
`include "lib/xc7pll_100_to_48.sv"
`include "lib/xc7pll_48_to_48_96_192.sv"

module xc7pll_100_to_48_96_192 (
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

  wire xc7pll_100_to_48_clk_out2;
  xc7pll_100_to_48 pll0 (
     .reset    (reset)
    ,.clk_in1  (clk_in1)
    ,.clk_out2 (xc7pll_100_to_48_clk_out2));

  wire xc7pll_48_to_48_96_192_clk_in1;
  (* BOX_TYPE = "PRIMITIVE" *)
  BUFG clkin1_bufg
   (.O (xc7pll_48_to_48_96_192_clk_in1),
    .I (xc7pll_100_to_48_clk_out2));

  xc7pll_48_to_48_96_192 pll1 (
     .reset    (reset)
    ,.locked   (locked)
    ,.clk_in1  (xc7pll_48_to_48_96_192_clk_in1)
    ,.clk_out1 (clk_out1)
    ,.clk_out2 (clk_out2)
    ,.clk_out3 (clk_out3)
);

endmodule
