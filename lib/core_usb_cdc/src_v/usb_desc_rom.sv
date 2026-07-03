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
// ROM built at elaboration from PORTCOUNT; it describes PORTCOUNT
// CDC-ACM functions (ie: COM ports) grouped by interface
// association descriptors when PORTCOUNT > 1, and is byte-identical
// to the original single-port generated ROM when PORTCOUNT == 1.
//-----------------------------------------------------------------
module usb_desc_rom (
    input  wire        hs_i,
    input  wire [15:0] addr_i,
    output wire [7:0]  data_o
);

parameter PORTCOUNT = 1; // number of CDC-ACM functions (1 to 5)

// Sizes of the configuration descriptor and of the whole ROM;
// the per-port block is 58 bytes, plus 8 bytes of interface
// association descriptor when PORTCOUNT > 1; the trailing 85 bytes
// are the string descriptors and the CDC line-coding data.
localparam ROM_DESC_CONF_SIZE = (9 + (((PORTCOUNT == 1) ? 58 : 66) * PORTCOUNT));
localparam ROM_SIZE           = (18 + ROM_DESC_CONF_SIZE + 85);

function automatic [(ROM_SIZE*8)-1:0] desc_rom_build (input hs);
    integer p;
    integer o;
    reg [(ROM_SIZE*8)-1:0] rom;
