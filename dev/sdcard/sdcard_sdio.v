// SPDX-License-Identifier: GPL-2.0-only
// 20250519 (c) William Fonkou Tambe

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
// - RESET: 0*(WORDBITSZ/8): Reading this register returns current status.
// 	A controller reset is initiated when writing any value to this register,
// 	and an interrupt is raised once the reset is complete.
// 	The status value returned can be:
// 	0: PowerOff.
// 	1: Ready.
// 	2: Busy.
// 	3: Error.
// 	Note that there is no reporting of timeout, as it is best implemented
// 	in software by timing how long the device has been busy.
// - SWAP: 1*(WORDBITSZ/8): Reading this register returns PHYBLKSZ.
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
// - READ: 2*(WORDBITSZ/8): Reading this register returns the total block
// 	count of the device.
// 	Writing this register read a block of data from the block address written.
// 	An interrupt is raised once reading the data block from the device is complete.
// 	Writing this register must be done when the controller status is ready,
// 	otherwise silent faillures and undefined behaviors will occur.
// - WRITE: 3*(WORDBITSZ/8): Reading this register returns the total block
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
// 	It must be greather than or equal to CLKFREQ.

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
// sdclk_o
// sdcmd_i, sdcmd_o, sdcmd_e
// sddat_i, sddat_o, sddat_e
// 	SDIO interface to the card.
//
// activity
// 	Report activity on the SDIO interface to the card.
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

`include "./sdcard_sdio_phy.v"

`include "lib/addr.v"

module sdcard_sdio (

	 rst_i

	,clk_i
	,clk_phy_i

	,sdclk_o
	,sdcmd_i ,sdcmd_o ,sdcmd_e
	,sddat_i ,sddat_o ,sddat_e

	,activity

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

parameter WORDBITSZ = 32;
parameter XWORDBITSZ = 32;

parameter CLKFREQ = 1;
parameter PHYCLKFREQ = 1;

// Size in bytes of each of the two caches used to implement double caching
// which allows the controller to read/write from/to the device, while in parallel,
// the next block of data to transfer is being prepared.
// CMDSWAP is used to swap between the cache used by the controller
// and the cache mapped in memory.
// Note also that the value of this macro is the block size used by the controller.
localparam PHYBLKSZ = 512; // ### Must not change for SDCard.

localparam CLOG2WORDBITSZ = clog2(WORDBITSZ);
localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ - CLOG2WORDBITSZBY8);

localparam CLOG2XWORDBITSZBY8 = clog2(XWORDBITSZ/8);
localparam XADDRBITSZ = (XWORDBITSZ-CLOG2XWORDBITSZBY8);

localparam CLOG2XWORDBITSZBY8DIFF = (CLOG2XWORDBITSZBY8 - CLOG2WORDBITSZBY8);

localparam MAPSZ = (PHYBLKSZ*2);

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));
localparam XMSBSZIGN = (XWORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

output wire            sdclk_o;
input  wire            sdcmd_i;
output wire            sdcmd_o;
output wire            sdcmd_e;
input  wire [4 -1 : 0] sddat_i;
output wire [4 -1 : 0] sddat_o;
output wire [4 -1 : 0] sddat_e;

output wire activity;

input  wire                                 wb_cyc_i;
input  wire                                 wb_stb_i;
input  wire                                 wb_we_i;
input  wire [(XADDRBITSZ-XMSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(XWORDBITSZ/8) -1 : 0]         wb_sel_i;
input  wire [XWORDBITSZ -1 : 0]             wb_dat_i;
output wire                                 wb_bsy_o;
output reg                                  wb_ack_o;
output reg  [XWORDBITSZ -1 : 0]             wb_dat_o;
output wire [(WORDBITSZ-MSBSZIGN) : 0]      wb_mapsz_o;

output reg  irq_stb_o;
input  wire irq_rdy_i;

assign activity = ~((sdcmd_e ? sdcmd_o : sdcmd_i) & (|sddat_e ? |sddat_o : |sddat_i));

assign wb_bsy_o = 1'b0;

assign wb_mapsz_o = MAPSZ;

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

reg                                 wb_stb_r;
reg                                 wb_we_r;
reg [(XADDRBITSZ-XMSBSZIGN) -1 : 0] wb_addr_r;
reg [(XWORDBITSZ/8) -1 : 0]         wb_sel_r;
reg [XWORDBITSZ -1 : 0]             wb_dat_r;

wire [(XWORDBITSZ-XMSBSZIGN) -1 : 0] _wb_addr_r;
addr #(
	.WORDBITSZ (XWORDBITSZ)
) addr (
	 .addr_i (wb_addr_r)
	,.sel_i  (wb_sel_r)
	,.addr_o (_wb_addr_r)
);
wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] addr_w = _wb_addr_r[(WORDBITSZ-MSBSZIGN) -1 : CLOG2WORDBITSZBY8];

