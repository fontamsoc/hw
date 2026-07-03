//-----------------------------------------------------------------
//                       USB CDC Device
//                            V0.1
//                     Ultra-Embedded.com
//                     Copyright 2014-2019
//
//                 Email: admin@ultra-embedded.com
//
//                         License: LGPL
//-----------------------------------------------------------------
//
// This source file may be used and distributed without         
// restriction provided that this copyright statement is not    
// removed from the file and that any derivative work contains  
// the original copyright notice and the associated disclaimer. 
//
// This source file is free software; you can redistribute it   
// and/or modify it under the terms of the GNU Lesser General   
// Public License as published by the Free Software Foundation; 
// either version 2.1 of the License, or (at your option) any   
// later version.
//
// This source is distributed in the hope that it will be       
// useful, but WITHOUT ANY WARRANTY; without even the implied   
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
// PURPOSE.  See the GNU Lesser General Public License for more 
// details.
//
// You should have received a copy of the GNU Lesser General    
// Public License along with this source; if not, write to the 
// Free Software Foundation, Inc., 59 Temple Place, Suite 330, 
// Boston, MA  02111-1307  USA
//-----------------------------------------------------------------

//-----------------------------------------------------------------
//                          Generated File
//-----------------------------------------------------------------

module usbf_device_core #(
    parameter NUM_EP = 4 // number of endpoints implemented (EP0 included, max 16)
)(
    // Inputs
     input  wire                  clk_i
    ,input  wire                  rst_i
    ,input  wire [7:0]            utmi_data_i
    ,input  wire                  utmi_txready_i
    ,input  wire                  utmi_rxvalid_i
    ,input  wire                  utmi_rxactive_i
    ,input  wire                  utmi_rxerror_i
    ,input  wire [1:0]            utmi_linestate_i
    ,input  wire [NUM_EP-1:0]     ep_stall_i
    ,input  wire [NUM_EP-1:0]     ep_iso_i
    ,input  wire [NUM_EP-1:0]     ep_cfg_int_rx_i
    ,input  wire [NUM_EP-1:0]     ep_cfg_int_tx_i
    ,input  wire [NUM_EP-1:0]     ep_rx_space_i
    ,input  wire [NUM_EP-1:0]     ep_tx_ready_i
    ,input  wire [NUM_EP-1:0]     ep_tx_data_valid_i
    ,input  wire [NUM_EP-1:0]     ep_tx_data_strb_i
    ,input  wire [(8*NUM_EP)-1:0] ep_tx_data_i
    ,input  wire [NUM_EP-1:0]     ep_tx_data_last_i
    ,input  wire                  reg_chirp_en_i
    ,input  wire                  reg_int_en_sof_i
    ,input  wire                  reg_sts_rst_clr_i
    ,input  wire [6:0]            reg_dev_addr_i
    // Outputs
    ,output wire                  intr_o
    ,output wire [7:0]            utmi_data_o
    ,output wire                  utmi_txvalid_o
    ,output wire                  rx_strb_o
    ,output wire [7:0]            rx_data_o
    ,output wire                  rx_last_o
    ,output wire                  rx_crc_err_o
    ,output wire [NUM_EP-1:0]     ep_rx_setup_o
    ,output wire [NUM_EP-1:0]     ep_rx_valid_o
    ,output wire [NUM_EP-1:0]     ep_tx_data_accept_o
    ,output wire                  reg_sts_rst_o
    ,output wire [10:0]           reg_sts_frame_num_o
);

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
`include "usbf_defs.sv"

`define USB_RESET_CNT_W     15

localparam STATE_W                       = 3;
localparam STATE_RX_IDLE                 = 3'd0;
localparam STATE_RX_DATA                 = 3'd1;
localparam STATE_RX_DATA_READY           = 3'd2;
localparam STATE_RX_DATA_IGNORE          = 3'd3;
localparam STATE_TX_DATA                 = 3'd4;
localparam STATE_TX_DATA_COMPLETE        = 3'd5;
localparam STATE_TX_HANDSHAKE            = 3'd6;
localparam STATE_TX_CHIRP                = 3'd7;
reg [STATE_W-1:0] state_q;

