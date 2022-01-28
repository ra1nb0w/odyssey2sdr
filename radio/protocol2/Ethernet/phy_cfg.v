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
  input [7:0] skew_rxtxc, //control
  input [7:0] skew_rxtxd, //data
  input [10:0] skew_rxtxclk21, //clocks, skew_changed is MSb

  //output
  output reg [1:0] speed,
  output reg duplex,
  output [7:0] reg_rxtxc,
  output [7:0] reg_rxtxd,
  output [10:0] reg_rxtxclk21,
  
  //hardware pins
  inout mdio_pin,
  output mdc_pin  
);


//-----------------------------------------------------------------------------
//                           initialization data
//-----------------------------------------------------------------------------

//mdio register values
logic [15:0] values [8:0];

//mdio register addresses 
logic [4:0] addresses [8:0];

reg [3:0] word_no, stop_word_no; 


//-----------------------------------------------------------------------------
//                            state machine
//-----------------------------------------------------------------------------

//phy initialization required 
reg init_required;
reg last_skew_changed;

wire ready;
wire [15:0] rd_data;
reg rd_request, wr_request;
reg [22:0] status_ignore;
reg update_skew;


//state machine  
localparam READING = 1'b0, WRITING = 1'b1;
reg state = READING;  

assign values[8] = {6'b0, allow_1Gbit, 9'b0};
assign values[7] = 16'h8104; // Rx clk/ctrl and Tx clk/ctrl delay, in 0.12 ns units to reg 104h
assign values[5] = 16'h8105; // Rx pad skews, reg 105h
assign values[3] = 16'h8106; // Tx pad skews, reg 106h, added 25th Sept
// register values moved to sdr_received.v
assign values[1] = 16'h1300;
assign values[0] = 16'hxxxx;

// program address 2 register 8
//values[5] = 16'h0002;
//values[4] = 16'h0008;
//values[3] = 16'h4002;
//values[2] = 16'b0000_00_00110_11010;  // TX_CLK: -0.54   - RX_CLK: +0.66
//values[2] = 16'b0000_00_01111_10000;  // TX_CLK: -0.0   - RX_CLK: +0.06

assign addresses[8] = 9;
assign addresses[7] = 11;
assign addresses[6] = 12;
assign addresses[5] = 11;
assign addresses[4] = 12;
assign addresses[3] = 11;
assign addresses[2] = 12;
assign addresses[1] = 0;
assign addresses[0] = 31; 

always @(posedge clock)  begin
  if ((init_request || skew_rxtxclk21[10] != last_skew_changed) && !init_required) begin
    if (last_skew_changed != skew_rxtxclk21[10]) begin
      last_skew_changed <= skew_rxtxclk21[10];
      stop_word_no <= 4'd2;
    end
    else
      stop_word_no <= 4'd1;

    update_skew <= 1'b1;
    status_ignore <= 23'd0;
    init_required <= 1'b1;
  end
  else if (update_skew) begin  
    values[6] <= {skew_rxtxclk21[8:5], skew_rxtxc[7:4], skew_rxtxclk21[3:0], skew_rxtxc[3:0]};
    values[4] <= {skew_rxtxd[7:4], skew_rxtxd[7:4], skew_rxtxd[7:4], skew_rxtxd[7:4]};
    values[2] <= {skew_rxtxd[3:0], skew_rxtxd[3:0], skew_rxtxd[3:0], skew_rxtxd[3:0]};
    reg_rxtxc <= skew_rxtxc;
    reg_rxtxd <= skew_rxtxd;
    reg_rxtxclk21 <= skew_rxtxclk21;
    update_skew <= 1'b0;
  end
  else if (ready) begin
    case (state)
      READING: begin
        if (status_ignore == 23'd75000) begin // ?? Approx 2 secs
          speed <= rd_data[6:5];
          duplex <= rd_data[3];
        end
        else
          status_ignore <= status_ignore + 23'd1;

        if (init_required) begin
          wr_request <= 1'b1;
          word_no <= 4'd8;
          state <= WRITING;
          init_required <= 1'b0;
        end
        else begin
          word_no <= 4'd0;
          rd_request <= 1'b1;
        end
      end

      WRITING: begin
        if (word_no == stop_word_no) state <= READING;
        else wr_request <= 1'b1;
        word_no <= word_no - 4'b1;		  
      end

      endcase
  end
  else begin //!ready
    rd_request <= 1'b0;
    wr_request <= 1'b0;
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
