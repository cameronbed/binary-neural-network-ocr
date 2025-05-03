## This file is a general .xdc for the Basys3 rev B board
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]


## Switches
# set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports rst_n_sw_input]
#set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
#set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
#set_property -dict { PACKAGE_PIN W17   IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
#set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
#set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]


## LEDs
# set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
# set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
# set_property -dict { PACKAGE_PIN U19   IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports heartbeat]
# set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 } [get_ports {led[4]}]


##7 Segment Display
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN W6   IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN U5   IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN V5   IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN U7   IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]
# set_property -dict { PACKAGE_PIN V7   IOSTANDARD LVCMOS33 } [get_ports dp]

# set_property -dict { PACKAGE_PIN U2   IOSTANDARD LVCMOS33 } [get_ports result_out[0]]
# set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports result_out[1]]
# set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports result_out[2]]
# set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports result_out[3]]

##Pmod Header JB
set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports SCLK];#Sch name = JB1
set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33 } [get_ports COPI];#Sch name = JB2
set_property -dict { PACKAGE_PIN B15   IOSTANDARD LVCMOS33 } [get_ports spi_cs_n];#Sch name = JB3
set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports status_code_reg[0]];#Sch name = JB4
set_property -dict { PACKAGE_PIN A15   IOSTANDARD LVCMOS33 } [get_ports status_code_reg[1]];#Sch name = JB7
set_property -dict { PACKAGE_PIN A17   IOSTANDARD LVCMOS33 } [get_ports status_code_reg[2]];#Sch name = JB8
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports status_code_reg[3]];#Sch name = JB9
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports rst_n_pin];#Sch name = JB10

##Pmod Header JC
#set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports {JC[0]}];#Sch name = JC1
#set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports {JC[1]}];#Sch name = JC2
#set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports {JC[2]}];#Sch name = JC3
#set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports {JC[3]}];#Sch name = JC4
#set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports {JC[4]}];#Sch name = JC7
#set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports {JC[5]}];#Sch name = JC8
#set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports {JC[6]}];#Sch name = JC9
#set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports {JC[7]}];#Sch name = JC10

## Configuration options, can be used for all designs
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## SPI configuration mode options for QSPI boot, can be used for all designs
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## --------------------------
## Timing Constraints Section
## --------------------------

# FPGA clock
create_clock -name clk -period 10.000 [get_ports clk]

## ---- SPI dummy clock (asynchronous) ----
set spi_clk_period 1000.0; # 1 MHz = 1000 ns
create_clock -name sclk_async -period $spi_clk_period [get_ports SCLK]
set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks sclk_async]


# Define output delay for seg[0] to seg[6]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {seg[0]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {seg[1]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {seg[2]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {seg[3]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {seg[4]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {seg[5]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {seg[6]}]

set_output_delay -min 0 -clock [get_clocks clk] [get_ports {seg[0]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {seg[1]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {seg[2]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {seg[3]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {seg[4]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {seg[5]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {seg[6]}]

# Define output delay for status code bits
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {status_code_reg[0]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {status_code_reg[1]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {status_code_reg[2]}]
set_output_delay -max 10 -clock [get_clocks clk] [get_ports {status_code_reg[3]}]

set_output_delay -min 0 -clock [get_clocks clk] [get_ports {status_code_reg[0]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {status_code_reg[1]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {status_code_reg[2]}]
set_output_delay -min 0 -clock [get_clocks clk] [get_ports {status_code_reg[3]}]

set_input_delay -max 10 -clock [get_clocks sclk_async] [get_ports COPI]
set_input_delay -min 0 -clock [get_clocks sclk_async] [get_ports COPI]

set_input_delay -max 10 -clock [get_clocks sclk_async] [get_ports spi_cs_n]
set_input_delay -min 0 -clock [get_clocks sclk_async] [get_ports spi_cs_n]

set_input_delay -max 10 -clock [get_clocks clk] [get_ports rst_n_pin]
set_input_delay -min 0  -clock [get_clocks clk] [get_ports rst_n_pin]