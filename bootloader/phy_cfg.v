//
//  HPSDR - High Performance Software Defined Radio
//
//  Metis code. 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


//  Metis code copyright 2010, 2011, 2012, 2013 Alex Shovkoplyas, VE3NEA.

//  25 Sept 2014 - Modified initial register values to correct for 0.12nS rather than 0.2nS steps.
//                 Also added write to register 106h to turn off Tx Data Pad Skews.  Both these
//						 changes are due to errors in the original data sheet which was corrected Feb 2014.


//-----------------------------------------------------------------------------
// initialize the PHY device on startup
// by writing config data to its MDIO registers; 
// continuously read PHY status from the MDIO registers
//-----------------------------------------------------------------------------

module phy_cfg(
  //input
  input clock,        //2.5 MHZ
  input init_request,
  
  //output
  output reg speed,
  output reg duplex,
  
  //hardware pins
  inout mdio_pin,
  output mdc_pin  
);


//-----------------------------------------------------------------------------
//                           initialization data
//-----------------------------------------------------------------------------


//mdio register addresses 
wire [7:0] addresses [18:0];

assign addresses[18] = 8'hd; // MMD addressing to 2h - 4h
assign addresses[17] = 8'he;
assign addresses[16] = 8'hd;
assign addresses[15] = 8'he;

assign addresses[14] = 8'hd; // MMD addressing to 2h - 5h
assign addresses[13] = 8'he;
assign addresses[12] = 8'hd;
assign addresses[11] = 8'he;

assign addresses[10] = 8'hd; // MMD addressing to 2h - 6h 
assign addresses[9] = 8'he;
assign addresses[8] = 8'hd;
assign addresses[7] = 8'he;
 
assign addresses[6] = 8'hd; // MMD addressing to 2h - 8h
assign addresses[5] = 8'he;
assign addresses[4] = 8'hd;
assign addresses[3] = 8'he;

assign addresses[2] = 8'h09;// 1000BASE-T Control
assign addresses[1] = 8'h00;// BASIC CONTROL
assign addresses[0] = 8'h1f;// PHY CONTROL for reading only

//mdio register values
wire [15:0] values [18:0];

assign values[18] = 16'h0002; // addressing to addr 02h and reg 04h
assign values[17] = 16'h0004;
assign values[16] = 16'h4002;
assign values[15] = {4'd0, 4'd0, 4'd7, 4'd7}; // data for SKEWS RX_CTL, TX_CTL   0 - 15

assign values[14] = 16'h0002; // addressing to addr 02h and reg 05h
assign values[13] = 16'h0005;
assign values[12] = 16'h4002;
assign values[11] = {4'd7, 4'd7, 4'd7, 4'd7}; // data for SKEWS RXD_3, RXD_2, RXD_1, RXD_0   0 - 15

assign values[10] = 16'h0002; // addressing to addr 02h and reg 06h
assign values[9]  = 16'h0006;
assign values[8]  = 16'h4002;
assign values[7]  = {4'd7, 4'd7, 4'd7, 4'd7}; // data for SKEWS TXD_3, TXD_2, TXD_1, TXD_0    0 - 15

assign values[6]  = 16'h0002; // addressing to addr 02h and reg 08h
assign values[5]  = 16'h0008;
assign values[4]  = 16'h4002;
assign values[3]  = {6'd0, 5'd15, 5'd15}; // data for TX_CLK SKEW, RX_CLK SKEW    0 - 31

assign values[2]  = {6'b0, 1'b1, 9'b0}; // 1 Gig FD mode advertizing
assign values[1]  = 16'b0000_0101_0100_0000;   //  
assign values[0]  = 16'h0000;  //



reg [4:0] word_no = 0; 


//-----------------------------------------------------------------------------
//                            state machine
//-----------------------------------------------------------------------------

//phy initialization required 
//if init_request input was raised
reg init_required;

wire ready;
wire [15:0] rd_data;
reg rd_request, wr_request;


//state machine  
localparam READING = 1'b0, WRITING = 1'b1;  
reg state = READING;  


always @(posedge clock)  
begin
   if (init_request) 
   init_required <= 1;
  
   if (ready)
   case (state)
   READING:
   begin
      speed <= rd_data[6] & !rd_data[5];
      duplex <= rd_data[3];
        
      if (init_required)
      begin
         wr_request <= 1;
         word_no <= 10;
         state  <= WRITING;
         init_required <= 0;
      end
      else
      rd_request <= 1'b1;
   end

   WRITING:
   begin
      if (word_no == 4'b1) state <= READING;   
      else wr_request <= 1;
      word_no <= word_no - 4'b1;		  
   end
   endcase
		
   else //!ready
   begin
      rd_request <= 0;
      wr_request <= 0;
   end
	
end

               
//-----------------------------------------------------------------------------
//                        MDIO interface to PHY
//-----------------------------------------------------------------------------


mdio mdio_inst (
  .clock(clock), 
  .addr(addresses[word_no]), 
  .rd_request(rd_request),
  .wr_request(wr_request),
  .ready(ready),
  .rd_data(rd_data),
  .wr_data(values[word_no]),
  .mdio_pin(mdio_pin),
  .mdc_pin(mdc_pin)
  );  
  
  
endmodule
