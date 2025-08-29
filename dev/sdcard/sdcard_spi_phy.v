// SPDX-License-Identifier: GPL-2.0-only
// 20250519 (c) William Fonkou Tambe

`ifndef SDCARD_SPI_PHY_V
`define SDCARD_SPI_PHY_V

// Module implementing an sd/mmc card controller using SPI mode.
// MMC, SDSC (8MB to 2GB), SDHC (4GB to 32GB) and SDXC (64GB to 2TB) cards are supported.
// HighSpeed mode (50MHz) is used when available,
// otherwise DefaultSpeed mode (25MHz) is used.
// CRC is turned-on.
// Read/Write is expected in a 512bytes block.

// Parameters:
//
// CLKFREQ
// 	Frequency of the clock input "clk_i" in Hz.
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_phy_i" in Hz.
// 	It must be greather than or equal to CLKFREQ.

// Ports:
//
// rst_i
// 	This input reset this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// clk_phy_i
// 	Clock input used by the phy device which transmit/receive.
// 	Its frequency determine the maximum transmission bitrate.
//
// cmd_pop_o
// cmd_data_i
// cmd_addr_i
// cmd_empty_i
// 	FWFT FIFO interface to send read/write commands.
// 	cmd_addr_i is the address within the card.
// 	cmd_data_i indicates whether read(0)/write(1).
//
// rx_push_o
// rx_data_o
// 	FWFT FIFO interface to retrieve data from read commands.
//
// tx_pop_o
// tx_data_i
// 	FWFT FIFO interface to buffer data for write commands.
//
// sclk_o
// di_o
// do_i
// cs_o
// 	SPI interface to the card.
//
// blkcnt_o
// 	This signal get set to the total number of blocks available
// 	in the card after it has been initialized.
//
// bsy_o
// 	This signal is high when the card is busy.
//
// err_o
// 	This signal is high when an error occured; a reset is needed to clear the error.

// There is no reporting of timeout, as it is best implemented
// in software by timing how long the card has been busy.

`include "lib/spi/spi_master.v"

module sdcard_spi_phy (

	 rst_i

	,clk_i
	,clk_phy_i

	,cmd_pop_o
	,cmd_data_i
	,cmd_addr_i
	,cmd_empty_i

	,rx_push_o
	,rx_data_o

	,tx_pop_o
	,tx_data_i

	,sclk_o
	,di_o
	,do_i
	,cs_o

	,blkcnt_o

	,bsy_o
	,err_o
);

`include "lib/clog2.v"

parameter CLKFREQ = 500000;

// Phy clock frequency in Hz.
// It should be at least 2 * 250KHz needed to drive the card's input "sclk_o".
parameter PHYCLKFREQ = 500000;

localparam CLOG2CLKFREQ = clog2(CLKFREQ);
localparam CLOG2PHYCLKFREQ = clog2(PHYCLKFREQ);

localparam SCLKDIVLIMIT = ((PHYCLKFREQ <= 250000) ? 2 : ((PHYCLKFREQ/250000)+|(PHYCLKFREQ%250000)));
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);
// ### Use `<` instead of `<=` if spi.sclkdiv_i can be null.
localparam SCLKDIV10LIMIT = (
	(PHYCLKFREQ <= 10000000) ? SCLKDIVLIMIT : ((PHYCLKFREQ/10000000)+|(PHYCLKFREQ%10000000)));
localparam SCLKDIV20LIMIT = (
	(PHYCLKFREQ <= 20000000) ? SCLKDIV10LIMIT : ((PHYCLKFREQ/20000000)+|(PHYCLKFREQ%20000000)));
localparam SCLKDIV25LIMIT = (
	(PHYCLKFREQ <= 25000000) ? SCLKDIV20LIMIT : ((PHYCLKFREQ/25000000)+|(PHYCLKFREQ%25000000)));
localparam SCLKDIV50LIMIT = (
	(PHYCLKFREQ <= 50000000) ? SCLKDIV25LIMIT : ((PHYCLKFREQ/50000000)+|(PHYCLKFREQ%50000000)));

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

localparam CMDADDRBITSZ = 32; // Per the spec, read/write address is 32bits.

output wire                       cmd_pop_o;
input  wire                       cmd_data_i;
input  wire [CMDADDRBITSZ -1 : 0] cmd_addr_i;
input  wire                       cmd_empty_i;

output wire            rx_push_o;
output wire [8 -1 : 0] rx_data_o;

output wire            tx_pop_o;
input  wire [8 -1 : 0] tx_data_i;

output wire sclk_o;
output wire di_o;
input wire  do_i;
output wire cs_o;

output reg [CMDADDRBITSZ -1 : 0] blkcnt_o = 0;

output wire bsy_o;
output wire err_o;

