# Angelia.sdc
# PHY_RX_CLOCK delay set to 0xF0 in setup register.
# 6th Oct - major review
# 10th Oct - false paths to slow I/0. 1nS delay for generated clocks.
# 14th Oct - remove max/min where symetrical
# 26th Oct - added generated clocks to PLL outputs that drive FPGA output pins
#          - set false path to all generated clocks that drive FPGA output pins
#  1st Nov - added CLRCIN CLRCOUT clocks 

# 20th May 2017 - testing muticlock 



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
create_clock -name {PHY_CLK125} -period 8.000 -waveform { 0.000 4.000 } [get_ports {PHY_CLK125}]
create_clock -name {PHY_RX_CLOCK} -period 8.000 -waveform { 2.000 6.000 } [get_ports {PHY_RX_CLOCK}]

#virtual base clocks on required inputs
create_clock -name {virt_PHY_RX_CLOCK} -period 8.000 -waveform { 0.000 4.000 } 
create_clock -name {virt_122MHz} -period 8.138 -waveform { 0.000 4.069 } 
create_clock -name {virt_CBCLK} -period 325.520 -waveform { 0.000 162.760 } 

derive_pll_clocks

#assign more familiar names!
set _122_90 PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0]
set CMCLK  PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1]
set CBCLK  PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2]
set CLRCLK PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3]

set clock_12_5MHz network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[2]
set clock_2_5MHz  network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[3]

#**************************************************************
# Create Generated Clock (internal to the FPGA)
#**************************************************************
# NOTE: Whilst derive_pll_clocks constrains PLL clocks if these are connected to an FPGA output pin then a generated
# clock needs to be attached to the pin and a false path set to it

#create genenerated clock for internal PHY Tx data clock.
create_generated_clock -source [get_pins {network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] \
  -name tx_clock -duty_cycle 50.00 [get_pins {network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0]}] -add

#create generated clock for PLL transmit clock output with 90 phase shift
create_generated_clock -source [get_pins {network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] \
  -name PHY_TX_CLOCK -phase 157.50 -duty_cycle 50.00 [get_pins {network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[1]}] -add

# data_clock = CMCLK/2 used by Attenuator and TLV320 SPI
create_generated_clock -name data_clk -source $CMCLK -divide 2

# data_clk2 = CBCLK/4 
create_generated_clock -name data_clk2 -source $CBCLK -divide 4

# PLL generated clocks feeding output pins
create_generated_clock -name CBCLK   -source $CBCLK  [get_ports CBCLK]
create_generated_clock -name CMCLK   -source $CMCLK  [get_ports CMCLK]
create_generated_clock -name CLRCIN  -source $CLRCLK [get_ports CLRCIN]
create_generated_clock -name CLRCOUT -source $CLRCLK [get_ports CLRCOUT]

derive_clock_uncertainty

#**************************************************************
# Set Clock Groups
#**************************************************************
set_clock_groups -asynchronous  -group { \
					LTC2208_122MHz \
					_122MHz \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0] \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1] \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3] \
					PLL_inst|altpll_component|auto_generated|pll1|clk[0] \
					data_clk \
					data_clk2 \
					CBCLK \
					CMCLK \
					CLRCIN \
					CLRCOUT \
				       } \
				-group {LTC2208_122MHz_2} \
				-group { \
					PHY_CLK125 \
					network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0] \
					network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[1] \
					network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[2] \
					network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[3] \
					tx_clock \
					PHY_TX_CLOCK \
				       } \
				-group {OSC_10MHZ} \
				-group {PHY_RX_CLOCK}
		

#**************************************************************
# Set Output Delay
#**************************************************************

# If setup and hold delays are equal then only need to specify once without max or min 

#122.88MHz clock for Tx DAC
set_output_delay 0.8 -clock _122MHz {DACD[*]} -add_delay

## Ethernet PHY TX per AN477, with PHY delay for TX disabled
set_output_delay  -max 1.0  -clock PHY_TX_CLOCK [get_ports {PHY_TX[*]}] -add_delay
set_output_delay  -min -0.8 -clock PHY_TX_CLOCK [get_ports {PHY_TX[*]}] -add_delay
set_output_delay  -max 1.0  -clock PHY_TX_CLOCK [get_ports {PHY_TX[*]}] -clock_fall -add_delay
set_output_delay  -min -0.8 -clock PHY_TX_CLOCK [get_ports {PHY_TX[*]}] -clock_fall -add_delay

