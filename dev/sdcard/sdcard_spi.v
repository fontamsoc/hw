// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// SDCard peripheral.
//
// This device transfers data in blocks where the block size can be
// computed from wb_mapsz_o which reports the size in bytes of the memory
// mapping used by the device.
// The first half of the mapping is a read/write RAM cache for the
// data to be transfered to/from the device.
// The second half of the mapping has read/write registers used to
// send commands to the device.
// The registers and their offsets within the second half of the mapping are:
// - RESET: 0*(ARCHBITSZ/8): Reading this register returns current status.
// 	A controller reset is initiated when writing any value to this register,
// 	and an interrupt is raised once the reset is complete.
// 	The status value returned can be:
// 	0: PowerOff.
// 	1: Ready.
// 	2: Busy.
// 	3: Error.
// 	Note that there is no reporting of timeout, as it is best implemented
// 	in software by timing how long the device has been busy.
// - SWAP: 1*(ARCHBITSZ/8): Reading this register returns PHYBLKSZ.
// 	Writing this register implements double caching whereby the RAM cache
// 	presented in the first half of the memory mapping is swapped so that
// 	the controller can now have access to it and so that its content can
// 	be stored in the device when the command WRITE is issued, or so that
// 	it can be loaded with a block of data from the device when the command
// 	READ is issued; after the swapping, the RAM cache now presented in the
// 	first half of the memory mapping, and which was previously used by the
// 	controller, can now be accessed.
// 	Hence, it is possible to do things such as preparing the next block
// 	of data to store in the device while simultaneously, a block of data
// 	is being stored in the device.
// 	Writing this register must be done when the controller status is ready,
// 	otherwise silent faillures and undefined behaviors will occur.
// - READ: 2*(ARCHBITSZ/8): Reading this register returns the total block
// 	count of the device.
// 	Writing this register read a block of data from the block address written.
// 	An interrupt is raised once reading the data block from the device is complete.
// 	Writing this register must be done when the controller status is ready,
// 	otherwise silent faillures and undefined behaviors will occur.
// - WRITE: 3*(ARCHBITSZ/8): Reading this register returns the total block
// 	count of the device.
// 	Writing this register write a block of data to the block address written.
// 	An interrupt is raised once writing the data block to the device is complete.
// 	Writing this register must be done when the controller status is ready,
// 	otherwise silent faillures and undefined behaviors will occur.
//
// Copying blocks between locations within the device can be done by issuing
// commands READ and WRITE without ever issuing the command SWAP.

// Parameters:
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_phy_i" in Hz.
// 	It should be at least 500KHz in order to provide
// 	at least 250KHz required by the device.
//
// SRCFILE
// 	File from which memory will be initialized using $readmemh().
// 	Used only when `SIMULATION was defined.
//
// SIMSTORAGESZ
// 	Size in PHYBLKSZ of the storage to be initialized using $readmemh().
// 	Used only when `SIMULATION was defined.

// Ports:
//
// rst_i
// 	This input reset this module when held high
// 	and must be held low for normal operation.
// 	This input is also to be used to report
// 	whether the device driven by the controller
// 	is powered off; hence this input is to be
// 	held high for as long as that device is in
// 	a poweroff state.
//
// clk_i
// 	Clock signal used by the memory interface.
//
// clk_phy_i
// 	Clock signal used by the PHY.
//
// sclk_o
// di_o
// do_i
// cs_o
// 	SPI interface to the card.
//
// wb_cyc_i
// wb_stb_i
// wb_we_i
// wb_addr_i
// wb_sel_i
// wb_dat_i
// wb_bsy_o
// wb_ack_o
// wb_dat_o
// 	Slave memory interface.
//
// wb_mapsz_o
// 	Memory map size in bytes.
//
// irq_stb_o
// 	This signal is set high to request an interrupt;
// 	an interrupt is raised, when either of the following
// 	events from the controller occurs:
// 	- Done resetting; also occur on poweron.
// 	- Done reading.
// 	- Done writing.
// 	- Error.
// 	- Poweroff.
//
// irq_rdy_i
// 	This signal become low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to automatically lower irq_stb_o.

`ifdef SIMULATION
`include "./sdcard_sim_phy.v"
`else
`include "./sdcard_spi_phy.v"
`endif

`include "lib/addr.v"

module sdcard_spi (

	 rst_i

	,clk_i
	,clk_phy_i

`ifndef SIMULATION
	,sclk_o
	,di_o
	,do_i
	,cs_o
`endif

	,wb_cyc_i
	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o
	,wb_mapsz_o

	,irq_stb_o
	,irq_rdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;
parameter XARCHBITSZ = 16;

parameter CLKFREQ = 1;
parameter PHYCLKFREQ = 1;
`ifdef SIMULATION
parameter SRCFILE = "";
parameter SIMSTORAGESZ = 4096;
`endif

// Size in bytes of each of the two caches used to implement double caching
// which allows the controller to read/write from/to the device, while in parallel,
// the next block of data to transfer is being prepared.
// CMDSWAP is used to swap between the cache used by the controller
// and the cache mapped in memory.
// Note also that the value of this macro is the block size used by the controller.
localparam PHYBLKSZ = 512; // ### Must not change for SDCard.

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);
localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ - CLOG2ARCHBITSZBY8);

