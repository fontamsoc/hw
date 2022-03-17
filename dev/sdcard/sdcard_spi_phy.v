// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef SDCARD_SPI_PHY_V
`define SDCARD_SPI_PHY_V

// Module implementing an sd/mmc card controller using SPI mode.
// MMC, SDSC, SDHC and SDXC cards are supported.
// HighSpeed mode (50MHz) is used when available,
// otherwise DefaultSpeed mode (25MHz) is used.
// CRC is turned-on.
// Read/Write is expected in a 512bytes block.

// Parameters:
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_phy_i" in Hz.
// 	It should be at least 250KHz needed to drive the card's input "sclk_o".

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
// 	Clock input used by the physical device which transmit/receive.
// 	Its frequency determine the maximum transmission bitrate.
// 	For a PHYPHYCLKFREQ of 100 Mhz, it results in a maximum bitrate of 100 Mbps.
// 	It cannot be 8 times faster than the clock input "clk_i".
//
// cmd_pop_o
// cmd_data_i
// cmd_addr_i
// cmd_empty_i
// 	FIFO interface to send read/write commands.
// 	cmd_addr_i is the address within the card.
// 	cmd_data_i indicates whether read(0)/write(1).
//
// rx_push_o
// rx_data_o
// rx_full_i
// 	FIFO interface to retrieve data from read commands.
//
// tx_pop_o
// tx_data_i
// tx_empty_i
// 	FIFO interface to buffer data for write commands.
//
// sclk_o
// di_o
// do_i
// cs_o
// 	SPI interface to the card.
//
// blkcnt_o
// 	This signal is set to the total number of blocks available
// 	in the card after it has been initialized.
//
// err_o
// 	This signal is high when an error occured; a reset is needed to clear the error.

// Note that there is no reporting of timeout, as it is best
// implemented in software by timing how long the card has been busy.

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
	,rx_full_i

	,tx_pop_o
	,tx_data_i
	,tx_empty_i

	,sclk_o
	,di_o
	,do_i
	,cs_o

	,blkcnt_o

	,err_o
);

`include "lib/clog2.v"

// Clock frequency in Hz.
// It should be at least 250KHz needed to drive the card's input "sclk_o".
parameter PHYCLKFREQ = 250000;

localparam CLOG2PHYCLKFREQ = clog2(PHYCLKFREQ);

localparam SCLKDIV200000000 = ((PHYCLKFREQ <= 200000000) ? 0 : clog2(PHYCLKFREQ/200000000));
localparam SCLKDIV100000000 = ((PHYCLKFREQ <= 100000000) ? 0 : clog2(PHYCLKFREQ/100000000));
localparam SCLKDIV50000000  = ((PHYCLKFREQ <= 50000000 ) ? 0 : clog2(PHYCLKFREQ/50000000));
localparam SCLKDIV25000000  = ((PHYCLKFREQ <= 25000000 ) ? 0 : clog2(PHYCLKFREQ/25000000));

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

localparam ADDRBITSZ = 32; // Per the spec, read/write address is 32bits.

output wire                    cmd_pop_o;
input  wire                    cmd_data_i;
input  wire [ADDRBITSZ -1 : 0] cmd_addr_i;
input  wire                    cmd_empty_i;

output wire            rx_push_o;
output wire [8 -1 : 0] rx_data_o;
input  wire            rx_full_i; // TODO: Implement ...

output wire            tx_pop_o;
input  wire [8 -1 : 0] tx_data_i;
input  wire            tx_empty_i; // TODO: Implement ...

output wire sclk_o;
output wire di_o;
input wire  do_i;
output wire cs_o;

output reg [ADDRBITSZ -1 : 0] blkcnt_o = 0;

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
// 	If no error reported, send CMD13 to check whether the write was successful.
// 	Expect response R2.

// Register used to implement timeout.
// The largest value that it will be set to, is > than the clock cycle count equivalent of 250ms.
// Since 250ms is 4 Hz, the number of clock cycles using a clock frequency of PHYCLKFREQ
// would be PHYCLKFREQ/4; the result of that value would largely be greater than
// ((spi_master.DATABITSIZE + 1) * (1 << spi_master.SCLKDIVLIMIT))
// which is the minimum number of clock cycles needed to reset spimaster;
// in fact PHYCLKFREQ must be at least 250 KHz.
reg [CLOG2PHYCLKFREQ -1 : 0] timeout = 0;

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
localparam SENDCMD13 = 13;
// States that wait for a command's response.
localparam CMD0RESP  = 14;
localparam CMD59RESP = 15;
localparam CMD8RESP  = 16;
localparam INITRESP  = 17;
localparam CMD6RESP  = 18;
localparam CMD9RESP  = 19;
localparam CMD58RESP = 20;
localparam CMD16RESP = 21;
localparam CMD17RESP = 22;
localparam CMD24RESP = 23;
localparam CMD13RESP = 24;
// States that prepare the card for the next command to send.
localparam PREPCMD59 = 25;
localparam PREPCMD8  = 26;
localparam PREPINIT  = 27;
localparam PREPCMD41 = 28;
localparam PREPCMD9  = 29;
localparam PREPCMD58 = 30;
localparam PREPCMD16 = 31;
localparam PREPCMD13 = 32;
localparam PREPREADY = 33;
localparam ERROR     = 34; // When in this state, an error occured, and a reset is required.
localparam RESET     = 35;

