//-----------------------------------------------------------------------------
//                          sdr receive
//-----------------------------------------------------------------------------

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


//  Metis code copyright 2010, 2011, 2012, 2013 Phil Harman VK6APH


module sdr_receive(
	// inputs
	input rx_clock,
	input [7:0] udp_rx_data,
	input udp_rx_active,
	input sending_sync,
	input broadcast,
	input erase_ACK,
	input send_more_ACK,					// set when sdr_send has seen send_more request
	input discovery_ACK,					// set when sdr_send has seen discovery_reply request
	input [9:0] EPCS_wrused,
	input [47:0] local_mac,
	input [15:0] to_port,
	input phasedone,
	input [1:0] dashdot,

	// outputs
	output reg [7:0] skew_rxtxc,
	output reg [7:0] skew_rxtxd,
	output reg [10:0] skew_rxtxclk21,
	output reg discovery_reply,
	output reg seq_error,
	output reg erase,					   	// set when we receive an EPCS16 erase command from PC 
	output reg [31:0]num_blocks,			// holds number of blocks of 256 bytes that we will save in the EPCS16
	output EPCS_FIFO_enable,				// set when we write to the EPCS fifo
	output reg set_ip,						// set when new static IP address available 
	output reg [31:0] assign_ip,			// static IP address to save in EEPROM.
	output phaseupdown, // 1-UP 0-DOWN
	output phasestep,
	output phaserst,
	output reg [7:0] phaseval,
	output reg [31:0] sequence_number	// sequence number from PC when programming.
);


reg [11:0] state;
reg [31:0] PC_sequence_number;		// sequence number from PC
reg [31:0] temp_PC_sequence_number;
reg [31:0] prev_seq_number;
reg [8:0]  EPCS_data_count;     		// counts how many bytes we send to the EPCS_Rx_fifo
reg [8:0]  byte_cnt;						// counts bytes sent to EPCS fifo 
reg [7:0]  byte_no;
reg [47:0] mac;
reg [7:0]  phasecmd;
reg [7:0]  phasecnt;
reg [7:0]  tmp_phaseval;
reg phasego, phaseset, phaseonce;
reg [7:0] new_skew_rxtxc;
reg [7:0] new_skew_rxtxd;
reg [9:0] new_skew_rxtxclk;
reg [31:0] skew_count;
reg [1:0] skew_dashdot;
reg skew_count_enable, n_skew_reset, skew_changed;
reg mod_reset;

localparam 
	ST_IDLE		= 12'd0,			// use 'one-hot' for state machine
	ST_COMMAND	= 12'd1,
	ST_DISCOVERY	= 12'd2,
	ST_SETIP	= 12'd4,
	ST_PROGRAM	= 12'd8,
	ST_TX		= 12'd16,
	ST_ERASE	= 12'd32,
	ST_PROGRAM_FIFO = 12'd64,
	ST_WAIT		= 12'd128,
	ST_PLL_PHASE	= 12'd256,
	ST_SKEW		= 12'd512;