wire cmd_reset = (wb_stb_r && (addr_w == ((CMDRESET * (WORDBITSZ/8) + PHYBLKSZ) >> CLOG2WORDBITSZBY8)));
wire cmd_swap  = (wb_stb_r && (addr_w == ((CMDSWAP  * (WORDBITSZ/8) + PHYBLKSZ) >> CLOG2WORDBITSZBY8)));
wire cmd_read  = (wb_stb_r && (addr_w == ((CMDREAD  * (WORDBITSZ/8) + PHYBLKSZ) >> CLOG2WORDBITSZBY8)));
wire cmd_write = (wb_stb_r && (addr_w == ((CMDWRITE * (WORDBITSZ/8) + PHYBLKSZ) >> CLOG2WORDBITSZBY8)));

wire phy_tx_pop_o, phy_rx_push_o;

wire [32 -1 : 0] phy_rx_data_o;
reg  [32 -1 : 0] phy_tx_data_i; // ### comb-block-reg.

reg phy_cmd_data_i;

reg [XADDRBITSZ -1 : 0] phy_cmd_addr_i;

wire [XADDRBITSZ -1 : 0] phy_blkcnt_o;

wire phy_bsy_o;
wire phy_err_o;

// A phy reset is done when "rst_i" is high or when CMDRESET is issued.
// Since "rst_i" is also used to signal whether the device is under power,
// a controller reset will be done as soon as the device is powered-on.
wire phy_rst_w = (rst_i || (wb_stb_r && wb_we_r && cmd_reset));

reg phy_cmd_empty_i;

wire phy_cmd_pop_o;

sdcard_sdio_phy #(
	 .CLKFREQ    (CLKFREQ)
	,.PHYCLKFREQ (PHYCLKFREQ)
) sdcard_phy (

	 .rst_i (phy_rst_w)

	,.clk_i (clk_i)

	,.clk_phy_i (clk_phy_i)

	,.sdclk_o (sdclk_o)
	,.sdcmd_i (sdcmd_i) ,.sdcmd_o (sdcmd_o) ,.sdcmd_e (sdcmd_e)
	,.sddat_i (sddat_i) ,.sddat_o (sddat_o) ,.sddat_e (sddat_e)

	,.cmd_pop_o   (phy_cmd_pop_o)
	,.cmd_data_i  (phy_cmd_data_i)
	,.cmd_addr_i  (phy_cmd_addr_i)
	,.cmd_empty_i (phy_cmd_empty_i)

	,.rx_push_o (phy_rx_push_o)
	,.rx_data_o (phy_rx_data_o)

	,.tx_pop_o   (phy_tx_pop_o)
	,.tx_data_i  (phy_tx_data_i)

	,.blkcnt_o (phy_blkcnt_o)

	,.bsy_o (phy_bsy_o)
	,.err_o (phy_err_o)
);

// When the value of this register is 1, "phy" has
// access to cache1 otherwise it has access to cache0.
// The cache not being accessed by "phy" is accessed
// by the memory interface.
reg cachesel;

// Register keeping track of the cache word location the PHY will access next.
reg [CLOG2PHYBLKSZ -1 : 0] cachephyaddr;

// Nets set to the index within the respective cache. Each cache element is XWORDBITSZ bits.
wire [(CLOG2PHYBLKSZ-CLOG2XWORDBITSZBY8) -1 : 0] cache0addr =
	cachesel ? wb_addr_r : cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2XWORDBITSZBY8];
