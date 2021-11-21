// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef SDCARD_PHY_SPI_V
`define SDCARD_PHY_SPI_V

`ifdef SDCARD_PHY_RCVE_CMD
`include "lib/fifo_fwft.v"
`endif

`include "lib/spi/spi_master.v"

module sdcard_spi_phy (

	 rst_i

	,clk_i

`ifdef SDCARD_PHY_RCVE_CMD

	,cmd_push_i
	,cmd_data_i
	,cmdaddr_data_i
	,cmd_full_o

	,rx_pop_i
	,rx_data_o
	,rx_empty_o

	,tx_push_i
	,tx_data_i
	,tx_full_o

`else

	,cmd_pop_o
	,cmd_data_i
	,cmdaddr_data_i
	,cmd_empty_i

	,rx_push_o
	,rx_data_o
	,rx_full_i

	,tx_pop_o
	,tx_data_i
	,tx_empty_i

`endif

	,sclk_o
	,di_o
	,do_i
	,cs_o

	,blkcnt

	,err
);

`include "lib/clog2.v"

parameter CLKFREQ = 500000;

`ifdef SDCARD_PHY_RCVE_CMD
parameter CMDBUFDEPTH = 2;
`endif

localparam CLOG2CLKFREQ            = clog2(CLKFREQ);
localparam CLOG2CLKFREQBY200000000 = clog2(CLKFREQ/200000000);
localparam CLOG2CLKFREQBY100000000 = clog2(CLKFREQ/100000000);
localparam CLOG2CLKFREQBY50000000  = clog2(CLKFREQ/50000000);
localparam CLOG2CLKFREQBY25000000  = clog2(CLKFREQ/25000000);

input wire rst_i;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
`else
input wire [1 -1 : 0] clk_i;
`endif

localparam ADDRBITSZ = 32;

`ifdef SDCARD_PHY_RCVE_CMD

input  wire                    cmd_push_i;
input  wire                    cmd_data_i;
input  wire [ADDRBITSZ -1 : 0] cmdaddr_data_i;
output wire                    cmd_full_o;

input  wire            rx_pop_i;
output wire [8 -1 : 0] rx_data_o;
output wire            rx_empty_o;

input  wire            tx_push_i;
input  wire [8 -1 : 0] tx_data_i;
output wire            tx_full_o;

`else

output wire                    cmd_pop_o;
input  wire                    cmd_data_i;
input  wire [ADDRBITSZ -1 : 0] cmdaddr_data_i;
input  wire                    cmd_empty_i;

output wire            rx_push_o;
output wire [8 -1 : 0] rx_data_o;
input  wire            rx_full_i;

output wire            tx_pop_o;
input  wire [8 -1 : 0] tx_data_i;
input  wire            tx_empty_i;

`endif

output wire sclk_o;
output wire di_o;
input wire  do_i;
output wire cs_o;

output reg [ADDRBITSZ -1 : 0] blkcnt = 0;

output wire err;

reg [CLOG2CLKFREQ -1 : 0] timeout = 0;

localparam RESETTING = 0;
localparam READY     = 1;
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
localparam PREPCMD59 = 25;
localparam PREPCMD8  = 26;
localparam PREPINIT  = 27;
localparam PREPCMD41 = 28;
localparam PREPCMD9  = 29;
localparam PREPCMD58 = 30;
localparam PREPCMD16 = 31;
localparam PREPCMD13 = 32;
localparam PREPREADY = 33;
localparam ERROR     = 34;
localparam RESET     = 35;

localparam STATEBITSZ = clog2(64);

reg [STATEBITSZ -1 : 0] state = 0;

assign err = (state == ERROR);

wire spiss;

localparam SCLKDIVIDELIMIT = clog2(CLKFREQ/250000);
localparam CLOG2SCLKDIVIDELIMIT = clog2(SCLKDIVIDELIMIT);

