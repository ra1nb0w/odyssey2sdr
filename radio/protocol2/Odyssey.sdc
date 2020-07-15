# Odyssey.sdc
#          


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3

derive_pll_clocks

derive_clock_uncertainty

#**************************************************************
# ADC input and Clock
#**************************************************************

create_clock -name INA_CLK 		-period 8.138	[get_ports INA_CLK]
create_clock -name INA_CLK_2   	-period 8.138 	[get_ports INA_CLK_2]

set_input_delay -clock INA_CLK   -max 1  [get_ports {INA[*]}]
set_input_delay -clock INA_CLK   -min -1 [get_ports {INA[*]}]

set_input_delay -clock INA_CLK_2 -max 1  [get_ports {INA_2[*]}]
set_input_delay -clock INA_CLK_2 -min -1 [get_ports {INA_2[*]}]

#set_input_delay -clock INA_CLK   -max 1  [get_ports INA_CLK]
#set_input_delay -clock INA_CLK   -min -1 [get_ports INA_CLK]

#set_input_delay -clock INA_CLK_2 -max 1  [get_ports INA_CLK_2]
#set_input_delay -clock INA_CLK_2 -min -1 [get_ports INA_CLK_2]

#**************************************************************
# PHY IO and clock
#**************************************************************

# ****************  TX section ******************************** 

# output clock
create_generated_clock -name PHY_TX_CLOCK -source [get_pins {tx_pll_c1}] [get_ports {PHY_TX_CLOCK}]

set tx_pll_inclk network_inst|rgmii_send:rgmii_send_inst|tx_pll:tx_pll_inst|altpll:altpll_component|tx_pll_altpll:auto_generated|pll1|inclk[0]
set tx_pll_c0    network_inst|rgmii_send:rgmii_send_inst|tx_pll:tx_pll_inst|altpll:altpll_component|tx_pll_altpll:auto_generated|pll1|clk[0]
set tx_pll_c1    network_inst|rgmii_send:rgmii_send_inst|tx_pll:tx_pll_inst|altpll:altpll_component|tx_pll_altpll:auto_generated|pll1|clk[1]



create_generated_clock -name clock_125_MHz_0_deg -phase -67.5 -source [get_pins {tx_pll_inclk}] [get_pins {tx_pll_c0}]

create_generated_clock -name clock_125_MHz_90_deg -phase 90   -source [get_pins {tx_pll_inclk}] [get_pins {tx_pll_c1}]

# Set output delay 
set_output_delay -clock PHY_TX_CLOCK             -max  1.0 [get_ports {PHY_TX[*]}]
set_output_delay -clock PHY_TX_CLOCK             -min -0.8 [get_ports {PHY_TX[*]}]
set_output_delay -clock PHY_TX_CLOCK -clock_fall -max  1.0 [get_ports {PHY_TX[*]}] 
set_output_delay -clock PHY_TX_CLOCK -clock_fall -min -0.8 [get_ports {PHY_TX[*]}]

#set_output_delay -clock PHY_TX_CLOCK             -max  1.0 [get_ports PHY_TX_CLOCK]
#set_output_delay -clock PHY_TX_CLOCK             -min -0.8 [get_ports PHY_TX_CLOCK] 
#set_output_delay -clock PHY_TX_CLOCK -clock_fall -max  1.0 [get_ports PHY_TX_CLOCK]
#set_output_delay -clock PHY_TX_CLOCK -clock_fall -min -0.8 [get_ports PHY_TX_CLOCK]

# Set false paths
set_false_path -fall_from [get_clocks clock_125_MHz_0_deg] -rise_to [get_clocks PHY_TX_CLOCK] -setup
set_false_path -rise_from [get_clocks clock_125_MHz_0_deg] -fall_to [get_clocks PHY_TX_CLOCK] -setup
set_false_path -fall_from [get_clocks clock_125_MHz_0_deg] -fall_to [get_clocks PHY_TX_CLOCK] -hold
set_false_path -rise_from [get_clocks clock_125_MHz_0_deg] -rise_to [get_clocks PHY_TX_CLOCK] -hold


# ****************  RX section ********************************

#input clock
create_clock -name PHY_RX_CLOCK -period 8 [get_ports PHY_RX_CLOCK] 