localparam CLOG2XARCHBITSZBY8 = clog2(XARCHBITSZ/8);
localparam XADDRBITSZ = (XARCHBITSZ-CLOG2XARCHBITSZBY8);

localparam CLOG2XARCHBITSZBY8DIFF = (CLOG2XARCHBITSZBY8 - CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

`ifndef SIMULATION
output wire sclk_o;
output wire di_o;
input  wire do_i;
output wire cs_o;
`endif

input  wire                         wb_cyc_i;
input  wire                         wb_stb_i;
input  wire                         wb_we_i;
input  wire [XADDRBITSZ -1 : 0]     wb_addr_i;
input  wire [(XARCHBITSZ/8) -1 : 0] wb_sel_i;
input  wire [XARCHBITSZ -1 : 0]     wb_dat_i;
output wire                         wb_bsy_o;
output reg                          wb_ack_o;
output reg  [XARCHBITSZ -1 : 0]     wb_dat_o;
output wire [ARCHBITSZ -1 : 0]      wb_mapsz_o;

output reg  irq_stb_o;
input  wire irq_rdy_i;

assign wb_bsy_o = 1'b0;

assign wb_mapsz_o = PHYBLKSZ*2;

localparam CLOG2PHYBLKSZ = clog2(PHYBLKSZ);

// Commands.
localparam CMDRESET = 0;
localparam CMDSWAP  = 1;
localparam CMDREAD  = 2;
localparam CMDWRITE = 3;

// Status.
localparam STATUSPOWEROFF = 0;
localparam STATUSREADY    = 1;
localparam STATUSBUSY     = 2;
localparam STATUSERROR    = 3;

reg                         wb_stb_r;
reg                         wb_we_r;
reg [XADDRBITSZ -1 : 0]     wb_addr_r;
reg [(XARCHBITSZ/8) -1 : 0] wb_sel_r;
reg [XARCHBITSZ -1 : 0]     wb_dat_r;

wire [XARCHBITSZ -1 : 0] _wb_addr_r;
addr #(
	.ARCHBITSZ (XARCHBITSZ)
) addr (
	 .addr_i (wb_addr_r)
	,.sel_i  (wb_sel_r)
	,.addr_o (_wb_addr_r)
);
wire [ADDRBITSZ -1 : 0] addr_w = _wb_addr_r[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];

wire cmd_reset = (addr_w == ((CMDRESET * (ARCHBITSZ/8) + PHYBLKSZ) >> CLOG2ARCHBITSZBY8));
wire cmd_swap  = (addr_w == ((CMDSWAP  * (ARCHBITSZ/8) + PHYBLKSZ) >> CLOG2ARCHBITSZBY8));
wire cmd_read  = (addr_w == ((CMDREAD  * (ARCHBITSZ/8) + PHYBLKSZ) >> CLOG2ARCHBITSZBY8));
wire cmd_write = (addr_w == ((CMDWRITE * (ARCHBITSZ/8) + PHYBLKSZ) >> CLOG2ARCHBITSZBY8));

wire phy_tx_pop_o, phy_rx_push_o;

wire [8 -1 : 0] phy_rx_data_o;
reg  [8 -1 : 0] phy_tx_data_i; // ### comb-block-reg.

reg phy_cmd_data_i;

reg [XADDRBITSZ -1 : 0] phy_cmd_addr_i;

wire [XADDRBITSZ -1 : 0] phy_blkcnt_o;

wire phy_err_o;

// A phy reset is done when "rst_i" is high or when CMDRESET is issued.
// Since "rst_i" is also used to signal whether the device is under power,
// a controller reset will be done as soon as the device is powered-on.
wire phy_rst_w = (rst_i || (wb_stb_r && wb_we_r && cmd_reset && !phy_err_o));

reg phy_cmd_empty_i;

wire phy_cmd_pop_o;

wire phy_bsy_w = (phy_cmd_empty_i || !phy_cmd_pop_o);