wire [(CLOG2PHYBLKSZ-CLOG2XWORDBITSZBY8) -1 : 0] cache1addr =
	cachesel ? cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2XWORDBITSZBY8] : wb_addr_r;

wire [XWORDBITSZ -1 : 0] cache0dato;
wire [XWORDBITSZ -1 : 0] cache1dato;

wire [XWORDBITSZ -1 : 0] cachephydata = cachesel ? cache1dato : cache0dato;

// Net set to the value from the PHY to store in the cache.
reg [XWORDBITSZ -1 : 0] phy_rx_data_o_wordselected; // ### comb-always-block-reg.
generate if (XWORDBITSZ == 32) begin
	always @* begin
		phy_rx_data_o_wordselected = phy_rx_data_o;
	end
end endgenerate
generate if (XWORDBITSZ == 64) begin
	always @* begin
		phy_rx_data_o_wordselected =
			(cachephyaddr[2] == 0) ? {cachephydata[63:32], phy_rx_data_o} :
			                         {                     phy_rx_data_o, cachephydata[31:0]};
	end
end endgenerate
generate if (XWORDBITSZ == 128) begin
	always @* begin
		phy_rx_data_o_wordselected =
			(cachephyaddr[3:2] == 0)  ? {cachephydata[127:32], phy_rx_data_o} :
			(cachephyaddr[3:2] == 1)  ? {cachephydata[127:64], phy_rx_data_o, cachephydata[31:0]} :
			(cachephyaddr[3:2] == 2)  ? {cachephydata[127:96], phy_rx_data_o, cachephydata[63:0]} :
			                            {                      phy_rx_data_o, cachephydata[95:0]};
	end
end endgenerate
generate if (XWORDBITSZ == 256) begin
	always @* begin
		phy_rx_data_o_wordselected =
			(cachephyaddr[4:2] == 0) ? {cachephydata[255:32],  phy_rx_data_o} :
			(cachephyaddr[4:2] == 1) ? {cachephydata[255:64],  phy_rx_data_o, cachephydata[31:0]} :
			(cachephyaddr[4:2] == 2) ? {cachephydata[255:96],  phy_rx_data_o, cachephydata[63:0]} :
			(cachephyaddr[4:2] == 3) ? {cachephydata[255:128], phy_rx_data_o, cachephydata[95:0]} :
			(cachephyaddr[4:2] == 4) ? {cachephydata[255:160], phy_rx_data_o, cachephydata[127:0]} :
			(cachephyaddr[4:2] == 5) ? {cachephydata[255:192], phy_rx_data_o, cachephydata[159:0]} :
			(cachephyaddr[4:2] == 6) ? {cachephydata[255:224], phy_rx_data_o, cachephydata[191:0]} :
			                           {                       phy_rx_data_o, cachephydata[223:0]};
	end
end endgenerate