// After poweron or reset, the spec demands to allow at least 250ms
// for the card to reach a stable powered state; and then to issue
// at least 74 cycles on the card's input "sclk_o", with the input "cs_o"
// held high during the 74 "sclk_o" cycles.
// The frequency of the card's input "sclk_o" should be between 100 KHz and 400 KHz.
// The card is ready to receive a command when 0xff keeps being received from it;
// similarly, when waiting or reading responses from the card, 0xff must keep
// being transmitted to it.
// The input "cs_o" of the card must be driven high to low prior to sending a command,
// and held low during the transaction (command, response and data transfer if any).
//
// The card must be initialized before data transfer can occur.
//
// Initialization or reset of the card is done as follow:
// - Send CMD0; software reset.
// 	Expect response R1 with idle state bit set to 1.
// - Send CMD59; turn-on CRC.
// 	Expect response R1.
// - Send CMD8.
// 	Expect response R7.
// 	If illigal command returned, the card is either SDv1 or MMC,
// 	otherwise the card is SDv2.
// - If card is SDv2, send ACMD41 with the HCS bit of the command set to 1.
// 	Expect response R1.
// 	If idle state bit set to 1, repeat this step until idle state bit gets set to 0.
// - If card is not SDv2, send ACMD41 with the HCS bit of the command set to 0.
// 	Expect response R1.
// 	If illigal command returned, the card is MMC; else if idle state bit set to 1,
// 	repeat this step until idle state bit gets set to 0.
// - If card is MMC, send CMD1.
// 	Expect reponse R1.
// 	If idle state bit set to 1, repeat this step until idle state bit gets set to 0.
// - If idle state bit set to 0, send CMD6 to enable high speed mode if available.
// 	Expect response R1.
// 	If no error reported, expect data packet.
// - Send CMD9 to read the card's CSD register from which the max "sclk_o" frequency
// 	and capacity will be computed.
// 	Expect response R1.
// 	If no error reported, expect data packet.
// - Send CMD58 to determine
// 	whether the card is block or byte aligned.
// 	Expect response R3.
// 	If bit30 of OCR is 0, the card is byte aligned, otherwise the card is block aligned.
// - Send CMD16 to set block size to 512Bytes.
// 	Expect response R1.
//
// Reading data from the card is done as follow:
// - Send CMD17; read a 512bytes block of data.
// 	Expect response R1.
// 	If no error reported, expect data packet.
//
// Writing data to the card
// is done as follow:
// - Send CMD24; write a 512bytes block of data.
// 	Expect response R1.
// 	If no error reported, send data packet, and expect data response byte.

// Register used to implement timeout.
// The largest value that it will be set to, is > than the clock cycle count equivalent of 250ms.
// Since 250ms is 4 Hz, the number of clock cycles using a clock frequency of CLKFREQ
// would be CLKFREQ/4; the result of that value would largely be greater than
// ((spi_master.DATABITSIZE + 1) * (1 << spi_master.SCLKDIVLIMIT))
// which is the minimum number of clock cycles needed to reset spimaster;
// in fact CLKFREQ must be at least 250 KHz.
reg [CLOG2CLKFREQ -1 : 0] timeout = 0;

// Constants used with the register state.

// When in this state, the controller is resseting by waiting 250ms,
// before driving the card spi interface, and then issuing at least 74
// "sclk_o" cycles with the card input "cs_o" high.
localparam RESETTING = 0;
// When in this state, the controller is not busy.
localparam READY     = 1;
// States that send a command.
localparam SENDCMD0  = 2;
localparam SENDCMD59 = 3;
localparam SENDCMD8  = 4;
localparam SENDINIT  = 5;
localparam SENDCMD41 = 6;
localparam SENDCMD6  = 7;
localparam SENDCMD9  = 8;
localparam SENDCMD58 = 9;
localparam SENDCMD16 = 10;
localparam SENDCMD17 = 11;
localparam SENDCMD24 = 12;
// States that wait for a command's response.
localparam CMD0RESP  = 13;
localparam CMD59RESP = 14;
localparam CMD8RESP  = 15;
localparam INITRESP  = 16;
localparam CMD6RESP  = 17;
localparam CMD9RESP  = 18;
localparam CMD58RESP = 19;
localparam CMD16RESP = 20;
localparam CMD17RESP = 21;
localparam CMD24RESP = 22;
// Other states.
localparam PREPNXTCMD = 23;
localparam PREPINIT   = 24;
localparam ERROR      = 25; // When in this state, an error occured, and a reset is required.

localparam STATEBITSZ = clog2(32);

// Register used to hold the state of the controller.
(* mark_debug = "true" *) reg [STATEBITSZ -1 : 0] state = ERROR;
reg [STATEBITSZ -1 : 0] nxtstate;