reg [CLOG2SCLKDIVIDELIMIT -1 : 0] spisclkdivide = 0;

reg spitxbufferwriteenable = 0;

reg [8 -1 : 0] spitxbufferdatain = 0;

localparam SPIBUFFERSIZE = 2;
localparam CLOG2SPIBUFFERSIZE = clog2(SPIBUFFERSIZE);

wire spitxbufferfull;

reg spirxbufferreadenable = 0;

wire [8 -1 : 0] rx_data_w;

wire spirxbufferempty;

spi_master #(

	 .SCLKDIVIDELIMIT (SCLKDIVIDELIMIT)
	,.DATABITSIZE     (8)
	,.BUFFERSIZE      (SPIBUFFERSIZE)

) spi (
	 .rst_i (state == RESETTING)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_i)

	,.sclk (sclk_o)
	,.mosi (di_o)
	,.miso (do_i)
	,.ss   (spiss)

	,.sclkdivide (spisclkdivide)

	,.txbufferwriteenable (spitxbufferwriteenable)
	,.txbufferdatain      (spitxbufferdatain)
	,.txbufferfull        (spitxbufferfull)

	,.rxbufferreadenable (spirxbufferreadenable)
	,.rxbufferdataout    (rx_data_w)
	,.rxbufferempty      (spirxbufferempty)
);

reg keepsdcardcshigh = 0;

assign cs_o = (spiss | keepsdcardcshigh);

reg miscflag = 0;

reg issdcardver2 = 0;

reg issdcardmmc = 0;

reg issdcardaddrblockaligned = 0;

reg [8 -1 : 0] sdcardcsd [16 -1 : 0];
integer init_sdcardcsd_idx;
initial begin
	for (init_sdcardcsd_idx = 0; init_sdcardcsd_idx < 16; init_sdcardcsd_idx = init_sdcardcsd_idx + 1)
		sdcardcsd[init_sdcardcsd_idx] = 0;
end

