
module cyc4pll_50_to_25_50_100 (
  // Clock in ports
  input  wire clk50mhz_i,
  // Clock out ports
  output wire clk25mhz_o,
  output wire clk50mhz_o,
  output wire clk100mhz_o,
  // Status and control signals
  output wire locked
);

  wire [4:0] clk_w;

  assign clk25mhz_o  = clk_w[0];
  assign clk50mhz_o  = clk_w[1];
  assign clk100mhz_o = clk_w[2];

  // altpll is given per-output multiply/divide ratios relative to the 50MHz
  // reference, from which Quartus solves the counters; the 600MHz to 1300MHz
  // vco range of this device holds eight multiples of 100MHz, and every one
  // of them is an exact integer multiple of 25MHz, 50MHz and 100MHz, which
  // insures that the ratios 1/2, 1/1 and 2/1 yield those frequencies exactly
  // rather than as approximations. width_clock is 5 because a Cyclone IV E
  // pll has five post-scale counters.
  // NO_COMPENSATION is used as opposed to NORMAL because normal mode
  // compensates one nominated output by feeding its global clock network back
  // into the pll, while a top routes only one of the three outputs and not
  // necessarily the nominated one; ie: the top here routes 50MHz alone, so
  // the 25MHz network normal mode would nominate does not exist.
  // Every optional input below is tied off rather than left dangling, hence
  // the default port_* value "PORT_CONNECTIVITY" would infer each of them as
  // in use and turn on clock switchover, dynamic reconfiguration and dynamic
  // phase shift; each port_* is therefore stated explicitly.
  altpll #(
    .bandwidth_type          ("AUTO"),
    .clk0_divide_by          (2),
    .clk0_duty_cycle         (50),
    .clk0_multiply_by        (1),
    .clk0_phase_shift        ("0"),
    .clk1_divide_by          (1),
    .clk1_duty_cycle         (50),
    .clk1_multiply_by        (1),
    .clk1_phase_shift        ("0"),
    .clk2_divide_by          (1),
    .clk2_duty_cycle         (50),
    .clk2_multiply_by        (2),
    .clk2_phase_shift        ("0"),
    .compensate_clock        ("CLK0"), // Inert in NO_COMPENSATION.
    .inclk0_input_frequency  (20000), // Reference period in ps; ie: 50MHz.
    .intended_device_family  ("Cyclone IV E"),
    .lpm_type                ("altpll"),
    .operation_mode          ("NO_COMPENSATION"),
    .pll_type                ("AUTO"),
    .port_activeclock        ("PORT_UNUSED"),
    .port_areset             ("PORT_UNUSED"),
    .port_clk0               ("PORT_USED"),
    .port_clk1               ("PORT_USED"),
    .port_clk2               ("PORT_USED"),
    .port_clk3               ("PORT_UNUSED"),
    .port_clk4               ("PORT_UNUSED"),
    .port_clk5               ("PORT_UNUSED"),
    .port_clkbad0            ("PORT_UNUSED"),
    .port_clkbad1            ("PORT_UNUSED"),
    .port_clkena0            ("PORT_UNUSED"),
    .port_clkena1            ("PORT_UNUSED"),
    .port_clkena2            ("PORT_UNUSED"),
    .port_clkena3            ("PORT_UNUSED"),
    .port_clkena4            ("PORT_UNUSED"),
    .port_clkena5            ("PORT_UNUSED"),
    .port_clkloss            ("PORT_UNUSED"),
    .port_clkswitch          ("PORT_UNUSED"),
    .port_configupdate       ("PORT_UNUSED"),
    .port_extclk0            ("PORT_UNUSED"),
    .port_extclk1            ("PORT_UNUSED"),
    .port_extclk2            ("PORT_UNUSED"),
    .port_extclk3            ("PORT_UNUSED"),
    .port_fbin               ("PORT_UNUSED"),
    .port_inclk0             ("PORT_USED"),
    .port_inclk1             ("PORT_UNUSED"),
    .port_locked             ("PORT_USED"),
    .port_pfdena             ("PORT_UNUSED"),
    .port_phasecounterselect ("PORT_UNUSED"),
    .port_phasedone          ("PORT_UNUSED"),
    .port_phasestep          ("PORT_UNUSED"),
    .port_phaseupdown        ("PORT_UNUSED"),
    .port_pllena             ("PORT_UNUSED"),
    .port_scanaclr           ("PORT_UNUSED"),
    .port_scanclk            ("PORT_UNUSED"),
    .port_scanclkena         ("PORT_UNUSED"),
    .port_scandata           ("PORT_UNUSED"),
    .port_scandataout        ("PORT_UNUSED"),
    .port_scandone           ("PORT_UNUSED"),
    .port_scanread           ("PORT_UNUSED"),
    .port_scanwrite          ("PORT_UNUSED"),
    .self_reset_on_loss_lock ("OFF"),
    .width_clock             (5)
  ) altpll_component (
    // Output clocks
    .clk                 (clk_w),
    // Input clock control
    .inclk               ({1'b0, clk50mhz_i}),
    // Ports for clock switchover
    .clkswitch           (1'b0),
    .clkbad              (),
    .activeclock         (),
    .clkloss             (),
    // Ports for dynamic reconfiguration
    .scanclk             (1'b0),
    .scanclkena          (1'b1),
    .scanaclr            (1'b0),
    .scandata            (1'b0),
    .scanread            (1'b0),
    .scanwrite           (1'b0),
    .scandataout         (),
    .scandone            (),
    .configupdate        (1'b0),
    // Ports for dynamic phase shift
    .phasecounterselect  ({4{1'b1}}),
    .phasestep           (1'b1),
    .phaseupdown         (1'b1),
    .phasedone           (),
    // Other control and status signals
    .areset              (1'b0),
    .pllena              (1'b1),
    .pfdena              (1'b1),
    .clkena              ({6{1'b1}}),
    .extclkena           ({4{1'b1}}),
    .extclk              (),
    .fbout               (),
    .fbin                (1'b1),
    .fbmimicbidir        (),
    .enable0             (),
    .enable1             (),
    .sclkout0            (),
    .sclkout1            (),
    .fref                (),
    .icdrclk             (),
    .vcooverrange        (),
    .vcounderrange       (),
    .locked              (locked));

endmodule
