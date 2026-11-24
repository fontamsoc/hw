/* Generated using:
gowin_pll \
-d "GW2AR-18 C8/I7" \
-i 27 -o 108 \
-m gw2apll_27_to_27_54_108
then extended by hand with the 54MHz and 27MHz outputs, with every
parameter of the rPLL primitive stated explicitly, and with the ports
declared as wires, which Gowin EDA requires under `default_nettype none. */

// The rPLL derives every output from CLKOUT: CLKOUTD divides it by the
// even DYN_SDIV_SEL, and CLKOUTD3 by 3; hence 108MHz must be the CLKOUT,
// from which CLKOUTD divides 54MHz. 27MHz, which would take CLKOUTD a
// second time, comes instead from the CLKDIV primitive dividing CLKOUT by
// 4, which leaves the 36MHz of CLKOUTD3 unused. The 27MHz reference
// reaches 108MHz through a 27MHz pfd (27/1*4), inside the 3MHz to 500MHz
// pfd range of this device; the vco runs at 108*8=864MHz, inside its
// 500MHz to 1250MHz range.

module gw2apll_27_to_27_54_108 (
    input  wire clk27mhz_i, // 27 MHz, 0 deg
    output wire clk108mhz_o, // 108 MHz, 0 deg
    output wire clk54mhz_o, // 54 MHz, 0 deg
    output wire clk27mhz_o, // 27 MHz, 0 deg
    output wire locked
);
rPLL #(
        .FCLKIN("27"),
        .DYN_IDIV_SEL("false"),
        .IDIV_SEL(0), // -> PFD = 27 MHz
        .DYN_FBDIV_SEL("false"),
        .FBDIV_SEL(3), // -> CLKOUT = 108 MHz
        .DYN_ODIV_SEL("false"),
        .ODIV_SEL(8), // -> VCO = 864 MHz
        .PSDA_SEL("0000"),
        .DYN_DA_EN("false"),
        .DUTYDA_SEL("1000"),
        .CLKOUT_FT_DIR(1'b1),
        .CLKOUTP_FT_DIR(1'b1),
        .CLKOUT_DLY_STEP(0),
        .CLKOUTP_DLY_STEP(0),
        .CLKFB_SEL("internal"),
        .CLKOUT_BYPASS("false"),
        .CLKOUTP_BYPASS("false"),
        .CLKOUTD_BYPASS("false"),
        .DYN_SDIV_SEL(2), // -> CLKOUTD = 54 MHz
        .CLKOUTD_SRC("CLKOUT"),
        .CLKOUTD3_SRC("CLKOUT"), // -> CLKOUTD3 = 36 MHz, unused
        .DEVICE("GW2AR-18C")
    ) pll_i (
        .CLKIN(clk27mhz_i),
        .CLKFB(1'b0),
        .RESET(1'b0),
        .RESET_P(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0),
        .CLKOUT(clk108mhz_o),
        .CLKOUTP(),
        .CLKOUTD(clk54mhz_o),
        .CLKOUTD3(),
        .LOCK(locked)
	);
CLKDIV #(
        .DIV_MODE("4"), // -> 27 MHz
        .GSREN("false")
    ) clkdiv_i (
        .HCLKIN(clk108mhz_o),
        .RESETN(1'b1),
        .CALIB(1'b0),
        .CLKOUT(clk27mhz_o)
	);
endmodule
