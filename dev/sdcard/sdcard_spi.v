// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// SDCard peripheral.
//
// This device transfers data in blocks, where DevMapSz reports
// the block size in bytes, and where the memory operations PIRDOP,
// PIWROP respectively read/write the memory mapping with the data
// to be transfered to/from the device.
// The memory operation PIRWOP is used to send commands to the device,
// and must be ARCHBITSZ bits aligned; the ARCHBITSZ bits aligned offset within
// the memory mapping identifies the command; the value to write is the argument
// of the command, while the value read is the return value of the command.
// The four commands are:
// RESET: Byte offset 0; returns current status.
// 	A controller reset is initiated when the argument is non-null,
// 	and an interrupt is raised once the reset is complete.
// 	The status value returned can be:
// 	0: PowerOff.
// 	1: Ready.
// 	2: Busy.
// 	3: Error.
// 	Note that there is no reporting of timeout, as it is best implemented
// 	in software by timing how long the device has been busy.
// SWAP: Byte offset (ARCHBITSZ/8); implements double caching whereby the cache
// 	associated with the mapped block presented in the physical address space
// 	is swapped so that the controller can now have access to it and so that
// 	its content can be stored in the device when the command WRITE is issued,
// 	or so that it can be loaded with a block of data from the device when
// 	the command READ is issued; after the swapping, the cache now presented
// 	in the physical address space, and which was previously used by the controller,
// 	can now be accessed using the memory operations PIRDOP and PIWROP.
// 	Hence, it is possible to do things such as preparing the next block
// 	of data to store in the device while simultaneously, a block of data
// 	is being stored in the device.
// 	This command does not take any argument, it returns PHYBLKSZ,
// 	and does not generate any interrupt; it must be issued when the controller
// 	status is ready, otherwise silent faillures and undefined behaviors will occur.
// READ: Byte offset 2*(ARCHBITSZ/8); read a block of data from the device;
// 	the argument is the block address within the device.
// 	The return value is the total block count of the device; the total block count
// 	returned can be made to change between issuance of this command, allowing
// 	the implementation of device with variable total block count.
// 	An interrupt is raised once reading the data block from the device is complete.
// 	This command must be issued when the controller status is ready, otherwise
// 	silent faillures and undefined behaviors will occur.
// WRITE: Byte offset 3*(ARCHBITSZ/8); write a block of data to the device;
// 	the argument is the block address within the device.
// 	The return value is the total block count of the device; the total block
// 	count value returned can be made to change between issuance of this command,
// 	allowing the implementation of device with variable total block count.
// 	An interrupt is raised once writing the data block to the device is complete.
// 	This command must be issued when the controller status is ready, otherwise
// 	silent faillures and undefined behaviors will occur.
//
// Copying blocks between locations within this device can be done
// simply issuing the command READ specifying the source block location,
// followed by the command WRITE specifying the destination block location.
//
// The memory operation PIRWOP with an address >= 4*(ARCHBITSZ/8) does not
// send any command to the device and behave like a regular atomic operation.

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
// 	### For now, it must be the same as clk_i until FIFOs are used with the PHY.
//
// sclk_o
// di_o
// do_i
// cs_o
// 	SPI interface to the card.
//
// pi1_op_i
// pi1_addr_i
// pi1_data_i
// pi1_data_o
// pi1_sel_i
// pi1_rdy_o
// pi1_mapsz_o
// 	Slave memory interface.
//
// intrqst_o
// 	This signal is set high to request an interrupt;
// 	an interrupt is raised, when either of the following
// 	events from the controller occurs:
// 	- Done resetting; also occur on poweron.
// 	- Done reading.
// 	- Done writing.
// 	- Error.
// 	- Poweroff.
//
// intrdy_i
// 	This signal become low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to automatically lower intrqst_o.

`include "lib/ram/dram.v"

`ifdef SIMULATION
`include "./sdcard_sim_phy.v"
`else
`include "./sdcard_spi_phy.v"
`endif