reg [XWORDBITSZ -1 : 0] _wb_sel_r; // ### comb-always-block-reg.
generate if (XWORDBITSZ == 32) begin
	always @* begin
		_wb_sel_r = {{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
	end
end endgenerate
generate if (XWORDBITSZ == 64) begin
	always @* begin
		_wb_sel_r = {
			{8{wb_sel_r[7]}}, {8{wb_sel_r[6]}}, {8{wb_sel_r[5]}}, {8{wb_sel_r[4]}},
			{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
	end
end endgenerate
generate if (XWORDBITSZ == 128) begin
	always @* begin
		_wb_sel_r = {
			{8{wb_sel_r[15]}}, {8{wb_sel_r[14]}}, {8{wb_sel_r[13]}}, {8{wb_sel_r[12]}},
			{8{wb_sel_r[11]}}, {8{wb_sel_r[10]}}, {8{wb_sel_r[9]}},  {8{wb_sel_r[8]}},
			{8{wb_sel_r[7]}},  {8{wb_sel_r[6]}},  {8{wb_sel_r[5]}},  {8{wb_sel_r[4]}},
			{8{wb_sel_r[3]}},  {8{wb_sel_r[2]}},  {8{wb_sel_r[1]}},  {8{wb_sel_r[0]}}};
	end
end endgenerate
generate if (XWORDBITSZ == 256) begin
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

wire [XWORDBITSZ -1 : 0] cachedato = (cachesel ? cache0dato : cache1dato);

wire [XWORDBITSZ -1 : 0] _wb_dat_r = ((wb_dat_r & _wb_sel_r) | (cachedato & ~_wb_sel_r));
// Nets set to the value to write in the respective cache.
wire [XWORDBITSZ -1 : 0] cache0dati = cachesel ? _wb_dat_r : phy_rx_data_o_wordselected[XWORDBITSZ -1 : 0];
wire [XWORDBITSZ -1 : 0] cache1dati = cachesel ? phy_rx_data_o_wordselected[XWORDBITSZ -1 : 0] : _wb_dat_r;

// phy_tx_data_i is set to the value read from the respective cache.
generate if (XWORDBITSZ == 32) begin
	always @* begin
		phy_tx_data_i = cachesel ? cache1dato : cache0dato;
	end
end endgenerate
generate if (XWORDBITSZ == 64) begin
	always @* begin
		if (cachephyaddr[2] == 0)
			phy_tx_data_i = cachesel ? cache1dato[31:0] : cache0dato[31:0];
		else
			phy_tx_data_i = cachesel ? cache1dato[63:32] : cache0dato[63:32];
	end
end endgenerate
generate if (XWORDBITSZ == 128) begin
	always @* begin
		if (cachephyaddr[3:2] == 0)
			phy_tx_data_i = cachesel ? cache1dato[31:0] : cache0dato[31:0];
		else if (cachephyaddr[3:2] == 1)
			phy_tx_data_i = cachesel ? cache1dato[63:32] : cache0dato[63:32];
		else if (cachephyaddr[3:2] == 2)
			phy_tx_data_i = cachesel ? cache1dato[95:64] : cache0dato[95:64];
		else
			phy_tx_data_i = cachesel ? cache1dato[127:96] : cache0dato[127:96];
	end
end endgenerate
generate if (XWORDBITSZ == 256) begin
	always @* begin
		if (cachephyaddr[4:2] == 0)
			phy_tx_data_i = cachesel ? cache1dato[31:0] : cache0dato[31:0];
		else if (cachephyaddr[4:2] == 1)
			phy_tx_data_i = cachesel ? cache1dato[63:32] : cache0dato[63:32];
		else if (cachephyaddr[4:2] == 2)
			phy_tx_data_i = cachesel ? cache1dato[95:64] : cache0dato[95:64];
		else if (cachephyaddr[4:2] == 3)
			phy_tx_data_i = cachesel ? cache1dato[127:96] : cache0dato[127:96];
		else if (cachephyaddr[4:2] == 4)
			phy_tx_data_i = cachesel ? cache1dato[159:128] : cache0dato[159:128];
		else if (cachephyaddr[4:2] == 5)
			phy_tx_data_i = cachesel ? cache1dato[191:160] : cache0dato[191:160];
		else if (cachephyaddr[4:2] == 6)
			phy_tx_data_i = cachesel ? cache1dato[223:192] : cache0dato[223:192];
		else
			phy_tx_data_i = cachesel ? cache1dato[255:224] : cache0dato[255:224];
	end
end endgenerate

// Register used to detect a falling edge of "irq_rdy_i".
reg  irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

// Register used to detect a rising edge of "phy_err_o".
reg  phy_err_o_r;
wire phy_err_o_posedge = (phy_err_o && !phy_err_o_r);

// Register used to detect a falling edge of "phy_bsy_o".
reg  phy_bsy_o_r;
wire phy_bsy_o_negedge = (!phy_bsy_o && phy_bsy_o_r);

wire cache_rdop = (wb_stb_r && !wb_we_r && wb_addr_r < (PHYBLKSZ >> CLOG2XWORDBITSZBY8));
wire cache_wrop = (wb_stb_r && wb_we_r  && wb_addr_r < (PHYBLKSZ >> CLOG2XWORDBITSZBY8));

// Nets set to 1 when a read/write request is done to their respective cache.
wire cache0rd = cachesel ? cache_rdop : phy_tx_pop_o;
wire cache1rd = cachesel ? phy_tx_pop_o : cache_rdop;
wire cache0wr = cachesel ? cache_wrop : phy_rx_push_o;
wire cache1wr = cachesel ? phy_rx_push_o : cache_wrop;

reg [XWORDBITSZ -1 : 0] cache0 [(PHYBLKSZ/(XWORDBITSZ/8)) -1 : 0];
reg [XWORDBITSZ -1 : 0] cache1 [(PHYBLKSZ/(XWORDBITSZ/8)) -1 : 0];

assign cache0dato = cache0[cache0addr];
assign cache1dato = cache1[cache1addr];

always @ (posedge clk_i) begin
	if (cache0wr)
		cache0[cache0addr] <= cache0dati;
end

always @ (posedge clk_i) begin
	if (cache1wr)
		cache1[cache1addr] <= cache1dati;
end

reg [2 -1 : 0] status; // ### comb-block-reg.
always @* begin
	if (rst_i)
		status = STATUSPOWEROFF;
	else if (phy_err_o)
		status = STATUSERROR;
	else if (phy_rst_w || phy_bsy_o)
		status = STATUSBUSY;
	else
		status = STATUSREADY;
end

reg [XWORDBITSZ -1 : 0] wb_dat_o_; // ### comb-block-reg.
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

always @ (posedge clk_i) begin
	wb_stb_r <= wb_stb_r_ ;
	wb_ack_o <= wb_stb_r;
end

wire [(CLOG2XWORDBITSZBY8DIFF+CLOG2WORDBITSZ)-1:0] wb_dat_shift;
generate if (XWORDBITSZ == WORDBITSZ) begin
assign wb_dat_shift = 0;
end else begin
assign wb_dat_shift = {_wb_addr_r[CLOG2XWORDBITSZBY8-1:CLOG2WORDBITSZBY8], {CLOG2WORDBITSZ{1'b0}}};
end endgenerate

always @ (posedge clk_i) begin
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_sel_r <= wb_sel_i;
		wb_dat_r <= wb_dat_i;
	end
end

always @ (posedge clk_i) begin
	// Logic that flips the value of cachesel when CMDSWAP is issued.
	if (wb_stb_r && wb_we_r && cmd_swap)
		cachesel <= ~cachesel;
end

always @ (posedge clk_i) begin
	if (rst_i || (phy_cmd_pop_o && !phy_cmd_empty_i))
		phy_cmd_empty_i <= 1'b1;
	else if (wb_we_r && (cmd_read || cmd_write)) begin
		phy_cmd_empty_i <= 1'b0;
		phy_cmd_data_i <= cmd_write;
		phy_cmd_addr_i <= (wb_dat_r >> wb_dat_shift);
	end
end

always @ (posedge clk_i) begin
	if (cache_rdop)
		wb_dat_o <= cachedato;
	else if (wb_stb_r && !wb_we_r)
		wb_dat_o <= (wb_dat_o_ << wb_dat_shift);
end

always @ (posedge clk_i) begin
	// Logic that sets cachephyaddr.
	// Increment cachephyaddr whenever the PHY is not busy and requesting
	// a read/write; reset cachephyaddr to 0 whenever "phy_bsy_o" is low.
	if (!phy_bsy_o)
		cachephyaddr <= 0;
	else if (cachesel ? (cache1rd | cache1wr) : (cache0rd | cache0wr))
		cachephyaddr <= cachephyaddr + 4;
end

always @ (posedge clk_i) begin
	// Logic to set/clear irq_stb_o.
	// A rising edge of "phy_err_o" means that an error occured
	// while the controller was processing the previous
	// operation, which is either initialization, read or write;
	// a falling edge of "phy_bsy_o" means that the controller
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
		irq_stb_o <= (phy_err_o_posedge || phy_bsy_o_negedge);
end

always @ (posedge clk_i) begin
	// Sampling used for edge detection.
	irq_rdy_i_r <= irq_rdy_i;
	phy_err_o_r <= phy_err_o;
	phy_bsy_o_r <= phy_bsy_o;
end

endmodule
