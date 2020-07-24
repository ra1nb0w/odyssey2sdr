# Angelia.sdc
# 10 April 2014, Joe Martin K5SO


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3


#**************************************************************************************
# Create Clock
#**************************************************************************************
# externally generated clocks (with respect to the FPGA)
#
create_clock -period 122.880MHz	-name INA_CLK    [get_ports INA_CLK]
create_clock -period 122.880MHz	-name INA_CLK_2  [get_ports INA_CLK_2]
create_clock -period 122.880MHz	-name _122MHz_in		[get_ports _122MHz_in]
create_clock -period  10.000MHz	-name OSC_10MHZ		[get_ports OSC_10MHZ]
create_clock -period 125.000MHz	-name PHY_CLK125	[get_ports PHY_CLK125]
create_clock -period  25.000MHz	-name PHY_RX_CLOCK	[get_ports PHY_RX_CLOCK]

#virtual base clocks on required inputs
#create_clock -name virt_PHY_RX_CLOCK 	-period 8.000 
#create_clock -name virt_122MHz_in 		-period 8.138
#create_clock -name virt_122MHz_2 	-period 8.138
#create_clock -name virt_CBCLK		-period 325.52

derive_pll_clocks

derive_clock_uncertainty

#assign more familiar names!
set CMCLK  		PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1]
set CBCLK  		PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2]
set CLRCLK 		PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3]
set EEPROM_clock 	PLL_clocks_inst|altpll_component|auto_generated|pll1|clk[0]
set clock_12_5MHz 	PLL_clocks_inst|altpll_component|auto_generated|pll1|clk[1]

#*************************************************************************************
# Create Generated Clock
#*************************************************************************************
# NOTE: Whilst derive_pll_clocks constrains PLL clocks if these are connected to an FPGA output pin then a generated
# clock needs to be attached to the pin and a false path set to it

# internally generated clocks
create_generated_clock -name PHY_RX_CLOCK_2 	-source PHY_RX_CLOCK 	-divide_by 2 	PHY_RX_CLOCK_2
#create_generated_clock -name userADC_clk	-source _122MHz_in 	-divide_by 4 	userADC_clk

# PLL generated clocks feeding output pins 
create_generated_clock -name CBCLK   -source $CBCLK  [get_ports CBCLK]
create_generated_clock -name CMCLK   -source $CMCLK  [get_ports CMCLK]
create_generated_clock -name CLRCIN  -source $CLRCLK [get_ports CLRCIN]
create_generated_clock -name CLRCOUT -source $CLRCLK [get_ports CLRCOUT]


#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group {PHY_CLK125 \
					PLL_clocks_inst|altpll_component|auto_generated|pll1|clk[0] \
					PLL_clocks_inst|altpll_component|auto_generated|pll1|clk[1] \
					PLL_clocks_inst|altpll_component|auto_generated|pll1|clk[2] \
					PHY_RX_CLOCK \
					PHY_RX_CLOCK_2 \
				       } \
				-group {_122MHz_in \
					INA_CLK \
					INA_CLK_2 \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[1] \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] \
					PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3] \
					PLL_inst|altpll_component|auto_generated|pll1|clk[0] \
					PLL_inst|altpll_component|auto_generated|pll1|clk[1] \
				       } \
				-group {PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0] }
				
					
#*************************************************************************************************************
# Set Input Delay
#*************************************************************************************************************
# If setup and hold delays are equal then only need to specify once without max or min

#TLV320 Data in +/- 20nS setup and hold
#set_input_delay  20  -clock virt_CBCLK  {CDOUT}

#EEPROM Data in +/- 40nS setup and hold
set_input_delay  40  -clock $EEPROM_clock {ESO}

#PHY PHY_MDIO Data in +/- 10nS setup and hold
set_input_delay  10  -clock $EEPROM_clock {PHY_MDIO}

#12.5MHz clock for Config EEPROM  +/- 10nS setup and hold
set_input_delay 10  -clock  $clock_12_5MHz { ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_cv82:ASMI_altasmi_parallel_cv82_component|sd2~ALTERA_DATA0}

#ADC78H90 Data in +/- 10nS setup and hold
#set_input_delay  10  -clock virt_CBCLK {ADCMISO}

set_input_delay -add_delay -max -clock PHY_CLK125 1.500  {PHY_MDIO PHY_RX[*] PHY_RX_DV }
set_input_delay -add_delay -min -clock PHY_CLK125 -0.500 {PHY_MDIO PHY_RX[*] PHY_RX_DV  }
set_input_delay -clock INA_CLK 1.000    { INA[*] }
set_input_delay -clock INA_CLK_2 1.000  { INA_2[*]}