`include "lib/perint/pi1b.v"

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

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o
	,pi1_mapsz_o

	,intrqst_o
	,intrdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;
parameter XARCHBITSZ = 16;

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
// Note also that the value of this macro is the block size used by the controller
// as well as the value of DevMapSz which is the size of the memory mapping
// used by the memory interface.
// The value of this macro must be greater than or equal to 16 to accomodate the memory
// mapping space needed for the four commands (CMDRESET, CMDSWAP, CMDREAD, CMDWRITE);
// and the value of this macro must be a power of 2.
localparam PHYBLKSZ = 512; // ### Must not change for SDCard.

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);
localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

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

input  wire [2 -1 : 0]              pi1_op_i;
input  wire [XADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [XARCHBITSZ -1 : 0]     pi1_data_i;
output wire [XARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(XARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                         pi1_rdy_o;
output wire [XARCHBITSZ -1 : 0]     pi1_mapsz_o;

output reg  intrqst_o = 0;
input  wire intrdy_i;

assign pi1_mapsz_o = PHYBLKSZ;

localparam CLOG2PHYBLKSZ = clog2(PHYBLKSZ);

wire [2 -1 : 0]              pi1b_op_i;
wire [XADDRBITSZ -1 : 0]     pi1b_addr_i;
wire [XARCHBITSZ -1 : 0]     pi1b_data_o;
wire [XARCHBITSZ -1 : 0]     pi1b_data_i;
wire [(XARCHBITSZ/8) -1 : 0] pi1b_sel_i;
reg                          pi1b_rdy_o;

pi1b #(

	.ARCHBITSZ (XARCHBITSZ)

) pi1b (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.m_op_i (pi1_op_i)
	,.m_addr_i (pi1_addr_i)
	,.m_data_i (pi1_data_i)
	,.m_data_o (pi1_data_o)
	,.m_sel_i (pi1_sel_i)
	,.m_rdy_o (pi1_rdy_o)

	,.s_op_o (pi1b_op_i)
	,.s_addr_o (pi1b_addr_i)
	,.s_data_o (pi1b_data_i)
	,.s_data_i (pi1b_data_o)
	,.s_sel_o (pi1b_sel_i)
	,.s_rdy_i (pi1b_rdy_o)
);

wire [XARCHBITSZ -1 : 0] pi1b_addr_w;

addr #(
	.ARCHBITSZ (XARCHBITSZ)
) addr (
	 .addr_i (pi1b_addr_i)
	,.sel_i  (pi1b_sel_i)
	,.addr_o (pi1b_addr_w)
);

wire [ADDRBITSZ -2 : 0] addr_w = pi1b_addr_w[ADDRBITSZ-1:CLOG2ARCHBITSZBY8];

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

// Commands.
localparam CMDRESET = 0;
localparam CMDSWAP  = 1;
localparam CMDREAD  = 2;
localparam CMDWRITE = 3;
localparam CMD_CNT  = 4; // Number of commands.

// Status.
localparam STATUSPOWEROFF = 0;
localparam STATUSREADY    = 1;
localparam STATUSBUSY     = 2;
localparam STATUSERROR    = 3;

wire phy_tx_pop_w, phy_rx_push_w;

wire [8 -1 : 0] phy_rx_data_w;
reg  [8 -1 : 0] phy_tx_data_w; // ### Net declared as reg so as to be useable by verilog within the always block.

reg phy_cmd = 0;

reg [XARCHBITSZ -1 : 0] phy_cmdaddr = 0;

wire [XARCHBITSZ -1 : 0] phy_blkcnt_w;

wire phy_err_w;

// A phy reset is done when "rst_i" is high or when
// CMDRESET is issued with its argument non-null.
// Since "rst_i" is also used to report whether
// the device is under power, a controller reset
// will be done as soon as the device is powered-on.
wire phy_rst_w = (rst_i | (pi1b_op_i == PIRWOP && addr_w == CMDRESET && pi1b_data_i));

reg phy_cmd_pending = 0;

wire phy_cmd_pop_w;

wire phy_bsy = (phy_cmd_pending || !phy_cmd_pop_w);

`ifdef SIMULATION
sdcard_sim_phy
`else
sdcard_spi_phy
`endif
#(
	`ifndef SIMULATION
	 .PHYCLKFREQ (PHYCLKFREQ)
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

	,.cmd_pop_o      (phy_cmd_pop_w)
	,.cmd_data_i     (phy_cmd)
	,.cmd_addr_i     (phy_cmdaddr)
	,.cmd_empty_i    (!phy_cmd_pending)

	,.rx_push_o (phy_rx_push_w)
	,.rx_data_o (phy_rx_data_w)
	,.rx_full_i (/* not needed */)

	,.tx_pop_o   (phy_tx_pop_w)
	,.tx_data_i  (phy_tx_data_w)
	,.tx_empty_i (/* not needed */)

	,.blkcnt_o (phy_blkcnt_w)

	,.err_o (phy_err_w)
);

wire pi1_op_is_rdop = (pi1b_op_i == PIRDOP || (pi1b_op_i == PIRWOP && addr_w >= CMD_CNT));
wire pi1_op_is_wrop = (pi1b_op_i == PIWROP || (pi1b_op_i == PIRWOP && addr_w >= CMD_CNT));
wire pi1_op_is_cmd = (pi1b_op_i == PIRWOP && addr_w < CMD_CNT);

reg pi1_op_is_wrop_hold = 0;
reg pi1_op_is_cmd_hold = 0;

// When the value of this register is 1, "phy" has
// access to cache1 otherwise it has access to cache0.
// The cache not being accessed by "phy" is accessed
// by the memory interface.
reg cacheselect = 0;

// Register keeping track of the cache byte location the PHY will access next.
reg [CLOG2PHYBLKSZ -1 : 0] cachephyaddr = 0;

reg  [XARCHBITSZ -1 : 0] pi1b_addr_w_hold = 0;
wire [XARCHBITSZ -1 : 0] _pi1b_addr_w = (pi1_op_is_wrop_hold ? pi1b_addr_w_hold : pi1b_addr_w);

// Nets set to the index within the respective cache. Each cache element is XARCHBITSZ bits.
wire [(CLOG2PHYBLKSZ-CLOG2XARCHBITSZBY8) -1 : 0] cache0addr =
	cacheselect ? _pi1b_addr_w[CLOG2PHYBLKSZ -1 : CLOG2XARCHBITSZBY8] : cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2XARCHBITSZBY8];
wire [(CLOG2PHYBLKSZ-CLOG2XARCHBITSZBY8) -1 : 0] cache1addr =
	cacheselect ? cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2XARCHBITSZBY8] : _pi1b_addr_w[CLOG2PHYBLKSZ -1 : CLOG2XARCHBITSZBY8];

localparam XARCHBITSZMAX = 256;

wire [XARCHBITSZMAX -1 : 0] cache0dato;
wire [XARCHBITSZMAX -1 : 0] cache1dato;

wire [XARCHBITSZMAX -1 : 0] cachephydata = cacheselect ? cache1dato : cache0dato;

// Net set to the value from the PHY to store in the cache.
wire [XARCHBITSZMAX -1 : 0] phy_rx_data_w_byteselected =
	(XARCHBITSZ == 16) ? (
		(cachephyaddr[0] == 0) ? {cachephydata[15:8], phy_rx_data_w} :
		                         {phy_rx_data_w, cachephydata[7:0]}) :
	(XARCHBITSZ == 32) ? (
		(cachephyaddr[1:0] == 0) ? {cachephydata[31:8], phy_rx_data_w} :
		(cachephyaddr[1:0] == 1) ? {cachephydata[31:16], phy_rx_data_w, cachephydata[7:0]} :
		(cachephyaddr[1:0] == 2) ? {cachephydata[31:24], phy_rx_data_w, cachephydata[15:0]} :
		                           {phy_rx_data_w, cachephydata[23:0]}) :
	(XARCHBITSZ == 64) ? (
		(cachephyaddr[2:0] == 0) ? {cachephydata[63:8], phy_rx_data_w} :
		(cachephyaddr[2:0] == 1) ? {cachephydata[63:16], phy_rx_data_w, cachephydata[7:0]} :
		(cachephyaddr[2:0] == 2) ? {cachephydata[63:24], phy_rx_data_w, cachephydata[15:0]} :
		(cachephyaddr[2:0] == 3) ? {cachephydata[63:32], phy_rx_data_w, cachephydata[23:0]} :
		(cachephyaddr[2:0] == 4) ? {cachephydata[63:40], phy_rx_data_w, cachephydata[31:0]} :
		(cachephyaddr[2:0] == 5) ? {cachephydata[63:48], phy_rx_data_w, cachephydata[39:0]} :
		(cachephyaddr[2:0] == 6) ? {cachephydata[63:56], phy_rx_data_w, cachephydata[47:0]} :
		                           {phy_rx_data_w, cachephydata[55:0]}) :
	(XARCHBITSZ == 128) ? (
		(cachephyaddr[3:0] == 0) ? {cachephydata[127:8], phy_rx_data_w} :
		(cachephyaddr[3:0] == 1) ? {cachephydata[127:16], phy_rx_data_w, cachephydata[7:0]} :
		(cachephyaddr[3:0] == 2) ? {cachephydata[127:24], phy_rx_data_w, cachephydata[15:0]} :
		(cachephyaddr[3:0] == 3) ? {cachephydata[127:32], phy_rx_data_w, cachephydata[23:0]} :
		(cachephyaddr[3:0] == 4) ? {cachephydata[127:40], phy_rx_data_w, cachephydata[31:0]} :
		(cachephyaddr[3:0] == 5) ? {cachephydata[127:48], phy_rx_data_w, cachephydata[39:0]} :
		(cachephyaddr[3:0] == 6) ? {cachephydata[127:56], phy_rx_data_w, cachephydata[47:0]} :
		(cachephyaddr[3:0] == 7) ? {cachephydata[127:64], phy_rx_data_w, cachephydata[55:0]} :
		(cachephyaddr[3:0] == 8) ? {cachephydata[127:72], phy_rx_data_w, cachephydata[63:0]} :
		(cachephyaddr[3:0] == 9) ? {cachephydata[127:80], phy_rx_data_w, cachephydata[71:0]} :
		(cachephyaddr[3:0] == 10) ? {cachephydata[127:88], phy_rx_data_w, cachephydata[79:0]} :
		(cachephyaddr[3:0] == 11) ? {cachephydata[127:96], phy_rx_data_w, cachephydata[87:0]} :
		(cachephyaddr[3:0] == 12) ? {cachephydata[127:104], phy_rx_data_w, cachephydata[95:0]} :
		(cachephyaddr[3:0] == 13) ? {cachephydata[127:112], phy_rx_data_w, cachephydata[103:0]} :
		(cachephyaddr[3:0] == 14) ? {cachephydata[127:120], phy_rx_data_w, cachephydata[111:0]} :
		                            {phy_rx_data_w, cachephydata[119:0]}) :
	/* (XARCHBITSZ == 256) ? */ (
		(cachephyaddr[4:0] == 0) ? {cachephydata[255:8], phy_rx_data_w} :
		(cachephyaddr[4:0] == 1) ? {cachephydata[255:16], phy_rx_data_w, cachephydata[7:0]} :
		(cachephyaddr[4:0] == 2) ? {cachephydata[255:24], phy_rx_data_w, cachephydata[15:0]} :
		(cachephyaddr[4:0] == 3) ? {cachephydata[255:32], phy_rx_data_w, cachephydata[23:0]} :
		(cachephyaddr[4:0] == 4) ? {cachephydata[255:40], phy_rx_data_w, cachephydata[31:0]} :
		(cachephyaddr[4:0] == 5) ? {cachephydata[255:48], phy_rx_data_w, cachephydata[39:0]} :
		(cachephyaddr[4:0] == 6) ? {cachephydata[255:56], phy_rx_data_w, cachephydata[47:0]} :
		(cachephyaddr[4:0] == 7) ? {cachephydata[255:64], phy_rx_data_w, cachephydata[55:0]} :
		(cachephyaddr[4:0] == 8) ? {cachephydata[255:72], phy_rx_data_w, cachephydata[63:0]} :
		(cachephyaddr[4:0] == 9) ? {cachephydata[255:80], phy_rx_data_w, cachephydata[71:0]} :
		(cachephyaddr[4:0] == 10) ? {cachephydata[255:88], phy_rx_data_w, cachephydata[79:0]} :
		(cachephyaddr[4:0] == 11) ? {cachephydata[255:96], phy_rx_data_w, cachephydata[87:0]} :
		(cachephyaddr[4:0] == 12) ? {cachephydata[255:104], phy_rx_data_w, cachephydata[95:0]} :
		(cachephyaddr[4:0] == 13) ? {cachephydata[255:112], phy_rx_data_w, cachephydata[103:0]} :
		(cachephyaddr[4:0] == 14) ? {cachephydata[255:120], phy_rx_data_w, cachephydata[111:0]} :
		(cachephyaddr[4:0] == 15) ? {cachephydata[255:128], phy_rx_data_w, cachephydata[119:0]} :
		(cachephyaddr[4:0] == 16) ? {cachephydata[255:136], phy_rx_data_w, cachephydata[127:0]} :
		(cachephyaddr[4:0] == 17) ? {cachephydata[255:144], phy_rx_data_w, cachephydata[135:0]} :
		(cachephyaddr[4:0] == 18) ? {cachephydata[255:152], phy_rx_data_w, cachephydata[143:0]} :
		(cachephyaddr[4:0] == 19) ? {cachephydata[255:160], phy_rx_data_w, cachephydata[151:0]} :
		(cachephyaddr[4:0] == 20) ? {cachephydata[255:168], phy_rx_data_w, cachephydata[159:0]} :
		(cachephyaddr[4:0] == 21) ? {cachephydata[255:176], phy_rx_data_w, cachephydata[167:0]} :
		(cachephyaddr[4:0] == 22) ? {cachephydata[255:184], phy_rx_data_w, cachephydata[175:0]} :
		(cachephyaddr[4:0] == 23) ? {cachephydata[255:192], phy_rx_data_w, cachephydata[183:0]} :
		(cachephyaddr[4:0] == 24) ? {cachephydata[255:200], phy_rx_data_w, cachephydata[191:0]} :
		(cachephyaddr[4:0] == 25) ? {cachephydata[255:208], phy_rx_data_w, cachephydata[199:0]} :
		(cachephyaddr[4:0] == 26) ? {cachephydata[255:216], phy_rx_data_w, cachephydata[207:0]} :
		(cachephyaddr[4:0] == 27) ? {cachephydata[255:224], phy_rx_data_w, cachephydata[215:0]} :
		(cachephyaddr[4:0] == 28) ? {cachephydata[255:232], phy_rx_data_w, cachephydata[223:0]} :
		(cachephyaddr[4:0] == 29) ? {cachephydata[255:240], phy_rx_data_w, cachephydata[231:0]} :
		(cachephyaddr[4:0] == 30) ? {cachephydata[255:248], phy_rx_data_w, cachephydata[239:0]} :
		                            {phy_rx_data_w, cachephydata[247:0]});

wire [XARCHBITSZ -1 : 0] _pi1b_data_i_hold;

// Nets set to the value to write in the respective cache.
wire [XARCHBITSZ -1 : 0] cache0dati = cacheselect ? _pi1b_data_i_hold : phy_rx_data_w_byteselected[XARCHBITSZ -1 : 0];
wire [XARCHBITSZ -1 : 0] cache1dati = cacheselect ? phy_rx_data_w_byteselected[XARCHBITSZ -1 : 0] : _pi1b_data_i_hold;

// phy_tx_data_w is set to the value read from the respective cache.
always @* begin
	if (XARCHBITSZ == 16) begin
		if (cachephyaddr[0] == 0)
			phy_tx_data_w = cacheselect ? cache1dato[7:0] : cache0dato[7:0];
		else
			phy_tx_data_w = cacheselect ? cache1dato[15:8] : cache0dato[15:8];
	end else if (XARCHBITSZ == 32) begin
		if (cachephyaddr[1:0] == 0)
			phy_tx_data_w = cacheselect ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[1:0] == 1)
			phy_tx_data_w = cacheselect ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[1:0] == 2)
			phy_tx_data_w = cacheselect ? cache1dato[23:16] : cache0dato[23:16];
		else
			phy_tx_data_w = cacheselect ? cache1dato[31:24] : cache0dato[31:24];
	end else if (XARCHBITSZ == 64) begin
		if (cachephyaddr[2:0] == 0)
			phy_tx_data_w = cacheselect ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[2:0] == 1)
			phy_tx_data_w = cacheselect ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[2:0] == 2)
			phy_tx_data_w = cacheselect ? cache1dato[23:16] : cache0dato[23:16];
		else if (cachephyaddr[2:0] == 3)
			phy_tx_data_w = cacheselect ? cache1dato[31:24] : cache0dato[31:24];
		else if (cachephyaddr[2:0] == 4)
			phy_tx_data_w = cacheselect ? cache1dato[39:32] : cache0dato[39:32];
		else if (cachephyaddr[2:0] == 5)
			phy_tx_data_w = cacheselect ? cache1dato[47:40] : cache0dato[47:40];
		else if (cachephyaddr[2:0] == 6)
			phy_tx_data_w = cacheselect ? cache1dato[55:48] : cache0dato[55:48];
		else
			phy_tx_data_w = cacheselect ? cache1dato[63:56] : cache0dato[63:56];
	end else if (XARCHBITSZ == 128) begin
		if (cachephyaddr[3:0] == 0)
			phy_tx_data_w = cacheselect ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[3:0] == 1)
			phy_tx_data_w = cacheselect ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[3:0] == 2)
			phy_tx_data_w = cacheselect ? cache1dato[23:16] : cache0dato[23:16];
		else if (cachephyaddr[3:0] == 3)
			phy_tx_data_w = cacheselect ? cache1dato[31:24] : cache0dato[31:24];
		else if (cachephyaddr[3:0] == 4)
			phy_tx_data_w = cacheselect ? cache1dato[39:32] : cache0dato[39:32];
		else if (cachephyaddr[3:0] == 5)
			phy_tx_data_w = cacheselect ? cache1dato[47:40] : cache0dato[47:40];
		else if (cachephyaddr[3:0] == 6)
			phy_tx_data_w = cacheselect ? cache1dato[55:48] : cache0dato[55:48];
		else if (cachephyaddr[3:0] == 7)
			phy_tx_data_w = cacheselect ? cache1dato[63:56] : cache0dato[63:56];
		else if (cachephyaddr[3:0] == 8)
			phy_tx_data_w = cacheselect ? cache1dato[71:64] : cache0dato[71:64];
		else if (cachephyaddr[3:0] == 9)
			phy_tx_data_w = cacheselect ? cache1dato[79:72] : cache0dato[79:72];
		else if (cachephyaddr[3:0] == 10)
			phy_tx_data_w = cacheselect ? cache1dato[87:80] : cache0dato[87:80];
		else if (cachephyaddr[3:0] == 11)
			phy_tx_data_w = cacheselect ? cache1dato[95:88] : cache0dato[95:88];
		else if (cachephyaddr[3:0] == 12)
			phy_tx_data_w = cacheselect ? cache1dato[103:96] : cache0dato[103:96];
		else if (cachephyaddr[3:0] == 13)
			phy_tx_data_w = cacheselect ? cache1dato[111:104] : cache0dato[111:104];
		else if (cachephyaddr[3:0] == 14)
			phy_tx_data_w = cacheselect ? cache1dato[119:112] : cache0dato[119:112];
		else
			phy_tx_data_w = cacheselect ? cache1dato[127:120] : cache0dato[127:120];
	end else /* if (XARCHBITSZ == 256) */ begin
		if (cachephyaddr[4:0] == 0)
			phy_tx_data_w = cacheselect ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[4:0] == 1)
			phy_tx_data_w = cacheselect ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[4:0] == 2)
			phy_tx_data_w = cacheselect ? cache1dato[23:16] : cache0dato[23:16];
		else if (cachephyaddr[4:0] == 3)
			phy_tx_data_w = cacheselect ? cache1dato[31:24] : cache0dato[31:24];
		else if (cachephyaddr[4:0] == 4)
			phy_tx_data_w = cacheselect ? cache1dato[39:32] : cache0dato[39:32];
		else if (cachephyaddr[4:0] == 5)
			phy_tx_data_w = cacheselect ? cache1dato[47:40] : cache0dato[47:40];
		else if (cachephyaddr[4:0] == 6)
			phy_tx_data_w = cacheselect ? cache1dato[55:48] : cache0dato[55:48];
		else if (cachephyaddr[4:0] == 7)
			phy_tx_data_w = cacheselect ? cache1dato[63:56] : cache0dato[63:56];
		else if (cachephyaddr[4:0] == 8)
			phy_tx_data_w = cacheselect ? cache1dato[71:64] : cache0dato[71:64];
		else if (cachephyaddr[4:0] == 9)
			phy_tx_data_w = cacheselect ? cache1dato[79:72] : cache0dato[79:72];
		else if (cachephyaddr[4:0] == 10)
			phy_tx_data_w = cacheselect ? cache1dato[87:80] : cache0dato[87:80];
		else if (cachephyaddr[4:0] == 11)
			phy_tx_data_w = cacheselect ? cache1dato[95:88] : cache0dato[95:88];
		else if (cachephyaddr[4:0] == 12)
			phy_tx_data_w = cacheselect ? cache1dato[103:96] : cache0dato[103:96];
		else if (cachephyaddr[4:0] == 13)
			phy_tx_data_w = cacheselect ? cache1dato[111:104] : cache0dato[111:104];
		else if (cachephyaddr[4:0] == 14)
			phy_tx_data_w = cacheselect ? cache1dato[119:112] : cache0dato[119:112];
		else if (cachephyaddr[4:0] == 15)
			phy_tx_data_w = cacheselect ? cache1dato[127:120] : cache0dato[127:120];
		else if (cachephyaddr[4:0] == 16)
			phy_tx_data_w = cacheselect ? cache1dato[135:128] : cache0dato[135:128];
		else if (cachephyaddr[4:0] == 17)
			phy_tx_data_w = cacheselect ? cache1dato[143:136] : cache0dato[143:136];
		else if (cachephyaddr[4:0] == 18)
			phy_tx_data_w = cacheselect ? cache1dato[151:144] : cache0dato[151:144];
		else if (cachephyaddr[4:0] == 19)
			phy_tx_data_w = cacheselect ? cache1dato[159:152] : cache0dato[159:152];
		else if (cachephyaddr[4:0] == 20)
			phy_tx_data_w = cacheselect ? cache1dato[167:160] : cache0dato[167:160];
		else if (cachephyaddr[4:0] == 21)
			phy_tx_data_w = cacheselect ? cache1dato[175:168] : cache0dato[175:168];
		else if (cachephyaddr[4:0] == 22)
			phy_tx_data_w = cacheselect ? cache1dato[183:176] : cache0dato[183:176];
		else if (cachephyaddr[4:0] == 23)
			phy_tx_data_w = cacheselect ? cache1dato[191:184] : cache0dato[191:184];
		else if (cachephyaddr[4:0] == 24)
			phy_tx_data_w = cacheselect ? cache1dato[199:192] : cache0dato[199:192];
		else if (cachephyaddr[4:0] == 25)
			phy_tx_data_w = cacheselect ? cache1dato[207:200] : cache0dato[207:200];
		else if (cachephyaddr[4:0] == 26)
			phy_tx_data_w = cacheselect ? cache1dato[215:208] : cache0dato[215:208];
		else if (cachephyaddr[4:0] == 27)
			phy_tx_data_w = cacheselect ? cache1dato[223:216] : cache0dato[223:216];
		else if (cachephyaddr[4:0] == 28)
			phy_tx_data_w = cacheselect ? cache1dato[231:224] : cache0dato[231:224];
		else if (cachephyaddr[4:0] == 29)
			phy_tx_data_w = cacheselect ? cache1dato[239:232] : cache0dato[239:232];
		else if (cachephyaddr[4:0] == 30)
			phy_tx_data_w = cacheselect ? cache1dato[247:240] : cache0dato[247:240];
		else
			phy_tx_data_w = cacheselect ? cache1dato[255:248] : cache0dato[255:248];
	end
end

// Register used to detect a falling edge of "intrdy_i".
reg  intrdy_i_sampled = 0;
wire intrdy_i_negedge = (!intrdy_i && intrdy_i_sampled);

// Register used to detect a rising edge of "phy_err_w".
reg  phy_err_w_sampled = 0;
wire phy_err_w_posedge = (phy_err_w && !phy_err_w_sampled);

// Register used to detect a falling edge of "phy_bsy".
reg  phy_bsy_sampled = 0;
wire phy_bsy_negedge = (!phy_bsy && phy_bsy_sampled);

// Nets set to 1 when a read/write request is done to their respective cache.
wire cache0read  = cacheselect ? pi1_op_is_rdop : phy_tx_pop_w;
wire cache1read  = cacheselect ? phy_tx_pop_w : pi1_op_is_rdop;
wire cache0write = cacheselect ? pi1_op_is_wrop_hold : phy_rx_push_w;
wire cache1write = cacheselect ? phy_rx_push_w : pi1_op_is_wrop_hold;

dram #(

	 .SZ (PHYBLKSZ/(XARCHBITSZ/8))
	,.DW (XARCHBITSZ)

) cache0 (

	 .clk1_i  (clk_i)
	,.we1_i   (cache0write)
	,.addr1_i (cache0addr)
	,.i1      (cache0dati)
	,.o1      (cache0dato)
);

dram #(

	 .SZ (PHYBLKSZ/(XARCHBITSZ/8))
	,.DW (XARCHBITSZ)

) cache1 (

	 .clk1_i  (clk_i)
	,.we1_i   (cache1write)
	,.addr1_i (cache1addr)
	,.i1      (cache1dati)
	,.o1      (cache1dato)
);

reg [2 -1 : 0] status; // ### Net declared as reg so as to be useable by verilog within the always block.

always @* begin
	if (rst_i)
		status = STATUSPOWEROFF;
	else if (phy_err_w)
		status = STATUSERROR;
	else if (phy_rst_w || phy_bsy)
		status = STATUSBUSY;
	else
		status = STATUSREADY;
end

reg [(256/*XARCHBITSZ*//8) -1 : 0] pi1b_sel_i_hold = 0;
// ### Net declared as reg so as to be useable by verilog within the always block.
reg [XARCHBITSZ -1 : 0] sel_w; // Net set to a bitmask used to modify only a portion of the indexed memory.
always @* begin
	if (XARCHBITSZ == 16)
		sel_w = {{8{pi1b_sel_i_hold[1]}}, {8{pi1b_sel_i_hold[0]}}};
	else if (XARCHBITSZ == 32)
		sel_w = {{8{pi1b_sel_i_hold[3]}}, {8{pi1b_sel_i_hold[2]}}, {8{pi1b_sel_i_hold[1]}}, {8{pi1b_sel_i_hold[0]}}};
	else if (XARCHBITSZ == 64)
		sel_w = {
			{8{pi1b_sel_i_hold[7]}}, {8{pi1b_sel_i_hold[6]}}, {8{pi1b_sel_i_hold[5]}}, {8{pi1b_sel_i_hold[4]}},
			{8{pi1b_sel_i_hold[3]}}, {8{pi1b_sel_i_hold[2]}}, {8{pi1b_sel_i_hold[1]}}, {8{pi1b_sel_i_hold[0]}}};
	else if (XARCHBITSZ == 128)
		sel_w = {
			{8{pi1b_sel_i_hold[15]}}, {8{pi1b_sel_i_hold[14]}}, {8{pi1b_sel_i_hold[13]}}, {8{pi1b_sel_i_hold[12]}},
			{8{pi1b_sel_i_hold[11]}}, {8{pi1b_sel_i_hold[10]}}, {8{pi1b_sel_i_hold[9]}}, {8{pi1b_sel_i_hold[8]}},
			{8{pi1b_sel_i_hold[7]}}, {8{pi1b_sel_i_hold[6]}}, {8{pi1b_sel_i_hold[5]}}, {8{pi1b_sel_i_hold[4]}},
			{8{pi1b_sel_i_hold[3]}}, {8{pi1b_sel_i_hold[2]}}, {8{pi1b_sel_i_hold[1]}}, {8{pi1b_sel_i_hold[0]}}};
	else if (XARCHBITSZ == 256)
		sel_w = {
			{8{pi1b_sel_i_hold[31]}}, {8{pi1b_sel_i_hold[30]}}, {8{pi1b_sel_i_hold[29]}}, {8{pi1b_sel_i_hold[28]}},
			{8{pi1b_sel_i_hold[27]}}, {8{pi1b_sel_i_hold[26]}}, {8{pi1b_sel_i_hold[25]}}, {8{pi1b_sel_i_hold[24]}},
			{8{pi1b_sel_i_hold[23]}}, {8{pi1b_sel_i_hold[22]}}, {8{pi1b_sel_i_hold[21]}}, {8{pi1b_sel_i_hold[20]}},
			{8{pi1b_sel_i_hold[19]}}, {8{pi1b_sel_i_hold[18]}}, {8{pi1b_sel_i_hold[17]}}, {8{pi1b_sel_i_hold[16]}},
			{8{pi1b_sel_i_hold[15]}}, {8{pi1b_sel_i_hold[14]}}, {8{pi1b_sel_i_hold[13]}}, {8{pi1b_sel_i_hold[12]}},
			{8{pi1b_sel_i_hold[11]}}, {8{pi1b_sel_i_hold[10]}}, {8{pi1b_sel_i_hold[9]}}, {8{pi1b_sel_i_hold[8]}},
			{8{pi1b_sel_i_hold[7]}}, {8{pi1b_sel_i_hold[6]}}, {8{pi1b_sel_i_hold[5]}}, {8{pi1b_sel_i_hold[4]}},
			{8{pi1b_sel_i_hold[3]}}, {8{pi1b_sel_i_hold[2]}}, {8{pi1b_sel_i_hold[1]}}, {8{pi1b_sel_i_hold[0]}}};
	else
		sel_w = {XARCHBITSZ{1'b0}};
end

// upconverter logic.
reg [XARCHBITSZ -1 : 0] pi1b_data_i_hold = 0;
reg [XARCHBITSZ -1 : 0] data_w0 = 0;
wire [((CLOG2XARCHBITSZBY8-CLOG2ARCHBITSZBY8)+CLOG2ARCHBITSZ):0] data_w_hold_shift = {pi1b_addr_w_hold[CLOG2XARCHBITSZBY8:CLOG2ARCHBITSZBY8], {CLOG2ARCHBITSZ{1'b0}}};
wire [((CLOG2XARCHBITSZBY8-CLOG2ARCHBITSZBY8)+CLOG2ARCHBITSZ):0] data_w_shift = {pi1b_addr_w[CLOG2XARCHBITSZBY8:CLOG2ARCHBITSZBY8], {CLOG2ARCHBITSZ{1'b0}}};
assign pi1b_data_o = (pi1_op_is_cmd_hold ? (data_w0 << data_w_hold_shift[(CLOG2XARCHBITSZBY8DIFF+CLOG2ARCHBITSZ)-1:0]) : data_w0);
assign _pi1b_data_i_hold = ((pi1b_data_i_hold & sel_w) | (data_w0 & ~sel_w));

always @ (posedge clk_i) begin
	// Logic to set/clear intrqst_o.
	// A rising edge of "phy_err_w" means that an error occured
	// while the controller was processing the previous
	// operation, which is either initialization, read or write;
	// a falling edge of "phy_bsy" means that the controller
	// has completed the previous operation, which is either
	// initialization, read or write.
	// Note that on poweron, it is expected that the device
	// transition from a poweroff state through a busy state
	// to a ready state, in order to trigger a poweron interrupt.
	intrqst_o <= intrqst_o ? ~intrdy_i_negedge : (phy_err_w_posedge || phy_bsy_negedge);

	// Logic that flips the value of cacheselect when CMDSWAP is issued.
	if (pi1b_op_i == PIRWOP && addr_w == CMDSWAP)
		cacheselect <= ~cacheselect;

	if (rst_i || !pi1b_rdy_o)
		pi1b_rdy_o <= 1;
	if (pi1b_rdy_o) begin
		pi1b_addr_w_hold <= pi1b_addr_w;
		pi1b_sel_i_hold <= pi1b_sel_i;
		pi1b_data_i_hold <= pi1b_data_i;
		pi1b_rdy_o <= !pi1_op_is_wrop;
		pi1_op_is_wrop_hold <= pi1_op_is_wrop;
		pi1_op_is_cmd_hold <= pi1_op_is_cmd;
	end

	// Logic that sets data_w0.
	if (pi1_op_is_rdop | pi1_op_is_wrop)
		data_w0 <= cacheselect ? cache0dato : cache1dato;
	else if (pi1b_op_i == PIRWOP) begin
		if (addr_w == CMDRESET)
			data_w0 <= status;
		else if (addr_w == CMDSWAP)
			data_w0 <= PHYBLKSZ;
		else if (addr_w == CMDREAD || addr_w == CMDWRITE)
			data_w0 <= phy_blkcnt_w;
	end

	// Logic that sets cachephyaddr.
	// Increment cachephyaddr whenever the PHY is not busy and requesting
	// a read/write; reset cachephyaddr to 0 whenever "phy_bsy" is low.
	if (!phy_bsy)
		cachephyaddr <= 0;
	else if (cacheselect ? (cache1read | cache1write) : (cache0read | cache0write))
		cachephyaddr <= cachephyaddr + 1'b1;

	if (rst_i || (phy_cmd_pop_w && phy_cmd_pending))
		phy_cmd_pending <= 0;
	else if (pi1b_op_i == PIRWOP && (addr_w == CMDREAD || addr_w == CMDWRITE))
		phy_cmd_pending <= 1;

	if (pi1b_op_i == PIRWOP && (addr_w == CMDREAD || addr_w == CMDWRITE)) begin
		phy_cmd <= (addr_w == CMDWRITE);
		phy_cmdaddr <= (pi1b_data_i >> data_w_shift[(CLOG2XARCHBITSZBY8DIFF+CLOG2ARCHBITSZ)-1:0]);
	end
	// Sampling used for edge detection.
	intrdy_i_sampled  <= intrdy_i;
	phy_err_w_sampled <= phy_err_w;
	phy_bsy_sampled   <= phy_bsy;
end

endmodule