# Set input delay 
set_input_delay -max  0.5 -clock PHY_RX_CLOCK              [get_ports {PHY_RX[*]}]
set_input_delay -min -0.5 -clock PHY_RX_CLOCK              [get_ports {PHY_RX[*]}]
set_input_delay -max  0.5 -clock PHY_RX_CLOCK -clock_fall  [get_ports {PHY_RX[*]}] -add_delay
set_input_delay -min -0.5 -clock PHY_RX_CLOCK -clock_fall  [get_ports {PHY_RX[*]}] -add_delay

#set_input_delay -max  0.5 -clock PHY_RX_CLOCK              [get_ports PHY_RX_CLOCK]
#set_input_delay -min -0.5 -clock PHY_RX_CLOCK              [get_ports PHY_RX_CLOCK]
#set_input_delay -max  0.5 -clock PHY_RX_CLOCK -clock_fall  [get_ports PHY_RX_CLOCK]
#set_input_delay -min -0.5 -clock PHY_RX_CLOCK -clock_fall  [get_ports PHY_RX_CLOCK]

# Set false paths 
set_false_path -fall_from PHY_RX_CLOCK -rise_to [get_clocks clock_125_MHz_90_deg] -setup
set_false_path -rise_from PHY_RX_CLOCK -fall_to [get_clocks clock_125_MHz_90_deg] -setup
set_false_path -fall_from PHY_RX_CLOCK -fall_to [get_clocks clock_125_MHz_90_deg] -hold
set_false_path -rise_from PHY_RX_CLOCK -rise_to [get_clocks clock_125_MHz_90_deg] -hold

#**************************************************************
# Create Clock (base clocks, external to the FPGA)
#**************************************************************

create_clock -name _122MHz_in 			-period 8.138 	[get_ports {_122MHz_in}]
create_clock -name OSC_10MHZ 				-period 100.000 [get_ports {OSC_10MHZ}]
create_clock -name PHY_CLK125				-period 8.000 	[get_ports {PHY_CLK125}]

#virtual base clocks on required inputs
#create_clock -name virt_122MHz_in 		-period 8.138
create_clock -name virt_CBCLK				-period 325.52




#assign more familiar names!
set CMCLK  PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0]
set CBCLK  PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1]
set CLRCLK PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2]

set clock_12_5MHz network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[2]

set clock_2_5MHz  network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[4]


#**************************************************************
# Create Generated Clock (internal to the FPGA)
#**************************************************************
# NOTE: Whilst derive_pll_clocks constrains PLL clocks if these are connected to an FPGA output pin then a generated
# clock needs to be attached to the pin and a false path set to it


# data_clock = CMCLK/2 used by Attenuator and TLV320 SPI
create_generated_clock -name data_clk -source $CMCLK -divide 2 

# data_clk2 = CBCLK/4 
create_generated_clock -name data_clk2 -source $CBCLK -divide 4

# PLL generated clocks feeding output pins 
create_generated_clock -name CBCLK   -source $CBCLK  [get_ports CBCLK]
create_generated_clock -name CMCLK   -source $CMCLK  [get_ports CMCLK]
create_generated_clock -name CLRCIN  -source $CLRCLK [get_ports CLRCIN]
create_generated_clock -name CLRCOUT -source $CLRCLK [get_ports CLRCOUT]


#************************************************************** 
# Set Input Delay
#**************************************************************

# If setup and hold delays are equal then only need to specify once without max or min 

#12.5MHz clock for Config EEPROM  +/- 10nS setup and hold
#set_input_delay 10  -clock  $clock_12_5MHz { ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_cv82:ASMI_altasmi_parallel_cv82_component|cycloneii_asmiblock2~ALTERA_DATA0}

#TLV320 Data in +/- 20nS setup and hold
set_input_delay  20  -clock virt_CBCLK  {CDOUT}

#EEPROM Data in +/- 40nS setup and hold
set_input_delay  40  -clock $clock_2_5MHz {ESO}

#PHY PHY_MDIO Data in +/- 10nS setup and hold
set_input_delay  10  -clock $clock_2_5MHz {PHY_MDIO}

