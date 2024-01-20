# Orion.sdc

#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock (base clocks, external to the FPGA)
#**************************************************************

create_clock -name {_122MHz} -period 8.138 -waveform { 0.000 4.069 } [get_ports {_122MHz}]
create_clock -name {LTC2208_122MHz} -period 8.138 -waveform { 0.000 4.069 } [get_ports {LTC2208_122MHz}]
create_clock -name {LTC2208_122MHz_2} -period 8.138 -waveform { 0.000 4.069 } [get_ports {LTC2208_122MHz_2}]
create_clock -name {OSC_10MHZ} -period 100.000 -waveform { 0.000 50.000 } [get_ports {OSC_10MHZ}]
create_clock -name {CLOCK_25MHZ} -period 40.000 -waveform { 0.000 20.000 } [get_ports {CLOCK_25MHZ}]

set_clock_groups -exclusive -group {CLOCK_25MHZ}

#virtual base clocks on required inputs
create_clock -name {virt_122MHz} -period 8.138 -waveform { 0.000 4.069 } 
create_clock -name {virt_CBCLK} -period 325.520 -waveform { 0.000 162.760 } 

#derive_pll_clocks

## Clocks in Eth TX Domain
create_clock -name phy_clk125 -period 125.000MHz	[get_ports PHY_CLK125]

create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -name clock_125MHz {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0]} -add
create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -phase 81.00 -duty_cycle 50.00 -name clock_90_125MHz {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[1]} -add
create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -divide_by 50 -duty_cycle 50.00 -name clock_2_5MHz {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[2]} -add
create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -phase 99.0 -divide_by 5 -duty_cycle 50.00 -name clock_25MHz {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[3]} -add
create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -divide_by 10 -duty_cycle 50.00 -name clock_12p5MHz {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[4]} -add

create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[1]} -name clock_ethtxextfast {network_inst|ethtxext_clkmux_i|auto_generated|clkctrl1|outclk}
create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[3]} -name clock_ethtxextslow {network_inst|ethtxext_clkmux_i|auto_generated|clkctrl1|outclk} -add
set_clock_groups -exclusive -group {clock_ethtxextslow} -group {clock_ethtxextfast}

create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0]} -name clock_ethtxintfast {network_inst|ethtxint_clkmux_i|auto_generated|clkctrl1|outclk}
create_generated_clock -source {network_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[4]} -name clock_ethtxintslow {network_inst|ethtxint_clkmux_i|auto_generated|clkctrl1|outclk} -add
set_clock_groups -exclusive -group {clock_ethtxintslow} -group {clock_ethtxintfast}


create_generated_clock -name clock_txoutputfast -master_clock [get_clocks {clock_ethtxextfast}] -source [get_pins {network_inst|ethtxext_clkmux_i|auto_generated|clkctrl1|outclk}] [get_ports {PHY_TX_CLOCK}]
create_generated_clock -name clock_txoutputslow -master_clock [get_clocks {clock_ethtxextslow}] -source [get_pins {network_inst|ethtxext_clkmux_i|auto_generated|clkctrl1|outclk}] [get_ports {PHY_TX_CLOCK}] -add
set_clock_groups -exclusive -group {clock_txoutputslow} -group {clock_txoutputfast}

## Clocks in Eth RX Domain
create_clock -name virt_phy_rx_clk_fast	-period 8.000
create_clock -name virt_phy_rx_clk_slow	-period 40.000

set_clock_groups -exclusive -group {virt_phy_rx_clk_fast} -group {virt_phy_rx_clk_slow}

create_clock -name phy_rx_clk -period 8.000	-waveform {2.0 6.0} [get_ports {PHY_RX_CLOCK}]

create_generated_clock -name clock_ethrxintfast -source [get_ports {PHY_RX_CLOCK}] {Orion:network_inst|rx_clock}
create_generated_clock -name clock_ethrxintslow -source [get_ports {PHY_RX_CLOCK}] {Orion:network_inst|rx_clock} -divide_by 10 -add
set_clock_groups -exclusive -group {clock_ethrxintslow} -group {clock_ethrxintfast}

