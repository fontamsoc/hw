// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "lib/fifo.v"
`include "lib/uart/uart_tx.v"

module dbgprobe (
	 rst_i
	,clk_i
	,trig_i
	,probe_i
	,tx_o
	,done_o
);

`include "lib/clog2.v"

parameter CLKFREQ = 1;
parameter PROBEWIDTH = 1;
parameter PROBEDEPTH = 2;
parameter TXDEPTH = 1;
parameter TXBITRATE = 115200;

input wire rst_i;

input wire clk_i;

input wire trig_i;

input wire [PROBEWIDTH -1 : 0] probe_i;

output wire tx_o;

output wire done_o;

// Register used to save the value of the input
// "probe_i" in order to detect when it changes.
reg [PROBEWIDTH -1 : 0] probesampled = 0;

// Register set to 1 when the probe buffer
// becomes full, marking the end of the probing.
reg doneprobing = 0;

assign done_o = doneprobing;

localparam NLCRSZ = 2; // Nbr of characters used for "\n\r".

// Register used to index each nible of a probed value.
// The 2nd to the last +1 accounts for the fact that
// when nibleidx is null, it means that all nibles
// of the probed value have been transmitted.
// The last +1 insures that that the clog2() will
// result in enough bit to encode the maximum value
// to set in nibleidx.
reg  [clog2(((((PROBEWIDTH -1) >> 2) +NLCRSZ) +1) +1) -1 : 0] nibleidx = 0;
wire [clog2(((((PROBEWIDTH -1) >> 2) +NLCRSZ) +1) +1) -1 : 0] nibleidx_minus_one = (nibleidx - 1'b1);

wire [(clog2(PROBEDEPTH) +1) -1 : 0] probebufferusage;

wire [PROBEWIDTH -1 : 0] probebufferdataout;

wire probebufferempty;
wire probebufferfull;

reg trig_r = 0;

fifo #(

	 .WIDTH (PROBEWIDTH)
	,.DEPTH (PROBEDEPTH)

) probebuffer (

	 .rst_i (rst_i)

	,.usage_o (probebufferusage)

	,.clk_read_i (clk_i)
	// A value gets retrieved from the probe buffer whenever
	// it is not empty and if a new transmission can begin.
	,.read_i (!nibleidx)
	,.data_o (probebufferdataout)
	,.empty_o (probebufferempty)

	,.clk_write_i (clk_i)
	// Data is written in the buffer whenever doneprobing
	// is false, and there is a change on the probe.
	,.write_i (!doneprobing && (trig_r || trig_i) && (probe_i != probesampled))
	,.data_i  (probe_i)
	,.full_o (probebufferfull)
);

reg [8 -1 : 0] uartbufferdatain; // ### comb-block-reg.

wire uart_tx_full;

uart_tx #(

	 .BUFSZ                  (TXDEPTH)
	,.CLOCKCYCLESPERBITLIMIT ((CLKFREQ/TXBITRATE)+1)

) uart_tx (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_i)

	,.clockcyclesperbit_i (CLKFREQ/TXBITRATE)

	,.push_i (nibleidx && !uart_tx_full)

	,.data_i (uartbufferdatain)

	,.full_o (uart_tx_full)

	,.tx_o (tx_o)
);

wire [3:0] nible = {probebufferdataout >> ({2'b00, nibleidx_minus_one} << 2)}[3:0];

always @* begin
	// Logic converting the indexed nible from
	// a probed value to its equivalent ASCII character.
	if (nibleidx == ((((PROBEWIDTH -1) >> 2) +NLCRSZ) +1))
		uartbufferdatain = "\n";
	else if (nibleidx == ((((PROBEWIDTH -1) >> 2) +(NLCRSZ -1)) +1))
		uartbufferdatain = "\r";
	else if (nible == 4'h0)
		uartbufferdatain = "0";
	else if (nible == 4'h1)
		uartbufferdatain = "1";
	else if (nible == 4'h2)
		uartbufferdatain = "2";
	else if (nible == 4'h3)
		uartbufferdatain = "3";
	else if (nible == 4'h4)
		uartbufferdatain = "4";
	else if (nible == 4'h5)
		uartbufferdatain = "5";
	else if (nible == 4'h6)
		uartbufferdatain = "6";
	else if (nible == 4'h7)
		uartbufferdatain = "7";
	else if (nible == 4'h8)
		uartbufferdatain = "8";
	else if (nible == 4'h9)
		uartbufferdatain = "9";
	else if (nible == 4'ha)
		uartbufferdatain = "a";
	else if (nible == 4'hb)
		uartbufferdatain = "b";
	else if (nible == 4'hc)
		uartbufferdatain = "c";
	else if (nible == 4'hd)
		uartbufferdatain = "d";
	else if (nible == 4'he)
		uartbufferdatain = "e";
	else if (nible == 4'hf)
		uartbufferdatain = "f";
	else uartbufferdatain = "?";
end

always @ (posedge clk_i) begin

	if (rst_i)
		trig_r <= 1'b0;
	else if (trig_i)
		trig_r <= 1'b1;

	// Logic sequencing the transmission
	// of the nible of each probed value.
	if (rst_i)
		nibleidx <= 0;
	else if (nibleidx) begin
		// When I get here, I am transmitting
		// each nible of the probed value
		// that was retrieved from the buffer.
		// I decrement nibleidx only if the transmit buffer was
		// not full, otherwise nible to transmit will get skipped.
		if (uart_tx_notfull)
			nibleidx <= nibleidx_minus_one;
	end else if (!probebufferempty) begin
		// When I get here, I am retrieving from
		// the probe buffer, a value for which
		// each nible will be transmitted.
		// I set nibleidx to a non-null value to begin
		// transmitting each nible of the probed value.
		// The last +1 accounts for the fact that when nibleidx
		// is null, it mean that all nible of the probed value
		// have been transmitted.
		nibleidx <= ((((PROBEWIDTH -1) >> 2) +NLCRSZ) +1);
	end

	// Save the current value of "probe_i".
	// On reset, set "probesampled" to a value different from "probe_i"
	// so that after reset, the value of "probe_i" get buffered.
	if (rst_i)
		probesampled <= ~probe_i;
	else
		probesampled <= probe_i;

	// Logic that set doneprobing.
	if (rst_i)
		doneprobing <= 0;
	else if (probebufferusage == (PROBEDEPTH -1))
		doneprobing <= 1;
end

endmodule
