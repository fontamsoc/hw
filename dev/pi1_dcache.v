// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// TODO: Documentation:
// rst_i: Reset cache cancelling on-going slave memory operation.
// crst_i: Reset cache without cancelling on-going slave memory operation.
// cenable_i: Disable the cache for next memory operation currently
// 	on m_pi1_op_i when m_pi1_rdy_o is high.
// cmiss_i: When cenable_i true, always cachemiss to force slave memory operation.
// conly_i: Cache becomes a bram if high on the next clock active edge.
// 	crst_i and cenable_i have no effects.
// 	master memory operations do not become slave memory operations.
// 	Cache resumes normal operation if low on the next clock active edge,
// 	and (rst_i || crst_i) is high.
// TODO: Documentation:
// CACHEWAYCOUNT
// 	Number of cache ways.
// 	It must be non-null and a power of 2.

`ifndef PI1_DCACHE_V
`define PI1_DCACHE_V

`include "lib/fifo_fwft.v"
`include "lib/ram/bram.v"

module pi1_dcache (

	 rst_i

	,clk_i

	,crst_i

	,cenable_i

	,cmiss_i

	,conly_i

	,m_pi1_op_i
	,m_pi1_addr_i
	,m_pi1_data_i
	,m_pi1_data_o
	,m_pi1_sel_i
	,m_pi1_rdy_o

	,s_pi1_op_o
	,s_pi1_addr_o
	,s_pi1_data_o
	,s_pi1_data_i
	,s_pi1_sel_o
	,s_pi1_rdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 0;

parameter CACHESETCOUNT = 2;
parameter CACHEWAYCOUNT = 1;

parameter INITFILE = "";

localparam CLOG2CACHESETCOUNT = clog2(CACHESETCOUNT);
localparam CLOG2CACHEWAYCOUNT = clog2(CACHEWAYCOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input wire crst_i;

input wire cenable_i;

input wire cmiss_i;

input wire conly_i;

input  wire [2 -1 : 0]             m_pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     m_pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     m_pi1_data_i;
output wire [ARCHBITSZ -1 : 0]     m_pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] m_pi1_sel_i;
output wire                        m_pi1_rdy_o;

output wire [2 -1 : 0]             s_pi1_op_o;
output wire [ADDRBITSZ -1 : 0]     s_pi1_addr_o;
output wire [ARCHBITSZ -1 : 0]     s_pi1_data_o;
input  wire [ARCHBITSZ -1 : 0]     s_pi1_data_i;
output wire [(ARCHBITSZ/8) -1 : 0] s_pi1_sel_o;
input  wire                        s_pi1_rdy_i;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg m_pi1_rdy_o_;

wire cachemiss;

reg conly_r;

assign m_pi1_rdy_o = (conly_r || (m_pi1_rdy_o_ && !cachemiss));

wire slvwriterdy;

wire [(CLOG2CACHESETCOUNT +1) -1 : 0] bufusage;

wire buffull;
wire bufempty;

// Note that m_pi1_rdy_o get set to 0 if the data to write in slv will make its buffer full.
wire bufpush = (m_pi1_op_i == PIWROP && m_pi1_rdy_o && !conly_r);

wire [ADDRBITSZ -1 : 0] addrbufdato;

fifo_fwft #(

	 .WIDTH (ADDRBITSZ)
	,.DEPTH (CACHESETCOUNT)

) addrbuf (

	 .rst_i (rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (slvwriterdy)
	,.data_o    (addrbufdato)
	,.empty_o   ()

	,.clk_push_i (clk_i)
	,.push_i     (bufpush)
	,.data_i     (m_pi1_addr_i)
	,.full_o     ()
);

wire [ARCHBITSZ -1 : 0] databufdato;

fifo_fwft #(

	 .WIDTH (ARCHBITSZ)
	,.DEPTH (CACHESETCOUNT)

) databuf (

	 .rst_i (rst_i)

	,.usage_o (bufusage)

	,.clk_pop_i (clk_i)
	,.pop_i     (slvwriterdy)
	,.data_o    (databufdato)
	,.empty_o   (bufempty)

	,.clk_push_i (clk_i)
	,.push_i     (bufpush)
	,.data_i     (m_pi1_data_i)
	,.full_o     (buffull)
);

