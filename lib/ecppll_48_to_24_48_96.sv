/* Generated using:
ecppll \
-n ecppll_48_to_24_48_96 \
--clkin_name clk48mhz_i -i 48 \
--clkout0_name clk48mhz_o -o 48 \
--clkout1_name clk96mhz_o --clkout1 96 \
--clkout2_name clk24mhz_o --clkout2 24 \
--internal_feedback \
-f lib/ecppll_48_to_24_48_96.sv */

// 48MHz must be the clkout0, because ecppll derives the vco
// frequency from clkout0 alone, and then merely rounds the
// divisor of every other clkout; ie: 24MHz as the clkout0
// yields a 600MHz vco, from which neither 48MHz nor 96MHz is
// exactly derivable, and they silently become 50MHz and 100MHz,
// while 48MHz as the clkout0 yields a 576MHz vco, from which
// all three frequencies are exactly derivable.

module ecppll_48_to_24_48_96 (
    input clk48mhz_i, // 48 MHz, 0 deg
    output clk48mhz_o, // 48 MHz, 0 deg
    output clk96mhz_o, // 96 MHz, 0 deg
    output clk24mhz_o, // 24 MHz, 0 deg
    output locked
);
wire clkfb;
(* FREQUENCY_PIN_CLKI="48" *)
(* FREQUENCY_PIN_CLKOP="48" *)
(* FREQUENCY_PIN_CLKOS="96" *)
(* FREQUENCY_PIN_CLKOS2="24" *)
(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(1),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(12),
        .CLKOP_CPHASE(5),
        .CLKOP_FPHASE(0),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(6),
        .CLKOS_CPHASE(5),
        .CLKOS_FPHASE(0),
        .CLKOS2_ENABLE("ENABLED"),
        .CLKOS2_DIV(24),
        .CLKOS2_CPHASE(5),
        .CLKOS2_FPHASE(0),
        .FEEDBK_PATH("INT_OP"),
        .CLKFB_DIV(1)
    ) pll_i (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(clk48mhz_i),
        .CLKOP(clk48mhz_o),
        .CLKOS(clk96mhz_o),
        .CLKOS2(clk24mhz_o),
        .CLKFB(clkfb),
        .CLKINTFB(clkfb),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(locked)
	);
endmodule