## Clocks in DSP C122 Domain
create_generated_clock -source {PLL_IF_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -phase 90.00 -name _122_90 {PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0]}
create_generated_clock -source {PLL_IF_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -divide_by 10 -name CMCLK {PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1]} -add
create_generated_clock -source {PLL_IF_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -phase 180.00 -divide_by 40 -name CBCLK {PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2]} -add
create_generated_clock -source {PLL_IF_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -divide_by 2560 -name CLRCLK {PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3]} -add

create_generated_clock -source {PLL_30MHz_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -divide_by 4 -name userADC_clock {PLL_30MHz_inst|altpll_component|auto_generated|pll1|clk[0]}
create_generated_clock -source {PLL_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -divide_by 1536 -multiply_by 125 -name osc_10MHZ {PLL_inst|altpll_component|auto_generated|pll1|clk[0]}

#**************************************************************
# Create Generated Clock (internal to the FPGA)
#**************************************************************
# NOTE: Whilst derive_pll_clocks constrains PLL clocks if these are connected to an FPGA output pin then a generated
# clock needs to be attached to the pin and a false path set to it

# data_clock = CMCLK/2  used by TLV320 SPI
create_generated_clock -name data_clk -source {PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1]} -divide 2

# data_clk2 = CBCLK/4 used by Attenuator
create_generated_clock -name data_clk2 -source {PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2]} -divide 4

derive_clock_uncertainty

#**************************************************************
# Set Clock Groups
#**************************************************************
set_clock_groups -asynchronous  -group { \
					phy_clk125 \
					clock_ethtxintfast clock_ethtxintslow \
					clock_ethtxextfast clock_ethtxextslow \
					clock_125MHz clock_90_125MHz clock_2_5MHz \
					clock_txoutputslow clock_txoutputfast \
				       } \
				-group { \
					phy_rx_clk \
					clock_ethrxintslow clock_ethrxintfast \
				       } \
				-group {LTC2208_122MHz_2} \
				-group { \
					LTC2208_122MHz \
					_122MHz \
					_122_90 CMCLK CBCLK CLRCLK \
					osc_10MHZ \
					data_clk data_clk2 \
					userADC_clock \
				       } \
				-group {OSC_10MHZ}
		
## Ethernet PHY TX per AN477, with PHY delay for TX disabled

set_output_delay  -max  1.0 -clock clock_txoutputfast [get_ports {PHY_TX[*]}]
set_output_delay  -min -0.8 -clock clock_txoutputfast [get_ports {PHY_TX[*]}]  -add_delay
set_output_delay  -max  1.0 -clock clock_txoutputfast [get_ports {PHY_TX[*]}]  -clock_fall -add_delay
set_output_delay  -min -0.8 -clock clock_txoutputfast [get_ports {PHY_TX[*]}]  -clock_fall -add_delay

set_output_delay  -max  1.0 -clock clock_txoutputfast [get_ports {PHY_TX_EN}]
set_output_delay  -min -0.8 -clock clock_txoutputfast [get_ports {PHY_TX_EN}]  -add_delay
set_output_delay  -max  1.0 -clock clock_txoutputfast [get_ports {PHY_TX_EN}]  -clock_fall -add_delay
set_output_delay  -min -0.8 -clock clock_txoutputfast [get_ports {PHY_TX_EN}]  -clock_fall -add_delay

set_output_delay  -max  1.0 -clock clock_txoutputslow [get_ports {PHY_TX[*]}]  -add_delay
set_output_delay  -min -0.8 -clock clock_txoutputslow [get_ports {PHY_TX[*]}]  -add_delay
set_output_delay  -max  1.0 -clock clock_txoutputslow [get_ports {PHY_TX[*]}]  -clock_fall -add_delay
set_output_delay  -min -0.8 -clock clock_txoutputslow [get_ports {PHY_TX[*]}]  -clock_fall -add_delay

set_output_delay  -max  1.0 -clock clock_txoutputslow [get_ports {PHY_TX_EN}]  -add_delay
set_output_delay  -min -0.8 -clock clock_txoutputslow [get_ports {PHY_TX_EN}]  -add_delay
set_output_delay  -max  1.0 -clock clock_txoutputslow [get_ports {PHY_TX_EN}]  -clock_fall -add_delay
set_output_delay  -min -0.8 -clock clock_txoutputslow [get_ports {PHY_TX_EN}]  -clock_fall -add_delay

