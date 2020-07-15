
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
//  copyright 2018 David Fainitski N7DDC
//  copyright 2020 Davide Gerhard IV3CVE


/*

  Commands used by the Bootloader Programmer

MAC address request, to device
"MAC00000000000000000000000000000"
'MAC' + 29 bytes of zeros

Reply, from device:
"MAC 0000000000000000000000000 M1 M2 M3 M4 M5 M6"
'MAC' + 23 bytes of zeros + 6 bytes of MAC address



Write IP command, to device
"WIP000000000000000000000000 I1 I2 I3 I4"
'WIP' + 25 bytes of zeros + 4 bytes of IP address

Reply, from device:
The same



Erase Slot# (0-3)
"ERS000000000000000000000000000N"
'ERS' + 28 bytes of zeros + 1 byte binary Slot #

Reply, from device:
The same, after finishing.



Data 256 bytes for writing
"WPD00000000000000000000000000000 ... 256 data bytes
'WPD' + 29 bytes of zeros + 256 bytes of data

Reply from device, after finishing:
"WPD00000000000000000000000000000 ... 256 data bytes
'WPD' + 29 bytes of zeros + 256 bytes of read data  from Flash after writing.



Status address request
"STS00000000000000000000000000000"
'STS' + 29 bytes of zeros

Reply, from device:
'STS' + 17 bytes of zeros
      + 1 byte = auto power on functionality (0=OFF 1=ON)
      + 1 byte = audio amplifier status (0=OFF 1=ON)
      + 1 byte = power amplifier status (0=OFF 1=ON)
      + 1 byte = slot number to boot
      + 8 bytes of bootloader version (64 bits)
TODO: add slot number, slot name and firmware version



Enable audio amplifier
"EAA0000000000000000000000000000N"
'EAA' + 28 bytes of zeros + 1 byte audio amplifier (0=OFF 1=ON)

Reply, from device:
The same, after finishing.



Enable RF power amplifier (1W)
"EPA0000000000000000000000000000N"
'EPA' + 28 bytes of zeros + 1 byte power amplifier (0=OFF 1=ON)

Reply, from device:
The same, after finishing.



Enable auto power on
"PWN0000000000000000000000000000N"
'PWN' + 28 bytes of zeros + 1 byte auto power on (0=OFF 1=ON)

Reply, from device:
The same, after finishing.



Stop in the bootloader
"STP00000000000000000000000000000"
'STP' + 29 bytes of zeros

Reply, from device:
The same, after finishing.



Start the firmware radio
"BOT00000000000000000000000000000"
'BOT' + 29 bytes of zeros

Reply, from device:
The same, after finishing.



Change the slot to boot
"SLC0000000000000000000000000000N"
'SLC' + 28 bytes of zeros + 1 byte with slot (2 bits format)

Reply, from device:
The same, after finishing.

*/



module Bootloader (
// Clock
input INA_CLK,                         // 122.88MHz from ADC

// Ethernet Interface
output  	wire     [3:0]PHY_TX,
input   	wire     [3:0]PHY_RX,
input		wire     PHY_RX_DV,				// PHY has data flag
output	wire     PHY_TX_CLOCK,			// PHY Tx data clock
output	wire 	 	PHY_TX_EN,				// PHY Tx enable
input		wire	 	PHY_RX_CLOCK,      	// PHY Rx data clock
input		wire     PHY_CLK125,				// 125MHz clock from PHY PLL
inout		wire     PHY_MDIO,				// data line to PHY MDIO
output	wire 	 	PHY_MDC,					// 2.5MHz clock to PHY MDIO
output	wire     PHY_RESET_N,         // PHY reset

// EEPROM
output 	wire		ESCK, 					// clock on MAC EEPROM
output 	wire		ESI,						// serial in on MAC EEPROM
input  	wire 		ESO, 					   // SO on MAC EEPROM
output 	wire 		ECS,			         // CS on MAC EEPROM

// FLASH interface
output DCLK,
output DATAOUT,
input DATAIN,
output FLASH_NCE,

// Reload
output  	wire     NCONFIG,

// morse pad input
input KEY_DOT,
input KEY_DASH,

// MCU connection
input  MCU_UART_RX,
output MCU_UART_TX,

// EXT.IO used to check the port status at boot time
input  PTT_2,
output FPGA_PTT,
output ANT,
output TUNE,
output VNA,
output UO0,
output UO1,
output UO2,
output UO3,
output UO4,
output UO5,
output UO6,

/*
 Ethernet status LEDs

LED 1 flashes with a period of 1 second, which means the arrival of
      the 125 MHz clock signal from the KSZ9031 chip.

LED 2 shows the status of the network connection. A quick flashing means
      there is no connection. Slow blinking means the connection is set to 100Mbps.
	 	Constant light means that a connection is established at a speed of 1 Gigabit.

LED 3 flashes when the transceiver successfully receives the network packet from
      the computer. With enough incoming packets the LED lights continuously.

LED 4 flashes when the transceiver sends a network packet to the computer.
      When the packets are sent often enough, the LED lights up continuously.
*/
output led1,
output led2,
output led3,
output led4
);

// Bootloader version
localparam [63:0] fw_version = "3.0";
// this is the bootloader version
localparam [7:0] fw_type = 8'h02;

// reset the device when high
assign NCONFIG = dev_reset;

// stop loading at bootloader when KEY_DOT and KEY_DASH
// are both connected to ground or if we received a STP command
reg bl_stop = 1'b0;
wire bl_mode;
assign bl_mode = (~KEY_DOT & ~KEY_DASH) | bl_stop;


//--------------------------------------------------------
// 					EXT.IO checks
//--------------------------------------------------------