set_output_delay  -max 1.0  -clock PHY_TX_CLOCK [get_ports {PHY_TX_EN}] -add_delay
set_output_delay  -min -0.8 -clock PHY_TX_CLOCK [get_ports {PHY_TX_EN}] -add_delay
set_output_delay  -max 1.0  -clock PHY_TX_CLOCK [get_ports {PHY_TX_EN}] -clock_fall -add_delay
set_output_delay  -min -0.8 -clock PHY_TX_CLOCK [get_ports {PHY_TX_EN}] -clock_fall -add_delay

# Set false paths to remove irrelevant setup and hold analysis
set_false_path -fall_from [get_clocks tx_clock] -rise_to [get_clocks PHY_TX_CLOCK] -setup
set_false_path -rise_from [get_clocks tx_clock] -fall_to [get_clocks PHY_TX_CLOCK] -setup
set_false_path -fall_from [get_clocks tx_clock] -fall_to [get_clocks PHY_TX_CLOCK] -hold
set_false_path -rise_from [get_clocks tx_clock] -rise_to [get_clocks PHY_TX_CLOCK] -hold

# Attenuators - min is referenced to falling edge of clock 
set_output_delay  10  -clock data_clk { ATTN_DATA* ATTN_LE* } -add_delay
set_output_delay  10  -clock data_clk { ATTN_DATA* ATTN_LE* } -clock_fall -add_delay

#TLV320 SPI  
set_output_delay  20 -clock data_clk { MOSI nCS} -add_delay

#TLV320 Data out 
set_output_delay  10 -clock $CBCLK {CDIN CMODE} -add_delay

#Alex  uses CBCLK/4
set_output_delay  10 -clock data_clk2 { SPI_SDO } -add_delay
set_output_delay  10 -clock { PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] } [get_ports {SPI_RX_LOAD}] -add_delay

#EEPROM (2.5MHz)
set_output_delay  40 -clock $clock_2_5MHz {SCK SI CS} -add_delay

#ADC78H90 
set_output_delay  10 -clock data_clk2 {ADCMOSI ADCCS_N} -add_delay

#PHY (2.5MHz)
set_output_delay  10 -clock $clock_2_5MHz {PHY_MDIO} -add_delay

#MCU
set_output_delay  10 -clock $CBCLK [get_ports {MCU_UART_TX}] -add_delay
set_output_delay  10 -clock { PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] } [get_ports {MCU_UART_TX}] -add_delay

#************************************************************** 
# Set Input Delay
#**************************************************************

# If setup and hold delays are equal then only need to specify once without max or min 

# data from LTC2208 +/- 2nS setup and hold
set_input_delay -add_delay  -clock [get_clocks {virt_122MHz}]  2.000 [get_ports {INA[*]}]
set_input_delay -add_delay  -clock [get_clocks {virt_122MHz}]  2.000 [get_ports {INA_2[*]}]

# clock to ADC
set_output_delay -clock { LTC2208_122MHz } -add_delay 2.0 [get_ports {_122MHz_out}]

## Ethernet PHY RX per AN477, with PHY delay for RX enabled
## Clock delay added by KSZ9031 is 1.0 to 2.6 per datasheet table 7-1
## Clock is 90deg shifted, 2ns
## Max delay is 2.6-2.0 = 0.6
## Min delay is 1.0-2.0 = -1.0

# data from PHY
set_input_delay  -max 0.6  -clock [get_clocks virt_PHY_RX_CLOCK] -add_delay [get_ports {PHY_RX[*]}]
set_input_delay  -min -1.0 -clock [get_clocks virt_PHY_RX_CLOCK] -add_delay [get_ports {PHY_RX[*]}]
set_input_delay  -max 0.6 -clock_fall -clock [get_clocks virt_PHY_RX_CLOCK] -add_delay [get_ports {PHY_RX[*]}]
set_input_delay  -min -1.0 -clock_fall -clock [get_clocks virt_PHY_RX_CLOCK] -add_delay [get_ports {PHY_RX[*]}]

set_input_delay  -max 0.6  -clock [get_clocks virt_PHY_RX_CLOCK] -add_delay [get_ports {PHY_RX_DV}]
set_input_delay  -min -1.0 -clock [get_clocks virt_PHY_RX_CLOCK] -add_delay [get_ports {PHY_RX_DV}]
set_input_delay  -max 0.6 -clock_fall -clock [get_clocks virt_PHY_RX_CLOCK] -add_delay [get_ports {PHY_RX_DV}]
set_input_delay  -min -1.0 -clock_fall -clock [get_clocks virt_PHY_RX_CLOCK] -add_delay [get_ports {PHY_RX_DV}]