`ifdef SIMULATION
sdcard_sim_phy
`else
sdcard_spi_phy
`endif
#(
	`ifndef SIMULATION
	 .CLKFREQ    (CLKFREQ)
	,.PHYCLKFREQ (PHYCLKFREQ)
	`else
	 .SRCFILE      (SRCFILE)
	,.SIMSTORAGESZ (SIMSTORAGESZ)
	`endif
) phy (

	 .rst_i (phy_rst_w)

	,.clk_i (clk_i)

`ifndef SIMULATION
	,.clk_phy_i (clk_phy_i)

	,.sclk_o (sclk_o)
	,.di_o   (di_o)
	,.do_i   (do_i)
	,.cs_o   (cs_o)
`endif

	,.cmd_pop_o   (phy_cmd_pop_o)
	,.cmd_data_i  (phy_cmd_data_i)
	,.cmd_addr_i  (phy_cmd_addr_i)
	,.cmd_empty_i (!phy_cmd_empty_i)

	,.rx_push_o (phy_rx_push_o)
	,.rx_data_o (phy_rx_data_o)
	,.rx_full_i (/* not needed */)

	,.tx_pop_o   (phy_tx_pop_o)
	,.tx_data_i  (phy_tx_data_i)
	,.tx_empty_i (/* not needed */)

	,.blkcnt_o (phy_blkcnt_o)

	,.err_o (phy_err_o)
);

// When the value of this register is 1, "phy" has
// access to cache1 otherwise it has access to cache0.
// The cache not being accessed by "phy" is accessed
// by the memory interface.
reg cachesel;

// Register keeping track of the cache byte location the PHY will access next.
reg [CLOG2PHYBLKSZ -1 : 0] cachephyaddr;

// Nets set to the index within the respective cache. Each cache element is XARCHBITSZ bits.
wire [(CLOG2PHYBLKSZ-CLOG2XARCHBITSZBY8) -1 : 0] cache0addr =
	cachesel ? wb_addr_r : cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2XARCHBITSZBY8];
wire [(CLOG2PHYBLKSZ-CLOG2XARCHBITSZBY8) -1 : 0] cache1addr =
	cachesel ? cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2XARCHBITSZBY8] : wb_addr_r;

wire [XARCHBITSZ -1 : 0] cache0dato;
wire [XARCHBITSZ -1 : 0] cache1dato;

wire [XARCHBITSZ -1 : 0] cachephydata = cachesel ? cache1dato : cache0dato;

// Net set to the value from the PHY to store in the cache.
reg [XARCHBITSZ -1 : 0] phy_rx_data_o_byteselected; // ### comb-always-block-reg.
generate if (XARCHBITSZ == 16) begin
	always @* begin
		phy_rx_data_o_byteselected =
			(cachephyaddr[0] == 0) ? {cachephydata[15:8], phy_rx_data_o} :
			                         {phy_rx_data_o, cachephydata[7:0]};
	end
end endgenerate
generate if (XARCHBITSZ == 32) begin
	always @* begin
		phy_rx_data_o_byteselected =
			(cachephyaddr[1:0] == 0) ? {cachephydata[31:8],  phy_rx_data_o} :
			(cachephyaddr[1:0] == 1) ? {cachephydata[31:16], phy_rx_data_o, cachephydata[7:0]} :
			(cachephyaddr[1:0] == 2) ? {cachephydata[31:24], phy_rx_data_o, cachephydata[15:0]} :
			                           {                     phy_rx_data_o, cachephydata[23:0]};
	end
end endgenerate
generate if (XARCHBITSZ == 64) begin
	always @* begin
		phy_rx_data_o_byteselected =
			(cachephyaddr[2:0] == 0) ? {cachephydata[63:8],  phy_rx_data_o} :
			(cachephyaddr[2:0] == 1) ? {cachephydata[63:16], phy_rx_data_o, cachephydata[7:0]} :
			(cachephyaddr[2:0] == 2) ? {cachephydata[63:24], phy_rx_data_o, cachephydata[15:0]} :
			(cachephyaddr[2:0] == 3) ? {cachephydata[63:32], phy_rx_data_o, cachephydata[23:0]} :
			(cachephyaddr[2:0] == 4) ? {cachephydata[63:40], phy_rx_data_o, cachephydata[31:0]} :
			(cachephyaddr[2:0] == 5) ? {cachephydata[63:48], phy_rx_data_o, cachephydata[39:0]} :
			(cachephyaddr[2:0] == 6) ? {cachephydata[63:56], phy_rx_data_o, cachephydata[47:0]} :
			                           {                     phy_rx_data_o, cachephydata[55:0]};
	end