always @(posedge rx_clock)
begin

  // A host pgm can send phy skew data which will re-init the phy with the new timings
  // ex: python setskew.py 192.168.1.202 67.46.07.0f.00
  // 
  // 67 is rx-ctl,tx-ctl . 46 is rx-data,tx-data . 07 is rxclk . 0f is txclk . 00 is cmd to set
  //
  // defaults
  if (mod_reset == 1'b0) begin
      skew_dashdot <= ~dashdot;
      mod_reset <= 1'b1;
      skew_count <= 32'h3B9ACA0; // 1/2 second
      skew_count_enable <= 1'b1;
  end
  else if (n_skew_reset == 1'b0) begin
    skew_count_enable <= 1'b0;
    n_skew_reset <= 1'b1;
    case (skew_dashdot)
      0:
        begin
          skew_rxtxc <= 8'h77;
          skew_rxtxd <= 8'h77;
          skew_rxtxclk21 <= {skew_changed, 10'b10000_01111}; //9031 NOTE: RXTX
        end
      1:
        begin
          skew_rxtxc <= 8'h77; // 56
          skew_rxtxd <= 8'h77; // 56
          skew_rxtxclk21 <= {skew_changed, 10'b01111_01111}; //9031 NOTE: RXTX
        end
      2:
        begin
          skew_rxtxc <= 8'h23;
          skew_rxtxd <= 8'h23;
          skew_rxtxclk21 <= {skew_changed, 10'b01000_01011}; //9021 NOTE: RXTX
        end
      3:
        begin
          skew_rxtxc <= 8'h23;
          skew_rxtxd <= 8'h23;
          skew_rxtxclk21 <= {skew_changed, 10'b01010_01110}; //9021 NOTE: RXTX
        end
    endcase
  end

  if (skew_count_enable) begin
    skew_count <= skew_count - 1'b1;
    if (skew_count == 32'd0) begin
      n_skew_reset <= 1'b0;
      skew_changed <= skew_changed ^ 1'b1;
    end
  end

  // 1 step is 4.5 degrees of phase
  if (phasego) begin
    if (phaserst)
      if (phasestep)
        if (phasecnt > 8'd0)
          phasecnt <= phasecnt - 1'b1;
        else begin
          phasestep <= 1'b0;
        end
      else if (phaseval > 0) begin
        if (phasedone) begin
          phaseval <= phaseval - 1'b1;
          phasestep <= 1'b1;
          phasecnt <= 8'd5;
        end
      end
      else begin
        phaserst <= 1'b0;
        if (!phaseset)
          phasego <= 1'b0;
      end
    else if (phaseset) begin
      if (phaseonce) begin
        phaseonce <= 1'b0;
        phaseval <= tmp_phaseval;
        if (tmp_phaseval[7]) begin
          phaseupdown <= 1'b0;
          tmp_phaseval <= -tmp_phaseval;
        end
        else
          phaseupdown <= 1'b1;
      end
      else if (phasestep)
        if (phasecnt > 8'd0)
          phasecnt <= phasecnt - 1'b1;
        else begin
          phasestep <= 1'b0;
        end
      else if (tmp_phaseval > 0) begin
        if (phasedone) begin
          tmp_phaseval <= tmp_phaseval - 1'b1;
          phasestep <= 1'b1;
          phasecnt <= 8'd5;
        end
      end
      else begin
        phaseset <= 1'b0;
        phasego <= 1'b0;
      end
    end
    else if (phasestep)
      if (phasecnt > 8'd0)
        phasecnt <= phasecnt - 1'b1;
      else begin
        phasestep <= 1'b0;
        phasego <= 1'b0;
      end
    else begin
      case (phasecmd)
        0: //step-down
          begin
            phaseupdown <= 1'b0;
            phasestep <= 1'b1;
            phasecnt <= 8'd5;
            phaseval <= phaseval - 1'b1;
          end
        1: //step-up
          begin
            phaseupdown <= 1'b1;
            phasestep <= 1'b1;
            phasecnt <= 8'd5;
            phaseval <= phaseval + 1'b1;
          end
        2: //set
          begin
            phaserst <= 1'b1;
            phasecnt <= 8'd5;
            phaseonce <= 1'b1;
            phaseset <= 1'b1;
            if (phaseval[7]) begin
              phaseval <= -phaseval;
              phaseupdown <= 1'b1;
            end
            else
              phaseupdown <= 1'b0;
          end
        3: //reset
          begin
            phaserst <= 1'b1;
            phasecnt <= 8'd5;
            if (phaseval[7]) begin
              phaseval <= -phaseval;
              phaseupdown <= 1'b1;
            end
            else
              phaseupdown <= 1'b0;
          end
      endcase
    end
  end

// ****** NOTE: This state machine only runs when udp_rx_active ******	
  if (udp_rx_active && to_port == 1024) begin	// look for HPSDR udp packet to port 1024
    case (state)
	 
		ST_IDLE:	
			begin
			byte_no <= 8'd0;
			sequence_number[31:24] <=  udp_rx_data;  //save MSB of sequence number 
			state <= ST_COMMAND;
			end 
			
		ST_COMMAND:
			begin
			byte_cnt <= 9'd5;
				case (byte_no) 	//save balance of sequence number
					0: sequence_number[23:16]  <= udp_rx_data;
					1: sequence_number[15:8]   <= udp_rx_data; 
					2: sequence_number[7:0]    <= udp_rx_data;
					3: begin 
						case (udp_rx_data)				// get command 
							2: state <= ST_DISCOVERY;		// allow Discovery to this address or broadcast 
							3: if (broadcast)  state <= ST_SETIP; 
							4: if (!broadcast) state <= ST_ERASE;
							5: if (!broadcast) state <= ST_PROGRAM_FIFO;
							6: if (!broadcast) state <= ST_PLL_PHASE;
							7: if (!broadcast) state <= ST_SKEW;
							default: state <= ST_WAIT;		// command not for us so wait for this to end
						endcase
					end

					default: state <= ST_WAIT;  // command not for us so wait for this to end
				endcase
				byte_no <= byte_no + 8'd1;  // byte_no will be 4 when we leave this state
			end
				

		ST_DISCOVERY:  state <= ST_TX;   

		ST_SKEW: 
			begin
				case(byte_no)
					 4: new_skew_rxtxc <= udp_rx_data;
					 5: new_skew_rxtxd <= udp_rx_data;
					 6: new_skew_rxtxclk[9:5] <= udp_rx_data[4:0];
					 7: new_skew_rxtxclk[4:0] <= udp_rx_data[4:0];
					 8: begin
						case (udp_rx_data) // cmd byte
					 	0: skew_count_enable <= 1'b0;
					 	default: begin
							skew_count <= (udp_rx_data < 8'd31) ? udp_rx_data * 32'h7735940 : 32'hDF847580; //max 30 secs
							skew_rxtxc <= new_skew_rxtxc;
							skew_rxtxd <= new_skew_rxtxd;
							skew_rxtxclk21[9:0] <= new_skew_rxtxclk;
							skew_rxtxclk21[10] <= skew_changed ^ 1'b1;
							skew_changed <= skew_changed ^ 1'b1;
							skew_count_enable <= 1'b1;
							state <= ST_WAIT;
						end
						endcase
					    end
				endcase
				byte_no <= byte_no + 8'd1;
			end

		ST_PLL_PHASE: 
			begin
				case(byte_no)
					 4: tmp_phaseval <= udp_rx_data;
					 5: begin
						phasecmd <= udp_rx_data;
						phasego <= 1'b1;
						state <= ST_WAIT;
					    end
				endcase
				byte_no <= byte_no + 8'd1;
			end

		ST_SETIP: 
			begin
				case(byte_no)
					 4: mac[47:40] <= udp_rx_data;
					 5: mac[39:32] <= udp_rx_data;							 
					 6: mac[31:24] <= udp_rx_data;
					 7: mac[23:16] <= udp_rx_data;
					 8: mac[15:8]  <= udp_rx_data;
					 9: mac[7:0]   <= udp_rx_data;

					10: begin 
						if (mac != local_mac) state <= ST_IDLE;   // not for this MAC so return
						else assign_ip[31:24] <= udp_rx_data;
					 end
					11: assign_ip[23:16] <= udp_rx_data;
					12: assign_ip[15:8]  <= udp_rx_data; 
					13: assign_ip[7:0]   <= udp_rx_data; 

					14: set_ip <= 1'b1;				// indicate new ip address available
					40: state <= ST_IDLE;				// leave set_ip active since read on very slow clock 
											// and FPGA is reset once new IP address is set
					default: state <= ST_IDLE;
				endcase
				byte_no <= byte_no + 8'd1;
			end 
		
		ST_ERASE: state <= ST_TX; 
			
		ST_PROGRAM_FIFO:
			begin 
				case (byte_cnt)						// can't use byte_no since byte_cnt enables the FIFO
					5: num_blocks[31:24] <= udp_rx_data;
					6: num_blocks[23:16] <= udp_rx_data;
					7: num_blocks[15:8]  <= udp_rx_data;						
					8: num_blocks[7:0]   <= udp_rx_data;	

					default: if(byte_cnt > 264) state <= ST_IDLE;
				endcase
				byte_cnt <= byte_cnt + 9'd1;
			end
	
		// wait for the end of sending
		ST_TX:  if (!sending_sync) state <= ST_IDLE;
		
		ST_WAIT: if (!udp_rx_active) state <= ST_IDLE;				// command not for us so loop until it ends.

		default: if (!udp_rx_active) state <= ST_IDLE;
		
	  endcase	
	end
	  
	else state <= ST_IDLE;  // rx not active
	
end 

//	assign discovery_reply = (state == ST_DISCOVERY);
   assign EPCS_FIFO_enable = (byte_cnt > 8 && byte_cnt < 265);   // enable 256 bytes to EPCS fifo
	

// Code to erase EPCS fifo. Needs separate state machine since above code only runs when udp_rx_active	
reg [2:0] EPCS_state;	
reg [26:0]delay;
always @ (posedge  rx_clock)  
begin
	case (EPCS_state)
	0: begin
		if (state == ST_ERASE) begin
			erase <= 1'b1;
			delay <= 27'd1;
			EPCS_state <= 	1;
		end 
	end 

	1: begin 								
		if (erase_ACK | delay == 27'd0) begin  // time out ACK so we don't get stuck here. 
			erase <= 1'b0;
			EPCS_state <= 0;
		end
		else delay <= delay + 27'd1;
	end 
	endcase
end
	
	
// wait for acknowledgement that sdr_send has seen the discovery reply request. 
// Needs separate state machine since udb Rx code only runs when udp_rx_active			
reg [2:0] DISC_state;	
reg [26:0]delay1;
always @ (posedge rx_clock)  
begin
	case (DISC_state)
	0: begin
		if (state == ST_DISCOVERY) begin
			discovery_reply <= 1'b1;
			delay1 <= 27'd1;
			DISC_state <= 	1;
		end 
	end 

	1: begin 								
		if (discovery_ACK | delay1 == 27'd0) begin  // time out ACK so we don't get stuck here. 
			discovery_reply <= 1'b0;
			DISC_state <= 0;
		end
		else delay1 <= delay1 + 27'd1;
	end 
	endcase
end	

endmodule
