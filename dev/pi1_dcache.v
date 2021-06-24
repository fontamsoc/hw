// Copyright (c) William Fonkou Tambe
// All rights reserved.

`ifndef PI1_DCACHE_V
`define PI1_DCACHE_V

`include "lib/fifo_fwft.v"
`include "lib/ram/bram.v"

module pi1_dcache (

	 rst_i

	,clk_i

	,crst_i

	,cenable_i

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

parameter CACHESETCOUNT = 2;

parameter INITFILE = "";

parameter ARCHBITSZ = 32;

localparam CLOG2CACHESETCOUNT = clog2(CACHESETCOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
`else
input wire [1 -1 : 0] clk_i;
`endif

input wire crst_i;

input wire cenable_i;

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

wire buffull  = (bufusage >= CACHESETCOUNT);
wire bufempty = (bufusage == 0);

wire bufpush = (m_pi1_op_i == PIWROP && m_pi1_rdy_o && !conly_r);

wire [ADDRBITSZ -1 : 0] addrbufdato;

fifo_fwft #(

	 .WIDTH (ADDRBITSZ)
	,.DEPTH (CACHESETCOUNT)

) addrbuf (

	 .rst_i (rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (slvwriterdy && !bufempty)
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
	,.pop_i     (slvwriterdy && !bufempty)
	,.data_o    (databufdato)
	,.empty_o   ()

	,.clk_push_i (clk_i)
	,.push_i     (bufpush)
	,.data_i     (m_pi1_data_i)
	,.full_o     ()
);

wire [(ARCHBITSZ/8) -1 : 0] bytselbufdato;

fifo_fwft #(

	 .WIDTH (ARCHBITSZ/8)
	,.DEPTH (CACHESETCOUNT)

) bytselbuf (

	 .rst_i (rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (slvwriterdy && !bufempty)
	,.data_o    (bytselbufdato)
	,.empty_o   ()

	,.clk_push_i (clk_i)
	,.push_i     (bufpush)
	,.data_i     (m_pi1_sel_i)
	,.full_o     ()
);

wire cachehit;

reg [2 -1 : 0] m_pi1_op_i_hold;

wire usesampled;

assign cachemiss = ((m_pi1_op_i_hold == PIRDOP) && !cachehit && !usesampled);

wire slvreadrqst = ((cachemiss || (m_pi1_op_i_hold == PIRWOP)) && !conly_r);

reg slvreading;

reg slvwriting;

wire slvnotreading = (!slvreading || s_pi1_rdy_i);
wire slvnotwriting = (!slvwriting || s_pi1_rdy_i);

wire slvreadrdy = (s_pi1_rdy_i && slvnotreading && (bufempty && slvreadrqst) && slvnotwriting);

reg slvreadwriterqst;

wire slvreadrqstdone = (slvreading && s_pi1_rdy_i);

assign slvwriterdy = (s_pi1_rdy_i && slvnotwriting && (!bufempty || (slvreadwriterqst && !slvreadrqstdone)) && slvnotreading);

reg [ADDRBITSZ -1 : 0] m_pi1_addr_i_hold;

reg [ARCHBITSZ -1 : 0] m_pi1_data_i_hold;

reg [(128/8) -1 : 0] m_pi1_sel_i_hold;

assign s_pi1_op_o   = {slvreadrdy, slvwriterdy};
assign s_pi1_addr_o = (slvreadrdy ? m_pi1_addr_i_hold : addrbufdato);
assign s_pi1_data_o = ((slvwriterdy && slvreadrdy) ? m_pi1_data_i_hold : databufdato);
assign s_pi1_sel_o  = (slvreadrdy ? m_pi1_sel_i_hold[(ARCHBITSZ/8) -1 : 0] : bytselbufdato);

localparam CACHETAGBITSIZE = (ADDRBITSZ - CLOG2CACHESETCOUNT);

reg cacheactive;

wire cacherdy = ((cacheactive && cenable_i && !crst_i) || conly_r);

wire cacheen = (cacherdy && m_pi1_op_i != PINOOP && m_pi1_rdy_o);

reg cacherdy_hold;

reg cachewe_;

wire cachewe = (slvreadrqstdone ? (cacherdy_hold && !slvreadwriterqst) : cachewe_);

wire [CACHETAGBITSIZE -1 : 0] cachetago;

bram #(

	 .SZ (CACHESETCOUNT)
	,.DW (CACHETAGBITSIZE)

) cachetags (

	 .clk0_i  (clk_i)        ,.clk1_i  (clk_i)
	,.en0_i   (cacheen)      ,.en1_i   (1'b1)
	                         ,.we1_i   (cachewe)
	,.addr0_i (m_pi1_addr_i) ,.addr1_i (m_pi1_addr_i_hold)
	                         ,.i1      (m_pi1_addr_i_hold[ADDRBITSZ -1 : CLOG2CACHESETCOUNT])
	,.o0      (cachetago)    ,.o1      ()
);

wire [ARCHBITSZ -1 : 0] cachedata = (slvreadrqstdone ? s_pi1_data_i : m_pi1_data_i_hold);

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
	else
		cachedatibitsel = {ARCHBITSZ{1'b0}};
end

wire [ARCHBITSZ -1 : 0] cachedato;

wire [ARCHBITSZ -1 : 0] cachedati =
	(cachedata & cachedatibitsel) | (cachedato & ~cachedatibitsel);

bram #(

	 .SZ (CACHESETCOUNT)
	,.DW (ARCHBITSZ)

	,.SRCFILE (INITFILE)

) cachedatas (

	 .clk0_i  (clk_i)        ,.clk1_i  (clk_i)
	,.en0_i   (cacheen)      ,.en1_i   (1'b1)
	                         ,.we1_i   (cachewe)
	,.addr0_i (m_pi1_addr_i) ,.addr1_i (m_pi1_addr_i_hold)
	                         ,.i1      (cachedati)
	,.o0      (cachedato)    ,.o1      ()
);

reg cachewe__sampled;

reg cacheen_sampled;

reg [ADDRBITSZ -1 : 0] m_pi1_addr_i_hold_sampled;

assign usesampled = (
	cachewe__sampled && cacheen_sampled &&
	(m_pi1_addr_i_hold == m_pi1_addr_i_hold_sampled));

reg [ARCHBITSZ -1 : 0] cachedati_sampled;

reg [ARCHBITSZ -1 : 0] s_pi1_data_i_hold;

assign m_pi1_data_o = (m_pi1_op_i_hold == PIRDOP) ?
	(usesampled ? cachedati_sampled : cachedato) : s_pi1_data_i_hold;

wire cacheoff = !cacheactive;

reg [CLOG2CACHESETCOUNT -1 : 0] cacherstidx;

wire cachevalido_;

bram #(

	 .SZ (CACHESETCOUNT)
	,.DW (1)

) cachevalids (

	 .clk0_i  (clk_i)        ,.clk1_i  (clk_i)
	,.en0_i   (cacheen)      ,.en1_i   (1'b1)
	                         ,.we1_i   (cachewe || cacheoff)
	,.addr0_i (m_pi1_addr_i) ,.addr1_i (cacheoff ? cacherstidx : m_pi1_addr_i_hold)
	                         ,.i1      (cacheoff ? 1'b0 : cacherdy_hold)
	,.o0      (cachevalido_) ,.o1      ()
);

wire cachevalido = (cachevalido_ & cacherdy_hold);

wire cachetaghit = (cachevalido && (m_pi1_addr_i_hold[ADDRBITSZ -1 : CLOG2CACHESETCOUNT] == cachetago));

wire [ARCHBITSZ -1 : 0] cachedatabitselo;

bram #(

	 .SZ (CACHESETCOUNT)
	,.DW (ARCHBITSZ)

) cachedatabitsels (

	 .clk0_i  (clk_i)            ,.clk1_i  (clk_i)
	,.en0_i   (cacheen)          ,.en1_i   (1'b1)
	                             ,.we1_i   (cachewe)
	,.addr0_i (m_pi1_addr_i)     ,.addr1_i (m_pi1_addr_i_hold)
	                             ,.i1      ((cachetaghit ? cachedatabitselo : {ARCHBITSZ{1'b0}}) | cachedatibitsel)
	,.o0      (cachedatabitselo) ,.o1      ()
);

assign cachehit = (cachetaghit && ((cachedatibitsel & cachedatabitselo) == cachedatibitsel));

wire slv_and_buf_rdy = (!slvreadrqst && !slvreading && !buffull);

always @ (posedge clk_i[0]) begin

	if (rst_i)
		m_pi1_op_i_hold <= PINOOP;
	else if (m_pi1_rdy_o) begin
		m_pi1_op_i_hold <= m_pi1_op_i;
		m_pi1_addr_i_hold <= m_pi1_addr_i;
		m_pi1_data_i_hold <= m_pi1_data_i;
		m_pi1_sel_i_hold <= m_pi1_sel_i;
	end else if (s_pi1_op_o == m_pi1_op_i_hold)
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
		if (slvreadrqstdone || slv_and_buf_rdy)
			m_pi1_rdy_o_ <= 1;
		else
			m_pi1_rdy_o_ <= 0;
	end else if (conly_r) begin
	end else if (m_pi1_op_i == PIRDOP) begin
		m_pi1_rdy_o_ <= 1;
	end else if (m_pi1_op_i == PIWROP) begin
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

`endif