end endgenerate
generate if (XARCHBITSZ == 128) begin
	always @* begin
		phy_rx_data_o_byteselected =
			(cachephyaddr[3:0] == 0)  ? {cachephydata[127:8],   phy_rx_data_o} :
			(cachephyaddr[3:0] == 1)  ? {cachephydata[127:16],  phy_rx_data_o, cachephydata[7:0]} :
			(cachephyaddr[3:0] == 2)  ? {cachephydata[127:24],  phy_rx_data_o, cachephydata[15:0]} :
			(cachephyaddr[3:0] == 3)  ? {cachephydata[127:32],  phy_rx_data_o, cachephydata[23:0]} :
			(cachephyaddr[3:0] == 4)  ? {cachephydata[127:40],  phy_rx_data_o, cachephydata[31:0]} :
			(cachephyaddr[3:0] == 5)  ? {cachephydata[127:48],  phy_rx_data_o, cachephydata[39:0]} :
			(cachephyaddr[3:0] == 6)  ? {cachephydata[127:56],  phy_rx_data_o, cachephydata[47:0]} :
			(cachephyaddr[3:0] == 7)  ? {cachephydata[127:64],  phy_rx_data_o, cachephydata[55:0]} :
			(cachephyaddr[3:0] == 8)  ? {cachephydata[127:72],  phy_rx_data_o, cachephydata[63:0]} :
			(cachephyaddr[3:0] == 9)  ? {cachephydata[127:80],  phy_rx_data_o, cachephydata[71:0]} :
			(cachephyaddr[3:0] == 10) ? {cachephydata[127:88],  phy_rx_data_o, cachephydata[79:0]} :
			(cachephyaddr[3:0] == 11) ? {cachephydata[127:96],  phy_rx_data_o, cachephydata[87:0]} :
			(cachephyaddr[3:0] == 12) ? {cachephydata[127:104], phy_rx_data_o, cachephydata[95:0]} :
			(cachephyaddr[3:0] == 13) ? {cachephydata[127:112], phy_rx_data_o, cachephydata[103:0]} :
			(cachephyaddr[3:0] == 14) ? {cachephydata[127:120], phy_rx_data_o, cachephydata[111:0]} :
			                            {                       phy_rx_data_o, cachephydata[119:0]};
	end
end endgenerate
generate if (XARCHBITSZ == 256) begin
	always @* begin
		phy_rx_data_o_byteselected =
			(cachephyaddr[4:0] == 0) ? {cachephydata[255:8],    phy_rx_data_o} :
			(cachephyaddr[4:0] == 1) ? {cachephydata[255:16],   phy_rx_data_o, cachephydata[7:0]} :
			(cachephyaddr[4:0] == 2) ? {cachephydata[255:24],   phy_rx_data_o, cachephydata[15:0]} :
			(cachephyaddr[4:0] == 3) ? {cachephydata[255:32],   phy_rx_data_o, cachephydata[23:0]} :
			(cachephyaddr[4:0] == 4) ? {cachephydata[255:40],   phy_rx_data_o, cachephydata[31:0]} :
			(cachephyaddr[4:0] == 5) ? {cachephydata[255:48],   phy_rx_data_o, cachephydata[39:0]} :
			(cachephyaddr[4:0] == 6) ? {cachephydata[255:56],   phy_rx_data_o, cachephydata[47:0]} :
			(cachephyaddr[4:0] == 7) ? {cachephydata[255:64],   phy_rx_data_o, cachephydata[55:0]} :
			(cachephyaddr[4:0] == 8) ? {cachephydata[255:72],   phy_rx_data_o, cachephydata[63:0]} :
			(cachephyaddr[4:0] == 9) ? {cachephydata[255:80],   phy_rx_data_o, cachephydata[71:0]} :
			(cachephyaddr[4:0] == 10) ? {cachephydata[255:88],  phy_rx_data_o, cachephydata[79:0]} :
			(cachephyaddr[4:0] == 11) ? {cachephydata[255:96],  phy_rx_data_o, cachephydata[87:0]} :
			(cachephyaddr[4:0] == 12) ? {cachephydata[255:104], phy_rx_data_o, cachephydata[95:0]} :
			(cachephyaddr[4:0] == 13) ? {cachephydata[255:112], phy_rx_data_o, cachephydata[103:0]} :
			(cachephyaddr[4:0] == 14) ? {cachephydata[255:120], phy_rx_data_o, cachephydata[111:0]} :
			(cachephyaddr[4:0] == 15) ? {cachephydata[255:128], phy_rx_data_o, cachephydata[119:0]} :
			(cachephyaddr[4:0] == 16) ? {cachephydata[255:136], phy_rx_data_o, cachephydata[127:0]} :
			(cachephyaddr[4:0] == 17) ? {cachephydata[255:144], phy_rx_data_o, cachephydata[135:0]} :
			(cachephyaddr[4:0] == 18) ? {cachephydata[255:152], phy_rx_data_o, cachephydata[143:0]} :
			(cachephyaddr[4:0] == 19) ? {cachephydata[255:160], phy_rx_data_o, cachephydata[151:0]} :
			(cachephyaddr[4:0] == 20) ? {cachephydata[255:168], phy_rx_data_o, cachephydata[159:0]} :
			(cachephyaddr[4:0] == 21) ? {cachephydata[255:176], phy_rx_data_o, cachephydata[167:0]} :
			(cachephyaddr[4:0] == 22) ? {cachephydata[255:184], phy_rx_data_o, cachephydata[175:0]} :
			(cachephyaddr[4:0] == 23) ? {cachephydata[255:192], phy_rx_data_o, cachephydata[183:0]} :
			(cachephyaddr[4:0] == 24) ? {cachephydata[255:200], phy_rx_data_o, cachephydata[191:0]} :
			(cachephyaddr[4:0] == 25) ? {cachephydata[255:208], phy_rx_data_o, cachephydata[199:0]} :
			(cachephyaddr[4:0] == 26) ? {cachephydata[255:216], phy_rx_data_o, cachephydata[207:0]} :
			(cachephyaddr[4:0] == 27) ? {cachephydata[255:224], phy_rx_data_o, cachephydata[215:0]} :
			(cachephyaddr[4:0] == 28) ? {cachephydata[255:232], phy_rx_data_o, cachephydata[223:0]} :
			(cachephyaddr[4:0] == 29) ? {cachephydata[255:240], phy_rx_data_o, cachephydata[231:0]} :
			(cachephyaddr[4:0] == 30) ? {cachephydata[255:248], phy_rx_data_o, cachephydata[239:0]} :
			                            {                       phy_rx_data_o, cachephydata[247:0]};
	end