set_false_path -fall_from [get_clocks {clock_ethtxintfast}] -rise_to [get_clocks {clock_txoutputfast}] -setup
set_false_path -rise_from [get_clocks {clock_ethtxintfast}] -fall_to [get_clocks {clock_txoutputfast}] -setup
set_false_path -fall_from [get_clocks {clock_ethtxintfast}] -fall_to [get_clocks {clock_txoutputfast}] -hold
set_false_path -rise_from [get_clocks {clock_ethtxintfast}] -rise_to [get_clocks {clock_txoutputfast}] -hold

set_false_path -fall_from [get_clocks {clock_ethtxintslow}] -rise_to [get_clocks {clock_txoutputslow}] -setup
set_false_path -rise_from [get_clocks {clock_ethtxintslow}] -fall_to [get_clocks {clock_txoutputslow}] -setup
set_false_path -fall_from [get_clocks {clock_ethtxintslow}] -fall_to [get_clocks {clock_txoutputslow}] -hold
set_false_path -rise_from [get_clocks {clock_ethtxintslow}] -rise_to [get_clocks {clock_txoutputslow}] -hold

set_false_path -from [get_clocks {clock_ethtxintfast}] -to [get_clocks {clock_txoutputslow}]
set_false_path -from [get_clocks {clock_ethtxintslow}] -to [get_clocks {clock_txoutputfast}]


## Ethernet PHY RX per AN477, with PHY delay for RX enabled
## Clock delay added by KSZ9031 is 1.0 to 2.6 per datasheet table 7-1
## Clock is 90deg shifted, 2ns
## Max delay is 2.6-2.0 = 0.6
## Min delay is 1.0-2.0 = -1.0

set_input_delay  -max  0.6 -clock virt_phy_rx_clk_fast [get_ports {PHY_RX[*]}]
set_input_delay  -min -1.0 -clock virt_phy_rx_clk_fast -add_delay [get_ports {PHY_RX[*]}]
set_input_delay  -max  0.6 -clock virt_phy_rx_clk_fast -clock_fall -add_delay [get_ports {PHY_RX[*]}]
set_input_delay  -min -1.0 -clock virt_phy_rx_clk_fast -clock_fall -add_delay [get_ports {PHY_RX[*]}]

set_input_delay  -max  0.6 -clock virt_phy_rx_clk_fast [get_ports {RX_DV}]
set_input_delay  -min -1.0 -clock virt_phy_rx_clk_fast -add_delay [get_ports {RX_DV}]
set_input_delay  -max  0.6 -clock virt_phy_rx_clk_fast -clock_fall -add_delay [get_ports {RX_DV}]
set_input_delay  -min -1.0 -clock virt_phy_rx_clk_fast -clock_fall -add_delay [get_ports {RX_DV}]

set_false_path -fall_from  virt_phy_rx_clk_fast -rise_to clock_ethrxintfast -setup
set_false_path -rise_from  virt_phy_rx_clk_fast -fall_to clock_ethrxintfast -setup
set_false_path -fall_from  virt_phy_rx_clk_fast -fall_to clock_ethrxintfast -hold
set_false_path -rise_from  virt_phy_rx_clk_fast -rise_to clock_ethrxintfast -hold

set_false_path -from [get_clocks {virt_phy_rx_clk_fast}] -to [get_clocks {clock_ethrxintslow}]

set_input_delay  -max  0.6 -clock virt_phy_rx_clk_slow [get_ports {PHY_RX[*]}] -add_delay
set_input_delay  -min -1.0 -clock virt_phy_rx_clk_slow -add_delay [get_ports {PHY_RX[*]}]
set_input_delay  -max  0.6 -clock virt_phy_rx_clk_slow -clock_fall -add_delay [get_ports {PHY_RX[*]}]
set_input_delay  -min -1.0 -clock virt_phy_rx_clk_slow -clock_fall -add_delay [get_ports {PHY_RX[*]}]

set_input_delay  -max  0.6 -clock virt_phy_rx_clk_slow [get_ports {RX_DV}] -add_delay
set_input_delay  -min -1.0 -clock virt_phy_rx_clk_slow -add_delay [get_ports {RX_DV}]
set_input_delay  -max  0.6 -clock virt_phy_rx_clk_slow -clock_fall -add_delay [get_ports {RX_DV}]
set_input_delay  -min -1.0 -clock virt_phy_rx_clk_slow -clock_fall -add_delay [get_ports {RX_DV}]

