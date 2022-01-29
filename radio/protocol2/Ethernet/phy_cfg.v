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
logic [15:0] values [18:0];

//mdio register addresses 
logic [4:0] addresses [18:0];

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

assign values[18] = {6'b0, allow_1Gbit, 9'b0};
assign values[17] = 16'h0002;
assign values[16] = 16'h0004;
assign values[15] = 16'h4002;
// --    values[14] = 16'b0000_0000_0111_0111;  // RX_CTL: +0.0   - TX_CTL: 0.0
assign values[13] = 16'h0002;
assign values[12] = 16'h0005;
assign values[11] = 16'h4002;
// --    values[10] = 16'b0111_0111_0111_0111;   // RD3: +0.0 - RD2: +0.0 - RD1: 0.0 - RD0: 0.0
assign values[9] = 16'h0002;
assign values[8] = 16'h0006;
assign values[7] = 16'h4002;
// --    values[6] = 16'b0111_0111_0111_0111;   // TD3: +0.0  - TD2: 0.0  - TD1: +0.0 - TD0: 0.0
assign values[5] = 16'h0002;
assign values[4] = 16'h0008;
assign values[3] = 16'h4002;
// --   values[2] = 16'b0000_00_01111_10000;  // TX_CLK: -0.0   - RX_CLK: +0.06
assign values[1] = 16'h1300;
assign values[0] = 16'hxxxx;

assign addresses[18] = 9;
assign addresses[17] = 5'h0d;
assign addresses[16] = 5'h0e;
assign addresses[15] = 5'h0d;
assign addresses[14] = 5'h0e;
assign addresses[13] = 5'h0d;
assign addresses[12] = 5'h0e;
assign addresses[11] = 5'h0d;
assign addresses[10] = 5'h0e;
assign addresses[9] = 5'h0d;
assign addresses[8] = 5'h0e;
assign addresses[7] = 5'h0d;
assign addresses[6] = 5'h0e;
assign addresses[5] = 5'h0d;
assign addresses[4] = 5'h0e;
assign addresses[3] = 5'h0d;
assign addresses[2] = 5'h0e;
assign addresses[1] = 0;
assign addresses[0] = 31;


always @(posedge clock)  begin
  if ((init_request || skew_rxtxclk21[10] != last_skew_changed) && !init_required) begin
    if (last_skew_changed != skew_rxtxclk21[10]) begin
      last_skew_changed <= skew_rxtxclk21[10];
      stop_word_no <= 5'd2;
    end
    else
      stop_word_no <= 5'd1;

    update_skew <= 1'b1;
    status_ignore <= 23'd0;
    init_required <= 1'b1;
  end
  else if (update_skew) begin
    // 67 is rx-ctl,tx-ctl . 46 is rx-data,tx-data . 07 is rxclk . 0f is txclk . 00 is cmd to set
    values[14] <= { 8'b0000_0000, skew_rxtxc[7:4], skew_rxtxc[3:0] };
    values[10] <= { skew_rxtxd[7:4], skew_rxtxd[7:4], skew_rxtxd[7:4], skew_rxtxd[7:4]};
    values[6] <= { skew_rxtxd[3:0], skew_rxtxd[3:0], skew_rxtxd[3:0], skew_rxtxd[3:0]};
    values[2] <= { 6'b0000_00, skew_rxtxclk21[4:0], skew_rxtxclk21[9:5] };
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
          word_no <= 5'd18;
          state <= WRITING;
          init_required <= 1'b0;
        end
        else begin
          word_no <= 5'd0;
          rd_request <= 1'b1;
        end
      end

      WRITING: begin
        if (word_no == stop_word_no) state <= READING;
        else wr_request <= 1'b1;
        word_no <= word_no - 5'b1;
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