end endgenerate

reg [XARCHBITSZ -1 : 0] _wb_sel_r; // ### comb-always-block-reg.
generate if (XARCHBITSZ == 16) begin
	always @* begin
		_wb_sel_r = {{8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
	end
end endgenerate
generate if (XARCHBITSZ == 32) begin
	always @* begin
		_wb_sel_r = {{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
	end
end endgenerate
generate if (XARCHBITSZ == 64) begin
	always @* begin
		_wb_sel_r = {
			{8{wb_sel_r[7]}}, {8{wb_sel_r[6]}}, {8{wb_sel_r[5]}}, {8{wb_sel_r[4]}},
			{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
	end
end endgenerate
generate if (XARCHBITSZ == 128) begin
	always @* begin
		_wb_sel_r = {
			{8{wb_sel_r[15]}}, {8{wb_sel_r[14]}}, {8{wb_sel_r[13]}}, {8{wb_sel_r[12]}},
			{8{wb_sel_r[11]}}, {8{wb_sel_r[10]}}, {8{wb_sel_r[9]}},  {8{wb_sel_r[8]}},
			{8{wb_sel_r[7]}},  {8{wb_sel_r[6]}},  {8{wb_sel_r[5]}},  {8{wb_sel_r[4]}},
			{8{wb_sel_r[3]}},  {8{wb_sel_r[2]}},  {8{wb_sel_r[1]}},  {8{wb_sel_r[0]}}};
	end
end endgenerate
generate if (XARCHBITSZ == 256) begin
	always @* begin
		_wb_sel_r = {
			{8{wb_sel_r[31]}}, {8{wb_sel_r[30]}}, {8{wb_sel_r[29]}}, {8{wb_sel_r[28]}},
			{8{wb_sel_r[27]}}, {8{wb_sel_r[26]}}, {8{wb_sel_r[25]}}, {8{wb_sel_r[24]}},
			{8{wb_sel_r[23]}}, {8{wb_sel_r[22]}}, {8{wb_sel_r[21]}}, {8{wb_sel_r[20]}},
			{8{wb_sel_r[19]}}, {8{wb_sel_r[18]}}, {8{wb_sel_r[17]}}, {8{wb_sel_r[16]}},
			{8{wb_sel_r[15]}}, {8{wb_sel_r[14]}}, {8{wb_sel_r[13]}}, {8{wb_sel_r[12]}},
			{8{wb_sel_r[11]}}, {8{wb_sel_r[10]}}, {8{wb_sel_r[9]}},  {8{wb_sel_r[8]}},
			{8{wb_sel_r[7]}},  {8{wb_sel_r[6]}},  {8{wb_sel_r[5]}},  {8{wb_sel_r[4]}},
			{8{wb_sel_r[3]}},  {8{wb_sel_r[2]}},  {8{wb_sel_r[1]}},  {8{wb_sel_r[0]}}};
	end
end endgenerate

wire [XARCHBITSZ -1 : 0] _wb_dat_r = ((wb_dat_r & _wb_sel_r) | (wb_dat_o & ~_wb_sel_r));
// Nets set to the value to write in the respective cache.
wire [XARCHBITSZ -1 : 0] cache0dati = cachesel ? _wb_dat_r : phy_rx_data_o_byteselected[XARCHBITSZ -1 : 0];
wire [XARCHBITSZ -1 : 0] cache1dati = cachesel ? phy_rx_data_o_byteselected[XARCHBITSZ -1 : 0] : _wb_dat_r;

// phy_tx_data_i is set to the value read from the respective cache.
generate if (XARCHBITSZ == 16) begin
	always @* begin
		if (cachephyaddr[0] == 0)
			phy_tx_data_i = cachesel ? cache1dato[7:0] : cache0dato[7:0];
		else
			phy_tx_data_i = cachesel ? cache1dato[15:8] : cache0dato[15:8];
	end
end endgenerate
generate if (XARCHBITSZ == 32) begin
	always @* begin
		if (cachephyaddr[1:0] == 0)
			phy_tx_data_i = cachesel ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[1:0] == 1)
			phy_tx_data_i = cachesel ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[1:0] == 2)
			phy_tx_data_i = cachesel ? cache1dato[23:16] : cache0dato[23:16];
		else
			phy_tx_data_i = cachesel ? cache1dato[31:24] : cache0dato[31:24];
	end
end endgenerate
generate if (XARCHBITSZ == 64) begin
	always @* begin
		if (cachephyaddr[2:0] == 0)
			phy_tx_data_i = cachesel ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[2:0] == 1)
			phy_tx_data_i = cachesel ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[2:0] == 2)
			phy_tx_data_i = cachesel ? cache1dato[23:16] : cache0dato[23:16];
		else if (cachephyaddr[2:0] == 3)
			phy_tx_data_i = cachesel ? cache1dato[31:24] : cache0dato[31:24];
		else if (cachephyaddr[2:0] == 4)
			phy_tx_data_i = cachesel ? cache1dato[39:32] : cache0dato[39:32];
		else if (cachephyaddr[2:0] == 5)
			phy_tx_data_i = cachesel ? cache1dato[47:40] : cache0dato[47:40];
		else if (cachephyaddr[2:0] == 6)
			phy_tx_data_i = cachesel ? cache1dato[55:48] : cache0dato[55:48];
		else
			phy_tx_data_i = cachesel ? cache1dato[63:56] : cache0dato[63:56];
	end
end endgenerate
generate if (XARCHBITSZ == 128) begin
	always @* begin
		if (cachephyaddr[3:0] == 0)
			phy_tx_data_i = cachesel ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[3:0] == 1)
			phy_tx_data_i = cachesel ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[3:0] == 2)
			phy_tx_data_i = cachesel ? cache1dato[23:16] : cache0dato[23:16];
		else if (cachephyaddr[3:0] == 3)
			phy_tx_data_i = cachesel ? cache1dato[31:24] : cache0dato[31:24];
		else if (cachephyaddr[3:0] == 4)
			phy_tx_data_i = cachesel ? cache1dato[39:32] : cache0dato[39:32];
		else if (cachephyaddr[3:0] == 5)
			phy_tx_data_i = cachesel ? cache1dato[47:40] : cache0dato[47:40];
		else if (cachephyaddr[3:0] == 6)
			phy_tx_data_i = cachesel ? cache1dato[55:48] : cache0dato[55:48];
		else if (cachephyaddr[3:0] == 7)
			phy_tx_data_i = cachesel ? cache1dato[63:56] : cache0dato[63:56];
		else if (cachephyaddr[3:0] == 8)
			phy_tx_data_i = cachesel ? cache1dato[71:64] : cache0dato[71:64];
		else if (cachephyaddr[3:0] == 9)
			phy_tx_data_i = cachesel ? cache1dato[79:72] : cache0dato[79:72];
		else if (cachephyaddr[3:0] == 10)
			phy_tx_data_i = cachesel ? cache1dato[87:80] : cache0dato[87:80];
		else if (cachephyaddr[3:0] == 11)
			phy_tx_data_i = cachesel ? cache1dato[95:88] : cache0dato[95:88];
		else if (cachephyaddr[3:0] == 12)
			phy_tx_data_i = cachesel ? cache1dato[103:96] : cache0dato[103:96];
		else if (cachephyaddr[3:0] == 13)
			phy_tx_data_i = cachesel ? cache1dato[111:104] : cache0dato[111:104];
		else if (cachephyaddr[3:0] == 14)
			phy_tx_data_i = cachesel ? cache1dato[119:112] : cache0dato[119:112];
		else
			phy_tx_data_i = cachesel ? cache1dato[127:120] : cache0dato[127:120];
	end
