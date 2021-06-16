// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

module bootldr (
	
	rst_i,
	
	clk_i,
	
	m_pi1_op_i,
	m_pi1_addr_i,
	m_pi1_data_i,
	m_pi1_data_o,
	m_pi1_sel_i,
	m_pi1_rdy_o,
	
	s_pi1_op_o,
	s_pi1_addr_o,
	s_pi1_data_o,
	s_pi1_data_i,
	s_pi1_sel_o,
	s_pi1_rdy_i
);

`include "lib/clog2.v"

parameter BOOTBLOCK = 0;

parameter ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             m_pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     m_pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     m_pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     m_pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] m_pi1_sel_i;
output reg                         m_pi1_rdy_o;

output reg  [2 -1 : 0]             s_pi1_op_o;
output reg  [ADDRBITSZ -1 : 0]     s_pi1_addr_o;
output reg  [ARCHBITSZ -1 : 0]     s_pi1_data_o;
input  wire [ARCHBITSZ -1 : 0]     s_pi1_data_i;
output reg  [(ARCHBITSZ/8) -1 : 0] s_pi1_sel_o;
input  wire                        s_pi1_rdy_i;

localparam BOOTLDRSTATUS = 0;
localparam BOOTLDRRESET  = 1;
localparam BOOTLDRREAD   = 2;
localparam BOOTLDRSWAP   = 3;
localparam BOOTLDRDONE   = 4;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

localparam CMDRESET = 0;
localparam CMDSWAP  = 1;
localparam CMDREAD  = 2;
localparam CMDWRITE = 3;

localparam STATUSPOWEROFF = 0;
localparam STATUSREADY    = 1;
localparam STATUSBUSY     = 2;
localparam STATUSERROR    = 3;

reg [3 -1 : 0] bootldrstate = BOOTLDRSTATUS;
reg [3 -1 : 0] nextbootldrstate = BOOTLDRRESET;

reg s_pi1_data_irdy = 0;

reg bootloadingdone = 0;

always @ (posedge clk_i) begin
	
	if (rst_i) begin

		bootloadingdone <= 0;
		
		s_pi1_data_irdy <= 0;
		
		bootldrstate <= BOOTLDRSTATUS;
		nextbootldrstate <= BOOTLDRRESET;
		
	end else if (!bootloadingdone) begin

		s_pi1_data_irdy <= (bootldrstate == BOOTLDRSTATUS);
		
		if (bootldrstate == BOOTLDRSTATUS) begin
			
			if (s_pi1_rdy_i && s_pi1_data_irdy && s_pi1_data_i == STATUSREADY)
				bootldrstate <= nextbootldrstate;
			
		end else if (bootldrstate == BOOTLDRRESET) begin
			
			if (s_pi1_rdy_i) begin
				bootldrstate <= BOOTLDRSTATUS;
				nextbootldrstate <= BOOTLDRREAD;
			end
			
		end else if (bootldrstate == BOOTLDRREAD) begin
			
			if (s_pi1_rdy_i) begin
				bootldrstate <= BOOTLDRSTATUS;
				nextbootldrstate <= BOOTLDRSWAP;
			end
			
		end else if (bootldrstate == BOOTLDRSWAP) begin
			
			if (s_pi1_rdy_i)
				bootldrstate <= BOOTLDRDONE;
			
		end else if (s_pi1_rdy_i)
			bootloadingdone <= 1;
	end
end

always @* begin
	
	if (bootloadingdone) begin

		s_pi1_op_o = m_pi1_op_i;
		s_pi1_addr_o = m_pi1_addr_i;
		s_pi1_data_o = m_pi1_data_i;
		m_pi1_data_o = s_pi1_data_i;
		s_pi1_sel_o = m_pi1_sel_i;
		m_pi1_rdy_o = s_pi1_rdy_i;
		
	end else begin

		m_pi1_data_o = 0;
		m_pi1_rdy_o = 0;
		
		if (bootldrstate == BOOTLDRSTATUS) begin
			
			s_pi1_op_o = PIRWOP;
			s_pi1_addr_o = CMDRESET;
			s_pi1_data_o = 0;
			s_pi1_sel_o = 4'b1111;
			
		end else if (bootldrstate == BOOTLDRRESET) begin
			
			s_pi1_op_o = PIRWOP;
			s_pi1_addr_o = CMDRESET;
			s_pi1_data_o = 1;
			s_pi1_sel_o = 4'b1111;
			
		end else if (bootldrstate == BOOTLDRREAD) begin
			
			s_pi1_op_o = PIRWOP;
			s_pi1_addr_o = CMDREAD;
			s_pi1_data_o = BOOTBLOCK;
			s_pi1_sel_o = 4'b1111;
			
		end else if (bootldrstate == BOOTLDRSWAP) begin
			
			s_pi1_op_o = PIRWOP;
			s_pi1_addr_o = CMDSWAP;
			s_pi1_data_o = 0;
			s_pi1_sel_o = 4'b1111;
			
		end else begin
			
			s_pi1_op_o = PINOOP;
			s_pi1_addr_o = 0;
			s_pi1_data_o = 0;
			s_pi1_sel_o = 0;
		end
	end
end

endmodule
