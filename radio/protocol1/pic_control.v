//
/*
Connection to PIC MCU


Commands:
1 - show firmware, 8bytes
2 - show  logo
3 - IP, 8 bytes, 1 - IP1, 2 - IP2, 3 - IP3, 4 - IP4
4 - show bootoader
5 - PTT ON
6 - PTT OFF





*/

module pic_control (
   input clock,  // 80kHz
	//
   inout MCU_RES,
	inout MCU_DATA,
	inout MCU_CLOCK,
	inout MCU_EN,
	//
	input PTT



);

parameter [63:0] fw_version = "no ver";

reg pic_res = 1;
reg pic_data, pic_clock, pic_en;
//
assign MCU_RES = 1'bz;
assign MCU_DATA = pic_data ? 1'bz : 1'b0;
assign MCU_CLOCK = pic_clock ? 1'bz : 1'b0;
assign MCU_EN = pic_en ? 1'bz : 1'b0;


reg [5:0] state = 0;
reg [5:0] return_state;
reg ptt_old = 0;
reg [7:0] send_data [0:8];
reg [7:0] send_byte;
reg [3:0] bit_cnt;
reg [3:0] byte_cnt;
reg[23:0] delay_cnt;

always @(posedge clock) 
begin
   case (state)
	0: begin
			pic_data <= 1;
			pic_clock <= 1;
			pic_en <= 1;
			delay_cnt <= 16'd4000; // 50ms
			return_state <= 1;
		   state <= 30;
	   end
		//	
	
		
	1: begin // show version command
	     send_data[0] <= 1;
		  send_data[1] <= fw_version[63:56];
		  send_data[2] <= fw_version[55:48];
        send_data[3] <= fw_version[47:40];
		  send_data[4] <= fw_version[39:32];
		  send_data[5] <= fw_version[31:24];
		  send_data[6] <= fw_version[23:16];
		  send_data[7] <= fw_version[15:8];
		  send_data[8] <= fw_version[7:0];
		  return_state <= 2;
		  state <= 20;
      end	
		

   2: begin
	      delay_cnt <= 24'd240000; // 3sec
			return_state <= 3;
		   state <= 30;
      end
	
   3:  begin
		   send_byte <= 2; // show logo command  
			bit_cnt <= 0;
			byte_cnt <= 8;
			pic_en <= 0;
			return_state <= 4; 
			state <= 22;   // send one byte  
	   end	
		
		
	
	4: if(PTT != ptt_old)
	   begin
	      if (PTT) send_byte = 5;
			else send_byte <= 6;
			bit_cnt <= 0;
			byte_cnt <= 8;
			pic_en <= 0;
			ptt_old <= PTT;
			return_state <= 4; 
			state <= 22;   // send one byte 
		end	
					

  20: begin
		   pic_en <= 0;
			bit_cnt <= 0;
			byte_cnt <=  0;
         state <= state + 1'd1;			
		end
		
  21: if(byte_cnt <= 8)
      begin
         send_byte <= send_data[byte_cnt];
			bit_cnt <= 0;
			state <= 22;  // send byte
      end
		else begin
		   pic_data <= 1;
			pic_clock <= 1;
			pic_en <= 1;
			delay_cnt <= 16'd4000;
		   state <= 30;
		end	
		
  22: if(bit_cnt <= 7) // sending a byte
      begin
	      pic_data <= send_byte[7-bit_cnt];
         state <= state + 1'd1;
      end
		else begin
		   byte_cnt <= byte_cnt + 1'd1;
		   state <= 21;
		end	
		
  23: begin
         pic_clock <= 0;
			state <= state + 1'd1;
      end 
		
  24: begin
         pic_clock <= 1;
			bit_cnt <= bit_cnt + 1'd1;
			state <= 22;
      end 
	


	
  30: if(delay_cnt != 0) delay_cnt <= delay_cnt - 1'd1; // delay
      else state <= return_state; 
	
	default: state <= 0;
	endcase

end





endmodule