assign err_o = (state == ERROR);

wire cs_w;

// Register that hold the value of the input "spi.sclkdiv_i".
(* mark_debug = "true" *) reg [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_r;

// Register that hold the value of the input "spi.push_i".
reg spitxbufferwriteenable;

// Register that hold the value of the input "spi.data_i".
reg [8 -1 : 0] spitxbufferdatain;

wire spitxbufferfull;

wire spirxbufferempty_;
reg  spirxbufferempty;
always @ (posedge clk_i)
	spirxbufferempty <= spirxbufferempty_;

// Size of the spimaster buffer.
// It is minimal to keep latency at its lowest when waiting
// for the transmission to end or when waiting for the transmit
// buffer to be full.
localparam SPIBUFFERSIZE = 2;

// SPI master which will be used to communicate with the card.
spi_master #(
	 .SCLKDIVLIMIT (SCLKDIVLIMIT)
	,.DATABITSZ    (8)
	,.CPOL         (0)
	,.BUFSZ        (SPIBUFFERSIZE)
) spi (
	// The spimaster is kept in a reset state
	// for as long as the controller is resetting.
	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.sclk_o (sclk_o)
	,.mosi_o (di_o)
	,.miso_i (do_i)
	,.cs_o   (cs_w)

	,.sclkdiv_i (sclkdiv_r)

	,.push_i (spitxbufferwriteenable)
	,.data_i (spitxbufferdatain)
	,.full_o (spitxbufferfull)

	,.read_i  (1'b1)
	,.data_o  (rx_data_o)
	,.empty_o (spirxbufferempty_)

	,.misoSync_i        (1'b0)
	,.misoSkipSyncBit_i (1'b0)
);

// Register which when 1, keeps the sdcard input "cs_o" high.
reg keepsdcardcshigh = 1;

assign cs_o = (cs_w | keepsdcardcshigh);

// Register used for multiple purposes.
reg miscflag;

// Register set to 1 when the card is found to be SDv2,
// otherwise it is set to 0.
(* mark_debug = "true" *) reg issdcardver2;

// Register set to 1 when the card is found to be MMC,
// otherwise it is set to 0.
(* mark_debug = "true" *) reg issdcardmmc;


// Register set to 1 if the card addressing
// is block aligned, otherwise it is set to 0.
(* mark_debug = "true" *) reg issdcardaddrblockaligned;

// Register which will be used to store the value of the card CSD register.
reg [128 -1 : 0] sdcardcsd;

always @ (posedge clk_i) begin
	// Logic which set blkcnt_o to the block count
	// of the card, computed from its CSD register.
	if (sdcardcsd[126+:2] == 2'd0 || issdcardmmc) begin
		// I get here if the card CSD format is 1.0.
		blkcnt_o <= (((
			sdcardcsd[62/*C_SIZE*/+:12] + 32'd1) << (
				sdcardcsd[47/*C_SIZE_MULT*/+:3] + 2 +
					sdcardcsd[80/*READ_BL_LEN*/+:4])) >> 9);
	end else if (sdcardcsd[126+:2] == 2'd1) begin
		// I get here if the card CSD format is 2.0.
		blkcnt_o <= ((sdcardcsd[48/*C_SIZE*/+:22] + 32'd1) << 10);
	end else begin
		// I get here if the card CSD format is unsupported.
		// I set the block count to 1, since the card
		// should surely have at least a single block.
		blkcnt_o <= 1;
	end
end

// Signal which gets set to the value to set on "spi.sclkdiv_i"
// in order to attain the maximum transmission frequency safe to use.
// It is computed from the card CSD register field TRAN_SPEED.
// The minimum transmission frequency is used for unsupported values.
reg [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_w = 0; // ### comb-always-block-reg.
always @* begin
	if      (sdcardcsd[96+:8] == 8'h5a) sclkdiv_w = (SCLKDIV50LIMIT-1);  // 50 Mbps.
	else if (sdcardcsd[96+:8] == 8'h32) sclkdiv_w = (SCLKDIV25LIMIT-1);  // 25 Mbps.
	else if (sdcardcsd[96+:8] == 8'h2a) sclkdiv_w = (SCLKDIV20LIMIT-1);  // 20 Mbps.
	else                                sclkdiv_w = (SCLKDIV10LIMIT-1);  // 10 Mbps.
end

(* mark_debug = "true" *) wire [2 -1 : 0] CSD_format = sdcardcsd[126+:2];
(* mark_debug = "true" *) wire [8 -1 : 0] CSD_speed = sdcardcsd[96+:8];

// Register used as the controller counter.
// The largest value that it will be set to, is greater
// than the clock cycle count equivalent of 250ms.
// Since 250ms is 4 Hz, the number of clock cycles using
// a clock frequency of CLKFREQ would be CLKFREQ/4.
// In fact CLKFREQ must be at least 250 KHz.
reg [CLOG2CLKFREQ -1 : 0] cntr;

assign tx_pop_o  = ((state == CMD24RESP) && !spitxbufferfull  && cntr && cntr <= 512);
assign rx_push_o = ((state == CMD17RESP) && !spirxbufferempty && cntr && cntr <= 512);

localparam cmd0 = 40'h4000000000;
localparam cmd8 = 40'h48000001aa;
localparam cmd1 = 40'h4100000000;
localparam cmd55 = 40'h7700000000;
localparam cmd41 = 40'h6900000000;
localparam cmd41hcs = 40'h6940000000;
localparam cmd58 = 40'h7a00000000;
localparam cmd16 = 40'h5000000200;
localparam cmd9 = 40'h4900000000;
reg  [CMDADDRBITSZ -1 : 0] cmdaddr = 0;
wire [CMDADDRBITSZ -1 : 0] cmdaddrshiftedleft = {cmdaddr[(CMDADDRBITSZ-9)-1:0], 9'd0};
wire [40 -1 : 0] cmd17 = {8'h51, issdcardaddrblockaligned ? cmdaddr : cmdaddrshiftedleft};
wire [40 -1 : 0] cmd24 = {8'h58, issdcardaddrblockaligned ? cmdaddr : cmdaddrshiftedleft};
localparam cmd6 = 40'h4680fffff1;
localparam cmd59 = 40'h7b00000001;

reg [40 -1 : 0] cmdX;
reg [8 -1 : 0] cmdXcntr; // ### comb-always-block-reg.
always @* begin
	if      (cntr[2:0] == 2) cmdXcntr = cmdX[7:0];
	else if (cntr[2:0] == 3) cmdXcntr = cmdX[15:8];
	else if (cntr[2:0] == 4) cmdXcntr = cmdX[23:16];
	else if (cntr[2:0] == 5) cmdXcntr = cmdX[31:24];
	else if (cntr[2:0] == 6) cmdXcntr = cmdX[39:32];
	else                     cmdXcntr = 8'hff;
end

// CRC7 value.
reg [7 -1 : 0] crc7 = 0;

// CRC16 value.
reg [16 -1 : 0] crc16 = 0;

// Byte value to accumulate in the CRC computation.
reg [8 -1 : 0] crcarg = 0;
reg [8 -1 : 0] _crcarg = 0;

// Net set to the bit that will stream through the register crc7.
wire crc7in = (_crcarg[7] ^ crc7[6]);

// Net set to the bit that will stream through the register crc16.
wire crc16in = (_crcarg[7] ^ crc16[15]);

localparam CRCCOUNTERBITSZ = clog2(8+1);

// Register used to keep track of the number of clock cycles left in the CRC computation.
// It is set to 8 for each byte to accumulate in the CRC computation.
reg [CRCCOUNTERBITSZ -1 : 0] crccounter = 0;
reg [CRCCOUNTERBITSZ -1 : 0] _crccounter = 0;

assign cmd_pop_o = (state == READY);

assign bsy_o = (!cmd_empty_i || !cmd_pop_o);

// Logic computing the CRC7 or CRC16 per the card spec.
// To insure that the CRC computation has enough clock cycles to complete, there must be
// at least 8 clock cycles between the transmission of each byte used in the CRC computation.
always @ (posedge clk_phy_i) begin

	if (_crccounter) begin

		crc7[6] <= crc7[5];
		crc7[5] <= crc7[4];
		crc7[4] <= crc7[3];
		crc7[3] <= crc7[2] ^ crc7in;
		crc7[2] <= crc7[1];
		crc7[1] <= crc7[0];
		crc7[0] <= crc7in;

		crc16[15] <= crc16[14];
		crc16[14] <= crc16[13];
		crc16[13] <= crc16[12];
		crc16[12] <= crc16[11] ^ crc16in;
		crc16[11] <= crc16[10];
		crc16[10] <= crc16[9];
		crc16[9]  <= crc16[8];
		crc16[8]  <= crc16[7];
		crc16[7]  <= crc16[6];
		crc16[6]  <= crc16[5];
		crc16[5]  <= crc16[4] ^ crc16in;
		crc16[4]  <= crc16[3];
		crc16[3]  <= crc16[2];
		crc16[2]  <= crc16[1];
		crc16[1]  <= crc16[0];
		crc16[0]  <= crc16in;

		// Get the next msb to accumulate in the CRC computation.
		_crcarg <= _crcarg << 1'b1;

		_crccounter <= _crccounter - 1'b1;

	end else if (!cntr) begin
		// Note that the register cntr is never
		// null when the CRC computation is needed,
		// hence it is used to reset null the registers
		// that will contain the result of the CRC computation.
		crc7 <= 0;
		crc16 <= 0;

	end else if (crccounter) begin
		_crcarg <= crcarg;
		_crccounter <= crccounter;
	end
end

always @ (posedge clk_i) begin

	if (_crccounter)
		crccounter <= 0;

	if (rst_i) begin
		// Reset logic.

		miscflag <= 0;

		issdcardver2 <= 0;

		issdcardmmc <= 0;

		// I move onto the state which will wait 250ms,
		// as required by the card spec after poweron.
		state <= RESETTING;

		// I set cntr to a clock cycle count which yield at least 250ms.
		cntr <= (CLKFREQ/4);

		// I set the spi clock to a frequency between 100 KHz
		// and 400 KHz, as required by the card spec after poweron.
		sclkdiv_r <= (SCLKDIVLIMIT-1); // 250 Kbps.

		// I set keepsdcardcshigh to 1 so that the card input cs_o be kept high.
		keepsdcardcshigh <= 1;

		// I set spi.push_i to 0 to stop the spi clock.
		spitxbufferwriteenable <= 0;

	end else if (state == RESETTING) begin
		// I come to this state after a falling edge of the
		// input "rst_i"; I wait 250ms and then issue at least 74
		// "sclk_o" cycles with the card input "cs_o" high, as required
		// by the card spec after poweron.

		if (miscflag) begin

			if (cntr) begin
				// I decrement cntr only if the transmit buffer is
				// not full, otherwise bytes to send will get skipped.
				if (!spitxbufferfull)
					cntr <= cntr - 1'b1;

			end else begin
				// I wait that the spimaster transmit all buffered data.
				if (cs_w) begin
					// When I get here, the card should be in idle sate.

					// I set keepsdcardcshigh to 0 so that the card
					// input "cs_o" be controllable by spimaster.
					keepsdcardcshigh <= 0;

					// I move onto the state which will send CMD0 to the card.
					state <= SENDCMD0;
					// The register cntr is set in such a way that
					// the transmit buffer be full with 0xff bytes before sending
					// each byte of the command; in fact keeping the buffer
					// full while sending each byte of the command is used
					// in order to have enough clock cycles to compute the CRC
					// for each byte transmitted.
					cntr <= (6 + SPIBUFFERSIZE + 1);
				end

				// I stop writting in the transmit buffer since
				// I wish to wait that spi.cs_o becomes high.
				spitxbufferwriteenable <= 0;
			end

		end else begin

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// When I get here, 250ms has passed
				// since the input "rst_i" was de-asserted.

				// I set cntr to 10 in order to write ten 0xff bytes
				// in the transmit buffer which will issue 80 "sclk_o" cycles,
				// well above 74 "sclk_o" cycles.
				cntr <= 10;

				// Byte value to write in the transmit buffer 10 times.
				spitxbufferdatain <= 'hff;

				spitxbufferwriteenable <= 1;

				miscflag <= 1;
			end
		end

	end else if (state == READY) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// Until there is something to do,
		// spitxbufferwriteenable == 0,
		// which is power efficient because
		// the spi clock will remain stopped.

		if (!cmd_empty_i) begin
			cmdaddr <= cmd_addr_i;
			if (cmd_data_i) begin
				// I move onto the state which will send CMD24 to the card.
				state <= SENDCMD24;
			end else begin
				// I move onto the state which will send CMD17 to the card.
				state <= SENDCMD17;
			end
		end

		miscflag <= 0; // Expected by states CMD24RESP and CMD17RESP.

	end else if (state == SENDCMD0) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd0;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD0RESP;
			end
		end

	end else if (state == SENDCMD59) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd59;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD59RESP;
			end
		end

	end else if (state == SENDCMD8) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd8;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD8RESP;
			end
		end

	end else if (state == SENDINIT) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		if (!miscflag) begin
			// If I get here, the card is done initializing.

			// I get here from PREPINIT which does what PREPNXTCMD do;
			// hence there is no need to go through PREPNXTCMD.
			state <= (issdcardmmc ? SENDCMD9 : SENDCMD6);

		end else begin
			// I write the command in the transmit buffer.
			spitxbufferwriteenable <= 1;

			// I wait that the transmit buffer
			// is not full, before doing anything,
			// otherwise bytes will get lost.
			if (!spitxbufferfull) begin

				if (cntr <= 6) begin
					// Transmit the byte containing the CRC7 when
					// cntr == 1, otherwise transmit the command bytes.
					if (cntr == 1)
						spitxbufferdatain <= {crc7, 1'b1};
					else
						spitxbufferdatain <= cmdXcntr;

					// Note that when I get here, crccounter == 0.

					if (cntr > 1) begin
						crcarg <= cmdXcntr;
						crccounter <= 8;
					end

				end else begin
					// If the card is MMC, use CMD1
					// to initialize it, otherwise use
					// ACMD41 which start with CMD55.
					cmdX <= (issdcardmmc ? cmd1 : cmd55);
				end

				if (cntr)
					cntr <= cntr - 1'b1;
				else begin
					// I move onto the state which will wait for the response.
					state <= INITRESP;

					// If ACMD41 need to be sent to the card,
					// set cntr[0] to 1 to signal it to the state INITRESP.
					if (!issdcardmmc)
						cntr[0] <= 1;
				end
			end
		end

	end else if (state == SENDCMD41) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else begin
				// If the card is SDv2, I use ACMD41 with its bit HCS == 1.
				cmdX <= (issdcardver2 ? cmd41hcs : cmd41);
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= INITRESP;
			end
		end

	end else if (state == SENDCMD6) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd6;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD6RESP;
			end
		end

	end else if (state == SENDCMD9) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd9;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD9RESP;
			end
		end

	end else if (state == SENDCMD58) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd58;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD58RESP;
			end
		end

	end else if (state == SENDCMD16) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd16;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD16RESP;
			end
		end

	end else if (state == SENDCMD17) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd17;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD17RESP;
			end
		end

	end else if (state == SENDCMD24) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 1);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd24;

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD24RESP;
			end
		end

	end else if (state == CMD0RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card
			// and it must be [0[5:0], x], otherwise throw an error.
			// Following the reception of a valid reponse R1, I move
			// onto the state which will send CMD59.
			if (rx_data_o[6:1])
				state <= ERROR;
			else begin
				state <= PREPNXTCMD;
				nxtstate <= SENDCMD59;
			end
		end

	end else if (state == CMD59RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card
			// and it must be 7'b0000x0x, otherwise throw an error.
			// Following the reception of a valid reponse R1, I move
			// onto the state which will send CMD8.
			if ({rx_data_o[6:3], rx_data_o[1]})
				state <= ERROR;
			else begin
				state <= PREPNXTCMD;
				nxtstate <= SENDCMD8;
			end
		end

	end else if (state == CMD8RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;

		if (issdcardver2) begin
			// If I get here, the card must be SDv2; I evaluate
			// the 4 bytes that follow the first byte of
			// response R7; the 12 bits in the least significant
			// bytes should be 0x1aa, otherwise throw an error.
			if (!spirxbufferempty) begin
				// I get here for each byte received.

				if (cntr == 2) begin
					if (rx_data_o[0] != 1)
						state <= ERROR;
				end else if (cntr == 3) begin
					if (rx_data_o != 'haa)
						state <= ERROR;
					else
						state <= PREPINIT;
				end

				cntr <= cntr + 1'b1;
			end

		end else if (rx_data_o != 'hff) begin
			// If I get here, I received the first byte of response R7
			// from the card; if bit2 is 1, the card is either SDv1 or MMC
			// and I should move onto the state which will prep for SENDINIT;
			// otherwise issdcardver2 get set, and checks on whether
			// the card is a valid SDv2 follow.
			if (rx_data_o[2])
				state <= PREPINIT;
			else
				issdcardver2 <= 1'b1;
		end

	end else if (state == INITRESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// and if ACMD41 needs to be sent,
		// cntr[0] == 1, otherwise cntr[0] == 0;

		if (rx_data_o != 'hff) begin
			// If I get here, I received the initialization response.

			if (cntr[0]) begin
				// If no error is found, I move onto the state which will
				// prepare the second portion of ACMD41 to send to the card.
				if ({rx_data_o[6:3], rx_data_o[1]}) begin
					state <= ERROR;
				end else if (rx_data_o[2]) begin
					issdcardmmc <= 1'b1;
					state <= PREPINIT;
				end else begin
					state <= PREPNXTCMD;
					nxtstate <= SENDCMD41;
				end

			end else begin
				// I update miscflag with the card idle state.
				miscflag <= rx_data_o[0];

				if (rx_data_o[6:1])
					state <= ERROR;
				else
					state <= PREPINIT;
			end
		end

	end else if (state == CMD6RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 0;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// looking at the data packet which follow response R1,
		// and which contain the SD status.
		if (miscflag) begin
			// If I get here, I expect the data packet that follow response R1.

			if (!cntr) begin

				if (rx_data_o == 'hfe) begin
					// If I get here, I received the byte which start a data packet.
					cntr <= cntr + 1'b1;
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else
					state <= ERROR;

			end else begin
				// If I get here, I receive and ignore the data packet
				// which contain the 64 bytes SD status.

				if (!spirxbufferempty) begin
					// I get here for each byte received.

					if (cntr == 66) begin
						// If I get here, I am done reading the 64 bytes SD status.
						// I ignore the 2 CRC bytes that terminate the response.
						state <= PREPNXTCMD;
						nxtstate <= SENDCMD9;
						miscflag <= 0;
					end

					cntr <= cntr + 1'b1;
				end
			end

		end else if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card;
			// move onto the state which will send CMD9 if it is not
			// [0[5:0], x], otherwise look at the data packet that follow.
			if (rx_data_o[6:1]) begin
				state <= PREPNXTCMD;
				nxtstate <= SENDCMD9;
			end else begin
				miscflag <= 1;
				timeout <= -1;
			end
		end

	end else if (state == CMD9RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 0;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// looking at the data packet which follow response R1,
		// and which contain the bytes from the card CSD register.
		if (miscflag) begin
			// If I get here, I expect the data packet that follow response R1.

			if (!cntr) begin

				if (rx_data_o == 'hfe) begin
					// If I get here, I received the byte which start a data packet.
					cntr <= cntr + 1'b1;
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else
					state <= ERROR;

			end else begin
				// If I get here, I receive the data packet which
				// contain the 16 bytes from the card CSD register.

				if (!spirxbufferempty) begin
					// I get here for each byte received.

					if (cntr == 18) begin
						// I check the second CRC16 byte.
						if (rx_data_o != crc16[7:0])
							state <= ERROR;
						else begin
							// Set the maximum spi clock frequency safe to use.
							sclkdiv_r <= sclkdiv_w;
							// Note that I send CMD58 for all type of cards;
							// but OCR[30] in the response R3 exist only for SDv2 cards,
							// but should correctly be 0 for SDv1 and MMC cards as for those
							// two types of card it is a reserved bit.
							state <= PREPNXTCMD;
							nxtstate <= SENDCMD58;
							miscflag <= 0;
						end

					end else if (cntr == 17) begin
						// If I get here, I am done reading the 16 bytes from the card CSD register.

						// I check the first CRC16 byte.
						if (rx_data_o != crc16[15:8])
							state <= ERROR;

					end else if (cntr >= 1) begin

						sdcardcsd <= {sdcardcsd[(128-8)-1:0], rx_data_o};

						// Note that when I get here, crccounter == 0.

						crcarg <= rx_data_o;
						crccounter <= 8;

					end

					if (cntr != 18)
						cntr <= cntr + 1'b1;
					else begin
						// Setting the register cntr to null so that
						// the logic computing the CRC reset itself null.
						cntr <= 0;
					end
				end
			end

		end else if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card;
			// throw an error if it is not [0[5:0], x], otherwise look
			// at the data packet that follow.
			if (rx_data_o[6:1])
				state <= ERROR;
			else begin
				miscflag <= 1;
				timeout <= -1;
			end
		end

	end else if (state == CMD58RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 0;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// looking at the 4 bytes that follow the first byte of response R3.
		if (miscflag) begin
			// I evaluate the 4 bytes that follow the first byte of response R3.
			if (!spirxbufferempty) begin
				// I get here for each byte received.

				if (cntr == 0) begin
					// I set issdcardaddrblockaligned using bit30
					// of the OCR register from the response R3.
					issdcardaddrblockaligned <= rx_data_o[6]; /* same as |(rx_data_o & 'h40) */

				end else if (cntr == 3) begin
					// I get here when I have received the 4 bytes
					// that follow the first byte of response R3.
					state <= PREPNXTCMD;
					nxtstate <= SENDCMD16;
				end

				cntr <= cntr + 1'b1;
			end

		end else if (rx_data_o != 'hff) begin
			// If I get here, I received the first byte of response R3
			// from the card; throw an error if it is not [0[5:0], x],
			// otherwise look at the following 4bytes.
			if (rx_data_o[6:1])
				state <= ERROR;
			else
				miscflag <= 1;
		end

	end else if (state == CMD16RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card
			// and it must be [0[5:0], x], otherwise throw an error.
			// Following the reception of a valid reponse R1, I move
			// onto the state which will set READY.
			if (rx_data_o[6:1])
				state <= ERROR;
			else begin
				state <= PREPNXTCMD;
				nxtstate <= READY;
			end
		end

	end else if (state == CMD17RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 0;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// looking at the data packet which follow response R1.
		if (miscflag) begin
			// If I get here, I expect the data packet that follow response R1.

			if (!cntr) begin

				if (rx_data_o == 'hfe) begin
					// If I get here, I received the byte which start a data packet.
					cntr <= cntr + 1'b1;
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else
					state <= ERROR;

			end else begin
				// If I get here, I receive the 512 bytes data packet.

				if (!spirxbufferempty) begin
					// I get here for each byte received.

					if (cntr == 514) begin
						// I check the second CRC16 byte.
						if (rx_data_o != crc16[7:0])
							state <= ERROR;
						else begin
							state <= PREPNXTCMD;
							nxtstate <= READY;
						end

					end else if (cntr == 513) begin
						// If I get here, I am done receiving the 512 bytes data packet.

						// I check the first CRC16 byte.
						if (rx_data_o != crc16[15:8])
							state <= ERROR;

					end else if (cntr >= 1) begin
						// Note that when I get here, crccounter == 0.

						crcarg <= rx_data_o;
						crccounter <= 8;
					end

					if (cntr != 514)
						cntr <= cntr + 1'b1;
					else begin
						// Setting the register cntr to null so that
						// the logic computing the CRC reset itself null.
						cntr <= 0;
					end
				end
			end

		end else if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card;
			// throw an error if it is not [0[5:0], x], otherwise look
			// at the data packet that follow.
			if (rx_data_o[6:1])
				state <= ERROR;
			else begin
				miscflag <= 1;
				timeout <= -1;
			end
		end

	end else if (state == CMD24RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 0;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// sending the data packet.
		if (miscflag) begin

			if (cntr == 516) begin
				// If I get here, I wait for the data response byte.

				if (rx_data_o != 'hff) begin
					// If I get here, I received the data response byte.
					// The only bits of interest in the data response
					// are bit3 thru bit1.
					if ((rx_data_o[3:1]) == 'b010) begin
						state <= PREPNXTCMD;
						nxtstate <= READY;
						miscflag <= 0;
					end else
						state <= ERROR;

					// Setting the register cntr to null so that
					// the logic computing the CRC reset itself null.
					cntr <= 0;
				end

			end else begin
				// If I get here, I send the data packet.

				if (!spitxbufferfull) begin

					if (cntr) begin
						// When cntr == 513, the last byte of the 512
						// bytes data packet has been buffered for transmission;
						// I buffer the CRC16 value followed by 0xff to keep
						// transmitting 0xff until a data response is received.
						if (cntr == 515)
							spitxbufferdatain <= 'hff;
						else if (cntr == 514)
							spitxbufferdatain <= crc16[7:0];
						else if (cntr == 513)
							spitxbufferdatain <= crc16[15:8];
						else begin
							spitxbufferdatain <= tx_data_i;
							// Note that when I get here, crccounter == 0.
							crcarg <= tx_data_i;
							crccounter <= 8;
						end

					end else begin
						// The first byte to transmit must be 0xfe;
						// it must be preceded by at least a single 0xff byte
						// which is guaranteed to have been buffered for transmission
						// since spitxbufferwriteenable was being held high
						// with spitxbufferdatain set to 0xff.
						spitxbufferdatain <= 'hfe;
					end

					cntr <= cntr + 1'b1;
				end
			end

		end else if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card;
			// throw an error if it is not [0[5:0], x], otherwise start
			// sending the data packet.
			if (rx_data_o[6:1])
				state <= ERROR;
			else
				miscflag <= 1;
		end

	end else if (state == PREPNXTCMD) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state which will send the next command to the card.
			state <= nxtstate;
			// The register cntr is set in such a way that
			// the transmit buffer be full with 0xff bytes before sending
			// each byte of the command; in fact keeping the buffer
			// full while sending each byte of the command is used
			// in order to have enough clock cycles to compute the CRC
			// for each byte transmitted.
			cntr <= (6 + SPIBUFFERSIZE + 1);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.cs_o becomes high.
		// I do so only after skipping all busy bytes.
		if (rx_data_o == 'hff)
			spitxbufferwriteenable <= 0;

	end else if (state == PREPINIT) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// When coming to this state, "spi.cs_o" is certainly low,
		// since spitxbufferwriteenable == 1 and data is being
		// written in the transmit buffer; I take advantage of that
		// to set "cntr" to the equivalent clock cycle count for 50ms
		// in order to wait for that long between checks of the card
		// idle state, and prevent too many unnecessary checks;
		// per the card spec, the card idle state should be polled
		// at less than 50ms intervals.
		if (cs_w) begin
			// After 50ms has elapsed, I move onto the state
			// which will send the init command to the card.
			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= SENDINIT;
				cntr <= (6 + SPIBUFFERSIZE + 1);
			end
		end else
			cntr <= ((CLKFREQ/20)-1); // 50ms is 20Hz.

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.cs_o becomes high.
		// I do so only after skipping all busy bytes.
		if (rx_data_o == 'hff)
			spitxbufferwriteenable <= 0;

	end else if (state == ERROR) begin
		// I get here, if an error occured.
		// Nothing gets done until reset.

		// I stop writing in the transmit buffer in order
		// to stop the spi clock, which is power efficient.
		spitxbufferwriteenable <= 0;

	end else
		state <= ERROR;
end

endmodule

`endif /* SDCARD_SPI_PHY_V */
