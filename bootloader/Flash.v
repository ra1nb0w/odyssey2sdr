//
// N7DDC, David Fainitski
// project Odyssey-II
// 04.2018
//



	
module flash (
input clock,  
input erase_req,
input write_req,
input [1:0] slot_num,
input [2047:0] wr_data,
output reg erase_done = 0,
output reg wr_done = 0,
output reg [2047:0] rd_data,
	
	
// FLASH interface
output reg DCLK,
output reg DATAOUT,
input      DATAIN,
output reg FLASH_NCE
);

	
parameter sSendCom   = 8'd50;
parameter sSendCom1  = 8'd51;
parameter sSendCom2  = 8'd52;
parameter sSendCom3  = 8'd53;
parameter sSendAddr  = 8'd60;
parameter sSendAddr1 = 8'd61;
parameter sSendAddr2 = 8'd62;
parameter sSendAddr3 = 8'd63;
parameter sReadSrv   = 8'd70;
parameter sReadSrv1  = 8'd71;
parameter sReadSrv2  = 8'd72;
parameter sReadSts   = 8'd80;
parameter sReadSts1  = 8'd81;
parameter sReadSts2  = 8'd82;
parameter sWriteSrv  = 8'd90;
parameter sWriteSrv1 = 8'd91;
parameter sWriteSrv2 = 8'd92;
parameter sWriteSrv3 = 8'd93;
	
	
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
//	
			
	default: state <= 1'd0;
	endcase
end	
	
	

endmodule
	
	