always @ (posedge clk_i[0]) begin
	if (sdcardcsd[0][7:6] == 'b00) begin
		blkcnt <= ((
			(({sdcardcsd[6], sdcardcsd[7], sdcardcsd[8]} & 'h03ffc0) >> 6)
				+ 1) << (
					(({sdcardcsd[9], sdcardcsd[10]} & 'h0380) >> 7)
						+ 2 +
							(sdcardcsd[5] & 'h0f)
								)) >> 9;
	end else if (sdcardcsd[0][7:6] == 'b01) begin
		blkcnt <= (
			({sdcardcsd[7], sdcardcsd[8], sdcardcsd[9]} & 'h3fffff)
				+ 1) << 10;
	end else begin
		blkcnt <= 1;
	end
end

reg [CLOG2SCLKDIVIDELIMIT -1 : 0] safemaxspisclkdivide = 0;

always @ (posedge clk_i[0]) begin
	if (sdcardcsd[3] == 'h2b)
		safemaxspisclkdivide <= (CLOG2CLKFREQBY200000000 -1);
	else if (sdcardcsd[3] == 'h0b)
		safemaxspisclkdivide <= (CLOG2CLKFREQBY100000000 -1);
	else if (sdcardcsd[3] == 'h5a)
		safemaxspisclkdivide <= (CLOG2CLKFREQBY50000000 -1);
	else if (sdcardcsd[3] == 'h32)
		safemaxspisclkdivide <= (CLOG2CLKFREQBY25000000 -1);
	else
		safemaxspisclkdivide <= (SCLKDIVIDELIMIT -1'b1);
end

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

reg [CLOG2CLKFREQ -1 : 0] cntr = 0;

wire tx_pop_w  = ((state == CMD24RESP) && !spitxbufferfull && cntr && cntr <= 512);
wire rx_push_w = ((state == CMD17RESP) && !spirxbufferempty && cntr > 1 && cntr <= 513);

reg [7 -1 : 0] crc7 = 0;

reg [16 -1 : 0] crc16 = 0;

reg [8 -1 : 0] crcarg = 0;

localparam CRCCOUNTERBITSZ = clog2(8 + 1);

reg [CRCCOUNTERBITSZ -1 : 0] crccounter = 0;

wire crc7in = (crcarg[7] ^ crc7[6]);

wire crc16in = (crcarg[7] ^ crc16[15]);

wire cmd_pop_w = (state == READY);
wire cmd_data_w;
wire cmd_empty_w;

wire [ADDRBITSZ -1 : 0] cmdaddr_data_w;

wire [8 -1 : 0] tx_data_w;

wire rx_full_w;
wire tx_empty_w;

reg resetting = 1;

always @ (posedge clk_i[0]) begin

	if (crccounter) begin

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

		crcarg <= crcarg << 1'b1;

		crccounter <= crccounter - 1'b1;

	end else if (!cntr) begin

		crc7 <= 0;
		crc16 <= 0;
	end

	if (rst_i || state == RESET) begin

		resetting <= 1;

		miscflag <= 0;

		state <= RESETTING;

		cntr <= (CLKFREQ/4);

		spisclkdivide <= (SCLKDIVIDELIMIT -1'b1);

		keepsdcardcshigh <= 1;

		spitxbufferwriteenable <= 0;

	end else if (state == RESETTING) begin

		if (miscflag) begin

			if (cntr) begin
				if (!spitxbufferfull)
					cntr <= cntr - 1'b1;

			end else begin

				if (spiss) begin

					keepsdcardcshigh <= 0;

					state <= SENDCMD0;

					cntr <= (6 + SPIBUFFERSIZE + 2);
				end

				spitxbufferwriteenable <= 0;
			end

		end else begin

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin

				cntr <= 10;

				spitxbufferdatain <= 'hff;

				spitxbufferwriteenable <= 1;

				spirxbufferreadenable <= 1;

				miscflag <= 1;
			end
		end

	end else if (state == READY) begin

		if (!cmd_empty_w) begin
			cmdaddr <= cmdaddr_data_w;
			if (cmd_data_w) begin
				state <= SENDCMD24;
			end else begin
				state <= SENDCMD17;
			end
		end

		resetting <= 0;

	end else if (state == SENDCMD0) begin

		issdcardver2 <= 0;

		issdcardmmc <= 0;

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd0[cntr];

				if (cntr > 1) begin
					crcarg <= cmd0[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD0RESP;
			end
		end

	end else if (state == SENDCMD59) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd59[cntr];

				if (cntr > 1) begin
					crcarg <= cmd59[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD59RESP;
			end
		end

	end else if (state == SENDCMD8) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd8[cntr];

				if (cntr > 1) begin
					crcarg <= cmd8[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD8RESP;
			end
		end

	end else if (state == SENDINIT) begin

		if (!miscflag) begin

			state <= SENDCMD6;

		end else begin

			spitxbufferwriteenable <= 1;

			if (!spitxbufferfull) begin

				if (cntr <= 6) begin

					if (issdcardmmc) begin

						if (cntr == 1)
							spitxbufferdatain <= {crc7, 1'b1};
						else
							spitxbufferdatain <= cmd1[cntr];

						if (cntr > 1)
							crcarg <= cmd1[cntr];

					end else begin

						if (cntr == 1)
							spitxbufferdatain <= {crc7, 1'b1};
						else
							spitxbufferdatain <= cmd55[cntr];

						if (cntr > 1)
							crcarg <= cmd55[cntr];
					end

					if (cntr > 1)
						crccounter <= 8;
				end

				if (cntr)
					cntr <= cntr - 1'b1;
				else begin

					state <= INITRESP;

					if (!issdcardmmc)
						cntr[0] <= 1;
				end
			end
		end

	end else if (state == SENDCMD41) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (issdcardver2) begin

					if (cntr == 1)
						spitxbufferdatain <= {crc7, 1'b1};
					else
						spitxbufferdatain <= cmd41hcs[cntr];

					if (cntr > 1)
						crcarg <= cmd41hcs[cntr];

				end else begin

					if (cntr == 1)
						spitxbufferdatain <= {crc7, 1'b1};
					else
						spitxbufferdatain <= cmd41[cntr];

					if (cntr > 1)
						crcarg <= cmd41[cntr];
				end

				if (cntr > 1)
					crccounter <= 8;
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= INITRESP;
			end
		end

	end else if (state == SENDCMD6) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd6[cntr];

				if (cntr > 1) begin

					crcarg <= cmd6[cntr];

					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD6RESP;
			end
		end

	end else if (state == SENDCMD9) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd9[cntr];

				if (cntr > 1) begin
					crcarg <= cmd9[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD9RESP;
			end
		end

	end else if (state == SENDCMD58) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd58[cntr];

				if (cntr > 1) begin
					crcarg <= cmd58[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD58RESP;
			end
		end

	end else if (state == SENDCMD16) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd16[cntr];

				if (cntr > 1) begin
					crcarg <= cmd16[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD16RESP;
			end
		end

	end else if (state == SENDCMD17) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd17[cntr];

				if (cntr > 1) begin

					crcarg <= cmd17[cntr];

					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD17RESP;
			end
		end

	end else if (state == SENDCMD24) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd24[cntr];

				if (cntr > 1) begin
					crcarg <= cmd24[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD24RESP;
			end
		end

	end else if (state == SENDCMD13) begin

		spitxbufferwriteenable <= 1;

		if (!spitxbufferfull) begin

			if (cntr <= 6) begin

				if (cntr == 1)
					spitxbufferdatain <= {crc7, 1'b1};
				else
					spitxbufferdatain <= cmd13[cntr];

				if (cntr > 1) begin
					crcarg <= cmd13[cntr];
					crccounter <= 8;
				end
			end

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= CMD13RESP;
			end
		end

	end else if (state == CMD0RESP) begin

		if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= ERROR;
			else
				state <= PREPCMD59;
		end

	end else if (state == CMD59RESP) begin

		if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= ERROR;
			else
				state <= PREPCMD8;
		end

	end else if (state == CMD8RESP) begin

		if (issdcardver2) begin

			if (!spirxbufferempty) begin

				if (cntr == 3) begin
					if (rx_data_w[0] != 1)
						state <= ERROR;
				end else if (cntr == 4) begin

					if (rx_data_w != 'haa)
						state <= ERROR;
					else
						state <= PREPINIT;
				end

				cntr <= cntr + 1'b1;
			end

		end else if (rx_data_w != 'hff) begin

			issdcardver2 <= !rx_data_w[2];

			issdcardmmc <= 0;

			if (rx_data_w[2])
				state <= PREPINIT;
		end

	end else if (state == INITRESP) begin

		if (rx_data_w != 'hff) begin

			if (cntr[0]) begin

				if (rx_data_w[6:1])
					state <= ERROR;
				else
					state <= PREPCMD41;

			end else begin

				miscflag <= rx_data_w[0];

				if (!issdcardver2 && !issdcardmmc && rx_data_w[2]) begin
					issdcardmmc <= 1;
				end

				if (rx_data_w[6:1])
					state <= ERROR;
				else
					state <= PREPINIT;
			end
		end

	end else if (state == CMD6RESP) begin

		if (miscflag) begin

			if (!cntr) begin

				if (rx_data_w == 'hfe) begin
					cntr <= cntr + 1'b1;
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else
					state <= ERROR;

			end else begin

				if (!spirxbufferempty) begin

					if (cntr >= 66) begin
						state <= PREPCMD9;
					end

					cntr <= cntr + 1'b1;
				end
			end

		end else if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= PREPCMD9;
			else begin
				miscflag <= 1;
				timeout <= -1;
			end
		end

	end else if (state == CMD9RESP) begin

		if (!miscflag) begin

			if (!cntr) begin

				if (rx_data_w == 'hfe) begin
					cntr <= cntr + 1'b1;
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else state <= ERROR;

			end else begin

				if (!spirxbufferempty) begin

					if (cntr == 19) begin

						if (rx_data_w != crc16[7:0])
							state <= ERROR;
						else begin
							spisclkdivide <= safemaxspisclkdivide;
							state <= PREPCMD58;
						end

					end else if (cntr == 18) begin

						if (rx_data_w != crc16[15:8]) state <= ERROR;

					end else if (cntr > 1) begin

						sdcardcsd[cntr -2] <= rx_data_w;

						crcarg <= rx_data_w;

						crccounter <= 8;

					end

					if (cntr != 19)
						cntr <= cntr + 1'b1;
					else begin
						cntr <= 0;
					end
				end
			end

		end else if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= ERROR;
			else begin
				miscflag <= 0;
				timeout <= -1;
			end
		end

	end else if (state == CMD58RESP) begin

		if (miscflag) begin

			if (!spirxbufferempty) begin

				if (cntr == 1) begin
					issdcardaddrblockaligned <= |(rx_data_w & 'h40);
				end else if (cntr == 4) begin
					state <= PREPCMD16;
				end

				cntr <= cntr + 1'b1;
			end

		end else if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= ERROR;
			else
				miscflag <= 1;
		end

	end else if (state == CMD16RESP) begin

		if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= ERROR;
			else
				state <= PREPREADY;
		end

	end else if (state == CMD17RESP) begin

		if (!miscflag) begin

			if (!cntr) begin

				if (rx_data_w == 'hfe) begin
					cntr <= cntr + 1'b1;
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else
					state <= ERROR;

			end else begin

				if (!spirxbufferempty) begin

					if (cntr == 515) begin

						if (rx_data_w != crc16[7:0]) state <= ERROR;
						else begin
							state <= PREPREADY;
						end

					end else if (cntr == 514) begin

						if (rx_data_w != crc16[15:8]) state <= ERROR;

					end else if (cntr > 1) begin
						crcarg <= rx_data_w;
						crccounter <= 8;
					end

					if (cntr != 515)
						cntr <= cntr + 1'b1;
					else begin
						cntr <= 0;
					end
				end
			end

		end else if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= ERROR;
			else begin
				miscflag <= 0;
				timeout <= -1;
			end
		end

	end else if (state == CMD24RESP) begin

		if (!miscflag) begin

			if (cntr == 516) begin

				if (rx_data_w != 'hff) begin

					if ((rx_data_w[3:1]) == 'b010) begin
						state <= PREPCMD13;
					end else state <= ERROR;

					cntr <= 0;
				end

			end else begin

				if (!spitxbufferfull) begin

					if (cntr) begin

						if (cntr == 515)
							spitxbufferdatain <= 'hff;
						else if (cntr == 514)
							spitxbufferdatain <= crc16[7:0];
						else if (cntr == 513)
							spitxbufferdatain <= crc16[15:8];
						else begin
							spitxbufferdatain <= tx_data_w;
							crcarg <= tx_data_w;
							crccounter <= 8;
						end

					end else begin
						spitxbufferdatain <= 'hfe;
					end

					cntr <= cntr + 1'b1;
				end
			end

		end else if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= ERROR;
			else
				miscflag <= 0;
		end

	end else if (state == CMD13RESP) begin

		if (miscflag) begin

			if (!spirxbufferempty) begin

				if (cntr == 1) begin

					if (rx_data_w)
						state <= ERROR;
					else
						state <= PREPREADY;
				end

				cntr <= cntr + 1'b1;
			end

		end else if (rx_data_w != 'hff) begin

			if (rx_data_w[6:1])
				state <= ERROR;
			else
				miscflag <= 1;
		end

	end else if (state == PREPCMD59) begin

		if (spiss) begin
			state <= SENDCMD59;
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD8) begin

		if (spiss) begin
			state <= SENDCMD8;
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		spitxbufferwriteenable <= 0;

	end else if (state == PREPINIT) begin

		if (spiss) begin

			if (cntr)
				cntr <= cntr - 1'b1;
			else begin
				state <= SENDINIT;
				cntr <= (6 + SPIBUFFERSIZE + 2);
			end

		end else
			cntr <= (CLKFREQ/20) -1;

		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD41) begin

		if (spiss) begin
			state <= SENDCMD41;
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD9) begin

		if (spiss) begin
			state <= SENDCMD9;
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD58) begin

		if (spiss) begin
			state <= SENDCMD58;
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD16) begin

		if (spiss) begin
			state <= SENDCMD16;
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		spitxbufferwriteenable <= 0;

	end else if (state == PREPCMD13) begin

		if (spiss) begin
			state <= SENDCMD13;
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		if (rx_data_w == 'hff) spitxbufferwriteenable <= 0;

	end else if (state == PREPREADY) begin

		miscflag <= 1;

		if (spiss) begin
			state <= READY;
			cntr <= (6 + SPIBUFFERSIZE + 2);
		end

		spitxbufferwriteenable <= 0;

	end else if (state == ERROR) begin

		spitxbufferwriteenable <= 0;

		if (resetting)
			state <= RESET;

	end else
		state <= ERROR;
end

`ifdef SDCARD_PHY_RCVE_CMD

fifo_fwft #(

	 .WIDTH (1)
	,.DEPTH (CMDBUFDEPTH)

) cmdbuf (

	 .rst_i (cmd_rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (cmd_pop_w)
	,.data_o    (cmd_data_w)
	,.empty_o   (cmd_empty_w)

	,.clk_push_i (clk_i)
	,.push_i     (cmd_push_i)
	,.data_i     (cmd_data_i)
	,.full_o     (cmd_full_o)
);

fifo_fwft #(

	 .WIDTH (ADDRBITSZ)
	,.DEPTH (CMDBUFDEPTH)

) cmdaddrbuf (

	 .rst_i (cmd_rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (cmd_pop_w)
	,.data_o    (cmdaddr_data_w)
	,.empty_o   (cmd_empty_w)

	,.clk_push_i (clk_i)
	,.push_i     (cmd_push_i)
	,.data_i     (cmdaddr_data_i)
	,.full_o     (cmd_full_o)
);

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (512*CMDBUFDEPTH)

) rx (

	 .rst_i (rx_rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (rx_pop_i)
	,.data_o    (rx_data_o)
	,.empty_o   (rx_empty_o)

	,.clk_push_i (clk_i)
	,.push_i     (rx_push_w)
	,.data_i     (rx_data_w)
	,.full_o     (rx_full_w)
);

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (512*CMDBUFDEPTH)

) tx (

	 .rst_i (tx_rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (tx_pop_w)
	,.data_o    (tx_data_w)
	,.empty_o   (tx_empty_w)

	,.clk_push_i (clk_i)
	,.push_i     (tx_push_i)
	,.data_i     (tx_data_i)
	,.full_o     (tx_full_o)
);

`else

assign cmd_pop_o      = cmd_pop_w;
assign cmd_data_w     = cmd_data_i;
assign cmdaddr_data_w = cmdaddr_data_i;
assign cmd_empty_w    = cmd_empty_i;

assign rx_push_o = rx_push_w;
assign rx_data_o = rx_data_w;
assign rx_full_w = rx_full_i;

assign tx_pop_o   = tx_pop_w;
assign tx_data_w  = tx_data_i;
assign tx_empty_w = tx_empty_i;

`endif

endmodule

`endif