begin
    rom = {(ROM_SIZE*8){1'b0}};
    o   = 0;
    // ---- device descriptor ----
    rom[o*8 +: 8] = 8'h12;                            o = o + 1; // bLength
    rom[o*8 +: 8] = 8'h01;                            o = o + 1; // bDescriptorType (DEVICE)
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // bcdUSB[7:0]
    rom[o*8 +: 8] = 8'h02;                            o = o + 1; // bcdUSB[15:8]
    rom[o*8 +: 8] = (PORTCOUNT == 1) ? 8'h02 : 8'hef; o = o + 1; // bDeviceClass (CDC : Misc)
    rom[o*8 +: 8] = (PORTCOUNT == 1) ? 8'h00 : 8'h02; o = o + 1; // bDeviceSubClass
    rom[o*8 +: 8] = (PORTCOUNT == 1) ? 8'h00 : 8'h01; o = o + 1; // bDeviceProtocol (IAD)
    rom[o*8 +: 8] = hs ? 8'h40 : 8'h08;               o = o + 1; // bMaxPacketSize0
    rom[o*8 +: 8] = 8'h50;                            o = o + 1; // idVendor[7:0]
    rom[o*8 +: 8] = 8'h1d;                            o = o + 1; // idVendor[15:8]
    rom[o*8 +: 8] = 8'h49;                            o = o + 1; // idProduct[7:0]
    rom[o*8 +: 8] = 8'h61;                            o = o + 1; // idProduct[15:8]
    rom[o*8 +: 8] = 8'h01;                            o = o + 1; // bcdDevice[7:0]
    rom[o*8 +: 8] = 8'h01;                            o = o + 1; // bcdDevice[15:8]
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // iManufacturer
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // iProduct
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // iSerialNumber
    rom[o*8 +: 8] = 8'h01;                            o = o + 1; // bNumConfigurations
    // ---- configuration descriptor ----
    rom[o*8 +: 8] = 8'h09;                            o = o + 1; // bLength
    rom[o*8 +: 8] = 8'h02;                            o = o + 1; // bDescriptorType (CONFIGURATION)
    rom[o*8 +: 8] = 8'(ROM_DESC_CONF_SIZE);           o = o + 1; // wTotalLength[7:0]
    rom[o*8 +: 8] = 8'(ROM_DESC_CONF_SIZE >> 8);      o = o + 1; // wTotalLength[15:8]
    rom[o*8 +: 8] = 8'(2*PORTCOUNT);                  o = o + 1; // bNumInterfaces
    rom[o*8 +: 8] = 8'h01;                            o = o + 1; // bConfigurationValue
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // iConfiguration
    rom[o*8 +: 8] = 8'h80;                            o = o + 1; // bmAttributes
    rom[o*8 +: 8] = 8'h32;                            o = o + 1; // bMaxPower (100mA)
    for (p = 0; p < PORTCOUNT; p = p + 1) begin
        if (PORTCOUNT > 1) begin
            // ---- interface association descriptor ----
            rom[o*8 +: 8] = 8'h08;                    o = o + 1; // bLength
            rom[o*8 +: 8] = 8'h0b;                    o = o + 1; // bDescriptorType (IAD)
            rom[o*8 +: 8] = 8'(2*p);                  o = o + 1; // bFirstInterface
            rom[o*8 +: 8] = 8'h02;                    o = o + 1; // bInterfaceCount
            rom[o*8 +: 8] = 8'h02;                    o = o + 1; // bFunctionClass (CDC)
            rom[o*8 +: 8] = 8'h02;                    o = o + 1; // bFunctionSubClass (ACM)
            rom[o*8 +: 8] = 8'h01;                    o = o + 1; // bFunctionProtocol
            rom[o*8 +: 8] = 8'h00;                    o = o + 1; // iFunction
        end
        // ---- communication interface descriptor ----
        rom[o*8 +: 8] = 8'h09;                        o = o + 1; // bLength
        rom[o*8 +: 8] = 8'h04;                        o = o + 1; // bDescriptorType (INTERFACE)
        rom[o*8 +: 8] = 8'(2*p);                      o = o + 1; // bInterfaceNumber
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // bAlternateSetting
        rom[o*8 +: 8] = 8'h01;                        o = o + 1; // bNumEndpoints
        rom[o*8 +: 8] = 8'h02;                        o = o + 1; // bInterfaceClass (CDC)
        rom[o*8 +: 8] = 8'h02;                        o = o + 1; // bInterfaceSubClass (ACM)
        rom[o*8 +: 8] = 8'h01;                        o = o + 1; // bInterfaceProtocol
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // iInterface
        // ---- CDC header functional descriptor ----
        rom[o*8 +: 8] = 8'h05;                        o = o + 1; // bFunctionLength
        rom[o*8 +: 8] = 8'h24;                        o = o + 1; // bDescriptorType (CS_INTERFACE)
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // bDescriptorSubtype (HEADER)
        rom[o*8 +: 8] = 8'h10;                        o = o + 1; // bcdCDC[7:0]
        rom[o*8 +: 8] = 8'h01;                        o = o + 1; // bcdCDC[15:8]
        // ---- CDC call management functional descriptor ----
        rom[o*8 +: 8] = 8'h05;                        o = o + 1; // bFunctionLength
        rom[o*8 +: 8] = 8'h24;                        o = o + 1; // bDescriptorType (CS_INTERFACE)
        rom[o*8 +: 8] = 8'h01;                        o = o + 1; // bDescriptorSubtype (CALL_MGMT)
        rom[o*8 +: 8] = 8'h03;                        o = o + 1; // bmCapabilities
        rom[o*8 +: 8] = 8'((2*p)+1);                  o = o + 1; // bDataInterface
        // ---- CDC ACM functional descriptor ----
        rom[o*8 +: 8] = 8'h04;                        o = o + 1; // bFunctionLength
        rom[o*8 +: 8] = 8'h24;                        o = o + 1; // bDescriptorType (CS_INTERFACE)
        rom[o*8 +: 8] = 8'h02;                        o = o + 1; // bDescriptorSubtype (ACM)
        rom[o*8 +: 8] = 8'h06;                        o = o + 1; // bmCapabilities
        // ---- CDC union functional descriptor ----
        rom[o*8 +: 8] = 8'h05;                        o = o + 1; // bFunctionLength
        rom[o*8 +: 8] = 8'h24;                        o = o + 1; // bDescriptorType (CS_INTERFACE)
        rom[o*8 +: 8] = 8'h06;                        o = o + 1; // bDescriptorSubtype (UNION)
        rom[o*8 +: 8] = 8'(2*p);                      o = o + 1; // bControlInterface
        rom[o*8 +: 8] = 8'((2*p)+1);                  o = o + 1; // bSubordinateInterface0
        // ---- notification endpoint descriptor ----
        rom[o*8 +: 8] = 8'h07;                        o = o + 1; // bLength
        rom[o*8 +: 8] = 8'h05;                        o = o + 1; // bDescriptorType (ENDPOINT)
        rom[o*8 +: 8] = 8'((8'h80|((3*p)+3)));        o = o + 1; // bEndpointAddress (IN)
        rom[o*8 +: 8] = 8'h03;                        o = o + 1; // bmAttributes (INTERRUPT)
        rom[o*8 +: 8] = 8'h40;                        o = o + 1; // wMaxPacketSize[7:0]
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // wMaxPacketSize[15:8]
        rom[o*8 +: 8] = 8'h02;                        o = o + 1; // bInterval
        // ---- data interface descriptor ----
        rom[o*8 +: 8] = 8'h09;                        o = o + 1; // bLength
        rom[o*8 +: 8] = 8'h04;                        o = o + 1; // bDescriptorType (INTERFACE)
        rom[o*8 +: 8] = 8'((2*p)+1);                  o = o + 1; // bInterfaceNumber
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // bAlternateSetting
        rom[o*8 +: 8] = 8'h02;                        o = o + 1; // bNumEndpoints
        rom[o*8 +: 8] = 8'h0a;                        o = o + 1; // bInterfaceClass (CDC-Data)
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // bInterfaceSubClass
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // bInterfaceProtocol
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // iInterface
        // ---- bulk-out endpoint descriptor ----
        rom[o*8 +: 8] = 8'h07;                        o = o + 1; // bLength
        rom[o*8 +: 8] = 8'h05;                        o = o + 1; // bDescriptorType (ENDPOINT)
        rom[o*8 +: 8] = 8'((3*p)+1);                  o = o + 1; // bEndpointAddress (OUT)
        rom[o*8 +: 8] = 8'h02;                        o = o + 1; // bmAttributes (BULK)
        rom[o*8 +: 8] = hs ? 8'h00 : 8'h40;           o = o + 1; // wMaxPacketSize[7:0]
        rom[o*8 +: 8] = hs ? 8'h02 : 8'h00;           o = o + 1; // wMaxPacketSize[15:8]
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // bInterval
        // ---- bulk-in endpoint descriptor ----
        rom[o*8 +: 8] = 8'h07;                        o = o + 1; // bLength
        rom[o*8 +: 8] = 8'h05;                        o = o + 1; // bDescriptorType (ENDPOINT)
        rom[o*8 +: 8] = 8'((8'h80|((3*p)+2)));        o = o + 1; // bEndpointAddress (IN)
        rom[o*8 +: 8] = 8'h02;                        o = o + 1; // bmAttributes (BULK)
        rom[o*8 +: 8] = hs ? 8'h00 : 8'h40;           o = o + 1; // wMaxPacketSize[7:0]
        rom[o*8 +: 8] = hs ? 8'h02 : 8'h00;           o = o + 1; // wMaxPacketSize[15:8]
        rom[o*8 +: 8] = 8'h00;                        o = o + 1; // bInterval
    end
    // ---- string descriptor 0 (language id) ----
    rom[o*8 +: 8] = 8'h04;                            o = o + 1; // bLength
    rom[o*8 +: 8] = 8'h03;                            o = o + 1; // bDescriptorType (STRING)
    rom[o*8 +: 8] = 8'h09;                            o = o + 1; // wLANGID[7:0] (0x0409)
    rom[o*8 +: 8] = 8'h04;                            o = o + 1; // wLANGID[15:8]
    // ---- string descriptor 1 ("ULTRA-EMBEDDED") ----
    rom[o*8 +: 8] = 8'h1e;                            o = o + 1; // bLength
    rom[o*8 +: 8] = 8'h03;                            o = o + 1; // bDescriptorType (STRING)
    rom[o*8 +: 8] = 8'h55; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'U'
    rom[o*8 +: 8] = 8'h4c; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'L'
    rom[o*8 +: 8] = 8'h54; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'T'
    rom[o*8 +: 8] = 8'h52; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'R'
    rom[o*8 +: 8] = 8'h41; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'A'
    rom[o*8 +: 8] = 8'h2d; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // '-'
    rom[o*8 +: 8] = 8'h45; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'E'
    rom[o*8 +: 8] = 8'h4d; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'M'
    rom[o*8 +: 8] = 8'h42; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'B'
    rom[o*8 +: 8] = 8'h45; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'E'
    rom[o*8 +: 8] = 8'h44; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'D'
    rom[o*8 +: 8] = 8'h44; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'D'
    rom[o*8 +: 8] = 8'h45; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'E'
    rom[o*8 +: 8] = 8'h44; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'D'
    // ---- string descriptor 2 ("USB DEMO      ") ----
    rom[o*8 +: 8] = 8'h1e;                            o = o + 1; // bLength
    rom[o*8 +: 8] = 8'h03;                            o = o + 1; // bDescriptorType (STRING)
    rom[o*8 +: 8] = 8'h55; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'U'
    rom[o*8 +: 8] = 8'h53; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'S'
    rom[o*8 +: 8] = 8'h42; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'B'
    rom[o*8 +: 8] = 8'h20; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // ' '
    rom[o*8 +: 8] = 8'h44; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'D'
    rom[o*8 +: 8] = 8'h45; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'E'
    rom[o*8 +: 8] = 8'h4d; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'M'
    rom[o*8 +: 8] = 8'h4f; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // 'O'
    rom[o*8 +: 8] = 8'h20; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // ' '
    rom[o*8 +: 8] = 8'h20; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // ' '
    rom[o*8 +: 8] = 8'h20; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // ' '
    rom[o*8 +: 8] = 8'h20; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // ' '
    rom[o*8 +: 8] = 8'h20; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // ' '
    rom[o*8 +: 8] = 8'h20; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // ' '
    // ---- string descriptor 3 ("000000") ----
    rom[o*8 +: 8] = 8'h0e;                            o = o + 1; // bLength
    rom[o*8 +: 8] = 8'h03;                            o = o + 1; // bDescriptorType (STRING)
    rom[o*8 +: 8] = 8'h30; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // '0'
    rom[o*8 +: 8] = 8'h30; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // '0'
    rom[o*8 +: 8] = 8'h30; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // '0'
    rom[o*8 +: 8] = 8'h30; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // '0'
    rom[o*8 +: 8] = 8'h30; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // '0'
    rom[o*8 +: 8] = 8'h30; o = o + 1; rom[o*8 +: 8] = 8'h00; o = o + 1; // '0'
    // ---- CDC line coding (115200 baud, 1 stop bit, no parity, 8 data bits) ----
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // dwDTERate[7:0]
    rom[o*8 +: 8] = 8'hc2;                            o = o + 1; // dwDTERate[15:8]
    rom[o*8 +: 8] = 8'h01;                            o = o + 1; // dwDTERate[23:16]
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // dwDTERate[31:24]
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // bCharFormat
    rom[o*8 +: 8] = 8'h00;                            o = o + 1; // bParityType
    rom[o*8 +: 8] = 8'h08;                            o = o + 1; // bDataBits
    desc_rom_build = rom;
end
endfunction

localparam [(ROM_SIZE*8)-1:0] ROM_FS = desc_rom_build(1'b0);
localparam [(ROM_SIZE*8)-1:0] ROM_HS = desc_rom_build(1'b1);

wire [(ROM_SIZE*8)-1:0] rom_w = hs_i ? ROM_HS : ROM_FS;

assign data_o = (addr_i < 16'(ROM_SIZE)) ? rom_w[addr_i*8 +: 8] : 8'h00;

endmodule