set_false_path -fall_from  virt_phy_rx_clk_slow -rise_to clock_ethrxintslow -setup
set_false_path -rise_from  virt_phy_rx_clk_slow -fall_to clock_ethrxintslow -setup
set_false_path -fall_from  virt_phy_rx_clk_slow -fall_to clock_ethrxintslow -hold
set_false_path -rise_from  virt_phy_rx_clk_slow -rise_to clock_ethrxintslow -hold

set_false_path -from [get_clocks {virt_phy_rx_clk_slow}] -to [get_clocks {clock_ethrxintfast}]

## Misc PHY

#PHY PHY_MDIO Data in +/- 10nS setup and hold
set_input_delay  10  -clock clock_2_5MHz -reference_pin [get_ports PHY_MDC] {PHY_MDIO}

#PHY (2.5MHz)
set_output_delay  10 -clock clock_2_5MHz -reference_pin [get_ports PHY_MDC] {PHY_MDIO}

set_max_delay -from clock_2_5MHz -to clock_ethtxintfast 22

set_false_path -from [get_keepers {network:network_inst|phy_cfg:phy_cfg_inst|speed[1]}]

#**************************************************************
# Set Output Delay
#**************************************************************

# If setup and hold delays are equal then only need to specify once without max or min 

#12.5MHz clock for Config EEPROM  +/- 10nS
set_output_delay  10 -clock clock_12p5MHz {ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_smm2:ASMI_altasmi_parallel_smm2_component|sd2~ALTERA_DCLK ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_smm2:ASMI_altasmi_parallel_smm2_component|sd2~ALTERA_SCE ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_smm2:ASMI_altasmi_parallel_smm2_component|sd2~ALTERA_SDO }

#122.88MHz clock for Tx DAC 
set_output_delay 0.8 -clock _122MHz {DACD[*]} -add_delay

# Attenuators - min is referenced to falling edge of clock 
set_output_delay  10  -clock data_clk { ATTN_DATA* ATTN_LE* MICBIAS_ENABLE MICBIAS_SELECT MIC_SIG_SELECT PTT_SELECT } -add_delay
set_output_delay  10  -clock data_clk { ATTN_DATA* ATTN_LE* MICBIAS_ENABLE MICBIAS_SELECT MIC_SIG_SELECT PTT_SELECT } -clock_fall -add_delay

#TLV320 SPI  
set_output_delay  20 -clock data_clk { MOSI nCS} -add_delay

#TLV320 Data out 
set_output_delay  10 -clock CBCLK {CDIN CMODE} -add_delay

#Alex  uses CBCLK/4
set_output_delay  10 -clock data_clk2 { SPI_SDO J15_5 J15_6} -add_delay

#EEPROM (2.5MHz)
set_output_delay  40 -clock clock_2_5MHz {SCK SI CS} -add_delay

#ADC78H90 
set_output_delay  10 -clock data_clk2 {ADCMOSI nADCCS} -add_delay

#************************************************************** 
# Set Input Delay
#**************************************************************

# If setup and hold delays are equal then only need to specify once without max or min 

#12.5MHz clock for Config EEPROM  +/- 10nS setup and hold
set_input_delay 10  -clock  clock_12p5MHz { ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_smm2:ASMI_altasmi_parallel_smm2_component|sd2~ALTERA_DATA0 }

# data from LTC2208 +/- 2nS setup and hold 
set_input_delay -add_delay  -clock [get_clocks {virt_122MHz}]  2.000 [get_ports {INA[*]}]
set_input_delay -add_delay  -clock [get_clocks {virt_122MHz}]  2.000 [get_ports {INA_2[*]}]

#TLV320 Data in +/- 20nS setup and hold
set_input_delay  20  -clock virt_CBCLK  {CDOUT} -add_delay

#EEPROM Data in +/- 40nS setup and hold
set_input_delay  40  -clock clock_2_5MHz {SO} -add_delay 

#PHY PHY_MDIO Data in +/- 10nS setup and hold
set_input_delay  10  -clock clock_2_5MHz -reference_pin [get_ports PHY_MDC] {PHY_MDIO} -add_delay

#ADC78H90 Data in +/- 10nS setup and hold
set_input_delay  10  -clock data_clk2 {ADCMISO} -add_delay


#**************************************************************
# Set Maximum Delay (for setup or recovery; low-level, over-riding timing adjustments)
#************************************************************** 

