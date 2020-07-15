
//  SPI flash memory code for Odyssey-2 project
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
//
//  copyright 2018 David Fainitski N7DDC


/*
 
	EPCS64 memory layout
	
	Bytes 				= 8M
	Sectors				= 128
	Bytes per sector 	= 65k
	Pages per sector 	= 256
	Number of pages  	= 32768
	Bytes per page   	= 256
	
	Slot              = 2MB
	
	Address Range (Byte Addresses in HEX)
	
	Sector	Start    End
	
Slot 3:
	127      H'7F0000 H'7FFFFF
   126      H'7E0000 H'7EFFFF
	..........................
	97       H'610000 H'61FFFF
   96       H'600000 H'60FFFF
	
Slot 2:
	95       H'5F0000 H'5FFFFF
   94       H'5E0000 H'5EFFFF
	..........................
	65       H'420000 H'42FFFF
   64       H'410000 H'41FFFF
	
Slot 1:
	63       H'400000 H'40FFFF
   62       H'3F0000 H'3FFFFF
	..........................
	33       H'210000 H'21FFFF
   32       H'200000 H'20FFFF  ****
	
	31 		H'1F0000 H'1FFFFF
	30 		H'1E0000 H'1EFFFF
	29 		H'1D0000 H'1DFFFF
	28 		H'1C0000 H'1CFFFF
	27 		H'1B0000 H'1BFFFF
	26 		H'1A0000 H'1AFFFF
	25 		H'190000 H'19FFFF
	24 		H'180000 H'18FFFF
	23 		H'170000 H'17FFFF
	22 		H'160000 H'16FFFF
	21 		H'150000 H'15FFFF
	20 		H'140000 H'14FFFF
	19 		H'130000 H'13FFFF
	18 		H'120000 H'12FFFF
	17 		H'110000 H'11FFFF
	16 		H'100000 H'10FFFF
	15 		H'0F0000 H'0FFFFF
	14 		H'0E0000 H'0EFFFF
	13 		H'0D0000 H'0DFFFF
	12 		H'0C0000 H'0CFFFF
	11 		H'0B0000 H'0BFFFF
	10 		H'0A0000 H'0AFFFF
	 9 		H'090000 H'09FFFF
	 8 		H'080000 H'08FFFF
	 7 		H'070000 H'07FFFF
	 6 		H'060000 H'06FFFF
	 5 		H'050000 H'05FFFF
	 4 		H'040000 H'04FFFF
	 3 		H'030000 H'03FFFF
	 2 		H'020000 H'02FFFF
	 1 		H'010000 H'01FFFF
	 0 		H'000000 H'00FFFF		
		
Each Sector holds 256 Pages each of 256 bytes

*/

module flash (
input clock,  
input erase_req,
input write_req,
input [1:0] slot_num,
input [2047:0] wr_data,
output reg erase_done = 0,
output reg wr_done = 0,
output reg [2047:0] rd_data,

// serial flash interface
// see W25Q64JV as example
output reg DCLK,
output reg DATAOUT,
input      DATAIN,
output reg FLASH_NCE
);

// states used un the machine
localparam 	sSendCom   = 8'd50,
				sSendCom1  = 8'd51,
				sSendCom2  = 8'd52,
				sSendCom3  = 8'd53,
				sSendAddr  = 8'd60,
				sSendAddr1 = 8'd61,
				sSendAddr2 = 8'd62,
				sSendAddr3 = 8'd63,
				sReadSrv   = 8'd70,
				sReadSrv1  = 8'd71,
				sReadSrv2  = 8'd72,
				sReadSts   = 8'd80,
				sReadSts1  = 8'd81,
				sReadSts2  = 8'd82,
				sWriteSrv  = 8'd90,
				sWriteSrv1 = 8'd91,
				sWriteSrv2 = 8'd92,
				sWriteSrv3 = 8'd93;
	
	
