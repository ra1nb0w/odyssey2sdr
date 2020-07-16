//
//  HPSDR - High Performance Software Defined Radio
//
//  Hermes code. 
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
//  Copyright 2020 Davide Gerhard IV3CVE

module mcu
#(parameter [63:0] fw_version = 64'b0)
(
	// 122.88 MHz
	input clk,
	
	// UART interface to MCU
	input  mcu_uart_rx,
	output mcu_uart_tx,
	
	// high when ptt is enabled
	input ptt
);


//**** UART declaration ****//
// the clock used divided by the UART speed
// calc: main clock (clk) divided by UART speed
// in this case: 122880000/9600
// since we are using as parameters 9600-8N1  = 12800
// since we are using as parameters 19200-8N1 = 6400
localparam uart_clock_per_bit = 6400;
// high when the byte is transmitted
wire uart_tx_done;
// high when the UART needs to send the byte
reg uart_tx_dv = 1'b0;
// byte to transmit through UART
reg [7:0] uart_tx_byte = 8'b0;
// high during tramission
wire uart_tx_active;

// instantiate the TX UART module
UART_TX #(.CLKS_PER_BIT(uart_clock_per_bit)) UART_TX_Inst
(
.i_Clock(clk),
.i_TX_DV(uart_tx_dv),
.i_TX_Byte(uart_tx_byte),
.o_TX_Active(uart_tx_active),
.o_TX_Serial(mcu_uart_tx),
.o_TX_Done(uart_tx_done),
.i_Rst_L(1'b1)
);

// waiting that trasmission has finished
reg send_waiting = 1'b0;

// UART TX status
localparam [2:0] TX_IDLE   = 3'd0;
localparam [2:0] TX_RADIO  = 3'd1;
localparam [2:0] TX_PTT    = 3'd2;

// state machine for the booting operation
reg [2:0] state_tx = TX_IDLE;

// variable to check if PTT has changed his status
reg ptt_old = 1'b0;

// just to send the radio stage at boot time
// we can got immediatelly to TX_RADIO since
// we need a cycle to initialize the UART module
reg first_start = 1'b1;

// MCU TX FSM
always @(posedge clk)
begin
	if (~send_waiting)
	case (state_tx)
		TX_IDLE:
		begin
			if (ptt != ptt_old)
			begin
				ptt_old <= ptt;
				if (ptt)
					state_tx <= TX_PTT;
				else
					state_tx <= TX_RADIO;
			end
			else if (first_start)
				state_tx <= TX_RADIO;
		end
		
		// we are in the radio stage (only RX)
		TX_RADIO:
		begin
			uart_tx_byte <= 8'h23;
			uart_tx_dv <= 1'b1;
			send_waiting <= 1'b1;
			state_tx <= TX_IDLE;
			if (first_start)
				first_start <= 1'b0;
		end
		
		// we are in transmission
		TX_PTT:
		begin
			uart_tx_byte <= 8'h24;
			uart_tx_dv <= 1'b1;
			send_waiting <= 1'b1;
			state_tx <= TX_IDLE;
		end
	endcase
			
	// send the next when we have sent the previous one
	else if (send_waiting & uart_tx_done)
	begin
		uart_tx_dv <= 1'b0;
		send_waiting <= 1'b0;
	end

end // always @(posedge clk)

endmodule



//////////////////////////////////////////////////////////////////////
// Author:      Russell Merrick
// Git:         https://github.com/nandland/nandland
// License:     not found
//////////////////////////////////////////////////////////////////////
// This file contains the UART Transmitter.  This transmitter is able
// to transmit 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When transmit is complete o_Tx_done will be
// driven high for one clock cycle.
//
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 25 MHz Clock, 115200 baud UART
// (25000000)/(115200) = 217
 
module UART_TX 
  #(parameter CLKS_PER_BIT = 217)
  (
   input       i_Rst_L,
   input       i_Clock,
   input       i_TX_DV,
   input [7:0] i_TX_Byte, 
   output reg  o_TX_Active,
   output reg  o_TX_Serial,
   output reg  o_TX_Done
   );
 
  localparam TX_IDLE      = 3'b000;
  localparam TX_START_BIT = 3'b001;
  localparam TX_DATA_BITS = 3'b010;
  localparam TX_STOP_BIT  = 3'b011;
  localparam TX_CLEANUP   = 3'b100;
  
  reg [2:0] t_SM_Main = TX_IDLE;
  reg [$clog2(CLKS_PER_BIT):0] t_Clock_Count;
  reg [2:0] t_Bit_Index;
  reg [7:0] t_TX_Data;


  // Purpose: Control TX state machine
  always @(posedge i_Clock or negedge i_Rst_L)
  begin
    if (~i_Rst_L)
    begin
      t_SM_Main <= 3'b000;
      o_TX_Done <= 1'b0;
    end
    else
    begin
      case (t_SM_Main)
      TX_IDLE :
        begin
          o_TX_Serial   <= 1'b1;         // Drive Line High for Idle
          o_TX_Done     <= 1'b0;
          t_Clock_Count <= 0;
          t_Bit_Index   <= 0;
			 o_TX_Active   <= 1'b0;
          
          if (i_TX_DV == 1'b1)
          begin
            o_TX_Active <= 1'b1;
            t_TX_Data   <= i_TX_Byte;
            t_SM_Main   <= TX_START_BIT;
          end
          else
            t_SM_Main <= TX_IDLE;
        end // case: IDLE
      
      
      // Send out Start Bit. Start bit = 0
      TX_START_BIT :
        begin
          o_TX_Serial <= 1'b0;
          
          // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
          if (t_Clock_Count < CLKS_PER_BIT-1)
          begin
            t_Clock_Count <= t_Clock_Count + 1;
            t_SM_Main     <= TX_START_BIT;
          end
          else
          begin
            t_Clock_Count <= 0;
            t_SM_Main     <= TX_DATA_BITS;
          end
        end // case: TX_START_BIT
      
      
      // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
      TX_DATA_BITS :
        begin
          o_TX_Serial <= t_TX_Data[t_Bit_Index];
          
          if (t_Clock_Count < CLKS_PER_BIT-1)
          begin
            t_Clock_Count <= t_Clock_Count + 1;
            t_SM_Main     <= TX_DATA_BITS;
          end
          else
          begin
            t_Clock_Count <= 0;
            
            // Check if we have sent out all bits
            if (t_Bit_Index < 7)
            begin
              t_Bit_Index <= t_Bit_Index + 1;
              t_SM_Main   <= TX_DATA_BITS;
            end
            else
            begin
              t_Bit_Index <= 0;
              t_SM_Main   <= TX_STOP_BIT;
            end
          end 
        end // case: TX_DATA_BITS
      
      
      // Send out Stop bit.  Stop bit = 1
      TX_STOP_BIT :
        begin
          o_TX_Serial <= 1'b1;
          
          // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if (t_Clock_Count < CLKS_PER_BIT-1)
          begin
            t_Clock_Count <= t_Clock_Count + 1;
            t_SM_Main     <= TX_STOP_BIT;
          end
          else
          begin
            o_TX_Done     <= 1'b1;
            t_Clock_Count <= 0;
            t_SM_Main     <= TX_CLEANUP;
            o_TX_Active   <= 1'b0;
          end 
        end // case: TX_STOP_BIT
      
      
      // Stay here 1 clock
      TX_CLEANUP :
        begin
          o_TX_Done <= 1'b1;
          t_SM_Main <= TX_IDLE;
        end
      
      
      default :
        t_SM_Main <= TX_IDLE;
      
    endcase
    end // else: !if(~i_Rst_L)
  end // always @ (posedge i_Clock or negedge i_Rst_L)
endmodule