end endgenerate
generate if (XARCHBITSZ == 256) begin
	always @* begin
		if (cachephyaddr[4:0] == 0)
			phy_tx_data_i = cachesel ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[4:0] == 1)
			phy_tx_data_i = cachesel ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[4:0] == 2)
			phy_tx_data_i = cachesel ? cache1dato[23:16] : cache0dato[23:16];
		else if (cachephyaddr[4:0] == 3)
			phy_tx_data_i = cachesel ? cache1dato[31:24] : cache0dato[31:24];
		else if (cachephyaddr[4:0] == 4)
			phy_tx_data_i = cachesel ? cache1dato[39:32] : cache0dato[39:32];
		else if (cachephyaddr[4:0] == 5)
			phy_tx_data_i = cachesel ? cache1dato[47:40] : cache0dato[47:40];
		else if (cachephyaddr[4:0] == 6)
			phy_tx_data_i = cachesel ? cache1dato[55:48] : cache0dato[55:48];
		else if (cachephyaddr[4:0] == 7)
			phy_tx_data_i = cachesel ? cache1dato[63:56] : cache0dato[63:56];
		else if (cachephyaddr[4:0] == 8)
			phy_tx_data_i = cachesel ? cache1dato[71:64] : cache0dato[71:64];
		else if (cachephyaddr[4:0] == 9)
			phy_tx_data_i = cachesel ? cache1dato[79:72] : cache0dato[79:72];
		else if (cachephyaddr[4:0] == 10)
			phy_tx_data_i = cachesel ? cache1dato[87:80] : cache0dato[87:80];
		else if (cachephyaddr[4:0] == 11)
			phy_tx_data_i = cachesel ? cache1dato[95:88] : cache0dato[95:88];
		else if (cachephyaddr[4:0] == 12)
			phy_tx_data_i = cachesel ? cache1dato[103:96] : cache0dato[103:96];
		else if (cachephyaddr[4:0] == 13)
			phy_tx_data_i = cachesel ? cache1dato[111:104] : cache0dato[111:104];
		else if (cachephyaddr[4:0] == 14)
			phy_tx_data_i = cachesel ? cache1dato[119:112] : cache0dato[119:112];
		else if (cachephyaddr[4:0] == 15)
			phy_tx_data_i = cachesel ? cache1dato[127:120] : cache0dato[127:120];
		else if (cachephyaddr[4:0] == 16)
			phy_tx_data_i = cachesel ? cache1dato[135:128] : cache0dato[135:128];
		else if (cachephyaddr[4:0] == 17)
			phy_tx_data_i = cachesel ? cache1dato[143:136] : cache0dato[143:136];
		else if (cachephyaddr[4:0] == 18)
			phy_tx_data_i = cachesel ? cache1dato[151:144] : cache0dato[151:144];
		else if (cachephyaddr[4:0] == 19)
			phy_tx_data_i = cachesel ? cache1dato[159:152] : cache0dato[159:152];
		else if (cachephyaddr[4:0] == 20)
			phy_tx_data_i = cachesel ? cache1dato[167:160] : cache0dato[167:160];
		else if (cachephyaddr[4:0] == 21)
			phy_tx_data_i = cachesel ? cache1dato[175:168] : cache0dato[175:168];
		else if (cachephyaddr[4:0] == 22)
			phy_tx_data_i = cachesel ? cache1dato[183:176] : cache0dato[183:176];
		else if (cachephyaddr[4:0] == 23)
			phy_tx_data_i = cachesel ? cache1dato[191:184] : cache0dato[191:184];
		else if (cachephyaddr[4:0] == 24)
			phy_tx_data_i = cachesel ? cache1dato[199:192] : cache0dato[199:192];
		else if (cachephyaddr[4:0] == 25)
			phy_tx_data_i = cachesel ? cache1dato[207:200] : cache0dato[207:200];
		else if (cachephyaddr[4:0] == 26)
			phy_tx_data_i = cachesel ? cache1dato[215:208] : cache0dato[215:208];
		else if (cachephyaddr[4:0] == 27)
			phy_tx_data_i = cachesel ? cache1dato[223:216] : cache0dato[223:216];
		else if (cachephyaddr[4:0] == 28)
			phy_tx_data_i = cachesel ? cache1dato[231:224] : cache0dato[231:224];
		else if (cachephyaddr[4:0] == 29)
			phy_tx_data_i = cachesel ? cache1dato[239:232] : cache0dato[239:232];
		else if (cachephyaddr[4:0] == 30)
			phy_tx_data_i = cachesel ? cache1dato[247:240] : cache0dato[247:240];
		else
			phy_tx_data_i = cachesel ? cache1dato[255:248] : cache0dato[255:248];
	end