wire [(ARCHBITSZ/8) -1 : 0] bytselbufdato;

fifo_fwft #(

	 .WIDTH (ARCHBITSZ/8)
	,.DEPTH (CACHESETCOUNT)

) bytselbuf (

	 .rst_i (rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (slvwriterdy)
	,.data_o    (bytselbufdato)
	,.empty_o   ()

	,.clk_push_i (clk_i)
	,.push_i     (bufpush)
	,.data_i     (m_pi1_sel_i)
	,.full_o     ()
);

// ### Net declared as reg so as to be useable
// ### by verilog within the always block.
reg cachehit;

// Register used to hold the value of the input "m_pi1_op_i".
reg [2 -1 : 0] m_pi1_op_i_hold;

// Net which is 1 when PIRDOP immediately follows PIWROP
// and cachedati must be returned instead of cachedato.
wire usesampled;

assign cachemiss = ((m_pi1_op_i_hold == PIRDOP) && !cachehit && !usesampled);

// Net set to 1 to make a request to retrieve data from slv.
wire slvreadrqst = ((cachemiss || (m_pi1_op_i_hold == PIRWOP)) && !conly_r);

// Register set to 1 when reading data from slv.
reg slvreading;

// Register set to 1 when writing data to slv.
reg slvwriting;

wire slvnotreading = (!slvreading /**/|| s_pi1_rdy_i/**/);
wire slvnotwriting = (!slvwriting /**/|| s_pi1_rdy_i/**/);

// Note that "slvreadrdy" is not raised until all data
// in the buffer, used for writing slv, has been written.
wire slvreadrdy = (s_pi1_rdy_i && slvnotreading && (bufempty && slvreadrqst) && slvnotwriting);

// This register is set to 1, when the memory operation issued was PIRWOP.
reg slvreadwriterqst;

// Net set to 1 when a request to retrieve data from slv has completed.
wire slvreadrqstdone = (slvreading && s_pi1_rdy_i);

assign slvwriterdy = (s_pi1_rdy_i && slvnotwriting && (!bufempty || (slvreadwriterqst && !slvreadrqstdone)) && slvnotreading);

// Register used to hold the value of the input "m_pi1_addr_i".
reg [ADDRBITSZ -1 : 0] m_pi1_addr_i_hold;

// Register used to hold the value of the input "m_pi1_data_i".
reg [ARCHBITSZ -1 : 0] m_pi1_data_i_hold;

// Register used to hold the value of the input "m_pi1_sel_i".
reg [(256/*ARCHBITSZ*//8) -1 : 0] m_pi1_sel_i_hold;

assign s_pi1_op_o   = {slvreadrdy, slvwriterdy};
assign s_pi1_addr_o = (slvreadrdy ? m_pi1_addr_i_hold : addrbufdato);
assign s_pi1_data_o = ((slvwriterdy && slvreadrdy) ? m_pi1_data_i_hold : databufdato);
assign s_pi1_sel_o  = (slvreadrdy ? m_pi1_sel_i_hold[(ARCHBITSZ/8) -1 : 0] : bytselbufdato);

// Bitsize of a cache tag.
localparam CACHETAGBITSIZE = (ADDRBITSZ - CLOG2CACHESETCOUNT);

// The caching is 1way set associative.

reg cacheactive; // The data cache is active when the value of this register is 1.

wire cacherdy = ((cacheactive && cenable_i && !crst_i) || conly_r);

wire cacheen = (cacherdy && m_pi1_op_i != PINOOP && m_pi1_rdy_o);

reg cacherdy_hold;

reg cachewe_;

wire cachewe = (slvreadrqstdone ? (cacherdy_hold && !slvreadwriterqst) : cachewe_);

wire [CACHETAGBITSIZE -1 : 0] cachetago [CACHEWAYCOUNT -1 : 0];

wire [ARCHBITSZ -1 : 0] cachedata = (slvreadrqstdone ? s_pi1_data_i : m_pi1_data_i_hold);

// ### Net declared as reg so as to be useable by verilog within the always block.
reg [ARCHBITSZ -1 : 0] cachedatibitsel;
always @* begin
	if (ARCHBITSZ == 16)
		cachedatibitsel = {{8{m_pi1_sel_i_hold[1]}}, {8{m_pi1_sel_i_hold[0]}}};
	else if (ARCHBITSZ == 32)
		cachedatibitsel = {{8{m_pi1_sel_i_hold[3]}}, {8{m_pi1_sel_i_hold[2]}}, {8{m_pi1_sel_i_hold[1]}}, {8{m_pi1_sel_i_hold[0]}}};
	else if (ARCHBITSZ == 64)
		cachedatibitsel = {
			{8{m_pi1_sel_i_hold[7]}}, {8{m_pi1_sel_i_hold[6]}}, {8{m_pi1_sel_i_hold[5]}}, {8{m_pi1_sel_i_hold[4]}},
			{8{m_pi1_sel_i_hold[3]}}, {8{m_pi1_sel_i_hold[2]}}, {8{m_pi1_sel_i_hold[1]}}, {8{m_pi1_sel_i_hold[0]}}};
	else if (ARCHBITSZ == 128)
		cachedatibitsel = {
			{8{m_pi1_sel_i_hold[15]}}, {8{m_pi1_sel_i_hold[14]}}, {8{m_pi1_sel_i_hold[13]}}, {8{m_pi1_sel_i_hold[12]}},
			{8{m_pi1_sel_i_hold[11]}}, {8{m_pi1_sel_i_hold[10]}}, {8{m_pi1_sel_i_hold[9]}}, {8{m_pi1_sel_i_hold[8]}},
			{8{m_pi1_sel_i_hold[7]}}, {8{m_pi1_sel_i_hold[6]}}, {8{m_pi1_sel_i_hold[5]}}, {8{m_pi1_sel_i_hold[4]}},
			{8{m_pi1_sel_i_hold[3]}}, {8{m_pi1_sel_i_hold[2]}}, {8{m_pi1_sel_i_hold[1]}}, {8{m_pi1_sel_i_hold[0]}}};
	else if (ARCHBITSZ == 256)
		cachedatibitsel = {
			{8{m_pi1_sel_i_hold[31]}}, {8{m_pi1_sel_i_hold[30]}}, {8{m_pi1_sel_i_hold[29]}}, {8{m_pi1_sel_i_hold[28]}},
			{8{m_pi1_sel_i_hold[27]}}, {8{m_pi1_sel_i_hold[26]}}, {8{m_pi1_sel_i_hold[25]}}, {8{m_pi1_sel_i_hold[24]}},
			{8{m_pi1_sel_i_hold[23]}}, {8{m_pi1_sel_i_hold[22]}}, {8{m_pi1_sel_i_hold[21]}}, {8{m_pi1_sel_i_hold[20]}},
			{8{m_pi1_sel_i_hold[19]}}, {8{m_pi1_sel_i_hold[18]}}, {8{m_pi1_sel_i_hold[17]}}, {8{m_pi1_sel_i_hold[16]}},
			{8{m_pi1_sel_i_hold[15]}}, {8{m_pi1_sel_i_hold[14]}}, {8{m_pi1_sel_i_hold[13]}}, {8{m_pi1_sel_i_hold[12]}},
			{8{m_pi1_sel_i_hold[11]}}, {8{m_pi1_sel_i_hold[10]}}, {8{m_pi1_sel_i_hold[9]}}, {8{m_pi1_sel_i_hold[8]}},
			{8{m_pi1_sel_i_hold[7]}}, {8{m_pi1_sel_i_hold[6]}}, {8{m_pi1_sel_i_hold[5]}}, {8{m_pi1_sel_i_hold[4]}},
			{8{m_pi1_sel_i_hold[3]}}, {8{m_pi1_sel_i_hold[2]}}, {8{m_pi1_sel_i_hold[1]}}, {8{m_pi1_sel_i_hold[0]}}};
	else
		cachedatibitsel = {ARCHBITSZ{1'b0}};
end

// Register used to hold cache-way index to write next.
reg [CLOG2CACHEWAYCOUNT -1 : 0] cachewaywriteidx;

// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg                             cachetagwayhit;
reg [CLOG2CACHEWAYCOUNT -1 : 0] cachetagwayhitidx;

wire [ARCHBITSZ -1 : 0] cachedato [CACHEWAYCOUNT -1 : 0];

// Net set to the value to write in the cache.
wire [ARCHBITSZ -1 : 0] cachedati =
	(cachedata & cachedatibitsel) | (cachedato[cachetagwayhit ? cachetagwayhitidx : cachewaywriteidx] & ~cachedatibitsel);

reg cachewe__sampled;

reg cacheen_sampled;

reg [ADDRBITSZ -1 : 0] m_pi1_addr_i_hold_sampled;

assign usesampled = (
	cachewe__sampled && cacheen_sampled &&
	(m_pi1_addr_i_hold == m_pi1_addr_i_hold_sampled));

reg [ARCHBITSZ -1 : 0] cachedati_sampled;

reg [ARCHBITSZ -1 : 0] s_pi1_data_i_hold;

// ### Net declared as reg so as to be useable
// ### by verilog within the always block.
reg [CLOG2CACHEWAYCOUNT -1 : 0] cachewayhitidx;

assign m_pi1_data_o = (m_pi1_op_i_hold == PIRDOP) ?
	(usesampled ? cachedati_sampled : cachedato[cachewayhitidx]) : s_pi1_data_i_hold;

wire cacheoff = !cacheactive;

// Register used as counter during cache reset.
reg [CLOG2CACHESETCOUNT -1 : 0] cacherstidx;

wire [CACHEWAYCOUNT -1 : 0] cachevalido;

wire [ARCHBITSZ -1 : 0] cachedatabitselo [CACHEWAYCOUNT -1 : 0];

reg cmiss_i_hold;

// ### Net declared as reg so as to be useable
// ### by verilog within the always block.
reg [CACHEWAYCOUNT -1 : 0] cachetaghit;
integer gencachetag_idx;
always @* begin
	cachehit = 0;
	cachewayhitidx = 0;
	cachetagwayhit = 0;
	cachetagwayhitidx = 0;
	for (gencachetag_idx = 0; gencachetag_idx < CACHEWAYCOUNT; gencachetag_idx = gencachetag_idx + 1) begin
		cachetaghit[gencachetag_idx] = (cachevalido[gencachetag_idx] && cacherdy_hold && (m_pi1_addr_i_hold[ADDRBITSZ -1 : CLOG2CACHESETCOUNT] == cachetago[gencachetag_idx]));
		if (!cachehit && !cmiss_i_hold &&
			// There is a cachehit when there is a cache tag hit and the selected bits are in the cache.
			(cachetaghit[gencachetag_idx] && ((cachedatibitsel & cachedatabitselo[gencachetag_idx]) == cachedatibitsel))) begin
			cachehit = 1;
			cachewayhitidx = gencachetag_idx;
		end
		if (!cachetagwayhit && cachetaghit[gencachetag_idx]) begin
			cachetagwayhit = 1;
			cachetagwayhitidx = gencachetag_idx;
		end
	end
end

always @ (posedge clk_i) begin
	if (rst_i)
		cachewaywriteidx <= 0;
	else if (cachewe && !cachetagwayhit) begin
		if (cachewaywriteidx >= (CACHEWAYCOUNT-1))
			cachewaywriteidx <= 0;
		else
			cachewaywriteidx <= cachewaywriteidx + 1'b1;
	end
end

genvar gencache_idx;
generate for (gencache_idx = 0; gencache_idx < CACHEWAYCOUNT; gencache_idx = gencache_idx + 1) begin :gencache

bram #(

	 .SZ (CACHESETCOUNT)
	,.DW (CACHETAGBITSIZE)

) cachetags (

	 .clk0_i  (clk_i)        ,.clk1_i  (clk_i)
	,.en0_i   (cacheen)      ,.en1_i   (1'b1)
	                         ,.we1_i   (cachewe && (cachetagwayhit ? (cachetagwayhitidx == gencache_idx) : (cachewaywriteidx == gencache_idx)))
	,.addr0_i (m_pi1_addr_i) ,.addr1_i (m_pi1_addr_i_hold)
	                         ,.i1      (m_pi1_addr_i_hold[ADDRBITSZ -1 : CLOG2CACHESETCOUNT])
	,.o0      (cachetago[gencache_idx]) ,.o1      ()
);

bram #(

	 .SZ (CACHESETCOUNT)
	,.DW (ARCHBITSZ)

	,.SRCFILE (INITFILE)

) cachedatas (

	 .clk0_i  (clk_i)        ,.clk1_i  (clk_i)
	,.en0_i   (cacheen)      ,.en1_i   (1'b1)
	                         ,.we1_i   (cachewe && (cachetagwayhit ? (cachetagwayhitidx == gencache_idx) : (cachewaywriteidx == gencache_idx)))
	,.addr0_i (m_pi1_addr_i) ,.addr1_i (m_pi1_addr_i_hold)
	                         ,.i1      (cachedati)
	,.o0      (cachedato[gencache_idx]) ,.o1      ()
);

bram #(

	 .SZ (CACHESETCOUNT)
	,.DW (1)

) cachevalids (

	 .clk0_i  (clk_i)          ,.clk1_i  (clk_i)
	,.en0_i   (cacheen)        ,.en1_i   (1'b1)
	                           ,.we1_i   ((cachewe && (cachetagwayhit ? (cachetagwayhitidx == gencache_idx) : (cachewaywriteidx == gencache_idx))) || cacheoff)
	,.addr0_i (m_pi1_addr_i)   ,.addr1_i (cacheoff ? cacherstidx : m_pi1_addr_i_hold)
	                           ,.i1      (cacheoff ? 1'b0 : cacherdy_hold)
	,.o0      (cachevalido[gencache_idx]) ,.o1      ()
);

bram #(

	 .SZ (CACHESETCOUNT)
	,.DW (ARCHBITSZ)

) cachedatabitsels (

	 .clk0_i  (clk_i)               ,.clk1_i  (clk_i)
	,.en0_i   (cacheen)             ,.en1_i   (1'b1)
	                                ,.we1_i   (cachewe && (cachetagwayhit ? (cachetagwayhitidx == gencache_idx) : (cachewaywriteidx == gencache_idx)))
	,.addr0_i (m_pi1_addr_i)        ,.addr1_i (m_pi1_addr_i_hold)
	                                ,.i1      ((cachetaghit[gencache_idx] ? cachedatabitselo[gencache_idx] : {ARCHBITSZ{1'b0}}) | cachedatibitsel)
	,.o0      (cachedatabitselo[gencache_idx]) ,.o1      ()
);

end endgenerate

wire slv_and_buf_rdy = (!slvreadrqst && !slvreading && !buffull);

always @ (posedge clk_i) begin

	if (rst_i)
		m_pi1_op_i_hold <= PINOOP;
	else if (m_pi1_rdy_o) begin
		m_pi1_op_i_hold <= m_pi1_op_i;
		m_pi1_addr_i_hold <= m_pi1_addr_i;
		m_pi1_data_i_hold <= m_pi1_data_i;
		m_pi1_sel_i_hold <= m_pi1_sel_i;
	end else if (s_pi1_op_o == m_pi1_op_i_hold /* note that s_pi1_op_o already depends on s_pi1_rdy_i */)
		m_pi1_op_i_hold <= PINOOP;

	if (rst_i)
		slvreading <= 0;
	else if (slvreading) begin
		if (s_pi1_rdy_i)
			slvreading <= slvreadrdy;
	end else if (slvreadrdy)
		slvreading <= 1;

	if (rst_i)
		slvwriting <= 0;
	else if (slvwriting) begin
		if (s_pi1_rdy_i)
			slvwriting <= slvwriterdy;
	end else if (slvwriterdy)
		slvwriting <= 1;

	if (m_pi1_rdy_o) begin
		cacherdy_hold <= cacherdy;
		cachewe_ <= (cacherdy && (m_pi1_op_i == PIWROP || m_pi1_op_i == PIRWOP));
	end else
		cachewe_ <= 0;

	cachewe__sampled <= cachewe_;

	cacheen_sampled <= cacheen;

	m_pi1_addr_i_hold_sampled <= m_pi1_addr_i_hold;

	cachedati_sampled <= cachedati;

	if (slvreadrqstdone)
		s_pi1_data_i_hold <= s_pi1_data_i;

	if (rst_i) begin
		m_pi1_rdy_o_ <= 1;
	end else if (!m_pi1_rdy_o) begin
		// In this state, I wait for the data request from slv to complete.
		// When writing, m_pi1_rdy_o should not become 1 until the buffer,
		// used for writing slv, is no longer full, because when
		// m_pi1_rdy_o == 1, it is assumed that it is possible to add data
		// to the buffer used for writing slv.
		// Within slv_and_buf_rdy, the check for (!slvreadrqst && !slvreading)
		// insures that m_pi1_rdy_o does not become 1 while waiting for a read
		// from slv to complete.
		// Note that when a request was made to read from slv,
		// the actual read do not occur until all data, already in the buffer,
		// used for writing slv, have been written.
		if (slvreadrqstdone || slv_and_buf_rdy) begin
			m_pi1_rdy_o_ <= 1;
			cmiss_i_hold <= 0;
		end else
			m_pi1_rdy_o_ <= 0;
	end else if (conly_r) begin
	end else if (m_pi1_op_i == PIRDOP) begin
		m_pi1_rdy_o_ <= 1; // m_pi1_rdy_o becomes 0 if a cachemiss occurs.
		cmiss_i_hold <= cmiss_i;
		// Because this cache implements writethrough policy,
		// setting cmiss_i_hold makes sense only for PIRDOP.
	end else if (m_pi1_op_i == PIWROP) begin
		// m_pi1_rdy_o becomes 0 if the data to write in slv will make its buffer full.
		m_pi1_rdy_o_ <= (bufusage < (CACHESETCOUNT-1));
	end else if (m_pi1_op_i == PIRWOP) begin
		m_pi1_rdy_o_ <= 0;
	end

	if (rst_i || slvreadrqstdone)
		slvreadwriterqst <= 0;
	else if (m_pi1_op_i == PIRWOP && m_pi1_rdy_o && !conly_r)
		slvreadwriterqst <= 1;

	if (crst_i) begin
		cacheactive <= 0;
		cacherstidx <= {CLOG2CACHESETCOUNT{1'b1}};
	end else if (cacheoff) begin
		if (cacherstidx)
			cacherstidx <= cacherstidx - 1'b1;
		else
			cacheactive <= 1;
	end

	if ((rst_i || crst_i) || !conly_r)
		conly_r <= conly_i;
end

initial begin
	m_pi1_rdy_o_ = 0;
	conly_r = 0;
	cmiss_i_hold = 0;
	m_pi1_op_i_hold = PINOOP;
	slvreading = 0;
	slvwriting = 0;
	slvreadwriterqst = 0;
	m_pi1_addr_i_hold = 0;
	m_pi1_data_i_hold = 0;
	m_pi1_sel_i_hold = 0;
	cacheactive = 0;
	cacherdy_hold = 0;
	cachewe_ = 0;
	cachewe__sampled = 0;
	cacheen_sampled = 0;
	m_pi1_addr_i_hold_sampled = 0;
	cachedati_sampled = 0;
	s_pi1_data_i_hold = 0;
	cacherstidx = 0;
end

endmodule

`endif /* PI1_DCACHE_V */
