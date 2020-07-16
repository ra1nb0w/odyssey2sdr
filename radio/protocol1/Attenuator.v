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


//  Attenuator - 2011  (C) Phil Harman VK6APH

//  Driver for Minicircuits DAT-33-SP+ attenuator
//  C16 set = 16dB, C8 set = 8dB etc

//
// NOTE: CLK is a max of 10MHz

/*


			    +--+  +--+  +--+  +--+  +--+  +--+  
CLK 	    ---+  +--+  +--+  +--+  +--+  +--+  +----
                >  < 30nS min      
											   >||< 10nS min
			   +-----+-----+-----+-----+-----+
DATA        | C16 | C8  | C4  | C2  | C1  |
			   +-----+-----+-----+-----+-----+--------------------
			  MSB                          LSB                                     
			                                        +--+
LE          -------------------------------------+  +----------
											           >  < 30nS min

The register data is latched once LE goes high. 


*/

module Attenuator (clk, att, att_2, ATTN_CLK, ATTN_DATA, ATTN_LE, ATTN_LE_2);

input clk;								   // CMCLK - 12.288MHz
input [4:0]att;		            	// Attenuator setting
input [4:0]att_2; 
output reg ATTN_CLK;					   // clock to attenuator chip - max 10MHz 
output reg ATTN_DATA;					// data to attenuator chip
output reg ATTN_LE;						// data latch to attenuator chip]
output reg ATTN_LE_2;

reg [2:0]bit_count;
wire [5:0]send_data, send_data_2;

assign send_data = {att, 1'b0};		// append 0 to end of data
assign send_data_2 = {att_2, 1'b0};		

reg [3:0] state;
reg [5:0] previous_data, previous_data_2;

always @ (negedge clk)
begin

case (state)

0: begin 
   bit_count <= 6;
   previous_data <= att;				// save current attenuator data in case it changes whilst we are 
	previous_data_2 <= att_2;
   state <= state + 1'b1;				// send data
   end 

1:	begin
	ATTN_DATA <= send_data[bit_count - 1];
	state <= state + 1'b1;
	end
	
// clock data out, set clock high  
2:  begin 
	bit_count <= bit_count - 1'b1;
	ATTN_CLK <= 1'b1;
	state <= state + 1'b1;
	end 
	
// set clock low	
3:	begin
	ATTN_CLK <= 0;
		if (bit_count == 0) begin		// all data sent? If so send latch signal
			state <= state + 1'b1;
		end 
		else state <= 1;				// more bits to send
	end
	 
// delay before we send the LE as required by the attenuator chip	
4:	begin
	ATTN_LE <= 1'b1;
	state <= state + 1'b1;
	end
	
	
// send to 2-nd ATT
5: begin
   ATTN_LE <= 0;
	bit_count <= 6;
	state <= state + 1'b1;
	end
	
6:	begin
	ATTN_DATA <= send_data_2[bit_count - 1];
	state <= state + 1'b1;
	end
	
// clock data out, set clock high  
7:  begin 
	bit_count <= bit_count - 1'b1;
	ATTN_CLK <= 1'b1;
	state <= state + 1'b1;
	end 
	
// set clock low	
8:	begin
	ATTN_CLK <= 0;
		if (bit_count == 0) begin		// all data sent? If so send latch signal
			state <= state + 1'b1;
		end 
		else state <= 4'd6;				// more bits to send
	end
	 
// delay before we send the LE as required by the attenuator chip	
9:	begin
	ATTN_LE_2 <= 1'b1;
	state <= state + 1'b1;
	end
	
	
	
	
// reset LE pulse and wait until data changes	
10:	begin
	ATTN_LE_2 <= 0;
		if (att != previous_data | att_2 != previous_data_2) begin  // loop here until data changes
			state <= 0;
		end
	end 
	
endcase

end 

endmodule