localparam STATEBITSZ = clog2(64);

// Register used to hold the state of the controller.
// There are less than 64 different values that can
// be set in this register.
reg [STATEBITSZ -1 : 0] state = RESET;

assign err_o = (state == ERROR);

wire cs_w;

// Number of division by 2 needed to go from PHYCLKFREQ to 250 KHz.
localparam SCLKDIVLIMIT = (((PHYCLKFREQ == 250000) ? 0 : clog2(PHYCLKFREQ/250000))+1);
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);

// Register that hold the value of the input "spi.sclkdiv_i".
reg [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_r = 0;

// Register that hold the value of the input "spi.txbufferwriteenable".
reg spitxbufferwriteenable = 0;

// Register that hold the value of the input "spi.txbufferdatain".
reg [8 -1 : 0] spitxbufferdatain = 0;

// Size of the spimaster buffer.
// It is minimal to keep latency at its lowest when waiting
// for the transmission to end or when waiting for the transmit
// buffer to be full.
localparam SPIBUFFERSIZE = 2;
localparam CLOG2SPIBUFFERSIZE = clog2(SPIBUFFERSIZE);

wire spitxbufferfull;

wire spirxbufferempty;

// SPI master which will be used to communicate with the card.
spi_master #(

	 .SCLKDIVLIMIT (SCLKDIVLIMIT)
	,.DATABITSZ    (8)
	,.BUFSZ        (SPIBUFFERSIZE)

) spi (
	// The spimaster is kept in a reset state
	// for as long as the controller is resetting.
	 .rst_i (state == RESET || state == RESETTING)

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
	,.empty_o (spirxbufferempty)
);

// Register which when 1, keeps the sdcard input "cs_o" high.
reg keepsdcardcshigh = 0;

assign cs_o = (/*cs_w |*/ keepsdcardcshigh);

// Register used for multiple purposes.
reg miscflag = 0;

// Register set to 1 when the card is found to be SDv2,
// otherwise it is set to 0.
reg issdcardver2 = 0;

// Register set to 1 when the card is found to be MMC,
// otherwise it is set to 0.
reg issdcardmmc = 0;

// Register set to 1 if the card addressing
// is block aligned, otherwise it is set to 0.
reg issdcardaddrblockaligned = 0;

// Register which will be used to store the value of the card CSD register.
reg [8 -1 : 0] sdcardcsd [16 -1 : 0];
integer init_sdcardcsd_idx;
initial begin
	for (init_sdcardcsd_idx = 0; init_sdcardcsd_idx < 16; init_sdcardcsd_idx = init_sdcardcsd_idx + 1)
		sdcardcsd[init_sdcardcsd_idx] = 0;
end

