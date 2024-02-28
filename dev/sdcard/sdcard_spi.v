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
// Only ARCHBITSZ bits memory operations are valid throughout the mapping.
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

`ifdef SIMULATION
`include "./sdcard_sim_phy.v"
`else
`include "./sdcard_spi_phy.v"
`endif

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

	,intrqst_o
	,intrdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

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

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

`ifndef SIMULATION
output wire sclk_o;
output wire di_o;
input  wire do_i;
output wire cs_o;
`endif

input  wire                        wb_cyc_i;
input  wire                        wb_stb_i;
input  wire                        wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     wb_dat_i;
output wire                        wb_bsy_o;
output reg                         wb_ack_o;
output reg  [ARCHBITSZ -1 : 0]     wb_dat_o;
output wire [ARCHBITSZ -1 : 0]     wb_mapsz_o;

output reg  intrqst_o;
input  wire intrdy_i;

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

reg                    wb_stb_r;
reg                    wb_we_r;
reg [ADDRBITSZ -1 : 0] wb_addr_r;
reg [ARCHBITSZ -1 : 0] wb_dat_r;

wire cmd_reset = (wb_addr_r == ((CMDRESET * (ARCHBITSZ/8) + PHYBLKSZ) >> CLOG2ARCHBITSZBY8));
wire cmd_swap  = (wb_addr_r == ((CMDSWAP  * (ARCHBITSZ/8) + PHYBLKSZ) >> CLOG2ARCHBITSZBY8));
wire cmd_read  = (wb_addr_r == ((CMDREAD  * (ARCHBITSZ/8) + PHYBLKSZ) >> CLOG2ARCHBITSZBY8));
wire cmd_write = (wb_addr_r == ((CMDWRITE * (ARCHBITSZ/8) + PHYBLKSZ) >> CLOG2ARCHBITSZBY8));

wire phy_tx_pop_o, phy_rx_push_o;

wire [8 -1 : 0] phy_rx_data_o;
reg  [8 -1 : 0] phy_tx_data_i; // ### comb-block-reg.

reg phy_cmd_data_i;

reg [ADDRBITSZ -1 : 0] phy_cmd_addr_i;

wire [ADDRBITSZ -1 : 0] phy_blkcnt_o;

wire phy_err_o;

// A phy reset is done when "rst_i" is high or when
// CMDRESET is issued with its argument non-null.
// Since "rst_i" is also used to signal whether
// the device is under power, a controller reset
// will be done as soon as the device is powered-on.
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

// Nets set to the index within the respective cache. Each cache element is ARCHBITSZ bits.
wire [(CLOG2PHYBLKSZ-CLOG2ARCHBITSZBY8) -1 : 0] cache0addr =
	cachesel ? wb_addr_r : cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2ARCHBITSZBY8];
wire [(CLOG2PHYBLKSZ-CLOG2ARCHBITSZBY8) -1 : 0] cache1addr =
	cachesel ? cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2ARCHBITSZBY8] : wb_addr_r;

wire [ARCHBITSZ -1 : 0] cache0dato;
wire [ARCHBITSZ -1 : 0] cache1dato;

wire [ARCHBITSZ -1 : 0] cachephydata = cachesel ? cache1dato : cache0dato;

// Net set to the value from the PHY to store in the cache.
reg [ARCHBITSZ -1 : 0] phy_rx_data_o_byteselected; // ### comb-always-block-reg.
generate if (ARCHBITSZ == 16) begin
	always @* begin
		phy_rx_data_o_byteselected =
			(cachephyaddr[0] == 0) ? {cachephydata[15:8], phy_rx_data_o} :
			                         {phy_rx_data_o, cachephydata[7:0]};
	end
end endgenerate
generate if (ARCHBITSZ == 32) begin
	always @* begin
		phy_rx_data_o_byteselected =
			(cachephyaddr[1:0] == 0) ? {cachephydata[31:8], phy_rx_data_o} :
			(cachephyaddr[1:0] == 1) ? {cachephydata[31:16], phy_rx_data_o, cachephydata[7:0]} :
			(cachephyaddr[1:0] == 2) ? {cachephydata[31:24], phy_rx_data_o, cachephydata[15:0]} :
			                           {phy_rx_data_o, cachephydata[23:0]};
	end
end endgenerate
generate if (ARCHBITSZ == 64) begin
	always @* begin
		phy_rx_data_o_byteselected =
			(cachephyaddr[2:0] == 0) ? {cachephydata[63:8], phy_rx_data_o} :
			(cachephyaddr[2:0] == 1) ? {cachephydata[63:16], phy_rx_data_o, cachephydata[7:0]} :
			(cachephyaddr[2:0] == 2) ? {cachephydata[63:24], phy_rx_data_o, cachephydata[15:0]} :
			(cachephyaddr[2:0] == 3) ? {cachephydata[63:32], phy_rx_data_o, cachephydata[23:0]} :
			(cachephyaddr[2:0] == 4) ? {cachephydata[63:40], phy_rx_data_o, cachephydata[31:0]} :
			(cachephyaddr[2:0] == 5) ? {cachephydata[63:48], phy_rx_data_o, cachephydata[39:0]} :
			(cachephyaddr[2:0] == 6) ? {cachephydata[63:56], phy_rx_data_o, cachephydata[47:0]} :
			                           {phy_rx_data_o, cachephydata[55:0]};
	end
end endgenerate

// Nets set to the value to write in the respective cache.
wire [ARCHBITSZ -1 : 0] cache0dati = cachesel ? wb_dat_r : phy_rx_data_o_byteselected[ARCHBITSZ -1 : 0];
wire [ARCHBITSZ -1 : 0] cache1dati = cachesel ? phy_rx_data_o_byteselected[ARCHBITSZ -1 : 0] : wb_dat_r;

// phy_tx_data_i is set to the value read from the respective cache.
generate if (ARCHBITSZ == 16) begin
	always @* begin
		if (cachephyaddr[0] == 0)
			phy_tx_data_i = cachesel ? cache1dato[7:0] : cache0dato[7:0];
		else
			phy_tx_data_i = cachesel ? cache1dato[15:8] : cache0dato[15:8];
	end
end endgenerate
generate if (ARCHBITSZ == 32) begin
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
generate if (ARCHBITSZ == 64) begin
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

// Register used to detect a falling edge of "intrdy_i".
reg  intrdy_i_r;
wire intrdy_i_negedge = (!intrdy_i && intrdy_i_r);

// Register used to detect a rising edge of "phy_err_o".
reg  phy_err_o_r;
wire phy_err_o_posedge = (phy_err_o && !phy_err_o_r);

// Register used to detect a falling edge of "phy_bsy_w".
reg  phy_bsy_w_r;
wire phy_bsy_w_negedge = (!phy_bsy_w && phy_bsy_w_r);

wire cache_rdop = (wb_stb_r && !wb_we_r && wb_addr_r < (PHYBLKSZ >> CLOG2ARCHBITSZBY8));
wire cache_wrop = (wb_stb_r && wb_we_r  && wb_addr_r < (PHYBLKSZ >> CLOG2ARCHBITSZBY8));

// Nets set to 1 when a read/write request is done to their respective cache.
wire cache0rd = cachesel ? cache_rdop : phy_tx_pop_o;
wire cache1rd = cachesel ? phy_tx_pop_o : cache_rdop;
wire cache0wr = cachesel ? cache_wrop : phy_rx_push_o;
wire cache1wr = cachesel ? phy_rx_push_o : cache_wrop;

reg [ARCHBITSZ -1 : 0] cache0 [(PHYBLKSZ/(ARCHBITSZ/8)) -1 : 0];
reg [ARCHBITSZ -1 : 0] cache1 [(PHYBLKSZ/(ARCHBITSZ/8)) -1 : 0];

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

wire wb_stb_r_ = (wb_cyc_i && wb_stb_i);

always @ (posedge clk_i) begin

	wb_stb_r <= wb_stb_r_ ;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
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
		phy_cmd_addr_i <= wb_dat_r;
	end

	wb_ack_o <= wb_stb_r;

	if (cache_rdop)
		wb_dat_o <= cachesel ? cache0dato : cache1dato;
	else if (wb_stb_r && !wb_we_r) begin
		if (cmd_reset)
			wb_dat_o <= {{30{1'b0}}, status};
		else if (cmd_swap)
			wb_dat_o <= PHYBLKSZ;
		else if (cmd_read || cmd_write)
			wb_dat_o <= phy_blkcnt_o;
	end

	// Logic that sets cachephyaddr.
	// Increment cachephyaddr whenever the PHY is not busy and requesting
	// a read/write; reset cachephyaddr to 0 whenever "phy_bsy_w" is low.
	if (!phy_bsy_w)
		cachephyaddr <= 0;
	else if (cachesel ? (cache1rd | cache1wr) : (cache0rd | cache0wr))
		cachephyaddr <= cachephyaddr + 1'b1;

	// Logic to set/clear intrqst_o.
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
		intrqst_o <= 1'b0;
	else if (intrqst_o)
		intrqst_o <= !intrdy_i_negedge;
	else
		intrqst_o <= (phy_err_o_posedge || phy_bsy_w_negedge);

	// Sampling used for edge detection.
	intrdy_i_r <= intrdy_i;
	phy_err_o_r <= phy_err_o;
	phy_bsy_w_r <= phy_bsy_w;
end

endmodule
