
module pll_100_to_50_100_mhz (
  // Clock in ports
  input  wire clk_in1,
  // Clock out ports
  output wire clk_out1,
  output wire clk_out2,
  // Status and control signals
  input  wire reset,
  output wire locked
);

  // Clocking primitive
  //------------------------------------
  wire        clk_out1_pll_100_to_50_100_mhz;
  wire        clk_out2_pll_100_to_50_100_mhz;
  wire [15:0] do_unused;
  wire        drdy_unused;
  wire        psdone_unused;
  wire        locked_int;
  wire        clkfbout_pll_100_to_50_100_mhz;
  wire        clkfbout_buf_pll_100_to_50_100_mhz;
  wire        clkfboutb_unused;
  wire        clkout2_unused;
  wire        clkout3_unused;
  wire        clkout4_unused;
  wire        clkout5_unused;
  wire        clkout6_unused;
  wire        clkfbstopped_unused;
  wire        clkinstopped_unused;
  wire        reset_high;
  (* KEEP = "TRUE" *)
  (* ASYNC_REG = "TRUE" *)
  reg  [7 :0] seq_reg1 = 0;
  (* KEEP = "TRUE" *)
  (* ASYNC_REG = "TRUE" *)
  reg  [7 :0] seq_reg2 = 0;

  PLLE2_ADV
  #(.BANDWIDTH            ("OPTIMIZED"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (1),
    .CLKFBOUT_MULT        (9),
    .CLKFBOUT_PHASE       (0.000),
    .CLKOUT0_DIVIDE       (18),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT1_DIVIDE       (9),
    .CLKOUT1_PHASE        (0.000),
    .CLKOUT1_DUTY_CYCLE   (0.500),
    .CLKIN1_PERIOD        (10.000)
  ) plle2_adv_inst (
    // Output clocks
    .CLKFBOUT            (clkfbout_pll_100_to_50_100_mhz),
    .CLKOUT0             (clk_out1_pll_100_to_50_100_mhz),
    .CLKOUT1             (clk_out2_pll_100_to_50_100_mhz),
    .CLKOUT2             (clkout2_unused),
    .CLKOUT3             (clkout3_unused),
    .CLKOUT4             (clkout4_unused),
    .CLKOUT5             (clkout5_unused),
    // Input clock control
    .CLKFBIN             (clkfbout_buf_pll_100_to_50_100_mhz),
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

  //-----------------------------------
  // Output buffering
  //-----------------------------------

  BUFG clkf_buf
   (.O (clkfbout_buf_pll_100_to_50_100_mhz),
    .I (clkfbout_pll_100_to_50_100_mhz));

  BUFGCE clkout1_buf
   (.O   (clk_out1),
    .CE  (seq_reg1[7]),
    .I   (clk_out1_pll_100_to_50_100_mhz));

  wire clk_out1_pll_100_to_50_100_mhz_en_clk;
  BUFH clkout1_buf_en
   (.O   (clk_out1_pll_100_to_50_100_mhz_en_clk),
    .I   (clk_out1_pll_100_to_50_100_mhz));
  always @(posedge clk_out1_pll_100_to_50_100_mhz_en_clk or posedge reset_high) begin
    if(reset_high == 1'b1) begin
	    seq_reg1 <= 8'h00;
    end
    else begin
        seq_reg1 <= {seq_reg1[6:0],locked_int};
    end
  end

  BUFGCE clkout2_buf
   (.O   (clk_out2),
    .CE  (seq_reg2[7]),
    .I   (clk_out2_pll_100_to_50_100_mhz));

  wire clk_out2_pll_100_to_50_100_mhz_en_clk;
  BUFH clkout2_buf_en
   (.O   (clk_out2_pll_100_to_50_100_mhz_en_clk),
    .I   (clk_out2_pll_100_to_50_100_mhz));
  always @(posedge clk_out2_pll_100_to_50_100_mhz_en_clk or posedge reset_high) begin
    if(reset_high == 1'b1) begin
	  seq_reg2 <= 8'h00;
    end
    else begin
        seq_reg2 <= {seq_reg2[6:0],locked_int};
    end
  end

endmodule