// continuos assignment of EXT.IO
assign FPGA_PTT = PTT_2 ? 1'b0 : extio_blink_cnt == 0;
assign ANT      = PTT_2 ? 1'b0 : extio_blink_cnt == 1;
assign TUNE     = PTT_2 ? 1'b0 : extio_blink_cnt == 2;
assign VNA      = PTT_2 ? 1'b0 : extio_blink_cnt == 3;
assign UO0      = PTT_2 ? 1'b0 : extio_blink_cnt == 4;
assign UO1      = PTT_2 ? 1'b0 : extio_blink_cnt == 5;
assign UO2      = PTT_2 ? 1'b0 : extio_blink_cnt == 6;
assign UO3      = PTT_2 ? 1'b0 : extio_blink_cnt == 7;
assign UO4      = PTT_2 ? 1'b0 : extio_blink_cnt == 8;
assign UO5      = PTT_2 ? 1'b0 : extio_blink_cnt == 9;
assign UO6      = PTT_2 ? 1'b0 : extio_blink_cnt == 10;

// check every 0.2 seconds (80KHz / 16000)
reg [23:0] extio_check_cnt = 24'd16000;
reg [4:0] extio_blink_cnt = 0;

// move on the counter used for EXT.IO checks
always @(posedge osc_80kHz)
begin
   if(extio_check_cnt != 0)
		extio_check_cnt <= extio_check_cnt - 1'd1;
	else
	begin
	   extio_check_cnt <= 24'd16000;
		extio_blink_cnt <= (extio_blink_cnt + 1'd1) % 5'd11;
	end
end


//--------------------------------------------------------
// 					Clocks
//--------------------------------------------------------

// Ethernet 125MHz reference clock output
wire C125_0_deg, C125_90_deg;
wire C12_5MHz, C2_5MHz;

// generate the 5MHz clock from 125MHz
C125_PLL PLL_125(.inclk0(PHY_RX_CLOCK), .c0(C125_0_deg), .c1(C125_90_deg), .c2(C12_5MHz), .c3(C2_5MHz));

wire phy_tx_clock = C125_0_deg;
wire phy_rx_clock = C125_90_deg;
assign PHY_TX_CLOCK = C125_90_deg;

// generate the 80KHz clock from 122.800 ADC clock
wire osc_80kHz;
C122_PLL PLL_122 (.inclk0(INA_CLK), .c0(osc_80kHz));

// add 1 second delay before resetting the ethernet PHY
reg [23:0] res_cnt = 24'd80000;

always @(posedge osc_80kHz)
	if (res_cnt != 0)
		res_cnt <= res_cnt - 1'd1;

// reset the ethernet chip after 1 second
assign PHY_RESET_N = (res_cnt == 0);


//------------------------------------------------------------
//  Network reset and values initialization
//------------------------------------------------------------

reg [4:0] net_start_up = 0;
// default MAC address
reg [47:0] local_MAC = 48'h11_22_33_44_55_66;
// default IP address
reg [31:0] local_IP  = {8'd192, 8'd168, 8'd2, 8'd160};
// UDP listening port
reg [15:0] local_Port = 16'd50000;
reg write_ip = 0, write_ip_old = 0;
reg [31:0] ip_to_write;
reg ip_ready = 0;

// finite state machine that read/write eeprom values
// and initialize the local values
always @ (posedge C2_5MHz)
begin
	case (net_start_up)

   0: // the ethernet chip is ready to be programmed
		if(PHY_RESET_N)
			net_start_up <= net_start_up + 1'd1;

   1: // read the ethernet parameters from eeprom
		if(ee_ready)
	   begin
		   ee_read_req <= 1;
			net_start_up <= net_start_up + 1'd1;
		end

	2: // if the eeprom values was read then configure it
		begin
	      ee_read_req <= 0;
			if(ee_ready)
			begin
			   if(EEPROM_MAC != 48'hff_ff_ff_ff_ff_ff & EEPROM_MAC != 48'h00_00_00_00_00_00)
					local_MAC <= EEPROM_MAC;
				if(EEPROM_IP != 32'hff_ff_ff_ff & EEPROM_IP != 32'h00_00_00)
					local_IP <= EEPROM_IP;
				net_start_up <= net_start_up + 1'd1;
				ip_ready = 1;
				//phy_init_req <= 1;
			end
      end

	3: // if the IP is changed, write it to the eeprom
		begin
	      //phy_init_req <= 0;
			if(write_ip != write_ip_old)
			begin
			   write_ip_old <= write_ip;
				if(ip_to_write != 32'hff_ff_ff_ff & ip_to_write != 32'h00_00_00_00)
				begin
				   local_IP <= ip_to_write;
				   ee_write_req <= 1;
				   net_start_up <= net_start_up + 1'd1;
				end
			end
      end

	4: // after the write complete, return to state 3
		begin
         ee_write_req <= 0;
			if(ee_ready)
				net_start_up <= 2'd3;
      end

	default:
		net_start_up <= 0;
   endcase
end

wire eth_reset = ~(net_start_up == 3 & phy_speed & phy_duplex);


//----------------------------------------------------------------------------------
// Read/Write the Ethernet PHY MDIO registers (NOTE: Max clock frequency is 2.5MHz)
//----------------------------------------------------------------------------------
reg phy_init_req = 0;
wire phy_speed, phy_duplex;

phy_cfg phy_config(.clock(C2_5MHz), .init_request(phy_init_req), .speed(phy_speed), .duplex(phy_duplex), .mdio_pin(PHY_MDIO), .mdc_pin(PHY_MDC));


//------------------------------------------------------------------
// 			EEPROM read/write contol
//------------------------------------------------------------------
wire [47:0]EEPROM_MAC;
wire [31:0]EEPROM_IP;
reg ee_read_req = 0, ee_write_req = 0;
wire ee_ready;

eeprom eeprom_inst(.clock(C2_5MHz), .rd_request(ee_read_req), .wr_request(ee_write_req), .ready(ee_ready), .mac(EEPROM_MAC), .ip(EEPROM_IP),
                   .ip_to_write(ip_to_write), .SCK(ESCK), .SI(ESI), .SO(ESO), .CS(ECS));


//--------------------------------------------------------------------------------
// FLASH memory operation
//--------------------------------------------------------------------------------
reg erase_req = 0, write_req = 0;
wire erase_done, wr_done;
reg erase_done_old = 0, wr_done_old = 0;
reg [(256*8)-1:0] wr_data;  // 256 bytes for writing a page
wire [(256*8)-1:0] rd_data; // 256 bytes for return data

flash flash_inst(.clock(C12_5MHz), .erase_req(erase_req), .write_req(write_req), .wr_data(wr_data), .slot_num(slot_num), .erase_done(erase_done),
                   .wr_done(wr_done), .rd_data(rd_data), .DCLK(DCLK), .DATAOUT(DATAOUT), .DATAIN(DATAIN), .FLASH_NCE(FLASH_NCE));


//------------------------------------------------------------------------------
//  Reconfigure the boot address and reboot - Remote Update
//------------------------------------------------------------------------------
Reconfigure Recon_inst(.reset(1'b0), .clock(C12_5MHz), .BootAddress(start_addr),
	.control(boot_radio), .CRC_error(fw_crc_error), .done(), .addr_ready(start_addr_ready));


//---------------------------------------------------------------------------------
// Connection to MCU
//---------------------------------------------------------------------------------
// address to boot based on slot
wire [23:0] start_addr;
reg start_addr_ready = 1'b0;
// slot value
wire [1:0] slot_num;
reg [1:0] slot_num_ext = 2'd1;
// high when we receive a valid slot from MCU
wire slot_ready;
// high if we have changed slot, power amplifier or audio amplifier
reg status_changed = 1'b0;
// status of the power amplifier
wire pa_enabled;
reg pa_enabled_ext = 1'b0;
// status of the audio amplifier
wire aa_enabled;
reg aa_enabled_ext = 1'b0;
// crc error during radio firmware loading
wire fw_crc_error;
// option that manage the auto power on functionality
reg auto_poweron_ext = 1'b0;
reg auto_poweron_changed_ext = 1'b0;
wire auto_poweron;

// generate the address from the slot number
assign start_addr = { slot_num[1] * 8'd64 + slot_num[0] * 8'd32, 16'b0 };

// in which stage we are; at the start at booting
reg [3:0] stage = 4'h01;
reg stage_changed = 1'b0;

mcu #(.fw_version(fw_version), .fw_type(fw_type)) mcu_uart (
 .clk(INA_CLK), .mcu_uart_rx(MCU_UART_RX), .mcu_uart_tx(MCU_UART_TX), .ip(local_IP), .eeprom_read_ready(ip_ready),
 .stage(stage), .stage_changed(stage_changed), .slot_ext(slot_num_ext), .slot(slot_num), .slot_ready(slot_ready),
 .power_amplifier(pa_enabled), .power_amplifier_ext(pa_enabled_ext), .audio_amplifier(aa_enabled), .audio_amplifier_ext(aa_enabled_ext),
 .poweron_ext(auto_poweron_ext), .poweron_changed_ext(auto_poweron_changed_ext), .poweron(auto_poweron),
 .status_changed_ext(status_changed), .ip_changed(write_ip)
 );

// add 10 seconds delay before deciding if boot radio or stay in the bootloader
// this it is needed to stop in bootloader mode from remote (network activation)
reg [23:0] boot_cnt = 24'd800000;

// when low reload the radio with the firmware at start_addr
reg boot_radio = 1'b1;

// used from remote to start immediately the radio firmware
reg bl_start_now = 1'b0;

// delay at boot before print bootloader or start the radio firmware
// to permit remote bootloader mode
always @(posedge osc_80kHz)
begin
	// move to bootloader if we have a bootloader mode request
	if (bl_mode)
	begin
		if (stage != 4'h02)
		begin
			stage <= 4'h02;
			stage_changed <= ~stage_changed;
		end
	end
	else
	begin
	// delay a bit
	if ((boot_cnt != 0) & ~bl_start_now)
	begin
		boot_cnt <= boot_cnt - 24'd1;
	end
	// at the end boot the radio firmware
	// if we have received the slot
	else
	begin
		if (slot_ready)
		begin
			if (fw_crc_error)
			begin
				if (stage != 4'h05)
				begin
					stage <= 4'h05;
					stage_changed <= ~stage_changed;
				end
			end
			else
			begin
				start_addr_ready <= 1'b1;
				boot_radio <= 1'b0;
			end
		end
		else
		begin
			stage <= 4'h00;
			stage_changed <= ~stage_changed;
		end
	end
	end
end

//---------------------------------------------------------------------------------
// Read packets from PHY
//---------------------------------------------------------------------------------
reg [7:0] phy_rx_data;
reg phy_rx_en;

// on positive edge receive the first four bit
always @(posedge phy_rx_clock)
begin
	phy_rx_data[3:0] <= PHY_RX;
end

// on the negative edge receive the second four bit
always @(negedge phy_rx_clock)
begin
	phy_rx_data[7:4] <= PHY_RX;
	phy_rx_en <= PHY_RX_DV;
end

// which stage we are analyzing
reg [4:0] eth_rx_state = 0;
// the buffer for Ethernet header, 42 bytes
reg [(42*8)-1 : 0] eth_rx_buffer;
// the buffer for UDP or ICMP data, 32 bytes
reg [(32*8)-1 : 0] ip_data_buffer;
reg [10:0] eth_rx_byte_cnt = 0;
// used during packet processing
reg udp_data = 0, udp_data_old = 0;
reg arp_data = 0, arp_data_old = 0;
reg icmp_data = 0, icmp_data_old = 0;
reg [31:0] icmp_checksum, header_checksum, ip_checksum;
reg [15:0] udp_length, ip_length;
reg network_rx_active = 0;

`define      eth_dest        eth_rx_buffer[(42-0)*8-1  -: 48]    // Eternet destination
`define      eth_source      eth_rx_buffer[(42-6)*8-1  -: 48]    // Eternet source
`define      eth_type        eth_rx_buffer[(42-12)*8-1 -: 16]    // Eternet type

`define      arp_h_addr      eth_rx_buffer[(42-14)*8-1 -: 16]    // ARP hardware address
`define      arp_p_addr      eth_rx_buffer[(42-16)*8-1 -: 16]    // ARP protocol address
`define      arp_h_size      eth_rx_buffer[(42-18)*8-1 -:  8]    // ARP hardware size
`define      arp_p_size      eth_rx_buffer[(42-19)*8-1 -:  8]    // ARP protocol size
`define      arp_oper        eth_rx_buffer[(42-20)*8-1 -: 16]    // ARP operation
`define      arp_src_mac     eth_rx_buffer[(42-22)*8-1 -: 48]    // ARP source MAC address
`define      arp_src_ip      eth_rx_buffer[(42-28)*8-1 -: 32]    // ARP source IP address
`define      arp_dest_mac    eth_rx_buffer[(42-32)*8-1 -: 48]    // ARP destination MAC address
`define      arp_dest_ip     eth_rx_buffer[(42-38)*8-1 -: 32]    // ARP destination IP address

`define      ip_version      eth_rx_buffer[(42-14)*8-1 -:  8]    // IP version
`define      ip_type         eth_rx_buffer[(42-15)*8-1 -:  8]    // IP type
`define      ip_size         eth_rx_buffer[(42-16)*8-1 -: 16]    // IP header and data length
`define      ip_ident        eth_rx_buffer[(42-18)*8-1 -: 16]    // IP identification
`define      ip_flags        eth_rx_buffer[(42-20)*8-1 -: 16]    // IP flags
`define      ip_time         eth_rx_buffer[(42-22)*8-1 -:  8]    // IP time to live
`define      ip_protocol     eth_rx_buffer[(42-23)*8-1 -:  8]    // IP protocol
`define      ip_h_crc        eth_rx_buffer[(42-24)*8-1 -: 16]    // IP header checksum
`define      ip_src          eth_rx_buffer[(42-26)*8-1 -: 32]    // IP source address
`define      ip_dest         eth_rx_buffer[(42-30)*8-1 -: 32]    // IP destination address

`define      udp_src         eth_rx_buffer[(42-34)*8-1 -: 16]    // UDP source port
`define      udp_dest        eth_rx_buffer[(42-36)*8-1 -: 16]    // UDP destination port
`define      udp_size        eth_rx_buffer[(42-38)*8-1 -: 16]    // UDP data length
`define      udp_crc         eth_rx_buffer[(42-40)*8-1 -: 16]    // UDP data checksum

`define      icmp_type       eth_rx_buffer[(42-34)*8-1 -:  8]    // ICMP type
`define      icmp_code       eth_rx_buffer[(42-35)*8-1 -:  8]    // ICMP code
`define      icmp_crc        eth_rx_buffer[(42-36)*8-1 -: 16]    // ICMP checksum
`define      icmp_ident      eth_rx_buffer[(42-38)*8-1 -: 16]    // ICMP identifier
`define      icmp_snum       eth_rx_buffer[(42-40)*8-1 -: 16]    // ICMP sequence number

// finite state machine to parse the received data from the network chip
// sincronized with phy_rx_data receiver cycle
always @(posedge phy_rx_clock)
begin
   case (eth_rx_state)

	0: // detect if the preamble is h55 and if it is 7 bytes long
		if(!eth_reset & phy_rx_data == 8'h55 & eth_rx_byte_cnt <= 6)
			eth_rx_byte_cnt <= eth_rx_byte_cnt + 1'd1;
		// detection of frame delimiter, 8th byte
	   else if(!eth_reset & phy_rx_data == 8'hd5 & eth_rx_byte_cnt == 7)
		begin
		   eth_rx_byte_cnt <= 0;
			eth_rx_state <= eth_rx_state + 1'd1;
		end
		// otherwise reset the counter if preamble is wrong
		else eth_rx_byte_cnt <= 0;

	1:	// receive the 42 bytes of Ethernet header
		if(eth_rx_byte_cnt <= 41)
	   begin
		   network_rx_active <= 1;
		   eth_rx_buffer[(42-eth_rx_byte_cnt)*8-1 -: 8] <= phy_rx_data;
		   eth_rx_byte_cnt <= eth_rx_byte_cnt + 1'd1;
		end
		// otherwise check if it is an ARP packet
		else if((`eth_dest == 48'hff_ff_ff_ff_ff_ff | `eth_dest == local_MAC) & `eth_type == 16'h0806 & `arp_oper == 16'h0001)
		begin
		   if(!eth_tx_buffer_use)
			begin
			   arp_data <= ~arp_data;
			   eth_rx_state <= eth_rx_state + 1'd1;
			end
		end
		// otherwise check if it is an IP packet and it is destined to this device
		else if(`eth_dest == local_MAC & `ip_dest == local_IP & `eth_type == 16'h0800 & `ip_version == 8'h45)
		begin
			// detect if it is an ICMP packet
			if(`ip_protocol == 8'h01 & `icmp_type == 8'h08)
			begin
				// receive the ICMP data
				if(eth_rx_byte_cnt <= 73)
				begin
					ip_data_buffer[(32-(eth_rx_byte_cnt-42))*8-1 -: 8] <= phy_rx_data;
					eth_rx_byte_cnt <= eth_rx_byte_cnt + 1'd1;
				end
				else
				begin
					icmp_data <= ~icmp_data;
					eth_rx_state <= eth_rx_state + 1'd1;
				end
		   end
			// detect if it is an UDP packet
			else if(`ip_protocol == 8'h11 & `udp_dest == local_Port)
			begin
				// check that the size has a correct size
				// 32 bytes  = command packet
				// 256 bytes = firmware data (the firmware data has 32 command bytes prepended)
			   if((`udp_size == 8+32) | (`udp_size == 8+32+256))
				begin
					// it is a short or a command packet
				   if(eth_rx_byte_cnt <= 73)
				   begin
					   ip_data_buffer[(32-(eth_rx_byte_cnt-42))*8-1 -: 8] <= phy_rx_data;
					   eth_rx_byte_cnt <= eth_rx_byte_cnt + 1'd1;
				   end
					// if it a long UDP packet
				   else if(`udp_size == 8+32+256)
					begin
						// if it is a firmware update write it to the flash
					   if(eth_rx_byte_cnt <= 329)
						begin
						   wr_data[(256-(eth_rx_byte_cnt-74))*8-1] <= phy_rx_data[0]; // LSB is first here */
							wr_data[(256-(eth_rx_byte_cnt-74))*8-2] <= phy_rx_data[1];
							wr_data[(256-(eth_rx_byte_cnt-74))*8-3] <= phy_rx_data[2];
							wr_data[(256-(eth_rx_byte_cnt-74))*8-4] <= phy_rx_data[3];
							wr_data[(256-(eth_rx_byte_cnt-74))*8-5] <= phy_rx_data[4];
							wr_data[(256-(eth_rx_byte_cnt-74))*8-6] <= phy_rx_data[5];
							wr_data[(256-(eth_rx_byte_cnt-74))*8-7] <= phy_rx_data[6];
							wr_data[(256-(eth_rx_byte_cnt-74))*8-8] <= phy_rx_data[7];
					      eth_rx_byte_cnt <= eth_rx_byte_cnt + 1'd1;
						end
						// otherwise start to process the UDP packet
						else
						begin
						   udp_data <= ~udp_data;
					      eth_rx_state <= eth_rx_state + 1'd1;
						end
					end
					// otherwise start to process the short UDP packet
					else
				   begin
					   udp_data <= ~udp_data;
					   eth_rx_state <= eth_rx_state + 1'd1;
					end
				end
			end
			else
		      eth_rx_state <= eth_rx_state + 1'd1;
		end
		else
		   eth_rx_state <= eth_rx_state + 1'd1;


	2: // wait the end of the frame and then restart the process
	   if(!phy_rx_en)
	   begin
		   network_rx_active <= 0;
	      eth_rx_byte_cnt <= 0;
			eth_rx_state <= 1'd0;
      end

	default:
		eth_rx_state <= 0;
	endcase
end


//--------------------------------------------------------------------------------------
//	Ethernet/IP packet processing
//--------------------------------------------------------------------------------------
reg [47:0] dest_MAC;
reg [31:0] dest_IP;
reg [15:0] dest_Port;
// reset the FPGA when high
reg dev_reset = 0;

// bootloader commands from the bootloader commander
// defined as the first 3 bytes
// for more information see the HEADER in this file
`define      CMD             ip_data_buffer[(32-0)*8-1 -: 24]

// buffer for UDP data of the command (32 bytes)
reg [32*8-1 : 0] udp_buffer;

// finite state machine state variable
reg [7:0] pkt_rx_state = 0;

// finite state machine to parse the packet received from the network
// sincronized with phy_rx_data receiver cycle
always @(posedge phy_rx_clock)
begin
   case (pkt_rx_state)

	0: // check if there is a new packet to process and of which type
		if(udp_data != udp_data_old)
			pkt_rx_state <= 1;
	   else if(arp_data != arp_data_old)
			pkt_rx_state <= 80;
		else if(icmp_data != icmp_data_old)
			pkt_rx_state <= 90;
		else if(erase_done != erase_done_old)
			pkt_rx_state <= 2;
		else if(wr_done != wr_done_old)
			pkt_rx_state <= 3;

	1: // process the UDP packet
		begin
	      udp_data_old <= udp_data;

			// the programmer requests the device MAC address
	      if(`CMD == "MAC")
		   begin
				// the endpoint is only configured if the first packet is MAC
		      dest_MAC <= `eth_source;
		      dest_IP <= `ip_src;
		      dest_Port <= `udp_src;
				// generate the answer with the local MAC address with 23*8 zero bits
			   udp_buffer[(32-0)*8-1 : 0] <= {"MAC", 184'b0, local_MAC};
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				// generate the UDP packet and send it at the next cycle
				pkt_rx_state <= 70;
		   end

			// the programmer requests to change the IP address
		   else if(`CMD == "WIP")
		   begin
				// get the new IP from the packet
		      ip_to_write <= ip_data_buffer[(32-28)*8-1 -: 32];
			   write_ip <= ~write_ip;
				// reply with the same packet received
			   udp_buffer <= ip_data_buffer;
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				pkt_rx_state <= 70;
		   end

			// the programmer requests to erase the slot N
			else if(`CMD == "ERS")
		   begin
				// get the slot from the packet
				// this change require another cycle at 122.88MHz before used
				// by flash module. Since the latter works at 12.5MHz should
				// be enought
		      slot_num_ext <= ip_data_buffer[1:0];
				status_changed <= ~status_changed;
			   erase_req <= ~erase_req;
				pkt_rx_state <= 1'd0;
		   end

			// the programmer requests to write the new firmware
			// the slot used to write the data is configured with the ERS command
			else if(`CMD == "WPD")
		   begin
			   write_req <= ~write_req;
				pkt_rx_state <= 1'd0;
		   end

			// the programmer requests to reset the FPGA
			else if(`CMD == "RES")
			begin
			   dev_reset <= 1;
				pkt_rx_state <= 1'd0;
			end

			// if not valid matching is found return to the start
			else
				pkt_rx_state <= 1'd0;

			// the programmer requests the status
	      if(`CMD == "STS")
		   begin
				// generate the answer with the audio amplifier status, power amplifier status, slot number and firmware version
			   udp_buffer[(32-0)*8-1 : 0] <= {"STS", 136'b0, 7'b0, auto_poweron, 7'b0, aa_enabled, 7'b0, pa_enabled, 6'b0, slot_num, fw_version};
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				// generate the UDP packet and send it at the next cycle
				pkt_rx_state <= 70;
		   end

			// the programmer requests to change the audio amplifier status
			else if(`CMD == "EAA")
		   begin
				// get the new status of the audio amplifier
		      aa_enabled_ext <= ip_data_buffer[0:0];
				// notify that the status is changed
				status_changed <= ~status_changed;
				// reply with the same package
				udp_buffer[(32-0)*8-1 : 0] <= {"EAA", 224'b0, 7'b0, ip_data_buffer[0:0] };
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				// generate the UDP packet and send it at the next cycle
				pkt_rx_state <= 70;
		   end

			// the programmer requests to change the RF power amplifier (1W)
			else if(`CMD == "EPA")
		   begin
				// get the new status of the audio amplifier
		      pa_enabled_ext <= ip_data_buffer[0:0];
				// notify that the status is changed
				status_changed <= ~status_changed;
				// reply with the same package
				udp_buffer[(32-0)*8-1 : 0] <= {"EPA", 224'b0, 7'b0, ip_data_buffer[0:0] };
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				// generate the UDP packet and send it at the next cycle
				pkt_rx_state <= 70;
		   end

			// the programmer requests to change the auto power on functionality
			else if(`CMD == "PWN")
		   begin
				// get the new status of the audio amplifier
		      auto_poweron_ext <= ip_data_buffer[0:0];
				// notify that the status is changed
				auto_poweron_changed_ext <= ~auto_poweron_changed_ext;
				// reply with the same package
				udp_buffer[(32-0)*8-1 : 0] <= {"PWN", 224'b0, 7'b0, ip_data_buffer[0:0] };
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				// generate the UDP packet and send it at the next cycle
				pkt_rx_state <= 70;
		   end

			// stop the loading
			else if(`CMD == "STP")
		   begin
				// define the destination endpoint
				dest_MAC <= `eth_source;
		      dest_IP <= `ip_src;
		      dest_Port <= `udp_src;
				bl_stop <= 1'b1;
				// reply with the same package
				udp_buffer[(32-0)*8-1 : 0] <= {"STP", 232'b0 };
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				// generate the UDP packet and send it at the next cycle
				pkt_rx_state <= 70;
		   end

			// boot the radio firmware
			else if(`CMD == "BOT")
		   begin
				bl_stop <= 1'b0;
				bl_start_now <= 1'b1;
				// reply with the same package
				udp_buffer[(32-0)*8-1 : 0] <= {"BOT", 232'b0 };
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				// generate the UDP packet and send it at the next cycle
				pkt_rx_state <= 70;
		   end

			// change the slot number to boot
			else if(`CMD == "SLC")
		   begin
				slot_num_ext <= ip_data_buffer[1:0];
				// notify that the status is changed
				status_changed <= ~status_changed;
				// reply with the same package
				udp_buffer[(32-0)*8-1 : 0] <= {"SLC", 224'b0, 6'b0, ip_data_buffer[1:0] };
				udp_length <= 8'd8 + 8'd32;
				ip_length <= 8'd28 + 8'd32;
				// generate the UDP packet and send it at the next cycle
				pkt_rx_state <= 70;
		   end
		end

	2: // create the answer after the slot erasing is completed
		begin
         erase_done_old <= erase_done;
			udp_buffer[(32-0)*8-1 : 0] <= {"ERS", 232'b0};
         udp_length <= 8'd8 + 8'd32;
			ip_length <= 8'd28 + 8'd32;
			pkt_rx_state <= 70;
      end

   3: // create the answer after the data was written to the slot
		begin
	      wr_done_old <= wr_done;
			erase_done_old <= erase_done;
			udp_buffer[(32-0)*8-1 : 0] <= {"WPD", 232'b0};
         udp_length <= 8'd8 + 8'd32 + 9'd256;
			ip_length <= 8'd28 + 8'd32 + 9'd256;
			pkt_rx_state <= 70;
      end

	70: // tx header buffer forming for UDP answer
		if(!eth_tx_buffer_use)
			begin
			   eth_tx_buffer <= {dest_MAC, local_MAC, 16'h0800/*`eth_type*/, 8'h45/*`ip_version*/, 8'h45/*`ip_type*/, ip_length, 16'h0807/*`ip_ident*/,
			           16'h0000/*`ip_flags*/, 8'd128/*`ip_time*/, 8'h11/*`ip_protocol*/,
		              /*`ip_h_crc*/ 16'h0000, local_IP, dest_IP, local_Port, dest_Port, udp_length, 16'h0000 /*`udp_crc*/};
            pkt_rx_state <= pkt_rx_state + 1'd1;
			end

	71: // IP header checksum calculating
		begin
	      ip_checksum <= eth_tx_buffer[(42-14)*8-1 -: 16] + eth_tx_buffer[(42-16)*8-1 -: 16]	+ eth_tx_buffer[(42-18)*8-1 -: 16] + eth_tx_buffer[(42-20)*8-1 -: 16] +
				            eth_tx_buffer[(42-22)*8-1 -: 16] + eth_tx_buffer[(42-26)*8-1 -: 16] + eth_tx_buffer[(42-28)*8-1 -: 16] + eth_tx_buffer[(42-30)*8-1 -: 16] +
								eth_tx_buffer[(42-32)*8-1 -: 16];
	      pkt_rx_state <= pkt_rx_state + 1'd1;
	   end

	72: // writing IP header checksum and start the answer
		begin
         eth_tx_buffer[(42-24)*8-1 -: 16] <= ~(ip_checksum[15:0] + ip_checksum[31:16]);
			send_is_udp <= ~send_is_udp;

			pkt_rx_state <= 0;
      end

	80: // ARP answer forming
		if(!eth_tx_buffer_use)
		begin
			eth_tx_buffer <= {`arp_src_mac, local_MAC, `eth_type, `arp_h_addr, `arp_p_addr, `arp_h_size, `arp_p_size, /*`arp_oper*/ 16'h0002,
			              local_MAC, local_IP, `eth_source,`arp_src_ip};
		   send_is_arp <= ~send_is_arp;
		   arp_data_old <= arp_data;
			pkt_rx_state <= 0;
		end

	90: // ICMP answer forming
		if(!eth_tx_buffer_use)
		begin
		   eth_tx_buffer <= {`eth_source, local_MAC, `eth_type, `ip_version, `ip_type, `ip_size, `ip_ident, `ip_flags, `ip_time, `ip_protocol,
		     	/*`ip_h_crc*/ 16'h0000, local_IP, `ip_src, /*`icmp_type*/ 8'h00, /*`icmp_code*/ 8'h00, /*`icmp_crc*/ 16'h0000, `icmp_ident, `icmp_snum};
			pkt_rx_state <=  pkt_rx_state + 1'd1;
		end

  91:	// ICMP checksum calculating
		begin
		   icmp_checksum <= eth_tx_buffer[(42-34)*8-1 -: 16] + eth_tx_buffer[(42-38)*8-1 -: 16] + eth_tx_buffer[(42-40)*8-1 -: 16] + ip_data_buffer[(32-0)*8-1 -: 16] +
		                    ip_data_buffer[(32-2)*8-1 -: 16] + ip_data_buffer[(32-4)*8-1 -: 16] + ip_data_buffer[(32-6)*8-1 -: 16] +
								  ip_data_buffer[(32-8)*8-1 -: 16] + ip_data_buffer[(32-10)*8-1 -: 16] + ip_data_buffer[(32-12)*8-1 -: 16] + ip_data_buffer[(32-14)*8-1 -: 16] +
							 	  ip_data_buffer[(32-16)*8-1 -: 16] + ip_data_buffer[(32-18)*8-1 -: 16] + ip_data_buffer[(32-20)*8-1 -: 16] + ip_data_buffer[(32-22)*8-1 -: 16] +
								  ip_data_buffer[(32-24)*8-1 -: 16] + ip_data_buffer[(32-26)*8-1 -: 16] + ip_data_buffer[(32-28)*8-1 -: 16] + ip_data_buffer[(32-30)*8-1 -: 16];
			ip_checksum <= eth_tx_buffer[(42-14)*8-1 -: 16] + eth_tx_buffer[(42-16)*8-1 -: 16]	+ eth_tx_buffer[(42-18)*8-1 -: 16] + eth_tx_buffer[(42-20)*8-1 -: 16] +
				            eth_tx_buffer[(42-22)*8-1 -: 16] + eth_tx_buffer[(42-26)*8-1 -: 16] + eth_tx_buffer[(42-28)*8-1 -: 16] + eth_tx_buffer[(42-30)*8-1 -: 16] +
							   eth_tx_buffer[(42-32)*8-1 -: 16];
		   pkt_rx_state <= pkt_rx_state + 1'd1;
		end

  92: // generate the frame and send it
		begin
		   eth_tx_buffer[(42-36)*8-1 -: 16] <= ~(icmp_checksum[15:0] + icmp_checksum[31:16]);
			eth_tx_buffer[(42-24)*8-1 -: 16] <= ~(ip_checksum[15:0] + ip_checksum[31:16]);
			send_is_icmp <= ~send_is_icmp;
			icmp_data_old <= icmp_data;
			pkt_rx_state <= 0;
		end

	default:
		pkt_rx_state <= 0;
	endcase

end



//--------------------------------------------------------------------------------------
// Write to PHY
//--------------------------------------------------------------------------------------

// finite state machine state variable
reg [4:0] pkt_tx_state = 0;
// Ethernet header buffer (42 bytes)
reg [42*8-1 : 0] eth_tx_buffer;
reg eth_tx_buffer_use = 0;
reg [7:0] pkt_tx_byte_cnt = 0;
reg send_is_arp = 0, send_is_arp_old = 0;
reg send_is_icmp = 0, send_is_icmp_old = 0;
reg send_is_udp = 0, send_is_udp_old = 0;
reg tx_arp = 0, tx_icmp = 0, tx_udp = 0;
reg network_tx_active = 0;

reg phy_tx_en = 0;
reg [7:0] phy_tx_data;
reg [31:0] CRC32_reg;

// Double Data Rate out
ddio_out	ddio_out_inst (
	.datain_h({phy_tx_en, phy_tx_data[3:0]}),
	.datain_l({phy_tx_en, phy_tx_data[7:4]}),
	.outclock(phy_tx_clock),
	.dataout({PHY_TX_EN, PHY_TX})
	);

// finite state machine to gdnerate the packet for the network
// sincronized with phy_rx_data receiver cycle
always @(posedge phy_tx_clock)
begin
   case (pkt_tx_state)

	0: // check which type of packet we need to generate
		if(send_is_arp != send_is_arp_old)
      begin
		   send_is_arp_old <= send_is_arp;
		   tx_arp = 1;
		   pkt_tx_state <= 1'd1;
		end
	   else if(send_is_icmp != send_is_icmp_old)
	   begin
		   send_is_icmp_old <= send_is_icmp;
			tx_icmp = 1;
	   	pkt_tx_state <= 1'd1;
		end
	   else if(send_is_udp != send_is_udp_old)
	   begin
	      send_is_udp_old <= send_is_udp;
		   tx_udp = 1;
		   pkt_tx_state <= 1'd1;
		end

	1: // generate the ethernet preamble
		if(pkt_tx_byte_cnt <= 6)
		begin
		   network_tx_active <= 1;
			phy_tx_en <= 1;
			phy_tx_data <= 8'h55;
			pkt_tx_byte_cnt <= pkt_tx_byte_cnt + 1'd1;
		end
		else
		begin
			phy_tx_data <= 8'hd5;
			pkt_tx_byte_cnt <= 1'd0;
			eth_tx_buffer_use <= 1;
			pkt_tx_state <= 5'd2;
		end

	2: // if the TX buffer is less than 40 bytes send the packates
		if(pkt_tx_byte_cnt <= 40)
		begin
			reset_CRC <= 0;
		   phy_tx_data <= eth_tx_buffer[(42-pkt_tx_byte_cnt)*8-1 -:8];
			pkt_tx_byte_cnt <= pkt_tx_byte_cnt + 1'd1;
	   end
		// otherwise generate the arp/icmp/udp packet
		else
		begin
		   phy_tx_data <= eth_tx_buffer[7 -:8];
			eth_tx_buffer_use <= 0;
			pkt_tx_byte_cnt <= 1'd0;
		   if(tx_arp)
				pkt_tx_state <= 5'd3;
			else if(tx_icmp | tx_udp)
				pkt_tx_state <= 5'd4;
		end

	3: // ARP 0-16 bytes zero filling sending
		if(pkt_tx_byte_cnt <= 16)
		begin
			phy_tx_data <= 8'h00;
			pkt_tx_byte_cnt <= pkt_tx_byte_cnt + 1'd1;
		end
		// otherwise create the CRC and close the frame
	   else
	   begin
		   phy_tx_data <= 8'h00;
		   pkt_tx_byte_cnt <= 1'd0;
			pkt_tx_state <= 5'd6;
	   end

	4: // ICMP or UDP 0-30 bytes data sending
		if(pkt_tx_byte_cnt <= 30)
		begin
			if(tx_icmp)
				phy_tx_data <= ip_data_buffer[(32-pkt_tx_byte_cnt)*8-1 -: 8];
			else if(tx_udp)
				phy_tx_data <= udp_buffer[(32-pkt_tx_byte_cnt)*8-1 -: 8];
			pkt_tx_byte_cnt <= pkt_tx_byte_cnt + 1'd1;
		end
		else
		begin
		   if(tx_icmp)
				phy_tx_data <= ip_data_buffer[7 -: 8];
			else if(tx_udp)
				phy_tx_data <= udp_buffer[7 -: 8];
			pkt_tx_byte_cnt <= 1'd0;
			// if we are writting the firmware move to the next state
         if(`CMD == "WPD")
				pkt_tx_state <= pkt_tx_state + 1'd1;
			// otherwise create the CRC and close the frame
			else
				pkt_tx_state <= 5'd6;
		end

	5: // when are writting the firmware we need to return the same received packet
		// to the programmer
		if(pkt_tx_byte_cnt <= 254)
		begin
		   phy_tx_data[0] <= rd_data[(256-pkt_tx_byte_cnt)*8-1];
			phy_tx_data[1] <= rd_data[(256-pkt_tx_byte_cnt)*8-2];
			phy_tx_data[2] <= rd_data[(256-pkt_tx_byte_cnt)*8-3];
			phy_tx_data[3] <= rd_data[(256-pkt_tx_byte_cnt)*8-4];
			phy_tx_data[4] <= rd_data[(256-pkt_tx_byte_cnt)*8-5];
			phy_tx_data[5] <= rd_data[(256-pkt_tx_byte_cnt)*8-6];
			phy_tx_data[6] <= rd_data[(256-pkt_tx_byte_cnt)*8-7];
			phy_tx_data[7] <= rd_data[(256-pkt_tx_byte_cnt)*8-8];
			pkt_tx_byte_cnt <= pkt_tx_byte_cnt + 1'd1;
		end
		else
      begin
		   phy_tx_data[0] <= rd_data[7];
			phy_tx_data[1] <= rd_data[6];
			phy_tx_data[2] <= rd_data[5];
			phy_tx_data[3] <= rd_data[4];
			phy_tx_data[4] <= rd_data[3];
			phy_tx_data[5] <= rd_data[2];
			phy_tx_data[6] <= rd_data[1];
			phy_tx_data[7] <= rd_data[0];
			pkt_tx_byte_cnt <= 1'd0;
			pkt_tx_state <= pkt_tx_state + 1'd1;
		end

	6:  // CRC sending first byte
		if(pkt_tx_byte_cnt == 0)
	   begin
         CRC32_reg <= CRC32;
			phy_tx_data <= CRC32[7 -:8];
			pkt_tx_byte_cnt <= pkt_tx_byte_cnt + 1'd1;
      end
		// CRC sending last 3 bytes
		else if(pkt_tx_byte_cnt <= 3)
	   begin
		   phy_tx_data <= CRC32_reg [(pkt_tx_byte_cnt*8)+7 -: 8];
			pkt_tx_byte_cnt <= pkt_tx_byte_cnt + 1'd1;
		end
		// 11 + 1 bytes inter-gap sending
		else if(pkt_tx_byte_cnt <= 14)
		begin
		   phy_tx_data <= 8'h55;
			phy_tx_en <= 0;
			pkt_tx_byte_cnt <= pkt_tx_byte_cnt + 1'd1;
		end
		// end of frame
		else
		begin
			pkt_tx_byte_cnt <= 1'd0;
			tx_udp <= 0;
			tx_icmp <= 0;
			tx_arp <= 0;
			reset_CRC <= 1;
			network_tx_active <= 0;
			pkt_tx_state <= 1'd0;
		end

	default:
		pkt_tx_state <= 1'd0;
	endcase


end


//----------------------------
//   802.3 CRC32 Calculation
//----------------------------
wire [31:0] CRC32;
reg reset_CRC = 1;

crc32 crc32_inst(.clock(phy_tx_clock), .clear(reset_CRC),  .data(phy_tx_data), .result(CRC32));


//-----------------------------------------------------------
//  		Ethernet LED status
//-----------------------------------------------------------
wire STATUS_LED;
wire DEBUG_LED1;
wire DEBUG_LED2;
wire DEBUG_LED3;

// led flash period; half seccond at 12.5MHz clock rate
parameter led_period_0_5s = 2500000;
// LED bright 0 - 100 %
parameter led_dimmer = 3;

// dimmer functionality
reg [7:0] led_dim_cnt = 0;
always @(posedge C12_5MHz)
	led_dim_cnt <= (led_dim_cnt + 1'd1) % 8'd101;

// Heart Beat: flashes when 125MHz clock
// is valid from the ethernet chip
assign led1 = STATUS_LED & (led_dim_cnt <= led_dimmer);

// connection's status:
//   - always on = 1Gbps
//   - slow blink = 100Mbps
//   - off = no connection
assign led2 = DEBUG_LED1 & (led_dim_cnt <= led_dimmer);

// flashes when the FPGA receive a package
assign led3 = DEBUG_LED2 & (led_dim_cnt <= led_dimmer);

// flashes when the FPGA send a package
assign led4 = DEBUG_LED3 & (led_dim_cnt <= led_dimmer);

// flash the heart beat led
reg [26:0] hb_counter;
always @(posedge PHY_CLK125)
	hb_counter <= hb_counter + 1'b1;
assign STATUS_LED = hb_counter[25];

// display state of PHY negotiations:
parameter clock_speed = 12_500_000;
Led_control #(clock_speed) Control_LED0(.clock(C12_5MHz), .on(phy_speed & phy_duplex), .fast_flash(!phy_duplex),
										.slow_flash(!phy_speed & phy_duplex), .LED(DEBUG_LED1));

// flash LED1 for ~ 0.2 second whenever rgmii_rx_active
Led_flash Flash_LED1(.clock(C12_5MHz), .signal(network_rx_active), .LED(DEBUG_LED2), .period(led_period_0_5s));

// flash LED2 for ~ 0.2 second whenever the PHY transmits
Led_flash Flash_LED2(.clock(C12_5MHz), .signal(network_tx_active), .LED(DEBUG_LED3), .period(led_period_0_5s));

endmodule
