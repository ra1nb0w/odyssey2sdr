//////////////////////////////////////////////////////////////////////
// Author:      Russell Merrick
// Git:         https://github.com/nandland/nandland
// License:     not found
//////////////////////////////////////////////////////////////////////
// Description: This file contains the UART Receiver.  This receiver is 
//              able to receive 8 bits of serial data, one start bit, one 
//              stop bit, and no parity bit.  When receive is complete 
//              o_RX_DV will be driven high for one clock cycle.
// 
// Parameters:  Set Parameter CLKS_PER_BIT as follows:
//              CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
//              Example: 25 MHz Clock, 115200 baud UART
//              (25000000)/(115200) = 217
//////////////////////////////////////////////////////////////////////////////

module UART_RX
  #(parameter CLKS_PER_BIT = 217)
  (
   input            i_Rst_L,
   input            i_Clock,
   input            i_RX_Serial,
   output reg       o_RX_DV,
   output reg [7:0] o_RX_Byte
   );
   
  localparam RX_IDLE      = 3'b000;
  localparam RX_START_BIT = 3'b001;
  localparam RX_DATA_BITS = 3'b010;
  localparam RX_STOP_BIT  = 3'b011;
  localparam RX_CLEANUP   = 3'b100;
  
  reg [$clog2(CLKS_PER_BIT)-1:0] r_Clock_Count;
  reg [2:0] r_Bit_Index; //8 bits total
  reg [2:0] r_SM_Main = RX_IDLE;
  
  
  // Purpose: Control RX state machine
  always @(posedge i_Clock or negedge i_Rst_L)
  begin
    if (~i_Rst_L)
    begin
      r_SM_Main <= 3'b000;
      o_RX_DV   <= 1'b0;
    end
    else
    begin
      case (r_SM_Main)
      RX_IDLE :
        begin
          o_RX_DV       <= 1'b0;
			 o_RX_Byte     <= 8'b0;
          r_Clock_Count <= 0;
          r_Bit_Index   <= 0;
          
          if (i_RX_Serial == 1'b0)          // Start bit detected
            r_SM_Main <= RX_START_BIT;
          else
            r_SM_Main <= RX_IDLE;
        end
      
      // Check middle of start bit to make sure it's still low
      RX_START_BIT :
        begin
          if (r_Clock_Count == (CLKS_PER_BIT-1)/2)
          begin
            if (i_RX_Serial == 1'b0)
            begin
              r_Clock_Count <= 0;  // reset counter, found the middle
              r_SM_Main     <= RX_DATA_BITS;
            end
            else
              r_SM_Main <= RX_IDLE;
          end
          else
          begin
            r_Clock_Count <= r_Clock_Count + 1;
            r_SM_Main     <= RX_START_BIT;
          end
        end // case: RX_START_BIT
      
      
      // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
      RX_DATA_BITS :
        begin
          if (r_Clock_Count < CLKS_PER_BIT-1)
          begin
            r_Clock_Count <= r_Clock_Count + 1;
            r_SM_Main     <= RX_DATA_BITS;
          end
          else
          begin
            r_Clock_Count          <= 0;
            o_RX_Byte[r_Bit_Index] <= i_RX_Serial;
            
            // Check if we have received all bits
            if (r_Bit_Index < 7)
            begin
              r_Bit_Index <= r_Bit_Index + 1;
              r_SM_Main   <= RX_DATA_BITS;
            end
            else
            begin
              r_Bit_Index <= 0;
              r_SM_Main   <= RX_STOP_BIT;
            end
          end
        end // case: RX_DATA_BITS
      
      
      // Receive Stop bit.  Stop bit = 1
      RX_STOP_BIT :
        begin
          // Wait CLKS_PER_BIT/2-1 clock cycles for Stop bit to finish
          if (r_Clock_Count < CLKS_PER_BIT/2-1)
          begin
            r_Clock_Count <= r_Clock_Count + 1;
            r_SM_Main     <= RX_STOP_BIT;
          end
          else
          begin
            o_RX_DV       <= 1'b1;
            r_Clock_Count <= 0;
            r_SM_Main     <= RX_CLEANUP;
          end
        end // case: RX_STOP_BIT
      
      
      // Stay here 1 clock
      RX_CLEANUP :
        begin
          r_SM_Main <= RX_IDLE;
          o_RX_DV   <= 1'b0;
        end
      
      
      default :
        r_SM_Main <= RX_IDLE;
      
    endcase
    end // else: !if(~i_Rst_L)
  end // always @ (posedge i_Clock or negedge i_Rst_L)
  
endmodule // UART_RX



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