end endgenerate

// Register used to detect a falling edge of "irq_rdy_i".
reg  irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

// Register used to detect a rising edge of "phy_err_o".
reg  phy_err_o_r;
wire phy_err_o_posedge = (phy_err_o && !phy_err_o_r);

// Register used to detect a falling edge of "phy_bsy_w".
reg  phy_bsy_w_r;
wire phy_bsy_w_negedge = (!phy_bsy_w && phy_bsy_w_r);

wire cache_rdop = (wb_stb_r && !wb_we_r && wb_addr_r < (PHYBLKSZ >> CLOG2XARCHBITSZBY8));
wire cache_wrop = (wb_stb_r && wb_we_r  && wb_addr_r < (PHYBLKSZ >> CLOG2XARCHBITSZBY8));
reg cache_wrop_r;
always @ (posedge clk_i)
	cache_wrop_r <= cache_wrop;

// Nets set to 1 when a read/write request is done to their respective cache.
wire cache0rd = cachesel ? cache_rdop : phy_tx_pop_o;
wire cache1rd = cachesel ? phy_tx_pop_o : cache_rdop;
wire cache0wr = cachesel ? cache_wrop_r : phy_rx_push_o;
wire cache1wr = cachesel ? phy_rx_push_o : cache_wrop_r;