set_max_delay -from LTC2208_122MHz -to LTC2208_122MHz 18
set_max_delay -from _122_90 -to LTC2208_122MHz 9
set_max_delay -from CLRCLK -to LTC2208_122MHz 9
set_max_delay -from CMCLK -to _122_90 5
set_max_delay -from LTC2208_122MHz -to _122_90 8

#set_max_delay -from clock_12p5MHz -to clock_ethrxintfast 4
#set_max_delay -from clock_12p5MHz -to clock_ethrxintslow 4
set_max_delay -from clock_ethrxintfast -to clock_12p5MHz 15
set_max_delay -from clock_ethtxintfast -to clock_ethtxintfast 24
set_max_delay -from clock_ethrxintfast -to clock_ethrxintfast 10
set_max_delay -from clock_ethtxintfast -to clock_txoutputfast 2

#**************************************************************
# Set Minimum Delay (for hold or removal; low-level, over-riding timing adjustments)
#**************************************************************

#set_min_delay -from LTC2208_122MHz -to LTC2208_122MHz -1
#set_min_delay -from PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3] -to PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] -1
set_min_delay -from virt_phy_rx_clk_fast -to clock_ethrxintfast -8
set_min_delay -from CLRCLK -to CBCLK -1


#**************************************************************
# Set Multicycle Path
#************************************************************** 

set_multicycle_path -from [get_keepers {network:network_inst|dhcp:dhcp_inst|length[*]}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -setup -start 3
set_multicycle_path -from [get_keepers {network:network_inst|dhcp:dhcp_inst|length[*]}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -hold -start 2

set_multicycle_path -from [get_keepers {network:network_inst|tx_protocol*}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -setup -start 3
set_multicycle_path -from [get_keepers {network:network_inst|tx_protocol*}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -hold -start 2

set_multicycle_path -from [get_keepers {network:network_inst|arp:arp_inst|tx_byte_no[*]}] -to [get_keepers {network:network_inst|mac_send:mac_send_inst|shift_reg[*]}] -setup -start 2
set_multicycle_path -from [get_keepers {network:network_inst|arp:arp_inst|tx_byte_no[*]}] -to [get_keepers {network:network_inst|mac_send:mac_send_inst|shift_reg[*]}] -hold -start 1

set_multicycle_path -from [get_keepers {sdr_send:sdr_send_inst|udp_tx_length[*]}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -setup -start 3
set_multicycle_path -from [get_keepers {sdr_send:sdr_send_inst|udp_tx_length[*]}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -hold -start 2

#**************************************************************
# Set False Paths
#**************************************************************
 
set_false_path -from [get_clocks {LTC2208_122MHz}] -to [get_clocks {LTC2208_122MHz_2}]
set_false_path -from [get_ports {PHY_RESET_N}]

# Set false path to generated clocks that feed output pins
set_false_path -to [get_ports {CMCLK CBCLK CLRCIN CLRCOUT ATTN_CLK* SSCK ADCCLK SPI_SCK PHY_MDC PHY_TX_CLOCK CLOCK_25MHZ}]

# 'get_keepers' denotes either ports or registers
# don't need fast paths to the LEDs and adhoc outputs so set false paths so Timing will be ignored
set_false_path -to [get_keepers { Status_LED DEBUG_LED* DITH* FPGA_PTT  NCONFIG  RAND*  USEROUT* FPGA_PLL DAC_ALC DRIVER_PA_EN CTRL_TRSW IO1 TX_ATTEN* atu_ctrl}]

#don't need fast paths from the following inputs
set_false_path -from [get_keepers  {ANT_TUNE IO2 IO4 IO5 IO6 IO8 KEY_DASH KEY_DOT OVERFLOW* PTT MODE2 TX_ATTEN_SELECT SW1}]

#these registers are set long before they are used
set_false_path -from [get_registers {network:network_inst|eeprom:eeprom_inst|mac[*]}] -to [all_registers]
set_false_path -from [get_registers {network:network_inst|eeprom:eeprom_inst|ip[*]}] -to [all_registers]
set_false_path -from [get_registers {network:network_inst|local_ip[*]}] -to [all_registers]
set_false_path -from [get_registers {network:network_inst|arp:arp_inst|destination_mac[*]}] -to [all_registers]