reg [7:0] sector_cnt;
reg [15:0] bit_cnt;
reg [7:0] command, status;
reg [23:0] address; 
reg [7:0] state = 0, return_state = 0;
reg erase_req_old = 0, write_req_old = 0;
	
	
always @(posedge clock)
begin
   case (state)
	0: begin
	      DCLK <= 0;
	      DATAOUT <= 0;
	      FLASH_NCE <= 1;
	      if(erase_req != erase_req_old)
		   begin
		      erase_req_old <= erase_req;
			   address[23 -:8] <= slot_num * 7'd32; // starting address
				address[15:0] <= 16'd0;
			   sector_cnt <= 8'd31;
			   state <= 1'd1;
		   end
		   else if(write_req != write_req_old)
		   begin
		      write_req_old <= write_req;
			   state <= 5'd10;
		   end
	   end
	1: begin  // Erasing slot
		    command <= 8'h06; // write enable command
			 return_state <= state + 1'd1;
			 state <= sSendCom;
		end
	2: begin
			 FLASH_NCE <= 1;
			 command <= 8'hD8;      //  erase sector command
			 return_state <= state + 1'd1;
			 state <= sSendCom;				
		end	
	3: begin 
			 return_state <= state + 1'd1;
			 state <= sSendAddr;
		end	
	4: begin     // waiting for the finish of erasing
			 FLASH_NCE <= 1;
			 command <= 8'h05;  // read status command
			 return_state <= state + 1'd1;
			 state <= sSendCom; 
	   end
   5: begin
		    return_state <= state + 1'd1;
			 state <= sReadSts;
	   end
   6: if(status[0] == 1) 
		   state <= 8'd4; // erasing is finished ?
		else state <= state + 1'd1;
		
	7:	if(sector_cnt != 0)
      begin
		   sector_cnt <= sector_cnt - 1'd1;
			address[23-:8] <= address[23-:8] + 1'd1;
			state <= 8'd1;               // erasing next sector in this slot
      end	
	   else        // the last sector in Slot was erased
		begin 
		   address[23 -:8] <= slot_num * 7'd32; // return to starting address
			erase_done <= ~erase_done;
			state <= 1'd0;  		  
		end 
		
		//
  10: begin // Writing the page (256 bytes of data)
		   command <= 8'h06; // write enable command
			return_state <= state + 1'd1;
			state <= sSendCom;
		end
  11: begin	 
         FLASH_NCE <= 1;  
			command <= 8'h02;   // writing data command
			return_state <= state + 1'd1;
			state <= sSendCom;
		end 
  12: begin
			return_state <= state + 1'd1; // write address
			state <= sSendAddr; 
		end
  13: begin
		   return_state <= state + 1'd1; // starting to write data
			state <= sWriteSrv;
		end
  14: begin  // waiting for the finish
		   command <= 8'h05;  // read status command
			return_state <= state + 1'd1;
			state <= sSendCom;
		end
  15: begin
		   return_state <= state + 1'd1; // read status
			state <= sReadSts;
	   end
  16: if (status[0] == 1) 
         state <= 8'd14; // check again
		else 
			state <= state + 1'd1;
//

  17: begin  // check writed data
			command <= 8'h03; // send the Read command
			return_state <= state + 1'd1;
			state <= sSendCom;
		end	
  18: begin
			return_state <= state + 1'd1;
			state <= sSendAddr; // send the address
		end	
  19: begin
			return_state <= state + 1'd1; // read data
			state <= sReadSrv;
		end	
  20: begin
         wr_done <= ~wr_done;
		   address[23:8] <= address[23:8] + 1'd1; // insrease address for writing next page
			state <= 1'd0;
      end  
		 		 
			 
//
 sSendCom :	begin    
               bit_cnt <= 8'd7;
					FLASH_NCE <= 0;
					state <= sSendCom1;
            end
 sSendCom1:	begin
               DATAOUT <= command[bit_cnt]; 
					state <= sSendCom2;
				end
 sSendCom2:	begin
               DCLK <= 1;
				   state <= sSendCom3;
				end
 sSendCom3:	begin
               DCLK <= 0;
				   if (bit_cnt != 0) begin bit_cnt <= bit_cnt - 1'd1; state <= sSendCom1; end
				   else state <= return_state; 
				end
//			
 sSendAddr: begin
               bit_cnt <= 8'd23;
					state <= sSendAddr1;
            end
 sSendAddr1: begin
               DATAOUT <= address[bit_cnt];
					state <= sSendAddr2;
            end				
 sSendAddr2: begin
               DCLK <=1;
					state <= sSendAddr3;
            end
 sSendAddr3: begin
               DCLK <= 0;
					if (bit_cnt != 0) begin bit_cnt <= bit_cnt - 1'd1; state <= sSendAddr1; end
					else state <= return_state;
            end	
//
  sReadSts: begin
               bit_cnt <= 8'd7;
					state <= sReadSts1;
            end				
 sReadSts1: begin
               status[bit_cnt] <= DATAIN;
				   DCLK <= 1;	
					state <= sReadSts2;
            end
 sReadSts2: begin
               DCLK <= 0;
					if (bit_cnt != 0) begin bit_cnt <= bit_cnt - 1'd1; state <= sReadSts1; end
					else begin FLASH_NCE <= 1; state <= return_state; end
            end
//			
 sWriteSrv: begin
               bit_cnt <= 16'd2047; 
	            state <= sWriteSrv1;			  
            end 
sWriteSrv1: begin
               DATAOUT <= wr_data[bit_cnt];
	            state <= sWriteSrv2;			  
            end 
sWriteSrv2: begin
               DCLK <= 1;
	            state <= sWriteSrv3;			  
            end
sWriteSrv3: begin
               DCLK <= 0;
					if (bit_cnt != 0) begin bit_cnt <= bit_cnt - 1'd1; state <= sWriteSrv1; end
	            else begin FLASH_NCE <= 1; state <= return_state; end		
				end									
//	
	
  sReadSrv: begin
               bit_cnt <= 16'd2047; // Read 256 bytes
				   state <= sReadSrv1;
            end 
 sReadSrv1:	begin
               rd_data[bit_cnt] <= DATAIN;
					DCLK <= 1;
               state <= sReadSrv2;
            end 
 sReadSrv2: begin
               DCLK <= 0;
					if (bit_cnt != 0) 
					begin 
					   bit_cnt <= bit_cnt - 1'd1; 
						state <= sReadSrv1; 
					end
					else begin FLASH_NCE <= 1; state <= return_state; end
            end
			
	default:
		state <= 1'd0;
	endcase
end	
	
	

endmodule
	
	