//-----------------------------------------------------------------
// Reset detection
//-----------------------------------------------------------------
reg [`USB_RESET_CNT_W-1:0] se0_cnt_q;

always_ff @(posedge clk_i)
if (rst_i)
    se0_cnt_q <= `USB_RESET_CNT_W'b0;
else if (utmi_linestate_i == 2'b0)
begin
    if (!se0_cnt_q[`USB_RESET_CNT_W-1])
        se0_cnt_q <= se0_cnt_q + `USB_RESET_CNT_W'd1;
end    
else
    se0_cnt_q <= `USB_RESET_CNT_W'b0;

wire usb_rst_w = se0_cnt_q[`USB_RESET_CNT_W-1];

//-----------------------------------------------------------------
// Wire / Regs
//-----------------------------------------------------------------
`define USB_FRAME_W    11
wire [`USB_FRAME_W-1:0] frame_num_w;

wire                    frame_valid_w;

`define USB_DEV_W      7
wire [`USB_DEV_W-1:0]   token_dev_w;

`define USB_EP_W       4
wire [`USB_EP_W-1:0]    token_ep_w;

`define USB_PID_W      8
wire [`USB_PID_W-1:0]   token_pid_w;

wire                    token_valid_w;

wire                    rx_data_valid_w;
wire                    rx_data_complete_w;

wire                    rx_handshake_w;

reg                     tx_data_valid_r;
reg                     tx_data_strb_r;
reg  [7:0]              tx_data_r;
reg                     tx_data_last_r;
wire                    tx_data_accept_w;

reg                     tx_valid_q;
reg [7:0]               tx_pid_q;
wire                    tx_accept_w;

reg                     rx_space_q;
reg                     rx_space_r;
reg                     tx_ready_r;
reg                     out_data_bit_r;
reg                     in_data_bit_r;

reg                     ep_stall_r;
reg                     ep_iso_r;

reg                     rx_enable_q;
reg                     rx_setup_q;

reg [NUM_EP-1:0]        ep_out_data_bit_q;
reg [NUM_EP-1:0]        ep_in_data_bit_q;

