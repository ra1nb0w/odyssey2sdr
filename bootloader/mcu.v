
//  BootLoader code for Odyssey-2 project
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
//  copyright 2020 Davide Gerhard IV3CVE

module mcu
#(parameter [63:0] fw_version = 64'b0,
  parameter [7:0]  fw_type    = 8'b0)
(
	// 122.88 MHz
   input clk,
	
	// UART interface to MCU
	input  mcu_uart_rx,
	output mcu_uart_tx,

	// local IP address (for the moment we have only IPv4)
	input [31:0] ip,
	input eeprom_read_ready,
	
	// in which stage we are (used by MCU to print strings on display)
	input [3:0] stage,
	input stage_changed,
	
	// slot configuration
	// can be modified by the remote programmer
	// or by the MIC buttons from MCU
	input [1:0] slot_ext,
	
	// alert Reconfigure when we have received the slot
	output reg slot_ready = 1'b0,
	
	// bit with the amplifiers status
	input power_amplifier_ext,
	input audio_amplifier_ext,
	
	// return to the bootloader module
	// the right values
	output reg [1:0] slot = 2'b0,
	output reg power_amplifier = 1'b0,
	output reg audio_amplifier = 1'b0,

	// different from before if amplifier/slot status changed
	input status_changed_ext,
	
	// variable for the auto power on functionality
	input poweron_ext,
	input poweron_changed_ext,
	output reg poweron = 1'b0,
	
	// different from before if the ip is changed
	input ip_changed
);

//**** UART declaration ****//
// the clock used divided by the UART speed
// calc: main clock (clk) divided by UART speed
// in this case: 122880000/9600
// since we are using as parameters 9600-8N1  = 12800
// since we are using as parameters 19200-8N1 = 6400
localparam uart_clock_per_bit = 6400;
// high when a byte is received
wire uart_rx_dv;
// byte received by UART
wire [7:0] uart_rx_byte;
// high when the byte is transmitted
wire uart_tx_done;
// high when the UART needs to send the byte
reg uart_tx_dv = 1'b0;
// byte to transmit through UART
reg [7:0] uart_tx_byte = 8'b0;
// high during tramission
wire uart_tx_active;
	