reg [XARCHBITSZ -1 : 0] cache0 [(PHYBLKSZ/(XARCHBITSZ/8)) -1 : 0];
reg [XARCHBITSZ -1 : 0] cache1 [(PHYBLKSZ/(XARCHBITSZ/8)) -1 : 0];

assign cache0dato = cache0[cache0addr];
assign cache1dato = cache1[cache1addr];

always @ (posedge clk_i) begin
	if (cache0wr)
		cache0[cache0addr] <= cache0dati;
	if (cache1wr)
		cache1[cache1addr] <= cache1dati;
end

reg [2 -1 : 0] status; // ### comb-block-reg.
always @* begin
	if (rst_i)
		status = STATUSPOWEROFF;
	else if (phy_err_o)
		status = STATUSERROR;
	else if (phy_rst_w || phy_bsy_w)
		status = STATUSBUSY;
	else
		status = STATUSREADY;
end

reg [XARCHBITSZ -1 : 0] wb_dat_o_; // ### comb-block-reg.
always @* begin
	if (cmd_reset)
		wb_dat_o_ = status;
	else if (cmd_swap)
		wb_dat_o_ = PHYBLKSZ;
	else if (cmd_read || cmd_write)
		wb_dat_o_ = phy_blkcnt_o;
	else
		wb_dat_o_ = 0;
end

wire wb_stb_r_ = (wb_cyc_i && wb_stb_i);

wire [(CLOG2XARCHBITSZBY8DIFF+CLOG2ARCHBITSZ)-1:0] wb_dat_shift;
generate if (XARCHBITSZ == ARCHBITSZ) begin
assign wb_dat_shift = 0;
end else begin
assign wb_dat_shift = {_wb_addr_r[CLOG2XARCHBITSZBY8-1:CLOG2ARCHBITSZBY8], {CLOG2ARCHBITSZ{1'b0}}};
end endgenerate

always @ (posedge clk_i) begin

	wb_stb_r <= wb_stb_r_ ;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_sel_r <= wb_sel_i;
		wb_dat_r <= wb_dat_i;
	end

	// Logic that flips the value of cachesel when CMDSWAP is issued.
	if (wb_stb_r && wb_we_r && cmd_swap)
		cachesel <= ~cachesel;

	if (rst_i || (phy_cmd_pop_o && phy_cmd_empty_i))
		phy_cmd_empty_i <= 1'b0;
	else if (wb_we_r && (cmd_read || cmd_write)) begin
		phy_cmd_empty_i <= 1'b1;
		phy_cmd_data_i <= cmd_write;
		phy_cmd_addr_i <= (wb_dat_r >> wb_dat_shift);
	end

	wb_ack_o <= wb_stb_r;

	if (cache_rdop || cache_wrop)
		wb_dat_o <= cachesel ? cache0dato : cache1dato;
	else if (wb_stb_r && !wb_we_r)
		wb_dat_o <= (wb_dat_o_ << wb_dat_shift);

	// Logic that sets cachephyaddr.
	// Increment cachephyaddr whenever the PHY is not busy and requesting
	// a read/write; reset cachephyaddr to 0 whenever "phy_bsy_w" is low.
	if (!phy_bsy_w)
		cachephyaddr <= 0;
	else if (cachesel ? (cache1rd | cache1wr) : (cache0rd | cache0wr))
		cachephyaddr <= cachephyaddr + 1'b1;

	// Logic to set/clear irq_stb_o.
	// A rising edge of "phy_err_o" means that an error occured
	// while the controller was processing the previous
	// operation, which is either initialization, read or write;
	// a falling edge of "phy_bsy_w" means that the controller
	// has completed the previous operation, which is either
	// initialization, read or write.
	// Note that on poweron, it is expected that the device
	// transition from a poweroff state through a busy state
	// to a ready state, in order to trigger a poweron interrupt.
	if (rst_i)
		irq_stb_o <= 1'b0;
	else if (irq_stb_o)
		irq_stb_o <= !irq_rdy_i_negedge;
	else
		irq_stb_o <= (phy_err_o_posedge || phy_bsy_w_negedge);

	// Sampling used for edge detection.
	irq_rdy_i_r <= irq_rdy_i;
	phy_err_o_r <= phy_err_o;
	phy_bsy_w_r <= phy_bsy_w;
end

endmodule