#ADC78H90 Data in +/- 10nS setup and hold
set_input_delay  10  -clock data_clk2 {ADCMISO}


#**************************************************************
# Set Output Delay
#**************************************************************

# If setup and hold delays are equal then only need to specify once without max or min 

#12.5MHz clock for Config EEPROM  +/- 10nS
#set_output_delay  10 -clock $clock_12_5MHz {ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_cv82:ASMI_altasmi_parallel_cv82_component|cycloneii_asmiblock2~ALTERA_SCE ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_cv82:ASMI_altasmi_parallel_cv82_component|cycloneii_asmiblock2~ALTERA_SDO ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_cv82:ASMI_altasmi_parallel_cv82_component|cycloneii_asmiblock2~ALTERA_DCLK}

#122.88MHz clock for Tx DAC 
set_output_delay  1.0 -clock _122MHz_in   { DACD[*]}

# Attenuators - min is referenced to falling edge of clock 
set_output_delay  10  -clock data_clk { ATTN_DATA* ATTN_LE* }
set_output_delay  10  -clock data_clk { ATTN_DATA* ATTN_LE* } -clock_fall -add_delay

#TLV320 SPI  
set_output_delay  20 -clock data_clk { CMOSI CCS_N}

#TLV320 Data out 
set_output_delay  10 -clock $CBCLK {CDIN CMODE}

#Alex  uses CBCLK/4
set_output_delay  10 -clock data_clk2 { SPI_SDO SPI_SCK SPI_RX_LOAD}

#EEPROM (2.5MHz)
set_output_delay  40 -clock $clock_2_5MHz {ESCK ESI ECS}

#ADC78H90 
set_output_delay  10 -clock data_clk2 {ADCMOSI ADCCS_N}

#PHY (2.5MHz)
set_output_delay  10 -clock $clock_2_5MHz {PHY_MDIO}

#**************************************************************
# Set Clock Groups
#**************************************************************
set_clock_groups -asynchronous  -group { \
					INA_CLK \
					INA_CLK_2 \
					_122MHz_in \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0] \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1] \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] \
					data_clk \
					data_clk2 \
					CBCLK \
					CMCLK \
					CLRCIN \
					CLRCOUT \
				       } \
				-group { \
					PHY_CLK125 \
					network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0] \
					network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[1] \
					network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[4] \
					tx_output_clock \
				       } \
				-group {OSC_10MHZ PLL2_inst|altpll_component|auto_generated|pll1|clk[0]} \
				-group {PHY_RX_CLOCK }
				
					
#**************************************************************
# Set Maximum Delay
#************************************************************** 

set_max_delay -from _122MHz_in -to _122MHz_in 13


set_max_delay -from PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] -to _122MHz_in 10


#**************************************************************
# Set Minimum Delay
#**************************************************************

set_min_delay -from PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] -to PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1] -1


#**************************************************************
# Set False Paths
#**************************************************************

set_false_path -from {network:network_inst|mac_recv:mac_recv_inst|is_arp} -to {High_Priority_CC:High_Priority_CC_inst|Rx_frequency*}

set_false_path -from [get_clocks {network_inst|rgmii_send_inst|tx_pll_inst|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {tx_output_clock}]

# Set false path to generated clocks that feed output pins
set_false_path -to [get_ports {CMCLK CBCLK CLRCIN CLRCOUT ATTN_CLK* CSCK ADCCLK SPI_SCK PHY_MDC PHY_TX_CLOCK}]

# don't need fast paths to the LEDs and adhoc outputs so set false paths so Timing will be ignored
set_false_path -to {FPGA_PTT  NCONFIG USEROUT* FPGA_PLL DAC_ALC led*}

#don't need fast paths from the following inputs
set_false_path -from  {ANT_TUNE KEY_DASH KEY_DOT OVERFLOW OVERFLOW_2 PTT}


#these registers are set long before they are used
set_false_path -from [get_registers {network:network_inst|eeprom:eeprom_inst|mac[*]}] -to [all_registers]
set_false_path -from [get_registers {network:network_inst|local_ip[*]}] -to [all_registers]
set_false_path -from [get_registers {network:network_inst|arp:arp_inst|destination_mac[*]}] -to [all_registers]