// instantiate the RX UART module
UART_RX #(.CLKS_PER_BIT(uart_clock_per_bit)) UART_RX_Inst
(
.i_Clock(clk),
.i_RX_Serial(mcu_uart_rx),
.o_RX_DV(uart_rx_dv),
.o_RX_Byte(uart_rx_byte),
.i_Rst_L(1'b1)
);
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

// variable to check if it is the first boot
reg first_start = 1'b1;

// waiting that trasmission has finished
reg send_waiting = 1'b0;

// counter used to track how many bytes we have sent within a state
reg [7:0] sent_bytes_counter = 8'b0;

// manage the variable change
reg ip_changed_old = 1'b0;
reg stage_changed_old = 1'b0;

// TX FSM status
localparam [3:0] STATE_SEND_IDLE        = 4'd0;
localparam [3:0] STATE_SEND_STATUS      = 4'd1;
localparam [3:0] STATE_SEND_IP          = 4'd2;
localparam [3:0] STATE_SEND_VERSION     = 4'd3;
localparam [3:0] STATE_SEND_STAGE       = 4'd4;
localparam [3:0] STATE_REQUEST_STATE    = 4'd5;
localparam [3:0] STATE_REQUEST_POWERON  = 4'd6;
localparam [3:0] STATE_SEND_POWERON     = 4'd7;
localparam [3:0] STATE_END_FIRST_START  = 4'd8;

// state machine for the booting operation
reg [3:0] state_tx = STATE_SEND_IDLE;

// internal status used during receiveing
reg [1:0] slot_int = 2'b0;
reg power_amplifier_int = 1'b0;
reg audio_amplifier_int = 1'b0;
reg status_changed_int = 1'b0;
reg status_changed_int_old = 1'b0;
reg status_changed_ext_old = 1'b0;

// manage the auto power on option
reg poweron_int = 1'b0;
reg poweron_changed_int = 1'b0;
reg poweron_changed_int_old = 1'b0;
reg poweron_changed_ext_old = 1'b0;

// manage the status changes from network programmer
// and from mcu keys
// NOTE: must exist a simplier solution!
always @(posedge clk)
begin
	// we prioritize the MCU data since it is the one
	// that is wrote to eeprom
	if (status_changed_int != status_changed_int_old)
	begin
		status_changed_int_old <= status_changed_int;
		slot <= slot_int;
		power_amplifier <= power_amplifier_int;
		audio_amplifier <= audio_amplifier_int;
	end
	else if (status_changed_ext != status_changed_ext_old)
	begin
		status_changed_ext_old <= status_changed_ext;
		slot <= slot_ext;
		power_amplifier <= power_amplifier_ext;
		audio_amplifier <= audio_amplifier_ext;
	end
	
	// check if the power on option is changed
	if (poweron_changed_int != poweron_changed_int_old)
	begin
		poweron_changed_int_old <= poweron_changed_int;
		poweron <= poweron_int;
	end
	else if (poweron_changed_ext != poweron_changed_ext_old)
	begin
		poweron_changed_ext_old <= poweron_changed_ext;
		poweron <= poweron_ext;
	end
end


// MCU TX FSM
always @(posedge clk)
begin
	if (eeprom_read_ready & ~send_waiting)
	case (state_tx)
	
		STATE_SEND_IDLE: // idle state
		begin
			send_waiting <= 1'b0;
			uart_tx_dv <= 1'b0;
			if (first_start)
			begin
				state_tx <= STATE_SEND_IP;
			end
			else if (ip_changed != ip_changed_old)
			begin
				ip_changed_old <= ip_changed;
				state_tx <= STATE_SEND_IP;
			end
			else if (status_changed_ext != status_changed_ext_old)
			begin
				state_tx <= STATE_SEND_STATUS;
			end
			else if (stage_changed != stage_changed_old)
			begin
				stage_changed_old <= stage_changed;
				state_tx <= STATE_SEND_STAGE;
			end
			else if (poweron_changed_ext != poweron_changed_ext_old)
			begin
				state_tx <= STATE_SEND_POWERON;
			end
		end
	
		STATE_SEND_STATUS: // send status
		begin
			uart_tx_byte <= { 4'h5, slot, power_amplifier, audio_amplifier };
			uart_tx_dv <= 1'b1;
			send_waiting <= 1'b1;
			if (first_start)
				state_tx <= STATE_SEND_IP;
			else
				state_tx <= STATE_SEND_IDLE;
		end
		
		STATE_SEND_IP: // send IP address
		begin
			// send the command
			if (sent_bytes_counter == 0)
			begin
				uart_tx_byte <= 8'h40;
				uart_tx_dv <= 1'b1;
				send_waiting <= 1'b1;
				sent_bytes_counter <= sent_bytes_counter + 5'd1;
			end
			// this limitation is for IPv4
			else if (sent_bytes_counter <= 4)
			begin
				uart_tx_byte <= ip[(39-(sent_bytes_counter*8))-:8];
				uart_tx_dv <= 1'b1;
				send_waiting <= 1'b1;
				sent_bytes_counter <= sent_bytes_counter + 5'd1;
			end
			// send empty byte as fullfill
			else if (sent_bytes_counter <= 16)
			begin
				uart_tx_byte <= 8'h00;
				uart_tx_dv <= 1'b1;
				send_waiting <= 1'b1;
				sent_bytes_counter <= sent_bytes_counter + 5'd1;
			end
			// at the end go to the next stage
			else
			begin
				sent_bytes_counter <= 5'd0;
				if (first_start)
					state_tx <= STATE_SEND_VERSION;
				else
					state_tx <= STATE_SEND_IDLE;
			end
		end
		
		STATE_SEND_VERSION: // send version
		begin
			if (sent_bytes_counter == 0)
			begin
				// this is the bootloader version
				uart_tx_byte <= 8'h30 | fw_type;
				uart_tx_dv <= 1'b1;
				send_waiting <= 1'b1;
				sent_bytes_counter <= sent_bytes_counter + 5'd1;
			end
			else if (sent_bytes_counter <= 8)
			begin
				uart_tx_byte <= fw_version[(71-(sent_bytes_counter*8))-:8];
				uart_tx_dv <= 1'b1;
				send_waiting <= 1'b1;
				sent_bytes_counter <= sent_bytes_counter + 5'd1;
			end
			// at the end go to the next stage
			else
			begin
				sent_bytes_counter <= 5'd0;
				if (first_start)
					state_tx <= STATE_SEND_STAGE;
				else
					state_tx <= STATE_SEND_IDLE;
			end
		end
		
		STATE_SEND_STAGE: // send stage
		begin
			uart_tx_byte <= { 4'h2,  stage };
			uart_tx_dv <= 1'b1;
			send_waiting <= 1'b1;
			if (first_start)
				state_tx <= STATE_REQUEST_STATE;
			else
				state_tx <= STATE_SEND_IDLE;
		end
		
		STATE_REQUEST_STATE: // request the state
		begin
			uart_tx_byte <= 8'h50;
			uart_tx_dv <= 1'b1;
			send_waiting <= 1'b1;
			if (first_start)
				state_tx <= STATE_REQUEST_POWERON;
			else
				state_tx <= STATE_SEND_IDLE;
		end
		
		STATE_REQUEST_POWERON: // request the power on option
		begin
			uart_tx_byte <= 8'h60;
			uart_tx_dv <= 1'b1;
			send_waiting <= 1'b1;
			if (first_start)
				state_tx <= STATE_END_FIRST_START;
			else
				state_tx <= STATE_SEND_IDLE;
		end
		
		STATE_SEND_POWERON: // send the power on option
		begin
			uart_tx_byte <= { 4'h6, 2'b0, poweron ? 2'b01 : 2'b10 };
			uart_tx_dv <= 1'b1;
			send_waiting <= 1'b1;
			state_tx <= STATE_SEND_IDLE;
		end
		
		STATE_END_FIRST_START:
		begin
			first_start <= 1'b0;
			state_tx <= STATE_SEND_IDLE;
		end
		
		default:
			state_tx <= STATE_SEND_IDLE;
	endcase
	
	// send the next when we have sent the previous one
	else if (send_waiting & uart_tx_done)
	begin
		uart_tx_dv <= 1'b0;
		send_waiting <= 1'b0;
	end
end // always @(posedge clk)



// check if we have received a new message from UART
always @(posedge uart_rx_dv)
begin
	case (uart_rx_byte[7:4])
		// 0: command reserved
		
		// 1: acknoledgement
		
		// 2: stage command is only OUTPUT
		
		// 3: MCU version not implemented
		
		// 4: IP only sent from fpga
				
		5: // status
		begin
			slot_int <= uart_rx_byte[3:2];
			power_amplifier_int <= uart_rx_byte[1];
			audio_amplifier_int <= uart_rx_byte[0];
			status_changed_int <= ~status_changed_int;
			slot_ready <= 1'b1;
		end
		
		6: // power on
		begin
			poweron_int <= uart_rx_byte[1:0] == 2'h1 ? 1'b1 : 1'b0;
			poweron_changed_int <= ~poweron_changed_int;
		end
	endcase
end // always @(posedge clk)


endmodule