reg [`USB_DEV_W-1:0]    current_addr_q;

//-----------------------------------------------------------------
// SIE - TX
//-----------------------------------------------------------------
usbf_sie_tx
u_sie_tx
(
    .clk_i(clk_i),
    .rst_i(rst_i),
    
    .enable_i(~usb_rst_w),
    .chirp_i(reg_chirp_en_i),

    // UTMI Interface
    .utmi_data_o(utmi_data_o),
    .utmi_txvalid_o(utmi_txvalid_o),
    .utmi_txready_i(utmi_txready_i),

    // Request
    .tx_valid_i(tx_valid_q),
    .tx_pid_i(tx_pid_q),
    .tx_accept_o(tx_accept_w),

    // Data
    .data_valid_i(tx_data_valid_r),
    .data_strb_i(tx_data_strb_r),
    .data_i(tx_data_r),
    .data_last_i(tx_data_last_r),
    .data_accept_o(tx_data_accept_w)
);

always_comb
begin
    tx_data_valid_r = 1'b0;
    tx_data_strb_r  = 1'b0;
    tx_data_r       = 8'b0;
    tx_data_last_r  = 1'b0;

    // Endpoints beyond NUM_EP-1 keep the default (zero) values
    // that the case statement default arm used to provide.
    if (token_ep_w < NUM_EP)
    begin
        tx_data_valid_r = ep_tx_data_valid_i[token_ep_w];
        tx_data_strb_r  = ep_tx_data_strb_i[token_ep_w];
        tx_data_r       = ep_tx_data_i[8*token_ep_w +: 8];
        tx_data_last_r  = ep_tx_data_last_i[token_ep_w];
    end
end

genvar gen_ep;
generate
for (gen_ep = 0; gen_ep < NUM_EP; gen_ep = gen_ep + 1)
begin : gen_ep_tx_data_accept
    assign ep_tx_data_accept_o[gen_ep] = tx_data_accept_w & (token_ep_w == gen_ep);
end
endgenerate

always_comb
begin
    rx_space_r     = 1'b0;
    tx_ready_r     = 1'b0;
    out_data_bit_r = 1'b0;
    in_data_bit_r  = 1'b0;

    ep_stall_r = 1'b0;
    ep_iso_r   = 1'b0;

    if (token_ep_w < NUM_EP)
    begin
        rx_space_r    = ep_rx_space_i[token_ep_w];
        tx_ready_r    = ep_tx_ready_i[token_ep_w];
        out_data_bit_r= ep_out_data_bit_q[token_ep_w];
        in_data_bit_r = ep_in_data_bit_q[token_ep_w];
        ep_stall_r    = ep_stall_i[token_ep_w];
        ep_iso_r      = ep_iso_i[token_ep_w];
    end
end

always_ff @(posedge clk_i)
if (rst_i)
    rx_space_q <= 1'b0;
else if (state_q == STATE_RX_IDLE)
    rx_space_q <= rx_space_r;

//-----------------------------------------------------------------
// SIE - RX
//-----------------------------------------------------------------
usbf_sie_rx
u_sie_rx
(
    .clk_i(clk_i),
    .rst_i(rst_i),
    
    .enable_i(~usb_rst_w && ~reg_chirp_en_i),

    // UTMI Interface
    .utmi_data_i(utmi_data_i),
    .utmi_rxvalid_i(utmi_rxvalid_i),
    .utmi_rxactive_i(utmi_rxactive_i),

    .current_addr_i(current_addr_q),

    .pid_o(token_pid_w),

    .frame_valid_o(frame_valid_w),
    .frame_number_o(reg_sts_frame_num_o),

    .token_valid_o(token_valid_w),
    .token_addr_o(token_dev_w),
    .token_ep_o(token_ep_w),
    .token_crc_err_o(),

    .handshake_valid_o(rx_handshake_w),

    .data_valid_o(rx_data_valid_w),
    .data_strb_o(rx_strb_o),
    .data_o(rx_data_o),
    .data_last_o(rx_last_o),

    .data_complete_o(rx_data_complete_w),
    .data_crc_err_o(rx_crc_err_o)
);

generate
for (gen_ep = 0; gen_ep < NUM_EP; gen_ep = gen_ep + 1)
begin : gen_ep_rx_valid_setup
    assign ep_rx_valid_o[gen_ep] = rx_enable_q & rx_data_valid_w & (token_ep_w == gen_ep);
    assign ep_rx_setup_o[gen_ep] = rx_setup_q & (token_ep_w == 4'd0);
end
endgenerate

//-----------------------------------------------------------------
// Next state
//-----------------------------------------------------------------
reg [STATE_W-1:0] next_state_r;

always_comb
begin
    next_state_r = state_q;

    //-----------------------------------------
    // State Machine
    //-----------------------------------------
    case (state_q)

    //-----------------------------------------
    // IDLE
    //-----------------------------------------
    STATE_RX_IDLE :
    begin
        // Token received (OUT, IN, SETUP, PING)
        if (token_valid_w)
        begin
            //-------------------------------
            // IN transfer (device -> host)
            //-------------------------------
            if (token_pid_w == `PID_IN)
            begin
                // Stalled endpoint?
                if (ep_stall_r)
                    next_state_r  = STATE_TX_HANDSHAKE;
                // Some data to TX?
                else if (tx_ready_r)
                    next_state_r  = STATE_TX_DATA;
                // No data to TX
                else
                    next_state_r  = STATE_TX_HANDSHAKE;
            end
            //-------------------------------
            // PING transfer (device -> host)
            //-------------------------------
            else if (token_pid_w == `PID_PING)
            begin
                next_state_r  = STATE_TX_HANDSHAKE;
            end
            //-------------------------------
            // OUT transfer (host -> device)
            //-------------------------------
            else if (token_pid_w == `PID_OUT)
            begin
                // Stalled endpoint?
                if (ep_stall_r)
                    next_state_r  = STATE_RX_DATA_IGNORE;
                // Some space to rx
                else if (rx_space_r)
                    next_state_r  = STATE_RX_DATA;
                // No rx space, ignore receive
                else
                    next_state_r  = STATE_RX_DATA_IGNORE;
            end
            //-------------------------------
            // SETUP transfer (host -> device)
            //-------------------------------
            else if (token_pid_w == `PID_SETUP)
            begin
                // Some space to rx
                if (rx_space_r)
                    next_state_r  = STATE_RX_DATA;
                // No rx space, ignore receive
                else
                    next_state_r  = STATE_RX_DATA_IGNORE;
            end
        end
        else if (reg_chirp_en_i)
            next_state_r  = STATE_TX_CHIRP;
    end

    //-----------------------------------------
    // RX_DATA
    //-----------------------------------------
    STATE_RX_DATA :
    begin
        // TODO: Exit data state handling?

        // TODO: Sort out ISO data bit handling
        // Check for expected DATAx PID
        if ((token_pid_w == `PID_DATA0 &&  out_data_bit_r && !ep_iso_r) ||
            (token_pid_w == `PID_DATA1 && !out_data_bit_r && !ep_iso_r))
            next_state_r  = STATE_RX_DATA_IGNORE;
        // Receive complete
        else if (rx_data_valid_w && rx_last_o)
            next_state_r  = STATE_RX_DATA_READY;
    end
    //-----------------------------------------
    // RX_DATA_IGNORE
    //-----------------------------------------
    STATE_RX_DATA_IGNORE :
    begin
        // Receive complete
        if (rx_data_valid_w && rx_last_o)
            next_state_r  = STATE_RX_DATA_READY;
    end
    //-----------------------------------------
    // RX_DATA_READY
    //-----------------------------------------
    STATE_RX_DATA_READY :
    begin
        if (rx_data_complete_w)
        begin
            // No response on CRC16 error
            if (rx_crc_err_o)
                next_state_r  = STATE_RX_IDLE;
            // ISO endpoint, no response?
            else if (ep_iso_r)
                next_state_r  = STATE_RX_IDLE;
            else
                next_state_r  = STATE_TX_HANDSHAKE;
        end
    end
    //-----------------------------------------
    // TX_DATA
    //-----------------------------------------
    STATE_TX_DATA :
    begin
        if (!tx_valid_q || tx_accept_w)
            if (tx_data_valid_r && tx_data_last_r && tx_data_accept_w)
                next_state_r  = STATE_TX_DATA_COMPLETE;
    end
    //-----------------------------------------
    // TX_HANDSHAKE
    //-----------------------------------------
    STATE_TX_DATA_COMPLETE :
    begin
        next_state_r  = STATE_RX_IDLE;
    end
    //-----------------------------------------
    // TX_HANDSHAKE
    //-----------------------------------------
    STATE_TX_HANDSHAKE :
    begin
        if (tx_accept_w)
            next_state_r  = STATE_RX_IDLE;
    end
    //-----------------------------------------
    // TX_CHIRP
    //-----------------------------------------
    STATE_TX_CHIRP :
    begin
        if (!reg_chirp_en_i)
            next_state_r  = STATE_RX_IDLE;
    end

    default :
       ;

    endcase

    //-----------------------------------------
    // USB Bus Reset (HOST->DEVICE)
    //----------------------------------------- 
    if (usb_rst_w && !reg_chirp_en_i)
        next_state_r  = STATE_RX_IDLE;
end

// Update state
always_ff @(posedge clk_i)
if (rst_i)
    state_q   <= STATE_RX_IDLE;
else
    state_q   <= next_state_r;

//-----------------------------------------------------------------
// Response
//-----------------------------------------------------------------
reg         tx_valid_r;
reg [7:0]   tx_pid_r;

always_comb
begin
    tx_valid_r = 1'b0;
    tx_pid_r   = 8'b0;

    case (state_q)
    //-----------------------------------------
    // IDLE
    //-----------------------------------------
    STATE_RX_IDLE :
    begin
        // Token received (OUT, IN, SETUP, PING)
        if (token_valid_w)
        begin
            //-------------------------------
            // IN transfer (device -> host)
            //-------------------------------
            if (token_pid_w == `PID_IN)
            begin
                // Stalled endpoint?
                if (ep_stall_r)
                begin
                    tx_valid_r = 1'b1;
                    tx_pid_r   = `PID_STALL;
                end
                // Some data to TX?
                else if (tx_ready_r)
                begin
                    tx_valid_r = 1'b1;
                    // TODO: Handle MDATA for ISOs
                    tx_pid_r   = in_data_bit_r ? `PID_DATA1 : `PID_DATA0;
                end
                // No data to TX
                else
                begin
                    tx_valid_r = 1'b1;
                    tx_pid_r   = `PID_NAK;
                end
            end
            //-------------------------------
            // PING transfer (device -> host)
            //-------------------------------
            else if (token_pid_w == `PID_PING)
            begin
                // Stalled endpoint?
                if (ep_stall_r)
                begin
                    tx_valid_r = 1'b1;
                    tx_pid_r   = `PID_STALL;
                end
                // Data ready to RX
                else if (rx_space_r)
                begin
                    tx_valid_r = 1'b1;
                    tx_pid_r   = `PID_ACK;
                end
                // No data to TX
                else
                begin
                    tx_valid_r = 1'b1;
                    tx_pid_r   = `PID_NAK;
                end
            end
        end
    end

    //-----------------------------------------
    // RX_DATA_READY
    //-----------------------------------------
    STATE_RX_DATA_READY :
    begin
       // Receive complete
       if (rx_data_complete_w)
       begin
            // No response on CRC16 error
            if (rx_crc_err_o)
                ;
            // ISO endpoint, no response?
            else if (ep_iso_r)
                ;
            // Send STALL?
            else if (ep_stall_r)
            begin
                tx_valid_r = 1'b1;
                tx_pid_r   = `PID_STALL;
            end
            // DATAx bit mismatch
            else if ( (token_pid_w == `PID_DATA0 && out_data_bit_r) ||
                      (token_pid_w == `PID_DATA1 && !out_data_bit_r) )
            begin
                // Ack transfer to resync
                tx_valid_r = 1'b1;
                tx_pid_r   = `PID_ACK;
            end
            // Send NAK
            else if (!rx_space_q)
            begin
                tx_valid_r = 1'b1;
                tx_pid_r   = `PID_NAK;
            end
            // TODO: USB 2.0, no more buffer space, return NYET
            else
            begin
                tx_valid_r = 1'b1;
                tx_pid_r   = `PID_ACK;
            end
       end
    end

    //-----------------------------------------
    // TX_CHIRP
    //-----------------------------------------
    STATE_TX_CHIRP :
    begin
        tx_valid_r = 1'b1;
        tx_pid_r   = 8'b0;
    end

    default :
       ;

    endcase
end

always_ff @(posedge clk_i)
if (rst_i)
    tx_valid_q <= 1'b0;
else if (!tx_valid_q || tx_accept_w)
    tx_valid_q <= tx_valid_r;

always_ff @(posedge clk_i)
if (rst_i)
    tx_pid_q <= 8'b0;
else if (!tx_valid_q || tx_accept_w)
    tx_pid_q <= tx_pid_r;

//-----------------------------------------------------------------
// Receive enable
//-----------------------------------------------------------------
always_ff @(posedge clk_i)
if (rst_i)
    rx_enable_q <= 1'b0;
else if (usb_rst_w ||reg_chirp_en_i)
    rx_enable_q <= 1'b0;
else
    rx_enable_q <= (state_q == STATE_RX_DATA);

//-----------------------------------------------------------------
// Receive SETUP: Pulse on SETUP packet receive
//-----------------------------------------------------------------
always_ff @(posedge clk_i)
if (rst_i)
    rx_setup_q <= 1'b0;
else if (usb_rst_w ||reg_chirp_en_i)
    rx_setup_q <= 1'b0;
else if ((state_q == STATE_RX_IDLE) && token_valid_w && (token_pid_w == `PID_SETUP) && (token_ep_w == 4'd0))
    rx_setup_q <= 1'b1;
else
    rx_setup_q <= 1'b0;

//-----------------------------------------------------------------
// Set Address
//-----------------------------------------------------------------
reg addr_update_pending_q;

wire ep0_tx_zlp_w = ep_tx_data_valid_i[0] && (ep_tx_data_strb_i[0] == 1'b0) &&
                    ep_tx_data_last_i[0] && ep_tx_data_accept_o[0];

reg sent_status_zlp_q;

always_ff @(posedge clk_i)
if (rst_i)
    sent_status_zlp_q   <= 1'b0;
else if (usb_rst_w)
    sent_status_zlp_q   <= 1'b0;
else if (ep0_tx_zlp_w)
    sent_status_zlp_q   <= 1'b1;
else if (rx_handshake_w)
    sent_status_zlp_q   <= 1'b0;

always_ff @(posedge clk_i)
if (rst_i)
    addr_update_pending_q   <= 1'b0;
else if ((sent_status_zlp_q && addr_update_pending_q && rx_handshake_w && token_pid_w == `PID_ACK) || usb_rst_w)
    addr_update_pending_q   <= 1'b0;
// TODO: Use write strobe
else if (reg_dev_addr_i != current_addr_q)
    addr_update_pending_q   <= 1'b1;

always_ff @(posedge clk_i)
if (rst_i)
    current_addr_q  <= `USB_DEV_W'b0;
else if (usb_rst_w)
    current_addr_q  <= `USB_DEV_W'b0;
else if (sent_status_zlp_q && addr_update_pending_q && rx_handshake_w && token_pid_w == `PID_ACK)
    current_addr_q  <= reg_dev_addr_i;

//-----------------------------------------------------------------
// Endpoint data bit toggle
//-----------------------------------------------------------------
reg new_out_bit_r;
reg new_in_bit_r;

always_comb
begin
    new_out_bit_r = out_data_bit_r;
    new_in_bit_r  = in_data_bit_r;

    case (state_q)
    //-----------------------------------------
    // RX_DATA_READY
    //-----------------------------------------
    STATE_RX_DATA_READY :
    begin
       // Receive complete
       if (rx_data_complete_w)
       begin
            // No toggle on CRC16 error
            if (rx_crc_err_o)
                ;
            // ISO endpoint, no response?
            else if (ep_iso_r)
                ; // TODO: HS handling
            // STALL?
            else if (ep_stall_r)
                ;
            // DATAx bit mismatch
            else if ( (token_pid_w == `PID_DATA0 && out_data_bit_r) ||
                      (token_pid_w == `PID_DATA1 && !out_data_bit_r) )
                ;
            // NAKd
            else if (!rx_space_q)
                ;
            // Data accepted - toggle data bit
            else
                new_out_bit_r = !out_data_bit_r;
       end
    end
    //-----------------------------------------
    // RX_IDLE
    //-----------------------------------------
    STATE_RX_IDLE :
    begin
        // Token received (OUT, IN, SETUP, PING)
        if (token_valid_w)
        begin
            // SETUP packets always start with DATA0
            if (token_pid_w == `PID_SETUP)
            begin
                new_out_bit_r = 1'b0;
                new_in_bit_r  = 1'b1;
            end
        end
        // ACK received
        else if (rx_handshake_w && token_pid_w == `PID_ACK)
        begin
            new_in_bit_r = !in_data_bit_r;
        end
    end
    default:
        ;
    endcase
end

// One update per clock cycle, on the endpoint that the current
// token addresses; equivalent to the per-endpoint always_ff
// blocks it replaces.
always_ff @(posedge clk_i)
if (rst_i)
begin
    ep_out_data_bit_q <= {NUM_EP{1'b0}};
    ep_in_data_bit_q  <= {NUM_EP{1'b0}};
end
else if (usb_rst_w)
begin
    ep_out_data_bit_q <= {NUM_EP{1'b0}};
    ep_in_data_bit_q  <= {NUM_EP{1'b0}};
end
else if (token_ep_w < NUM_EP)
begin
    ep_out_data_bit_q[token_ep_w] <= new_out_bit_r;
    ep_in_data_bit_q[token_ep_w]  <= new_in_bit_r;
end

//-----------------------------------------------------------------
// Reset event
//-----------------------------------------------------------------
reg rst_event_q;

always_ff @(posedge clk_i)
if (rst_i)
    rst_event_q <= 1'b0;
else if (usb_rst_w)
    rst_event_q <= 1'b1;
else if (reg_sts_rst_clr_i)
    rst_event_q <= 1'b0;

assign reg_sts_rst_o = rst_event_q;

//-----------------------------------------------------------------
// Interrupts
//-----------------------------------------------------------------
reg intr_q;

reg cfg_int_rx_r;
reg cfg_int_tx_r;

always_comb
begin
    cfg_int_rx_r = 1'b0;
    cfg_int_tx_r = 1'b0;

    if (token_ep_w < NUM_EP)
    begin
        cfg_int_rx_r = ep_cfg_int_rx_i[token_ep_w];
        cfg_int_tx_r = ep_cfg_int_tx_i[token_ep_w];
    end
end

always_ff @(posedge clk_i)
if (rst_i)
    intr_q <= 1'b0;
// SOF
else if (frame_valid_w && reg_int_en_sof_i)
    intr_q <= 1'b1;
// Reset event
else if (!rst_event_q && usb_rst_w)
    intr_q <= 1'b1;
// Rx ready
else if (state_q == STATE_RX_DATA_READY && rx_space_q && cfg_int_rx_r)
    intr_q <= 1'b1;
// Tx complete
else if (state_q == STATE_TX_DATA_COMPLETE && cfg_int_tx_r)
    intr_q <= 1'b1;    
else
    intr_q <= 1'b0;

assign intr_o = intr_q;

//-------------------------------------------------------------------
// Debug
//-------------------------------------------------------------------
`ifdef verilator
/* verilator lint_off WIDTH */
reg [79:0] dbg_state;

always_comb
begin
    dbg_state = "-";

    case (state_q)
    STATE_RX_IDLE: dbg_state = "IDLE";
    STATE_RX_DATA: dbg_state = "RX_DATA";
    STATE_RX_DATA_READY: dbg_state = "RX_DATA_READY";
    STATE_RX_DATA_IGNORE: dbg_state = "RX_IGNORE";
    STATE_TX_DATA: dbg_state = "TX_DATA";
    STATE_TX_DATA_COMPLETE: dbg_state = "TX_DATA_COMPLETE";
    STATE_TX_HANDSHAKE: dbg_state = "TX_HANDSHAKE";
    STATE_TX_CHIRP: dbg_state = "CHIRP";
    endcase
end

reg [79:0] dbg_pid;
reg [7:0]  dbg_pid_r;
always_comb
begin
    dbg_pid = "-";

    if (tx_valid_q && tx_accept_w)
        dbg_pid_r = tx_pid_q;
    else if (token_valid_w || rx_handshake_w || rx_data_valid_w)
        dbg_pid_r = token_pid_w;
    else
        dbg_pid_r = 8'b0;

    case (dbg_pid_r)
    // Token
    `PID_OUT:
        dbg_pid = "OUT";
    `PID_IN:
        dbg_pid = "IN";
    `PID_SOF:
        dbg_pid = "SOF";
    `PID_SETUP:
        dbg_pid = "SETUP";
    `PID_PING:
        dbg_pid = "PING";
    // Data
    `PID_DATA0:
        dbg_pid = "DATA0";
    `PID_DATA1:
        dbg_pid = "DATA1";
    `PID_DATA2:
        dbg_pid = "DATA2";
    `PID_MDATA:
        dbg_pid = "MDATA";
    // Handshake
    `PID_ACK:
        dbg_pid = "ACK";
    `PID_NAK:
        dbg_pid = "NAK";
    `PID_STALL:
        dbg_pid = "STALL";
    `PID_NYET:
        dbg_pid = "NYET";
    // Special
    `PID_PRE:
        dbg_pid = "PRE/ERR";
    `PID_SPLIT:
        dbg_pid = "SPLIT";
    default:
        ;
    endcase
end
/* verilator lint_on WIDTH */
`endif


endmodule
