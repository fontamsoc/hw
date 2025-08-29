// SPDX-License-Identifier: GPL-2.0-only
// 20250619 (c) William Fonkou Tambe

`ifndef SDCARD_SPI_PHY_V
`define SDCARD_SPI_PHY_V

// Module implementing an sd card controller using SD mode.
// SDSC (8MB to 2GB), SDHC (4GB to 32GB) and SDXC (64GB to 2TB) cards are supported.
// HighSpeed mode (50MHz) is used when available,
// otherwise DefaultSpeed mode (25MHz) is used.
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
// sdclk_o
// sdcmd_i, sdcmd_o, sdcmd_e
// sddat_i, sddat_o, sddat_e
// 	SDIO interface to the card.
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

module sdcard_sdio_phy (

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

	,sdclk_o
	,sdcmd_i ,sdcmd_o ,sdcmd_e
	,sddat_i ,sddat_o ,sddat_e

	,blkcnt_o

	,bsy_o
	,err_o
);

`include "lib/clog2.v"

parameter CLKFREQ = 500000;

// Phy clock frequency in Hz.
// It should be at least 2 * 250KHz needed to drive the card's input "sdclk_o".
parameter PHYCLKFREQ = 500000;

localparam CLOG2CLKFREQ = clog2(CLKFREQ);
localparam CLOG2PHYCLKFREQ = clog2(PHYCLKFREQ);

localparam SDCLKDIVLIMIT = ((PHYCLKFREQ <= 400000) ? 2 : ((PHYCLKFREQ/400000)+|(PHYCLKFREQ%400000)));
localparam CLOG2SDCLKDIVLIMIT = clog2(SDCLKDIVLIMIT);
// ### Use `<` instead of `<=` if sdcmd.sclkdiv_i can be null.
localparam SDCLKDIV10LIMIT = ((PHYCLKFREQ <= 10000000) ? SDCLKDIVLIMIT : ((PHYCLKFREQ/10000000)+|(PHYCLKFREQ%10000000)));
localparam SDCLKDIV25LIMIT = ((PHYCLKFREQ <= 25000000) ? SDCLKDIV10LIMIT : ((PHYCLKFREQ/25000000)+|(PHYCLKFREQ%25000000)));
localparam SDCLKDIV50LIMIT = ((PHYCLKFREQ <= 50000000) ? SDCLKDIV25LIMIT : ((PHYCLKFREQ/50000000)+|(PHYCLKFREQ%50000000)));

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

localparam CMDADDRBITSZ = 32; // Per the spec, read/write address is 32bits.

output wire                       cmd_pop_o;
input  wire                       cmd_data_i;
input  wire [CMDADDRBITSZ -1 : 0] cmd_addr_i;
input  wire                       cmd_empty_i;

output wire             rx_push_o;
output wire [32 -1 : 0] rx_data_o;

output wire             tx_pop_o;
input  wire [32 -1 : 0] tx_data_i;

output wire            sdclk_o;
input  wire            sdcmd_i;
output wire            sdcmd_o;
output reg             sdcmd_e = 0;
(* mark_debug = "true" *) input  wire [4 -1 : 0] sddat_i;
(* mark_debug = "true" *) output wire [4 -1 : 0] sddat_o;
(* mark_debug = "true" *) output reg  [4 -1 : 0] sddat_e = 0;

output reg [CMDADDRBITSZ -1 : 0] blkcnt_o = 0;

output wire bsy_o;
output wire err_o;

// After poweron or reset, the spec demands to allow at least 250ms
// for the card to reach a stable powered state; and then to issue
// at least 74 cycles on the card's input "sdclk_o".
// The frequency of the card's input "sdclk_o" should be 400 KHz.
// The card is ready to receive a command when 0xff keeps being received from it;
// similarly, when waiting or reading responses from the card, 0xff must keep
// being transmitted to it.
//
// The card must be initialized before data transfer can occur.
//
// Initialization or reset of the card is done as follow:
// - Send CMD0; software reset.
// 	No response expected.
// - Send CMD8.
// 	Expect response R7 only if the card accepted the supplied voltage.
// 	If no response or illigal command returned, the card is SDv1,
// 	otherwise the card is SDv2.
// - If card is SDv2, send ACMD41 with the HCS bit of the command set to 1.
// 	If card is not SDv2, send ACMD41 with the HCS bit of the command set to 0.
// 	Expect response R3.
// 	Repeat this step until OCR bit31 gets set to 1.
// - Send CMD2.
// 	Expect response R2.
// - Send CMD3 to get the card's RCA.
// 	Expect response R6.
// - Send CMD9 to read the card's CSD register from which the max "sdclk_o" frequency
// 	and capacity will be computed.
// 	Expect response R2.
// - Send CMD7.
// 	Expect response R1b.
// - Send ACMD6; switch to 4-bit mode.
// 	Expect response R1.
// - Send CMD6; set high speed mode if available.
// 	Expect response R1.
// - Send CMD16; set block size to 512Bytes.
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
// ((spi_master.DATABITSIZE + 1) * (1 << spi_master.SDCLKDIVLIMIT))
// which is the minimum number of clock cycles needed to reset spi_master;
// in fact CLKFREQ must be at least 250 KHz.
reg [CLOG2CLKFREQ -1 : 0] timeout = 0;

// Constants used with the register state.

// When in this state, the controller is resseting by waiting 250ms, before
// driving the card SDIO interface, and then issuing at least 74 "sdclk_o" cycles.
localparam RESETTING = 0;
// When in this state, the controller is not busy.
localparam READY     = 1;
// States that send a command.
localparam SENDCMD0   = 2;
localparam SENDCMD8   = 3;
localparam SENDINIT   = 4;
localparam SENDACMD41 = 5;
localparam SENDCMD2   = 6;
localparam SENDCMD3   = 7;
localparam SENDCMD9   = 8;
localparam SENDCMD7   = 28;
localparam SENDACMD6  = 30;
localparam SENDCMD6   = 9;
localparam SENDCMD16  = 10;
localparam SENDCMD17  = 11;
localparam SENDCMD24  = 12;
// States that wait for a command's response.
localparam CMD8RESP   = 14;
localparam CMD55RESP  = 15;
localparam ACMD41RESP = 16;
localparam CMD2RESP   = 17;
localparam CMD3RESP   = 18;
localparam CMD9RESP   = 19;
localparam CMD7RESP   = 29;
localparam ACMD6RESP  = 31;
localparam CMD6RESP   = 20;
localparam CMD16RESP  = 21;
localparam CMD17RESP  = 22;
localparam CMD24RESP  = 23;
// Other states.
localparam PREPNXTCMD = 25;
localparam PREPINIT   = 26;
localparam ERROR      = 27; // When in this state, an error occured, and a reset is required.

localparam STATEBITSZ = clog2(32);

// Register used to hold the state of the controller.
(* mark_debug = "true" *) reg [STATEBITSZ -1 : 0] state = ERROR;
reg [STATEBITSZ -1 : 0] nxtstate;

assign err_o = (state == ERROR);

// Register that hold the value of the input "sdcmd.sclkdiv_i".
(* mark_debug = "true" *) reg [CLOG2SDCLKDIVLIMIT -1 : 0] sclkdiv_r;

wire sdcmd_cs_w;

// Register that hold the value of the input "sdcmd.push_i".
reg sdcmd_txbuf_we;

// Register that hold the value of the input "sdcmd.data_i".
(* mark_debug = "true" *) reg [8 -1 : 0] sdcmd_txbuf_dati;

wire sdcmd_txbuf_full;

wire sdcmd_rxbuf_empty_;
reg  sdcmd_rxbuf_empty;
always @ (posedge clk_i)
	sdcmd_rxbuf_empty <= sdcmd_rxbuf_empty_;

(* mark_debug = "true" *) wire [8 -1 : 0] sdcmd_rxbuf_dato;

// Size of spi_master buffer.
// It is minimal to keep latency at its lowest when waiting
// for the transmission to end or when waiting for the transmit
// buffer to be full.
localparam SDIOBUFFERSIZE = 2;

spi_master #(
	 .SCLKDIVLIMIT (SDCLKDIVLIMIT)
	,.DATABITSZ    (8)
	,.CPOL         (0)
	,.BUFSZ        (SDIOBUFFERSIZE)
) sdcmd (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.sclk_o (sdclk_o)

	,.miso_i (sdcmd_e ? 1'b1 : sdcmd_i)
	,.mosi_o (sdcmd_o)
	,.cs_o   (sdcmd_cs_w)

	,.sclkdiv_i (sclkdiv_r)

	,.push_i (sdcmd_txbuf_we)
	,.data_i (sdcmd_txbuf_dati)
	,.full_o (sdcmd_txbuf_full)

	,.read_i  (1'b1)
	,.data_o  (sdcmd_rxbuf_dato)
	,.empty_o (sdcmd_rxbuf_empty_)

	,.misoSync_i        (!sdcmd_e)
	,.misoSkipSyncBit_i (1'b0)
);

wire [4 -1 : 0] sddat_cs_w;
reg             sddat_cs_r;
(* mark_debug = "true" *) wire sddat_cs_w_posedge = (&sddat_cs_w && !sddat_cs_r);
always @ (posedge clk_i) // TODO: Remove ...
	sddat_cs_r <= &sddat_cs_w;

// Register that hold the value of the input "sddat.push_i".
reg sddat_txbuf_we;

// Register that hold the value of the input "sddat.data_i".
(* mark_debug = "true" *) reg  [32 -1 : 0] sddat_txbuf_dati;
(* mark_debug = "true" *) wire [32 -1 : 0] _sddat_txbuf_dati;

wire [32 -1 : 0] _tx_data_i;
wire [32 -1 : 0] __tx_data_i;

(* mark_debug = "true" *) wire [4 -1 : 0] sddat_txbuf_full;

wire [4 -1 : 0] sddat_rxbuf_empty_;
(* mark_debug = "true" *) reg             sddat_rxbuf_empty;
always @ (posedge clk_i)
	sddat_rxbuf_empty <= &sddat_rxbuf_empty_;

(* mark_debug = "true" *) wire [32 -1 : 0] sddat_rxbuf_dato_;
(* mark_debug = "true" *) wire [32 -1 : 0] sddat_rxbuf_dato;

(* mark_debug = "true" *) wire [32 -1 : 0] crc16_msb;
(* mark_debug = "true" *) wire [32 -1 : 0] crc16_lsb;
wire [32 -1 : 0] _crc16_msb;
wire [32 -1 : 0] _crc16_lsb;

genvar gen_sddat_idx;
generate for (
	gen_sddat_idx = 0;
	gen_sddat_idx < 4;
	gen_sddat_idx = gen_sddat_idx + 1) begin :gen_sddat

spi_master #(
	 .SCLKDIVLIMIT (SDCLKDIVLIMIT)
	,.DATABITSZ    (8)
	,.CPOL         (0)
	,.BUFSZ        (SDIOBUFFERSIZE)
) sddat (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.sclk_o ()

	,.miso_i (sddat_e[gen_sddat_idx] ? 1'b1 : sddat_i[gen_sddat_idx])
	,.mosi_o (sddat_o[gen_sddat_idx])
	,.cs_o   (sddat_cs_w[gen_sddat_idx])

	,.sclkdiv_i (sclkdiv_r)

	,.push_i (sddat_txbuf_we)
	,.data_i (_sddat_txbuf_dati[(gen_sddat_idx*8)+:8])
	,.full_o (sddat_txbuf_full[gen_sddat_idx])

	,.read_i  (1'b1)
	,.data_o  (sddat_rxbuf_dato_[(gen_sddat_idx*8)+:8])
	,.empty_o (sddat_rxbuf_empty_[gen_sddat_idx])

	,.misoSync_i        (!sddat_e[gen_sddat_idx])
	,.misoSkipSyncBit_i (!sddat_e[gen_sddat_idx])
);

assign __tx_data_i[(gen_sddat_idx*8)+:8] = {
		_tx_data_i[28+gen_sddat_idx], _tx_data_i[24+gen_sddat_idx],
		_tx_data_i[20+gen_sddat_idx], _tx_data_i[16+gen_sddat_idx],
		_tx_data_i[12+gen_sddat_idx], _tx_data_i[ 8+gen_sddat_idx],
		_tx_data_i[ 4+gen_sddat_idx], _tx_data_i[ 0+gen_sddat_idx]};

assign _sddat_txbuf_dati[(gen_sddat_idx*8)+:8] = {
		sddat_txbuf_dati[28+gen_sddat_idx], sddat_txbuf_dati[24+gen_sddat_idx],
		sddat_txbuf_dati[20+gen_sddat_idx], sddat_txbuf_dati[16+gen_sddat_idx],
		sddat_txbuf_dati[12+gen_sddat_idx], sddat_txbuf_dati[ 8+gen_sddat_idx],
		sddat_txbuf_dati[ 4+gen_sddat_idx], sddat_txbuf_dati[ 0+gen_sddat_idx]};

assign {sddat_rxbuf_dato[28+gen_sddat_idx], sddat_rxbuf_dato[24+gen_sddat_idx],
		sddat_rxbuf_dato[20+gen_sddat_idx], sddat_rxbuf_dato[16+gen_sddat_idx],
		sddat_rxbuf_dato[12+gen_sddat_idx], sddat_rxbuf_dato[ 8+gen_sddat_idx],
		sddat_rxbuf_dato[ 4+gen_sddat_idx], sddat_rxbuf_dato[ 0+gen_sddat_idx]}
		= sddat_rxbuf_dato_[(gen_sddat_idx*8)+:8];

assign {_crc16_msb[28+gen_sddat_idx], _crc16_msb[24+gen_sddat_idx],
		_crc16_msb[20+gen_sddat_idx], _crc16_msb[16+gen_sddat_idx],
		_crc16_msb[12+gen_sddat_idx], _crc16_msb[ 8+gen_sddat_idx],
		_crc16_msb[ 4+gen_sddat_idx], _crc16_msb[ 0+gen_sddat_idx]}
		= crc16_msb[(gen_sddat_idx*8)+:8];
assign {_crc16_lsb[28+gen_sddat_idx], _crc16_lsb[24+gen_sddat_idx],
		_crc16_lsb[20+gen_sddat_idx], _crc16_lsb[16+gen_sddat_idx],
		_crc16_lsb[12+gen_sddat_idx], _crc16_lsb[ 8+gen_sddat_idx],
		_crc16_lsb[ 4+gen_sddat_idx], _crc16_lsb[ 0+gen_sddat_idx]}
		= crc16_lsb[(gen_sddat_idx*8)+:8];

end endgenerate

assign rx_data_o = {
	sddat_rxbuf_dato[0+:8],  sddat_rxbuf_dato[8+:8],
	sddat_rxbuf_dato[16+:8], sddat_rxbuf_dato[24+:8]};

assign _tx_data_i = {
	tx_data_i[0+:8],  tx_data_i[8+:8],
	tx_data_i[16+:8], tx_data_i[24+:8]};

// Register used for multiple purposes.
reg miscflag;

// Register set to 1 when the card is found to be SDv2,
// otherwise it is set to 0.
(* mark_debug = "true" *) reg issdcardver2;

// Register set to 1 if the card addressing
// is block aligned, otherwise it is set to 0.
(* mark_debug = "true" *) reg issdcardaddrblockaligned;

// Register which will be used to store the value of the published RCA.
reg [16 -1 : 0] sdcardrca;

// Register which will be used to store the value of the card CSD register.
reg [128 -1 : 0] sdcardcsd;

always @ (posedge clk_i) begin
	// Logic which set blkcnt_o to the block count
	// of the card, computed from its CSD register.
	if (sdcardcsd[126+:2] == 2'd0) begin
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

// Signal which gets set to the value to set on "sdcmd.sclkdiv_i"
// in order to attain the maximum transmission frequency safe to use.
// It is computed from the card CSD register field TRAN_SPEED.
// The minimum transmission frequency is used for unsupported values.
reg [CLOG2SDCLKDIVLIMIT -1 : 0] sclkdiv_w; // ### comb-always-block-reg.
always @* begin
	if      (sdcardcsd[96+:8] == 8'h5a) sclkdiv_w = (SDCLKDIV50LIMIT-1);  // 50 Mbps.
	else if (sdcardcsd[96+:8] == 8'h32) sclkdiv_w = (SDCLKDIV25LIMIT-1);  // 25 Mbps.
	else                                sclkdiv_w = (SDCLKDIV10LIMIT-1);  // 10 Mbps.
end

(* mark_debug = "true" *) wire [2 -1 : 0] CSD_format = sdcardcsd[126+:2];
(* mark_debug = "true" *) wire [8 -1 : 0] CSD_speed = sdcardcsd[96+:8];

// Register used as the controller counter.
// The largest value that it will be set to, is greater
// than the clock cycle count equivalent of 250ms.
// Since 250ms is 4 Hz, the number of clock cycles using
// a clock frequency of CLKFREQ would be CLKFREQ/4.
// In fact CLKFREQ must be at least 250 KHz.
(* mark_debug = "true" *) reg [CLOG2CLKFREQ -1 : 0] cntr;

assign tx_pop_o  = ((state == CMD24RESP) && !sddat_txbuf_full  && cntr && cntr <= 128);
assign rx_push_o = ((state == CMD17RESP) && !sddat_rxbuf_empty && cntr && cntr <= 128);

localparam cmd0 = 40'h4000000000;
localparam cmd8 = 40'h48000001aa;
wire [40 -1 : 0] cmd55 = {8'h77, sdcardrca, 16'd0};
localparam acmd41 = 40'h6900000000;
localparam acmd41hcs = 40'h6940100000;
localparam cmd2 = 40'h4200000000;
localparam cmd3 = 40'h4300000000;
wire [40 -1 : 0] cmd9 = {8'h49, sdcardrca, 16'd0};
wire [40 -1 : 0] cmd7 = {8'h47, sdcardrca, 16'd0};
localparam acmd6 = 40'h4600000002;
localparam cmd16 = 40'h5000000200;
reg  [CMDADDRBITSZ -1 : 0] cmdaddr = 0;
wire [CMDADDRBITSZ -1 : 0] cmdaddrshiftedleft = {cmdaddr[(CMDADDRBITSZ-9)-1:0], 9'd0};
wire [40 -1 : 0] cmd17 = {8'h51, issdcardaddrblockaligned ? cmdaddr : cmdaddrshiftedleft};
wire [40 -1 : 0] cmd24 = {8'h58, issdcardaddrblockaligned ? cmdaddr : cmdaddrshiftedleft};
localparam cmd6 = 40'h4680fffff1;

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
reg [7 -1 : 0] crc7;

// CRC16 value.
reg [16 -1 : 0] crc16 [0 : 3];

// Byte value to accumulate in the CRC computation.
reg [8 -1 : 0] crcarg  [0 : 3];
reg [8 -1 : 0] _crcarg [0 : 3];

// Net set to the bit that will stream through the register crc7.
wire crc7in = (_crcarg[0][7] ^ crc7[6]);

// Net set to the bit that will stream through the register crc16.
wire crc16in0 = (_crcarg[0][7] ^ crc16[0][15]);
wire crc16in1 = (_crcarg[1][7] ^ crc16[1][15]);
wire crc16in2 = (_crcarg[2][7] ^ crc16[2][15]);
wire crc16in3 = (_crcarg[3][7] ^ crc16[3][15]);

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

		crc16[0][15] <= crc16[0][14];
		crc16[0][14] <= crc16[0][13];
		crc16[0][13] <= crc16[0][12];
		crc16[0][12] <= crc16[0][11] ^ crc16in0;
		crc16[0][11] <= crc16[0][10];
		crc16[0][10] <= crc16[0][9];
		crc16[0][9]  <= crc16[0][8];
		crc16[0][8]  <= crc16[0][7];
		crc16[0][7]  <= crc16[0][6];
		crc16[0][6]  <= crc16[0][5];
		crc16[0][5]  <= crc16[0][4] ^ crc16in0;
		crc16[0][4]  <= crc16[0][3];
		crc16[0][3]  <= crc16[0][2];
		crc16[0][2]  <= crc16[0][1];
		crc16[0][1]  <= crc16[0][0];
		crc16[0][0]  <= crc16in0;

		crc16[1][15] <= crc16[1][14];
		crc16[1][14] <= crc16[1][13];
		crc16[1][13] <= crc16[1][12];
		crc16[1][12] <= crc16[1][11] ^ crc16in1;
		crc16[1][11] <= crc16[1][10];
		crc16[1][10] <= crc16[1][9];
		crc16[1][9]  <= crc16[1][8];
		crc16[1][8]  <= crc16[1][7];
		crc16[1][7]  <= crc16[1][6];
		crc16[1][6]  <= crc16[1][5];
		crc16[1][5]  <= crc16[1][4] ^ crc16in1;
		crc16[1][4]  <= crc16[1][3];
		crc16[1][3]  <= crc16[1][2];
		crc16[1][2]  <= crc16[1][1];
		crc16[1][1]  <= crc16[1][0];
		crc16[1][0]  <= crc16in1;

		crc16[2][15] <= crc16[2][14];
		crc16[2][14] <= crc16[2][13];
		crc16[2][13] <= crc16[2][12];
		crc16[2][12] <= crc16[2][11] ^ crc16in2;
		crc16[2][11] <= crc16[2][10];
		crc16[2][10] <= crc16[2][9];
		crc16[2][9]  <= crc16[2][8];
		crc16[2][8]  <= crc16[2][7];
		crc16[2][7]  <= crc16[2][6];
		crc16[2][6]  <= crc16[2][5];
		crc16[2][5]  <= crc16[2][4] ^ crc16in2;
		crc16[2][4]  <= crc16[2][3];
		crc16[2][3]  <= crc16[2][2];
		crc16[2][2]  <= crc16[2][1];
		crc16[2][1]  <= crc16[2][0];
		crc16[2][0]  <= crc16in2;

		crc16[3][15] <= crc16[3][14];
		crc16[3][14] <= crc16[3][13];
		crc16[3][13] <= crc16[3][12];
		crc16[3][12] <= crc16[3][11] ^ crc16in3;
		crc16[3][11] <= crc16[3][10];
		crc16[3][10] <= crc16[3][9];
		crc16[3][9]  <= crc16[3][8];
		crc16[3][8]  <= crc16[3][7];
		crc16[3][7]  <= crc16[3][6];
		crc16[3][6]  <= crc16[3][5];
		crc16[3][5]  <= crc16[3][4] ^ crc16in3;
		crc16[3][4]  <= crc16[3][3];
		crc16[3][3]  <= crc16[3][2];
		crc16[3][2]  <= crc16[3][1];
		crc16[3][1]  <= crc16[3][0];
		crc16[3][0]  <= crc16in3;

		// Get the next msb to accumulate in the CRC computation.
		_crcarg[0] <= _crcarg[0] << 1'b1;
		_crcarg[1] <= _crcarg[1] << 1'b1;
		_crcarg[2] <= _crcarg[2] << 1'b1;
		_crcarg[3] <= _crcarg[3] << 1'b1;

		_crccounter <= _crccounter - 1'b1;

	end else if (!cntr) begin
		// Note that the register cntr is never
		// null when the CRC computation is needed,
		// hence it is used to reset null the registers
		// that will contain the result of the CRC computation.
		crc7 <= 0;
		crc16[0] <= 0;
		crc16[1] <= 0;
		crc16[2] <= 0;
		crc16[3] <= 0;

	end else if (crccounter) begin
		_crcarg[0] <= crcarg[0];
		_crcarg[1] <= crcarg[1];
		_crcarg[2] <= crcarg[2];
		_crcarg[3] <= crcarg[3];
		_crccounter <= crccounter;
	end
end

//assign crc16_msb = {crc16[0][15:8], crc16[1][15:8], crc16[2][15:8], crc16[3][15:8]};
//assign crc16_lsb = {crc16[0][7:0],  crc16[1][7:0],  crc16[2][7:0],  crc16[3][7:0]};

assign crc16_msb = {crc16[3][15:8], crc16[2][15:8], crc16[1][15:8], crc16[0][15:8]};
assign crc16_lsb = {crc16[3][7:0],  crc16[2][7:0],  crc16[1][7:0],  crc16[0][7:0]};

always @ (posedge clk_i) begin

	if (_crccounter)
		crccounter <= 0;

	if (rst_i) begin
		// Reset logic.

		sdcmd_e <= 0;
		sddat_e <= 4'b0000;

		miscflag <= 0;

		issdcardver2 <= 0;

		sdcardrca <= 0;

		// I move onto the state which will wait 250ms,
		// as required by the card spec after poweron.
		state <= RESETTING;

		// I set cntr to a clock cycle count which yield at least 250ms.
		cntr <= (CLKFREQ/4);

		// I set the sdio clock to a frequency of 400 KHz,
		// as required by the card spec after poweron.
		sclkdiv_r <= (SDCLKDIVLIMIT-1); // 400 Kbps.

		// I set sdcmd.push_i to 0 to stop the sdio clock.
		sdcmd_txbuf_we <= 0;
		sddat_txbuf_we <= 1;

		sddat_txbuf_dati <= {32{1'b1}};

	end else if (state == RESETTING) begin
		// I come to this state after a falling edge of the
		// input "rst_i"; I wait 250ms and then issue at least 74
		// "sdclk_o" cycles, as required by the card spec after poweron.

		if (miscflag) begin

			if (cntr) begin
				// I decrement cntr only if the transmit buffer is
				// not full, otherwise bytes to send will get skipped.
				if (!sdcmd_txbuf_full)
					cntr <= cntr - 1'b1;

			end else begin
				// I wait that spi_master transmit all buffered data.
				if (sdcmd_cs_w) begin
					// When I get here, the card should be in idle sate.

					// I move onto the state which will send CMD0 to the card.
					state <= SENDCMD0;
					// The register cntr is set in such a way that
					// the transmit buffer be full with 0xff bytes before sending
					// each byte of the command; in fact keeping the buffer
					// full while sending each byte of the command is used
					// in order to have enough clock cycles to compute the CRC
					// for each byte transmitted.
					cntr <= (6 + SDIOBUFFERSIZE + 1);
				end

				// I stop writting in the transmit buffer since
				// I wish to wait that sdcmd.cs_o becomes high.
				sdcmd_txbuf_we <= 0;
			end

		end else begin

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				// When I get here, 250ms has passed
				// since the input "rst_i" was de-asserted.

				// I set cntr to 10 in order to write ten 0xff bytes
				// in the transmit buffer which will issue 80 "sdclk_o" cycles,
				// well above 74 "sdclk_o" cycles.
				cntr <= 10;

				// Byte value to write in the transmit buffer 10 times.
				sdcmd_txbuf_dati <= 'hff;

				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;

				sddat_txbuf_we <= 0;

				miscflag <= 1;
			end
		end

	end else if (state == READY) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// Until there is something to do,
		// sdcmd_txbuf_we == 0,
		// which is power efficient because
		// the sdio clock will remain stopped.

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

	end else if (state == SENDCMD0) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd0;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// There is no response expected.
				state <= PREPNXTCMD;
				nxtstate <= SENDCMD8;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD8) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd8;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				timeout <= -1;
				state <= CMD8RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDINIT) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		if (!miscflag) begin
			// If I get here, the card is done initializing.

			// I get here from PREPINIT which does what PREPNXTCMD do;
			// hence there is no need to go through PREPNXTCMD.
			state <= SENDCMD2;

		end else begin
			// I write the command in the transmit buffer.

			// I wait that the transmit buffer
			// is not full, before doing anything,
			// otherwise bytes will get lost.
			if (!sdcmd_txbuf_full) begin

				if (cntr <= 6) begin
					// Transmit the byte containing the CRC7 when
					// cntr == 1, otherwise transmit the command bytes.
					if (cntr == 1)
						sdcmd_txbuf_dati <= {crc7, 1'b1};
					else
						sdcmd_txbuf_dati <= cmdXcntr;

					// Note that when I get here, crccounter == 0.

					if (cntr > 1) begin
						crcarg[0] <= cmdXcntr;
						crccounter <= 8;
					end

				end else
					cmdX <= cmd55;

				if (cntr) begin
					cntr <= cntr - 1'b1;
					sdcmd_txbuf_we <= 1;
					sdcmd_e <= 1;
				end else if (sdcmd_cs_w) begin
					// I move onto the state which will wait for the response.
					state <= CMD55RESP;
					nxtstate <= SENDACMD41; // Used by CMD55RESP.
					sdcmd_txbuf_we <= 1;
					sdcmd_e <= 0;
				end else
					sdcmd_txbuf_we <= 0;
			end
		end

	end else if (state == SENDACMD41) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else begin
				// If the card is SDv2, I use ACMD41 with its bit HCS == 1.
				cmdX <= (issdcardver2 ? acmd41hcs : acmd41);
			end

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= ACMD41RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD2) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd2;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= CMD2RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD3) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd3;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= CMD3RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD9) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd9;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= CMD9RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD7) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd7;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= CMD7RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDACMD6) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);
		// miscflag == 0;

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= (miscflag ? acmd6 : cmd55);

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= (miscflag ? ACMD6RESP : CMD55RESP);
				miscflag <= !miscflag;
				nxtstate <= SENDACMD6; // Used by CMD55RESP.
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD6) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd6;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= CMD6RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD16) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd16;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= CMD16RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD17) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd17;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= CMD17RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == SENDCMD24) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 0;
		// cntr == (6 + SDIOBUFFERSIZE + 1);

		// I write the command in the transmit buffer.

		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (!sdcmd_txbuf_full) begin

			if (cntr <= 6) begin
				// Transmit the byte containing the CRC7 when
				// cntr == 1, otherwise transmit the command bytes.
				if (cntr == 1)
					sdcmd_txbuf_dati <= {crc7, 1'b1};
				else
					sdcmd_txbuf_dati <= cmdXcntr;

				// Note that when I get here, crccounter == 0.

				if (cntr > 1) begin
					crcarg[0] <= cmdXcntr;
					crccounter <= 8;
				end

			end else
				cmdX <= cmd24;

			if (cntr) begin
				cntr <= cntr - 1'b1;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 1;
			end else if (sdcmd_cs_w) begin
				// I move onto the state which will wait for the response.
				state <= CMD24RESP;
				sdcmd_txbuf_we <= 1;
				sdcmd_e <= 0;
			end else
				sdcmd_txbuf_we <= 0;
		end

	end else if (state == CMD8RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;
		// timeout == -1;

		if (issdcardver2) begin
			// If I get here, the card must be SDv2; I evaluate
			// the 4 bytes that follow the first byte of
			// response R7; the 12 bits in the least significant
			// bytes should be 0x1aa, otherwise throw an error.
			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.

				if (cntr == 2) begin
					if (sdcmd_rxbuf_dato[0] != 1)
						state <= ERROR;
				end else if (cntr == 3) begin
					if (sdcmd_rxbuf_dato != 'haa)
						state <= ERROR;
					else
						state <= PREPINIT;
				end

				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the first byte of response R7
			// from the card; if command index is invalid, the card is SDv1
			// and I should move onto the state which will prep for SENDINIT;
			// otherwise issdcardver2 get set, and checks on whether
			// the card is a valid SDv2 follow.
			if (sdcmd_rxbuf_dato[5:0] != 6'b001000)
				state <= PREPINIT;
			else
				issdcardver2 <= 1'b1;
		end else if (timeout)
			timeout <= timeout - 1'b1;
		else
			state <= PREPINIT;

	end else if (state == CMD55RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (cntr) begin

			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 5) begin
					state <= PREPNXTCMD;
					// nxtstate has been set by the previous SEND state.
				end
				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b110111)
				state <= ERROR;
			cntr <= cntr + 1'b1;
		end

	end else if (state == ACMD41RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (cntr) begin

			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 1) begin
					// I update miscflag using OCR bit31.
					miscflag <= !sdcmd_rxbuf_dato[7];
					// I update issdcardaddrblockaligned using OCR bit30.
					issdcardaddrblockaligned <= sdcmd_rxbuf_dato[6];
				end else if (cntr == 5)
					state <= PREPINIT;
				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b111111)
				state <= ERROR;
			cntr <= cntr + 1'b1;
		end

	end else if (state == CMD2RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (cntr) begin

			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 16) begin
					state <= PREPNXTCMD;
					nxtstate <= SENDCMD3;
				end
				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b111111)
				state <= ERROR;
			cntr <= cntr + 1'b1;
		end

	end else if (state == CMD3RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (cntr) begin

			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 5) begin
					state <= PREPNXTCMD;
					nxtstate <= SENDCMD9;
				end else if (cntr == 3) begin
					if (sdcmd_rxbuf_dato[7:5])
						state <= ERROR;
				end else if (cntr <= 2)
					sdcardrca <= {sdcardrca[(16-8)-1:0], sdcmd_rxbuf_dato};
				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b000011)
				state <= ERROR;
			cntr <= cntr + 1'b1;
		end

	end else if (state == CMD9RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (cntr) begin

			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 16) begin
					if (sdcmd_rxbuf_dato[7:1] != crc7)
						state <= ERROR;
					else begin
						state <= PREPNXTCMD;
						nxtstate <= SENDCMD7;
					end
				end else if (cntr >= 1) begin
					// Note that when I get here, crccounter == 0.
					crcarg[0] <= sdcmd_rxbuf_dato;
					crccounter <= 8;
				end

				sdcardcsd <= {sdcardcsd[(128-8)-1:0], sdcmd_rxbuf_dato};

				if (cntr != 16)
					cntr <= cntr + 1'b1;
				else begin
					// Setting the register cntr to null so that
					// the logic computing the CRC reset itself null.
					cntr <= 0;
				end
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b111111)
				state <= ERROR;
			cntr <= cntr + 1'b1;
		end

	end else if (state == CMD7RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (cntr) begin

			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 5) begin
					state <= PREPNXTCMD;
					nxtstate <= SENDACMD6;
				end
				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b000111)
				state <= ERROR;
			cntr <= cntr + 1'b1;
		end

	end else if (state == ACMD6RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (cntr) begin

			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 5) begin
					state <= PREPNXTCMD;
					nxtstate <= SENDCMD6;
				end
				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b000110)
				state <= ERROR;
			cntr <= cntr + 1'b1;
		end

	end else if (state == CMD6RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (sddat_cs_w_posedge) begin
			state <= PREPNXTCMD;
			nxtstate <= SENDCMD16; // TODO: skip cmd16 if not sdsc ...
		end

		if (cntr) begin

			if (!sddat_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 18+2/* +2 to account for function change timing */) begin
					sddat_txbuf_we <= 0;
					// Set the maximum spi clock frequency safe to use.
					sclkdiv_r <= sclkdiv_w;
				end
				if (cntr == 5) begin
					// Update CSD.TRAN_SPEED if high-speed capable shows
					// in bits [379:376] of switch function status data.
					if (sddat_rxbuf_dato[27:24] == 4'h1)
						sdcardcsd[96+:8] <= 8'h5a;
				end
				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b000110)
				state <= ERROR;
			else
				sddat_txbuf_we <= 1;
			cntr <= cntr + 1'b1;
		end

	end else if (state == CMD16RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;

		if (cntr) begin

			if (!sdcmd_rxbuf_empty) begin
				// I get here for each byte received.
				if (cntr == 5) begin
					state <= PREPNXTCMD;
					nxtstate <= READY;
				end
				cntr <= cntr + 1'b1;
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b010000)
				state <= ERROR;
			cntr <= cntr + 1'b1;
		end

	end else if (state == CMD17RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;
		// miscflag == 0;

		if (sddat_cs_w_posedge) begin
			state <= PREPNXTCMD;
			nxtstate <= READY;
		end

		if (miscflag) begin

			if (!sddat_rxbuf_empty) begin
				// I get here for each word received.
				if (cntr == 130) begin
					// I check the second CRC16 byte.
					if (sddat_rxbuf_dato_[0+:8]  != crc16[0][7:0] ||
						sddat_rxbuf_dato_[8+:8]  != crc16[1][7:0] ||
						sddat_rxbuf_dato_[16+:8] != crc16[2][7:0] ||
						sddat_rxbuf_dato_[24+:8] != crc16[3][7:0])
						state <= ERROR;
					else
						sddat_txbuf_we <= 0;
				end else if (cntr == 129) begin
					// If I get here, I am done receiving the 512 bytes data packet.
					// I check the first CRC16 byte.
					if (sddat_rxbuf_dato_[0+:8]  != crc16[0][15:8] ||
						sddat_rxbuf_dato_[8+:8]  != crc16[1][15:8] ||
						sddat_rxbuf_dato_[16+:8] != crc16[2][15:8] ||
						sddat_rxbuf_dato_[24+:8] != crc16[3][15:8])
						state <= ERROR;
				end else begin
					// Note that when I get here, crccounter == 0.
					crcarg[0] <= sddat_rxbuf_dato_[0+:8];
					crcarg[1] <= sddat_rxbuf_dato_[8+:8];
					crcarg[2] <= sddat_rxbuf_dato_[16+:8];
					crcarg[3] <= sddat_rxbuf_dato_[24+:8];
					crccounter <= 8;
				end

				if (cntr != 130)
					cntr <= cntr + 1'b1;
				else begin
					// Setting the register cntr to null so that
					// the logic computing the CRC reset itself null.
					cntr <= 0;
					miscflag <= 0;
				end
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b010001)
				state <= ERROR;
			else begin
				sddat_txbuf_we <= 1;
				miscflag <= 1;
				cntr <= cntr + 1'b1;
			end
		end

	end else if (state == CMD24RESP) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;
		// cntr == 0;
		// miscflag == 0;

		if (sddat_cs_w_posedge && !sddat_e[0]) begin
			state <= PREPNXTCMD;
			nxtstate <= READY;
		end

		if (miscflag) begin

			if (!sddat_txbuf_full/*[0]*/) begin
				// I get here for each word to send.
				if (cntr == 133) begin
					if (sddat_cs_w_posedge) begin
						sddat_e <= 4'b0000;
						sddat_txbuf_we <= 1;
					end
					// If I get here, I wait for the data response byte.
					if (sddat_rxbuf_dato_[7:0] != 'hff) begin
						// If I get here, I received the data response byte.
						// The only bits of interest in the data response
						// are bit3 thru bit1.
						if (sddat_rxbuf_dato_[3:1] == 'b010)
							 sddat_txbuf_we <= 0;
						else
							state <= ERROR;
					end
				end else if (cntr == 132) begin
					sddat_txbuf_we <= 0;
				end else if (cntr == 131) begin
					// 0xff is transmitted on each data line until the data response is received.
					sddat_txbuf_dati <= 32'hffffffff;
				end else if (cntr == 130) begin
					// I send the second CRC16 byte for each data line.
					sddat_txbuf_dati <= _crc16_lsb;
				end else if (cntr == 129) begin
					// If I get here, I am done sending the 512 bytes data packet.
					// I send the first CRC16 byte for each data line.
					sddat_txbuf_dati <= _crc16_msb;
				end else if (cntr == 0) begin
					// The first byte to transmit on each data line must be 0xfe.
					sddat_txbuf_dati <= 32'hfffffff0;
				end else begin
					sddat_txbuf_dati <= _tx_data_i;
					// Note that when I get here, crccounter == 0.
					crcarg[0] <= __tx_data_i[0+:8];
					crcarg[1] <= __tx_data_i[8+:8];
					crcarg[2] <= __tx_data_i[16+:8];
					crcarg[3] <= __tx_data_i[24+:8];
					crccounter <= 8;
				end

				if (cntr != 133)
					cntr <= cntr + 1'b1;
				else if (sddat_rxbuf_dato_[7:0] != 'hff) begin
					// Setting the register cntr to null so that
					// the logic computing the CRC reset itself null.
					cntr <= 0;
					miscflag <= 0;
				end
			end

		end else if (sdcmd_rxbuf_dato != 'hff) begin
			// If I get here, I received the response first byte.
			if (sdcmd_rxbuf_dato[5:0] != 6'b011000)
				state <= ERROR;
			else begin
				sddat_txbuf_we <= 1;
				sddat_e <= 4'b1111;
				miscflag <= 1;
			end
		end

	end else if (state == PREPNXTCMD) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;

		// I wait that spi_master transmit all buffered data
		// in order to complete the previous transaction, and
		// start a new transaction.
		if (sdcmd_cs_w /*&& sddat_cs_w[0]*/) begin
			// I move onto the state which will send the next command to the card.
			state <= nxtstate;
			// The register cntr is set in such a way that
			// the transmit buffer be full with 0xff bytes before sending
			// each byte of the command; in fact keeping the buffer
			// full while sending each byte of the command is used
			// in order to have enough clock cycles to compute the CRC
			// for each byte transmitted.
			cntr <= (6 + SDIOBUFFERSIZE + 1);
		end

		// I stop writting in the transmit buffer since
		// I wish to wait that sdcmd.cs_o and sddat.cs_o become high.
		// I do so only after skipping all busy bytes.
		if (sdcmd_rxbuf_dato == 'hff)
			sdcmd_txbuf_we <= 0;
		//if (sddat_rxbuf_dato_[7:0] == 'hff)
		//	sddat_txbuf_we <= 0;

	end else if (state == PREPINIT) begin
		// When I come to this state I expect:
		// sdcmd_txbuf_we == 1;

		// When coming to this state, "sdcmd.cs_o" is certainly low,
		// since sdcmd_txbuf_we == 1 and data is being
		// written in the transmit buffer; I take advantage of that
		// to set "cntr" to the equivalent clock cycle count for 50ms
		// in order to wait for that long between checks of the card
		// busy state, and prevent too many unnecessary checks;
		// per the card spec, the card busy state should be polled
		// at less than 50ms intervals.
		if (sdcmd_cs_w) begin
			// After 50ms has elapsed, I move onto the state
			// which will send the init command to the card.
			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= SENDINIT;
				cntr <= (6 + SDIOBUFFERSIZE + 1);
			end
		end else
			cntr <= ((CLKFREQ/20)-1); // 50ms is 20Hz.

		// I stop writting in the transmit buffer since
		// I wish to wait that sdcmd.cs_o becomes high.
		// I do so only after skipping all busy bytes.
		if (sdcmd_rxbuf_dato == 'hff)
			sdcmd_txbuf_we <= 0;

	end else if (state == ERROR) begin
		// I get here, if an error occured.
		// Nothing gets done until reset.

		// I stop writing in the transmit buffer in order
		// to stop the sdio clock, which is power efficient.
		sdcmd_txbuf_we <= 0;
		sddat_txbuf_we <= 0;

	end else
		state <= ERROR;
end

endmodule

`endif /* SDCARD_SPI_PHY_V */