# Set false paths to remove irrelevant setup and hold analysis
set_false_path -fall_from [get_clocks virt_PHY_RX_CLOCK] -rise_to [get_clocks {PHY_RX_CLOCK}] -setup
set_false_path -rise_from [get_clocks virt_PHY_RX_CLOCK] -fall_to [get_clocks {PHY_RX_CLOCK}] -setup
set_false_path -fall_from [get_clocks virt_PHY_RX_CLOCK] -fall_to [get_clocks {PHY_RX_CLOCK}] -hold
set_false_path -rise_from [get_clocks virt_PHY_RX_CLOCK] -rise_to [get_clocks {PHY_RX_CLOCK}] -hold

#TLV320 Data in +/- 20nS setup and hold
set_input_delay  20  -clock virt_CBCLK  {CDOUT} -add_delay

#EEPROM Data in +/- 40nS setup and hold
set_input_delay  40  -clock $clock_2_5MHz {SO} -add_delay 

#PHY PHY_MDIO Data in +/- 10nS setup and hold
set_input_delay  10  -clock $clock_2_5MHz -reference_pin [get_ports PHY_MDC] {PHY_MDIO} -add_delay

#ADC78H90 Data in +/- 10nS setup and hold
set_input_delay  10  -clock data_clk2 {ADCMISO} -add_delay


#**************************************************************
# Set Maximum Delay (for setup or recovery; low-level, over-riding timing adjustments)
#************************************************************** 

set_max_delay -from tx_clock -to network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0] 21
set_max_delay -from network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0] -to tx_clock 21
set_max_delay -from tx_clock -to tx_clock 21
set_max_delay -from network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0] -to network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0] 21
set_max_delay -from LTC2208_122MHz -to LTC2208_122MHz 18
set_max_delay -from LTC2208_122MHz -to PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0] 7
set_max_delay -from PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0] -to _122MHz 7
set_max_delay -from PHY_RX_CLOCK -to PHY_RX_CLOCK 10
set_max_delay -from tx_clock -to PHY_TX_CLOCK 11
set_max_delay -from network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0] -to PHY_TX_CLOCK 11


#**************************************************************
# Set Minimum Delay (for hold or removal; low-level, over-riding timing adjustments)
#**************************************************************

set_min_delay -from PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3] -to PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] -1


#**************************************************************
# Set Multicycle Path
#************************************************************** 

set_multicycle_path -from [get_keepers {network:network_inst|dhcp:dhcp_inst|length[*]}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -setup -start 3
set_multicycle_path -from [get_keepers {network:network_inst|dhcp:dhcp_inst|length[*]}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -hold -start 2

set_multicycle_path -from [get_keepers {network:network_inst|tx_protocol*}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -setup -start 3
set_multicycle_path -from [get_keepers {network:network_inst|tx_protocol*}] -to [get_keepers {network:network_inst|ip_send:ip_send_inst|shift_reg[*]}] -hold -start 2

set_multicycle_path -from [get_keepers {network:network_inst|arp:arp_inst|tx_byte_no[*]}] -to [get_keepers {network:network_inst|mac_send:mac_send_inst|shift_reg[*]}] -setup -start 2
set_multicycle_path -from [get_keepers {network:network_inst|arp:arp_inst|tx_byte_no[*]}] -to [get_keepers {network:network_inst|mac_send:mac_send_inst|shift_reg[*]}] -hold -start 1


#**************************************************************
# Set False Paths
#**************************************************************
 
set_false_path -from [get_clocks {LTC2208_122MHz}] -to [get_clocks {LTC2208_122MHz_2}]
set_false_path -from [get_ports {PHY_RESET_N}]

# Set false path to generated clocks that feed output pins
set_false_path -to [get_ports {CMCLK CBCLK CLRCIN CLRCOUT ATTN_CLK* SSCK ADCCLK SPI_SCK PHY_MDC PHY_TX_CLOCK}]

# 'get_keepers' denotes either ports or registers
# don't need fast paths to the LEDs and adhoc outputs so set false paths so Timing will be ignored
set_false_path -to [get_keepers { Status_LED DEBUG_LED* DEBUG_TP* FPGA_PTT NCONFIG USEROUT* FPGA_PLL DAC_ALC ANT2_RELAY PHY_RESET_N VNA_out}]

#don't need fast paths from the following inputs
set_false_path -from [get_keepers  {ANT_TUNE KEY_DASH KEY_DOT OVERFLOW* PTT PTT2}]


#these registers are set long before they are used
set_false_path -from [get_registers {network:network_inst|eeprom:eeprom_inst|mac[*]}] -to [all_registers]
set_false_path -from [get_registers {network:network_inst|eeprom:eeprom_inst|ip[*]}] -to [all_registers]
set_false_path -from [get_registers {network:network_inst|local_ip[*]}] -to [all_registers]
set_false_path -from [get_registers {network:network_inst|arp:arp_inst|destination_mac[*]}] -to [all_registers]