always @ (posedge clk_i) begin
	// Logic which set blkcnt_o to the block count
	// of the card, computed from its CSD register.
	if (sdcardcsd[0][7:6] == 'b00) begin
		// I get here if the card CSD format is 1.0;

		// I compute the block count using extracted CSD fields.
		blkcnt_o <= ((
			// I extract the CSIZE field.
			(({sdcardcsd[6], sdcardcsd[7], sdcardcsd[8]} & 'h03ffc0) >> 6)
				+ 1) << (
					// I extract the CSIZEMULT field.
					(({sdcardcsd[9], sdcardcsd[10]} & 'h0380) >> 7)
						+ 2 +
							// I extract the READBLLEN field.
							(sdcardcsd[5] & 'h0f)
								)) >> 9;

	end else if (sdcardcsd[0][7:6] == 'b01) begin
		// I get here if the card CSD format is 2.0;

		// I compute the block count using extracted CSD fields.
		blkcnt_o <= (
			// I extract the CSIZE field.
			({sdcardcsd[7], sdcardcsd[8], sdcardcsd[9]} & 'h3fffff)
				+ 1) << 10;

	end else begin
		// I get here if the card CSD format is unsupported.

		// I set the block count to 1, since the card
		// should surely have at least a single block.
		blkcnt_o <= 1;
	end
end

// Register which will be set to the value to set on "spi.sclkdiv_i"
// in order to attain the maximum transmission frequency safe to use.
// It is computed from the card CSD register.
reg [CLOG2SCLKDIVLIMIT -1 : 0] safemaxsclkdiv_r = 0;

always @ (posedge clk_i) begin
	// Logic that set safemaxsclkdiv_r.
	// For unsupported values of sdcardcsd[3],
	// the minimum transmission frequency is used.
	if (sdcardcsd[3] == 'h2b)
		safemaxsclkdiv_r <= SCLKDIV200000000; // 200 Mbps.
	else if (sdcardcsd[3] == 'h0b)
		safemaxsclkdiv_r <= SCLKDIV100000000; // 100 Mbps.
	else if (sdcardcsd[3] == 'h5a)
		safemaxsclkdiv_r <= SCLKDIV50000000;  // 50 Mbps.
	else if (sdcardcsd[3] == 'h32)
		safemaxsclkdiv_r <= SCLKDIV25000000;  // 25 Mbps.
	else
		safemaxsclkdiv_r <= (SCLKDIVLIMIT-1); // 250 Kbps.
end

// Commands to be sent to the card.
// All commands are 6 bytes, but I append 0xff so that
// the register spitxbufferdatain be 0xff once the 6 bytes
// of the command have been transmitted, and so as to keep
// transmitting 0xff while waiting for a response from the card.

wire [64 -1 : 0] dmc0 = 64'hff400000000001ff;
wire [8 -1 : 0]  cmd0[7:0];
assign cmd0[0] = dmc0[7:0];
assign cmd0[1] = dmc0[15:8];
assign cmd0[2] = dmc0[23:16];
assign cmd0[3] = dmc0[31:24];
assign cmd0[4] = dmc0[39:32];
assign cmd0[5] = dmc0[47:40];
assign cmd0[6] = dmc0[55:48];
assign cmd0[7] = dmc0[63:56];

wire [64 -1 : 0] dmc8 = 64'hff48000001aa01ff;
wire [8 -1 : 0]  cmd8[7:0];
assign cmd8[0] = dmc8[7:0];
assign cmd8[1] = dmc8[15:8];
assign cmd8[2] = dmc8[23:16];
assign cmd8[3] = dmc8[31:24];
assign cmd8[4] = dmc8[39:32];
assign cmd8[5] = dmc8[47:40];
assign cmd8[6] = dmc8[55:48];
assign cmd8[7] = dmc8[63:56];

wire [64 -1 : 0] dmc1 = 64'hff410000000001ff;
wire [8 -1 : 0]  cmd1[7:0];
assign cmd1[0] = dmc1[7:0];
assign cmd1[1] = dmc1[15:8];
assign cmd1[2] = dmc1[23:16];
assign cmd1[3] = dmc1[31:24];
assign cmd1[4] = dmc1[39:32];
assign cmd1[5] = dmc1[47:40];
assign cmd1[6] = dmc1[55:48];
assign cmd1[7] = dmc1[63:56];

wire [64 -1 : 0]  dmc55 = 64'hff770000000001ff;
wire [8 -1 : 0]   cmd55[7:0];
assign cmd55[0] = dmc55[7:0];
assign cmd55[1] = dmc55[15:8];
assign cmd55[2] = dmc55[23:16];
assign cmd55[3] = dmc55[31:24];
assign cmd55[4] = dmc55[39:32];
assign cmd55[5] = dmc55[47:40];
assign cmd55[6] = dmc55[55:48];
assign cmd55[7] = dmc55[63:56];

wire [64 -1 : 0]  dmc41 = 64'hff690000000001ff;
wire [8 -1 : 0]   cmd41[7:0];
assign cmd41[0] = dmc41[7:0];
assign cmd41[1] = dmc41[15:8];
assign cmd41[2] = dmc41[23:16];
assign cmd41[3] = dmc41[31:24];
assign cmd41[4] = dmc41[39:32];
assign cmd41[5] = dmc41[47:40];
assign cmd41[6] = dmc41[55:48];
assign cmd41[7] = dmc41[63:56];

wire [64 -1 : 0]     dmc41hcs = 64'hff694000000001ff;
wire [8 -1 : 0]      cmd41hcs[7:0];
assign cmd41hcs[0] = dmc41hcs[7:0];
assign cmd41hcs[1] = dmc41hcs[15:8];
assign cmd41hcs[2] = dmc41hcs[23:16];
assign cmd41hcs[3] = dmc41hcs[31:24];
assign cmd41hcs[4] = dmc41hcs[39:32];
assign cmd41hcs[5] = dmc41hcs[47:40];
assign cmd41hcs[6] = dmc41hcs[55:48];
assign cmd41hcs[7] = dmc41hcs[63:56];

wire [64 -1 : 0]  dmc58 = 64'hff7a0000000001ff;
wire [8 -1 : 0]   cmd58[7:0];
assign cmd58[0] = dmc58[7:0];
assign cmd58[1] = dmc58[15:8];
assign cmd58[2] = dmc58[23:16];
assign cmd58[3] = dmc58[31:24];
assign cmd58[4] = dmc58[39:32];
assign cmd58[5] = dmc58[47:40];
assign cmd58[6] = dmc58[55:48];
assign cmd58[7] = dmc58[63:56];

wire [64 -1 : 0]  dmc16 = 64'hff500000020001ff;
wire [8 -1 : 0]   cmd16[7:0];
assign cmd16[0] = dmc16[7:0];
assign cmd16[1] = dmc16[15:8];
assign cmd16[2] = dmc16[23:16];
assign cmd16[3] = dmc16[31:24];
assign cmd16[4] = dmc16[39:32];
assign cmd16[5] = dmc16[47:40];
assign cmd16[6] = dmc16[55:48];
assign cmd16[7] = dmc16[63:56];

wire [64 -1 : 0] dmc9 = 64'hff490000000001ff;
wire [8 -1 : 0]  cmd9[7:0];
assign cmd9[0] = dmc9[7:0];
assign cmd9[1] = dmc9[15:8];
assign cmd9[2] = dmc9[23:16];
assign cmd9[3] = dmc9[31:24];
assign cmd9[4] = dmc9[39:32];
assign cmd9[5] = dmc9[47:40];
assign cmd9[6] = dmc9[55:48];
assign cmd9[7] = dmc9[63:56];

reg  [ADDRBITSZ -1 : 0] cmdaddr = 0;
wire [ADDRBITSZ -1 : 0] cmdaddrshiftedleft = (cmdaddr << 9);

wire [64 -1 : 0]  dmc17 = {16'hff51, issdcardaddrblockaligned ? cmdaddr : cmdaddrshiftedleft, 16'h01ff};
wire [8 -1 : 0]   cmd17[7:0];
assign cmd17[0] = dmc17[7:0];
assign cmd17[1] = dmc17[15:8];
assign cmd17[2] = dmc17[23:16];
assign cmd17[3] = dmc17[31:24];
assign cmd17[4] = dmc17[39:32];
assign cmd17[5] = dmc17[47:40];
assign cmd17[6] = dmc17[55:48];
assign cmd17[7] = dmc17[63:56];

wire [64 -1 : 0]  dmc24 = {16'hff58, issdcardaddrblockaligned ? cmdaddr : cmdaddrshiftedleft, 16'h01ff};
wire [8 -1 : 0]   cmd24[7:0];
assign cmd24[0] = dmc24[7:0];
assign cmd24[1] = dmc24[15:8];
assign cmd24[2] = dmc24[23:16];
assign cmd24[3] = dmc24[31:24];
assign cmd24[4] = dmc24[39:32];
assign cmd24[5] = dmc24[47:40];
assign cmd24[6] = dmc24[55:48];
assign cmd24[7] = dmc24[63:56];

wire [64 -1 : 0]  dmc13 = 64'hff4d0000000001ff;
wire [8 -1 : 0]   cmd13[7:0];
assign cmd13[0] = dmc13[7:0];
assign cmd13[1] = dmc13[15:8];
assign cmd13[2] = dmc13[23:16];
assign cmd13[3] = dmc13[31:24];
assign cmd13[4] = dmc13[39:32];
assign cmd13[5] = dmc13[47:40];
assign cmd13[6] = dmc13[55:48];
assign cmd13[7] = dmc13[63:56];

wire [64 -1 : 0] dmc6 = 64'hff4680fffff101ff;
wire [8 -1 : 0]  cmd6[7:0];
assign cmd6[0] = dmc6[7:0];
assign cmd6[1] = dmc6[15:8];
assign cmd6[2] = dmc6[23:16];
assign cmd6[3] = dmc6[31:24];
assign cmd6[4] = dmc6[39:32];
assign cmd6[5] = dmc6[47:40];
assign cmd6[6] = dmc6[55:48];
assign cmd6[7] = dmc6[63:56];

wire [64 -1 : 0]  dmc59 = 64'hff7b0000000101ff;
wire [8 -1 : 0]   cmd59[7:0];
assign cmd59[0] = dmc59[7:0];
assign cmd59[1] = dmc59[15:8];
assign cmd59[2] = dmc59[23:16];
assign cmd59[3] = dmc59[31:24];
assign cmd59[4] = dmc59[39:32];
assign cmd59[5] = dmc59[47:40];
assign cmd59[6] = dmc59[55:48];
assign cmd59[7] = dmc59[63:56];

// Register used as the controller counter.
// The largest value that it will be set to, is > than the clock cycle count equivalent of 250ms.
// Since 250ms is 4 Hz, the number of clock cycles using a clock frequency of PHYCLKFREQ
// would be PHYCLKFREQ/4; the result of that value would largely be greater than
// ((spi_master.DATABITSIZE + 1) * (1 << spi_master.SCLKDIVLIMIT))
// which is the minimum number of clock cycles needed to reset spimaster;
// in fact PHYCLKFREQ must be at least 250 KHz.
reg [CLOG2PHYCLKFREQ -1 : 0] cntr = 0;

assign tx_pop_o  = ((state == CMD24RESP) && !spitxbufferfull && cntr && cntr <= 512);
assign rx_push_o = ((state == CMD17RESP) && !spirxbufferempty && cntr > 1 && cntr <= 513);

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

localparam CRCCOUNTERBITSZ = clog2(8 + 1);

// Register used to keep track of the number
// of clock cycles left in the CRC computation.
// It is set to 8 for each byte to accumulate
// in the CRC computation.
reg [CRCCOUNTERBITSZ -1 : 0] crccounter = 0;
reg [CRCCOUNTERBITSZ -1 : 0] _crccounter = 0;

assign cmd_pop_o = (state == READY);

reg resetting = 1;

// Logic computing the CRC7 or CRC16 per the card spec.
// To insure that the CRC computation has enough
// clock cycles to complete, it must use "spi.clk_phy_i"
// so that when (spi.sclkdiv_i == 0), there is at least
// 8 clock cycles between the transmission of each byte
// used in the CRC computation.
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

	// Controller logic.
	if (rst_i || state == RESET) begin
		// Reset logic.

		resetting <= 1;

		miscflag <= 0;

		// I move onto the state which will wait 250ms,
		// as required by the card spec after poweron.
		state <= RESETTING;

		// I set cntr to a clock cycle count
		// which yield at least 250ms.
		cntr <= (PHYCLKFREQ/4);

		// I set the spi clock to a frequency between 100 KHz
		// and 400 KHz, as required by the card spec after poweron.
		sclkdiv_r <= (SCLKDIVLIMIT-1);

		// I set keepsdcardcshigh to 1 so that the card input cs_o be kept high.
		keepsdcardcshigh <= 1;

		// I set spi.txbufferwriteenable to 0 to stop the spi clock.
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
					// to insure that there be enough clock cycles to compute the CRC
					// between each byte transmitted.
					// +2 account for the number of clock cycles needed for
					// the first byte to make it to the empty transmit buffer,
					// where it will be immediately removed for transmission,
					// and after which SPIBUFFERSIZE bytes will be added
					// to the transmit buffer to fill it up.
					cntr <= (6 + SPIBUFFERSIZE + 2);
				end

				// I stop writting in the transmit buffer since
				// I wish to wait that spi.ss become high.
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
		// cntr == (6 + SPIBUFFERSIZE + 2);

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

		resetting <= 0;

	end else if (state == SENDCMD0) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 2);

		issdcardver2 <= 0;

		issdcardmmc <= 0;

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
					spitxbufferdatain <= cmd0[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd0[cntr];
					crccounter <= 8;
				end
			end

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
		// cntr == (6 + SPIBUFFERSIZE + 2);

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
					spitxbufferdatain <= cmd59[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd59[cntr];
					crccounter <= 8;
				end
			end

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
		// cntr == (6 + SPIBUFFERSIZE + 2);

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
					spitxbufferdatain <= cmd8[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd8[cntr];
					crccounter <= 8;
				end
			end

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
		// cntr == (6 + SPIBUFFERSIZE + 2);
		// miscflag == 1;

		if (!miscflag) begin
			// If I get here, the card is done initializing.

			// I move onto the state which will send CMD6 to the card.
			state <= SENDCMD6;

			// There is no need to set cntr, because
			// it would have already been set to 6 when
			// coming to this state.

		end else begin
			// I write the command in the transmit buffer.
			spitxbufferwriteenable <= 1;

			// I wait that the transmit buffer
			// is not full, before doing anything,
			// otherwise bytes will get lost.
			if (!spitxbufferfull) begin

				if (cntr <= 6) begin
					// If the card is MMC, use CMD1
					// to initialize it, otherwise use
					// ACMD41 which start with CMD55.
					if (issdcardmmc) begin
						// Transmit the byte containing the CRC7 when
						// cntr == 1, otherwise transmit the command bytes.
						if (cntr == 1)
							spitxbufferdatain <= {crc7, 1'b1};
						else
							spitxbufferdatain <= cmd1[cntr];

						if (cntr > 1)
							crcarg <= cmd1[cntr];

					end else begin
						// Transmit the byte containing the CRC7 when
						// cntr == 1, otherwise transmit the command bytes.
						if (cntr == 1)
							spitxbufferdatain <= {crc7, 1'b1};
						else
							spitxbufferdatain <= cmd55[cntr];

						if (cntr > 1)
							crcarg <= cmd55[cntr];
					end

					// Note that when I get here, crccounter == 0.

					if (cntr > 1)
						crccounter <= 8;
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
		// cntr == (6 + SPIBUFFERSIZE + 2);

		// I write the command in the transmit buffer.
		spitxbufferwriteenable <= 1;

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!spitxbufferfull) begin

			if (cntr <= 6) begin
				// If the card is SDv2, I use ACMD41 with its bit HCS == 1.
				if (issdcardver2) begin
					// Transmit the byte containing the CRC7 when
					// cntr == 1, otherwise transmit the command bytes.
					if (cntr == 1)
						spitxbufferdatain <= {crc7, 1'b1};
					else
						spitxbufferdatain <= cmd41hcs[cntr];

					if (cntr > 1)
						crcarg <= cmd41hcs[cntr];

				end else begin
					// Transmit the byte containing the CRC7 when
					// cntr == 1, otherwise transmit the command bytes.
					if (cntr == 1)
						spitxbufferdatain <= {crc7, 1'b1};
					else
						spitxbufferdatain <= cmd41[cntr];

					if (cntr > 1)
						crcarg <= cmd41[cntr];
				end

				// Note that when I get here, crccounter == 0.

				if (cntr > 1)
					crccounter <= 8;
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
		// cntr == (6 + SPIBUFFERSIZE + 2);

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
					spitxbufferdatain <= cmd6[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd6[cntr];
					crccounter <= 8;
				end
			end

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
		// cntr == (6 + SPIBUFFERSIZE + 2);

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
					spitxbufferdatain <= cmd9[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd9[cntr];
					crccounter <= 8;
				end
			end

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
		// cntr == (6 + SPIBUFFERSIZE + 2);

		// Note that I will come to this state for all type of cards;
		// but OCR[30] in the response R3 exist only for SDv2 cards,
		// but should correctly be 0 for SDv1 and MMC cards as for those
		// two types of card it is a reserved bit.

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
					spitxbufferdatain <= cmd58[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd58[cntr];
					crccounter <= 8;
				end
			end

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
		// cntr == (6 + SPIBUFFERSIZE + 2);

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
					spitxbufferdatain <= cmd16[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd16[cntr];
					crccounter <= 8;
				end
			end

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
		// cntr == (6 + SPIBUFFERSIZE + 2);

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
					spitxbufferdatain <= cmd17[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd17[cntr];
					crccounter <= 8;
				end
			end

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
		// cntr == (6 + SPIBUFFERSIZE + 2);

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
					spitxbufferdatain <= cmd24[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd24[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD24RESP;
			end
		end

	end else if (state == SENDCMD13) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 0;
		// cntr == (6 + SPIBUFFERSIZE + 2);

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
					spitxbufferdatain <= cmd13[cntr];

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg <= cmd13[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// I move onto the state which will wait for the response.
				state <= CMD13RESP;
			end
		end

	end else if (state == CMD0RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card
			// and it must be [0[5:0], x], otherwise throw an error.
			// Following the reception of a valid reponse R1, I move
			// onto the state which will set SENDCMD59.
			if (rx_data_o[6:1])
				state <= ERROR;
			else
				state <= PREPCMD59;
		end

	end else if (state == CMD59RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card
			// and it must be [0[5:0], x], otherwise throw an error.
			// Following the reception of a valid reponse R1, I move
			// onto the state which will set SENDCMD8.
			if (rx_data_o[6:1])
				state <= ERROR;
			else
				state <= PREPCMD8;
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
				// The byte received is evaluated next time
				// that spi.rxbufferusage become non-null;
				// hence when cntr == 0, the byte following
				// the first byte of response R7 has been received,
				// but spi.rxbufferdataout still has the value of
				// the first byte of response R7 and will be updated
				// with the received byte on the next clock edge.

				if (cntr == 3) begin
					if (rx_data_o[0] != 1)
						state <= ERROR;
				end else if (cntr == 4) begin
					// If no error is found, I move onto the state which will set SENDINIT.
					if (rx_data_o != 'haa)
						state <= ERROR;
					else
						state <= PREPINIT;
				end

				cntr <= cntr + 1'b1;
			end

		end else if (rx_data_o != 'hff) begin

			issdcardver2 <= !rx_data_o[2];

			issdcardmmc <= 0;

			// If I get here, I received the first byte of response R7
			// from the card; if bit2 is 1, the card is either SDv1 or MMC
			// and I should move onto the state which will set SENDINIT;
			// otherwise issdcardver2 get set, and checks on whether
			// the card is a valid SDv2 follow.
			if (rx_data_o[2])
				state <= PREPINIT;
		end

	end else if (state == INITRESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// and if ACMD41 need to be sent,
		// cntr[0] == 1, otherwise
		// cntr[0] == 0;

		if (rx_data_o != 'hff) begin
			// If I get here, I received
			// the initialization response.

			if (cntr[0]) begin
				// If no error is found, I move onto the state which will
				// prepare the second portion of ACMD41 to send to the card.
				if (rx_data_o[6:1])
					state <= ERROR;
				else
					state <= PREPCMD41;

			end else begin
				// I update miscflag with the card idle state.
				miscflag <= rx_data_o[0];

				if (!issdcardver2 && !issdcardmmc && rx_data_o[2]) begin
					// If I get here, the card is MMC.
					issdcardmmc <= 1;
				end

				// If no error is found, I move onto the state which will set SENDINIT.
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
					// The byte received is evaluated next time
					// that spi.rxbufferusage become non-null;
					// hence when cntr == 0, the byte following
					// the byte starting a data packet has been received,
					// but spi.rxbufferdataout still has the value of
					// the byte starting a data packet and will be updated
					// with the following byte on the next clock edge.

					if (cntr >= 66) begin
						// If I get here, I am done reading the 64 bytes SD status.
						// I ignore the 2 CRC bytes that terminate the response.

						// I move onto the state which will set SENDCMD9.
						state <= PREPCMD9;
					end

					cntr <= cntr + 1'b1;
				end
			end

		end else if (rx_data_o != 'hff) begin
			// If I get here, I received response R1 from the card;
			// move onto the state which will set SENDCMD9 if it is not
			// [0[5:0], x], otherwise look at the data packet that follow.
			if (rx_data_o[6:1])
				state <= PREPCMD9;
			else begin
				miscflag <= 1;
				timeout <= -1;
			end
		end

	end else if (state == CMD9RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 1;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// looking at the data packet which follow response R1,
		// and which contain the bytes from the card CSD register.
		if (!miscflag) begin
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
					// The byte received is evaluated next time
					// that spi.rxbufferusage become non-null;
					// hence when cntr == 0, the byte following
					// the byte starting a data packet has been received,
					// but spi.rxbufferdataout still has the value of
					// the byte starting a data packet and will be updated
					// with the following byte on the next clock edge.

					if (cntr == 19) begin
						// I check the second CRC16 byte.
						if (rx_data_o != crc16[7:0])
							state <= ERROR;
						else begin
							// Set the maximum spi clock frequency safe to use.
							sclkdiv_r <= safemaxsclkdiv_r;
							// I move onto the state which will set SENDCMD58.
							state <= PREPCMD58;
						end

					end else if (cntr == 18) begin
						// If I get here, I am done reading the 16 bytes from the card CSD register.

						// I check the first CRC16 byte.
						if (rx_data_o != crc16[15:8])
							state <= ERROR;

					end else if (cntr > 1) begin

						sdcardcsd[cntr -2] <= rx_data_o;

						// Note that when I get here, crccounter == 0.

						crcarg <= rx_data_o;
						crccounter <= 8;

					end

					if (cntr != 19)
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
				miscflag <= 0;
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
				// The byte received is evaluated next time
				// that spi.rxbufferusage become non-null;
				// hence when cntr == 0, the byte following
				// the first byte of response R3 has been received,
				// but spi.rxbufferdataout still has the value of
				// the first byte of response R3 and will be updated
				// with the received byte on the next clock edge.

				if (cntr == 1) begin
					// I set issdcardaddrblockaligned using bit30
					// of the OCR register from the response R3.
					issdcardaddrblockaligned <= |(rx_data_o & 'h40);

				end else if (cntr == 4) begin
					// I get here when I have received the 4 bytes
					// that follow the first byte of response R3.

					// I move onto the state which will set SENDCMD16.
					state <= PREPCMD16;
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
			else
				state <= PREPREADY;
		end

	end else if (state == CMD17RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 1;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// looking at the data packet which follow response R1.
		if (!miscflag) begin
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
					// The byte received is evaluated next time
					// that spi.rxbufferusage become non-null;
					// hence when cntr == 0, the byte following
					// the byte starting a data packet has been received,
					// but spi.rxbufferdataout still has the value of
					// the byte starting a data packet and will be updated
					// with the following byte on the next clock edge.

					if (cntr == 515) begin
						// I check the second CRC16 byte.
						if (rx_data_o != crc16[7:0])
							state <= ERROR;
						else begin
							// I move onto the state which will set READY.
							state <= PREPREADY;
						end

					end else if (cntr == 514) begin
						// If I get here, I am done receiving the 512 bytes data packet.

						// I check the first CRC16 byte.
						if (rx_data_o != crc16[15:8])
							state <= ERROR;

					end else if (cntr > 1) begin
						// Note that when I get here, crccounter == 0.

						crcarg <= rx_data_o;
						crccounter <= 8;
					end

					if (cntr != 515)
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
				miscflag <= 0;
				timeout <= -1;
			end
		end

	end else if (state == CMD24RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 1;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// sending the data packet.
		if (!miscflag) begin

			if (cntr == 516) begin
				// If I get here, I wait for the data response byte.

				if (rx_data_o != 'hff) begin
					// If I get here, I received the data response byte.
					// The only bits of interest in the data response
					// are bit3 thru bit1.
					if ((rx_data_o[3:1]) == 'b010) begin
						// I move onto the state which will skip busy bytes and set SENDCMD13.
						state <= PREPCMD13;
					end else
						state <= ERROR;

					// Setting the register cntr to null so that
					// the logic computing the CRC reset itself null.
					cntr <= 0;
				end

			end else begin
				// If I get here, I send the data packet.

				if (!spitxbufferfull) begin
					// Since spitxbufferwriteenable is being held high and the fact
					// that it take more than 1 clock cycle to transmit a single byte,
					// spi.txbufferusage will certainly be SPIBUFFERSIZE after the next
					// active clock edge.

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
				miscflag <= 0;
		end

	end else if (state == CMD13RESP) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;
		// cntr == 0;
		// miscflag == 0;

		// When I get here, miscflag can be re-used for something
		// else; so here I use it to determine whether I can start
		// looking at the byte that follow the first byte of response R2.
		if (miscflag) begin
			// I evaluate the byte that follow the first byte of response R2.

			if (!spirxbufferempty) begin
				// I get here for each byte received.
				// The byte received is evaluated next time
				// that spi.rxbufferusage become non-null;
				// hence when cntr == 0, the byte following
				// the first byte of response R2 has been received,
				// but spi.rxbufferdataout still has the value of
				// the first byte of response R2 and will be updated
				// with the received byte on the next clock edge.

				if (cntr == 1) begin
					// I get here when I have received the byte
					// that follow the first byte of response R2.

					// If no error is found, I move onto the state which will set READY.
					if (rx_data_o)
						state <= ERROR;
					else
						state <= PREPREADY;
				end

				cntr <= cntr + 1'b1;
			end

		end else if (rx_data_o != 'hff) begin
			// If I get here, I received the first byte of response R2
			// from the card; throw an error if it is not [0[5:0], x],
			// otherwise look at the following byte.
			if (rx_data_o[6:1])
				state <= ERROR;
			else
				miscflag <= 1;
		end

	end else if (state == PREPCMD59) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state which will send CMD59 to the card.
			state <= SENDCMD59;
			// The register cntr is set in such a way that
			// the transmit buffer become full with 0xff bytes
			// before sending each byte of the command;
			// in fact keeping the buffer full while sending
			// each byte of the command is used to insure that
			// there be enough clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number of clock cycles needed for
			// the first byte to make it to the empty transmit buffer,
			// where it will be immediately removed for transmission,
			// and after which SPIBUFFERSIZE bytes will be added
			// to the transmit buffer to fill it up.
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high.
		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD8) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state which will send CMD8 to the card.
			state <= SENDCMD8;
			// The register cntr is set in such a way that
			// the transmit buffer become full with 0xff bytes
			// before sending each byte of the command;
			// in fact keeping the buffer full while sending
			// each byte of the command is used to insure that
			// there be enough clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number of clock cycles needed for
			// the first byte to make it to the empty transmit buffer,
			// where it will be immediately removed for transmission,
			// and after which SPIBUFFERSIZE bytes will be added
			// to the transmit buffer to fill it up.
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high.
		spitxbufferwriteenable <= 0;

	end else if (state == PREPINIT) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		// When coming to this state, "spi.ss" is certainly null,
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
				// The register cntr is set in such a way that
				// the transmit buffer become full with 0xff bytes
				// before sending each byte of the command;
				// in fact keeping the buffer full while sending
				// each byte of the command is used to insure that
				// there be enough clock cycles to compute the CRC
				// between each byte transmitted.
				// +2 account for the number of clock cycles needed for
				// the first byte to make it to the empty transmit buffer,
				// where it will be immediately removed for transmission,
				// and after which SPIBUFFERSIZE bytes will be added
				// to the transmit buffer to fill it up.
				cntr <= (6 + SPIBUFFERSIZE + 2);
			end

		end else
			cntr <= (PHYCLKFREQ/20) -1; // 50ms is 20Hz.

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high.
		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD41) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state which will send CMD41 to the card.
			state <= SENDCMD41;
			// The register cntr is set in such a way that
			// the transmit buffer become full with 0xff bytes
			// before sending each byte of the command;
			// in fact keeping the buffer full while sending
			// each byte of the command is used to insure that
			// there be enough clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number of clock cycles needed for
			// the first byte to make it to the empty transmit buffer,
			// where it will be immediately removed for transmission,
			// and after which SPIBUFFERSIZE bytes will be added
			// to the transmit buffer to fill it up.
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high.
		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD9) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state which will send CMD9 to the card.
			state <= SENDCMD9;
			// The register cntr is set in such a way that
			// the transmit buffer become full with 0xff bytes
			// before sending each byte of the command;
			// in fact keeping the buffer full while sending
			// each byte of the command is used to insure that
			// there be enough clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number of clock cycles needed for
			// the first byte to make it to the empty transmit buffer,
			// where it will be immediately removed for transmission,
			// and after which SPIBUFFERSIZE bytes will be added
			// to the transmit buffer to fill it up.
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high.
		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD58) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state which will send CMD58 to the card.
			state <= SENDCMD58;
			// The register cntr is set in such a way that
			// the transmit buffer become full with 0xff bytes
			// before sending each byte of the command;
			// in fact keeping the buffer full while sending
			// each byte of the command is used to insure that
			// there be enough clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number of clock cycles needed for
			// the first byte to make it to the empty transmit buffer,
			// where it will be immediately removed for transmission,
			// and after which SPIBUFFERSIZE bytes will be added
			// to the transmit buffer to fill it up.
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high.
		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD16) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state which will send CMD16 to the card.
			state <= SENDCMD16;
			// The register cntr is set in such a way that
			// the transmit buffer become full with 0xff bytes
			// before sending each byte of the command;
			// in fact keeping the buffer full while sending
			// each byte of the command is used to insure that
			// there be enough clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number of clock cycles needed for
			// the first byte to make it to the empty transmit buffer,
			// where it will be immediately removed for transmission,
			// and after which SPIBUFFERSIZE bytes will be added
			// to the transmit buffer to fill it up.
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high.
		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD13) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state which will send CMD13 to the card.
			state <= SENDCMD13;
			// The register cntr is set in such a way that
			// the transmit buffer become full with 0xff bytes
			// before sending each byte of the command;
			// in fact keeping the buffer full while sending
			// each byte of the command is used to insure that
			// there be enough clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number of clock cycles needed for
			// the first byte to make it to the empty transmit buffer,
			// where it will be immediately removed for transmission,
			// and after which SPIBUFFERSIZE bytes will be added
			// to the transmit buffer to fill it up.
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high; and
		// I do so only after skipping all busy bytes
		// from CMD24, since I come to this from CMD24RESP.
		if (rx_data_o == 'hff)
			spitxbufferwriteenable <= 0;

	end else if (state == PREPREADY) begin
		// When I come to this state I expect:
		// spitxbufferwriteenable == 1;

		// I set miscflag to 1, which is expected by the state CMD17RESP.
		miscflag <= 1;

		// I wait that the spimaster transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (cs_w) begin
			// I move onto the state in which the card is ready to be accessed.
			state <= READY;
			// The register cntr is set in such a way that
			// the transmit buffer become full with 0xff bytes
			// before sending each byte of the command;
			// in fact keeping the buffer full while sending
			// each byte of the command is used to insure that
			// there be enough clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number of clock cycles needed for
			// the first byte to make it to the empty transmit buffer,
			// where it will be immediately removed for transmission,
			// and after which SPIBUFFERSIZE bytes will be added
			// to the transmit buffer to fill it up.
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that spi.ss become high.
		spitxbufferwriteenable <= 0;

	end else if (state == ERROR) begin
		// I get here, if an error occured.
		// Nothing gets done until reset.

		// I stop writing in the transmit buffer in order
		// to stop the spi clock, which is power efficient.
		spitxbufferwriteenable <= 0;

		if (resetting) // Retry reset.
			state <= RESET;

	end else
		state <= ERROR;
end

endmodule

`endif /* SDCARD_SPI_PHY_V */