#*************************************************************************************************************
# Set Output Delay
#*************************************************************************************************************
# If setup and hold delays are equal then only need to specify once without max or min

set_output_delay -add_delay -max -clock PHY_CLK125 1.500  { PHY_TX[*] PHY_TX_EN PHY_TX_CLOCK }
set_output_delay -add_delay -min -clock PHY_CLK125 -0.500 { PHY_TX[*] PHY_TX_EN PHY_TX_CLOCK } 

# Set 15 degree DAC data clock to data
#set_output_delay 1.00 -clock $DACD_clock { DACD[*]}
 
#122.88MHz clock  
#set_output_delay  1.000 -clock _122MHz   { DACD[*] FPGA_PLL DAC_ALC}
set_output_delay  1.000 -clock _122MHz_in   { FPGA_PLL DAC_ALC}

# Attenuator - min is referenced to falling edge of clock 
set_output_delay  10  -clock $CMCLK { ATTN_DATA* ATTN_LE* }
set_output_delay  10  -clock $CMCLK { ATTN_DATA* ATTN_LE* } -clock_fall -add_delay

#TLV320 SPI  
set_output_delay  20 -clock $CMCLK { CMOSI CCS_N CMODE}

#TLV320 Data out 
set_output_delay  10 -clock $CBCLK {CDIN}

#Alex  uses CBCLK
set_output_delay  10 -clock $CBCLK { SPI_SDO SPI_SCK SPI_RX_LOAD}

#EEPROM (2.5MHz)
set_output_delay  40 -clock $EEPROM_clock {ESCK ESI ECS}

#ADC78H90 
set_output_delay  10 -clock $CBCLK {ADCMOSI ADCCS_N}

#PHY (2.5MHz)
set_output_delay  10 -clock $EEPROM_clock {PHY_MDIO}

#12.5MHz clock for Config EEPROM  +/- 10nS
set_output_delay  10 -clock $clock_12_5MHz {ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_cv82:ASMI_altasmi_parallel_cv82_component|sd2~ALTERA_DCLK ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_cv82:ASMI_altasmi_parallel_cv82_component|sd2~ALTERA_SCE ASMI_interface:ASMI_int_inst|ASMI:ASMI_inst|ASMI_altasmi_parallel_cv82:ASMI_altasmi_parallel_cv82_component|sd2~ALTERA_SDO }



#**************************************************************************************
# Set Maximum Delay (for setup or recovery; low-level, over-riding timing adjustments)
#**************************************************************************************

set_max_delay -from _122MHz_in -to _122MHz_in 12

set_max_delay -from INA_CLK -to INA_CLK 15
set_max_delay -from INA_CLK -to INA_CLK_2 10

set_max_delay -from INA_CLK -to PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] 10

set_max_delay -from PLL_clocks_inst|altpll_component|auto_generated|pll1|clk[1] -to PLL_clocks_inst|altpll_component|auto_generated|pll1|clk[1] 24

set_max_delay -from PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3] -to _122MHz_in 11
set_max_delay -from PLL_IF_inst|altpll_component|auto_generated|pll1|clk[3] -to INA_CLK 9

set_max_delay -from PLL_inst|altpll_component|auto_generated|pll1|clk[0] -to _122MHz_in 7

set_max_delay -from PLL_clocks_inst|altpll_component|auto_generated|pll1|clk[1] -to PHY_TX_CLOCK 6

#set_max_delay -from userADC_clk -to PLL_IF_inst|altpll_component|auto_generated|pll1|clk[0] 12
#set_max_delay -from userADC_clk -to PLL_IF_inst|altpll_component|auto_generated|pll1|clk[2] 27


#************************************************************************************
# Set Minimum Delay (for hold or removal; low-level, over-riding timing adjustments)
#************************************************************************************



#**************************************************************
# Set False Paths
#**************************************************************

set_false_path -from [get_clocks {INA_CLK_2}] -to [get_clocks {INA_CLK}]


# Set false path to generated clocks that feed output pins
set_false_path -to [get_ports {CMCLK CBCLK CLRCIN CLRCOUT ATTN_CLK* CSCK ADCCLK SPI_SCK PHY_MDC}]

# don't need fast paths to the LEDs and adhoc outputs so set false paths so Timing will be ignored
set_false_path -to {FPGA_PTT  NCONFIG   USEROUT*}

#don't need fast paths from the following inputs
set_false_path -from  {ANT_TUNE  KEY_DASH KEY_DOT OVERFLOW* PTT}

# code executes much better without constraining the DACD[*] output port!
set_false_path -to DACD[*]
