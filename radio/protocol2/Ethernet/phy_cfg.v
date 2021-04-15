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
// initialize the PHY device on startup and when allow_1Gbit changes
// by writing config data to its MDIO registers; 
// continuously read PHY status from the MDIO registers
//-----------------------------------------------------------------------------

module phy_cfg(
  //input
  input clock,        //2.5 MHZ
  input init_request,
  input allow_1Gbit,  //speed selection jumper: open 

  //output
  output reg [1:0] speed,
  output reg duplex,
  
  //hardware pins
  inout mdio_pin,
  output mdc_pin  
);


//-----------------------------------------------------------------------------
//                           initialization data
//-----------------------------------------------------------------------------

//mdio register values
logic [15:0] values [18:0];

//mdio register addresses 
logic [4:0] addresses [18:0];

reg [3:0] word_no; 


//-----------------------------------------------------------------------------
//                            state machine
//-----------------------------------------------------------------------------

//phy initialization required 
//if allow_1Gbit input has changed or init_request input was raised
reg last_allow_1Gbit, init_required;

wire ready;
wire [15:0] rd_data;
reg rd_request, wr_request;


//state machine  
localparam READING = 1'b0, WRITING = 1'b1;  
reg state = READING;  

always @(posedge clock)  
  begin
  if (init_request || (allow_1Gbit != last_allow_1Gbit))  begin
    init_required <= 1;
    values[18] = {6'b0, allow_1Gbit, 9'b0};

    values[17] = 16'h0002;
    values[16] = 16'h0004;
    values[15] = 16'h4002;
    //values[14] = 16'b0000_0000_0110_0111;  // RX_CTL: -0.06   - TX_CTL: 0.0
    values[14] = 16'b0000_0000_0111_0111;  // RX_CTL: +0.0   - TX_CTL: 0.0

    // program address 2 register 5
    values[13] = 16'h0002;
    values[12] = 16'h0005;
    values[11] = 16'h4002;
    //values[10] = 16'b1010_1010_0111_0111;   // RD3: +0.18 - RD2: +0.18 - RD1: 0.0 - RD0: 0.0
    values[10] = 16'b0111_0111_0111_0111;   // RD3: +0.0 - RD2: +0.0 - RD1: 0.0 - RD0: 0.0

    // program address 2 register 6
    values[9] = 16'h0002;
    values[8] = 16'h0006;
    values[7] = 16'h4002;
    //values[6] = 16'b1000_0111_1001_0111;   // TD3: +0.06  - TD2: 0.0  - TD1: +0.12 - TD0: 0.0
    values[6] = 16'b0111_0111_0111_0111;   // TD3: +0.0  - TD2: 0.0  - TD1: +0.0 - TD0: 0.0

    // program address 2 register 8
    values[5] = 16'h0002;
    values[4] = 16'h0008;
    values[3] = 16'h4002;
    //values[2] = 16'b0000_00_00110_11010;  // TX_CLK: -0.54   - RX_CLK: +0.66
    values[2] = 16'b0000_00_01111_10000;  // TX_CLK: -0.0   - RX_CLK: +0.06

    values[1] = 16'h1300;
    values[0] = 16'hxxxx;

    addresses[18] = 9;
    addresses[17] = 5'h0d;
    addresses[16] = 5'h0e;
    addresses[15] = 5'h0d;
    addresses[14] = 5'h0e;
    addresses[13] = 5'h0d;
    addresses[12] = 5'h0e;
    addresses[11] = 5'h0d;
    addresses[10] = 5'h0e;
    addresses[9] = 5'h0d;
    addresses[8] = 5'h0e;
    addresses[7] = 5'h0d;
    addresses[6] = 5'h0e;
    addresses[5] = 5'h0d;
    addresses[4] = 5'h0e;
    addresses[3] = 5'h0d;
    addresses[2] = 5'h0e;
    addresses[1] = 0;
    addresses[0] = 31; 
  end
  
  if (ready)
    case (state)
      READING:
        begin
        speed <= rd_data[6:5];
        duplex <= rd_data[3];
        
        if (init_required)
          begin
          wr_request <= 1;
          word_no <= 18;
          last_allow_1Gbit <= allow_1Gbit;
          state  <= WRITING;
          init_required <= 0;
          end
        else
          rd_request <= 1'b1;
        end

      WRITING:
        begin
        if (word_no == 4'b1) state <= READING;   // *** should this be == 0?
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
