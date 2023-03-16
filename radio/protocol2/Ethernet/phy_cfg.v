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
  input [10:0] skew_rxtxclk31,

  //output
  output reg [1:0] speed,
  output reg duplex,
  output reg [1:0] phychip,
  output [7:0] reg_rxtxc,
  output [7:0] reg_rxtxd,
  output [10:0] reg_rxtxclk21,
  output [10:0] reg_rxtxclk31,
  
  //hardware pins
  inout mdio_pin,
  output mdc_pin  
);


//-----------------------------------------------------------------------------
//                           initialization data
//-----------------------------------------------------------------------------

//mdio register values
logic [15:0] values [19:0];

//mdio register addresses 
logic [4:0] addresses [19:0];

reg [4:0] word_no, stop_word_no;


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

always @(posedge clock)  begin
  // find out if we're a 9021 or a 9031
  if (!phychip[1])  begin
    word_no <= 19;
    addresses[19] <= 3; 
    values[19] <= 16'hxxxx;

    if (ready) begin
      rd_request <= 1'b1;
      if (rd_data[9:4] == 6'b100001) begin // 9021
        phychip <= 2'b11;
        values[8] <= 16'h0200; // Allow 1GB but don't advertise half duplex in 1000BASET
        values[7] <= 16'h8104;
        values[5] <= 16'h8105;
        values[3] <= 16'h8106;
        values[1] <= 16'h1300; // Restart autonegotiation
        values[0] <= 16'hxxxx;
        addresses[8] <= 9;
        addresses[7] <= 11;
        addresses[6] <= 12;
        addresses[5] <= 11;
        addresses[4] <= 12;
        addresses[3] <= 11;
        addresses[2] <= 12;
        addresses[1] <= 0;
        addresses[0] <= 31; 
      end
      else if (rd_data[9:4] == 6'b100010) begin // 9031
        phychip <= 2'b10;
        values[18] <= 16'h0200; // Allow 1GB but don't advertise half duplex in 1000BASET
        values[17] <= 16'h0002;
        values[16] <= 16'h0004;
        values[15] <= 16'h4002;
        values[13] <= 16'h0002;
        values[12] <= 16'h0005;
        values[11] <= 16'h4002;
        values[9] <= 16'h0002;
        values[8] <= 16'h0006;
        values[7] <= 16'h4002;
        values[5] <= 16'h0002;
        values[4] <= 16'h0008;
        values[3] <= 16'h4002;
        values[1] <= 16'h1300; // Restart autonegotiation
        values[0] <= 16'hxxxx;
        addresses[18] <= 9;
        addresses[17] <= 5'h0d;
        addresses[16] <= 5'h0e;
        addresses[15] <= 5'h0d;
        addresses[14] <= 5'h0e;
        addresses[13] <= 5'h0d;
        addresses[12] <= 5'h0e;
        addresses[11] <= 5'h0d;
        addresses[10] <= 5'h0e;
        addresses[9] <= 5'h0d;
        addresses[8] <= 5'h0e;
        addresses[7] <= 5'h0d;
        addresses[6] <= 5'h0e;
        addresses[5] <= 5'h0d;
        addresses[4] <= 5'h0e;
        addresses[3] <= 5'h0d;
        addresses[2] <= 5'h0e;
        addresses[1] <= 0;
        addresses[0] <= 31; 
      end
      word_no <= 0;
    end
    else //!ready
      rd_request <= 0;
  end
  else if ((init_request || skew_rxtxclk21[10] != last_skew_changed) && !init_required) begin
    if (last_skew_changed != skew_rxtxclk21[10]) begin
      last_skew_changed <= skew_rxtxclk21[10];
      stop_word_no <= 4'd2; // skip Restart autonegotiation
    end
    else
      stop_word_no <= 4'd1;

    update_skew <= 1'b1;
    status_ignore <= 23'd0;
    init_required <= 1'b1;
  end
  else if (update_skew) begin  
    if (phychip[0]) begin // 9021
      values[6] <= {skew_rxtxclk21[8:5], skew_rxtxc[7:4], skew_rxtxclk21[3:0], skew_rxtxc[3:0]};
      values[4] <= {skew_rxtxd[7:4], skew_rxtxd[7:4], skew_rxtxd[7:4], skew_rxtxd[7:4]};
      values[2] <= {skew_rxtxd[3:0], skew_rxtxd[3:0], skew_rxtxd[3:0], skew_rxtxd[3:0]};
    end
    else begin // 9031
      values[14] <= {8'b0, skew_rxtxc}; //RGMII Control Signal Pad Skew
      values[10] <= {skew_rxtxd[7:4], skew_rxtxd[7:4], skew_rxtxd[7:4], skew_rxtxd[7:4]}; //RGMII RX Data Pad Skew
      values[6] <= {skew_rxtxd[3:0], skew_rxtxd[3:0], skew_rxtxd[3:0], skew_rxtxd[3:0]}; //RGMII TX Data Pad Skew
      values[2] <= {6'b0, skew_rxtxclk31[4:0], skew_rxtxclk31[9:5]}; //RGMII TX/RX Clock Pad Skew
    end
    reg_rxtxc <= skew_rxtxc;
    reg_rxtxd <= skew_rxtxd;
    reg_rxtxclk21 <= skew_rxtxclk21;
    reg_rxtxclk31 <= skew_rxtxclk31;
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
          word_no <= (phychip[0]) ? 8 : 18;
          state <= WRITING;
          init_required <= 1'b0;
        end
        else begin
          word_no <= 4'd0;
          rd_request <= 1'b1;
          state <= READING;
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
