## basys3.xdc -- pin constraints for the DSD-8 board demo (dsd8_top)
## ASSUMPTION: Digilent Basys 3 (Artix-7 XC7A35T-1CPG236C). The spec names
## the board signals (8 switches, 5 buttons U/D/L/R/C, 8 LEDs, 4-digit 7-seg)
## but not the board; change the PACKAGE_PINs if your lab uses another board.
##
## Mapping:  switches[7:0] = SW0..SW7      rst_n  = SW15 (up = run, down = reset)
##           buttons = {btnU,btnD,btnL,btnR,btnC}
##           leds[7:0] = LD0..LD7          halted = LD15
##           seg/an    = the on-board 4-digit display (active low)
## Program: set dsd8_top's IMAGE parameter to the .hex to demonstrate
## (e.g. build/conformance/T36_multiply.hex) in the synthesis settings.

## 100 MHz board clock; the core runs on clk / CLK_DIV (default 4 -> 25 MHz)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]
create_generated_clock -name cpu_clk -source [get_ports clk] -divide_by 4 [get_pins cpu_clk_reg/Q]

## reset switch (SW15)
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports rst_n]

## slide switches SW0..SW7 -> port 0x00
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {switches[0]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {switches[1]}]
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {switches[2]}]
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {switches[3]}]
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {switches[4]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {switches[5]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {switches[6]}]
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {switches[7]}]

## buttons {btnU,btnD,btnL,btnR,btnC} = buttons[4:0] -> port 0x01
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports {buttons[4]}]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports {buttons[3]}]
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports {buttons[2]}]
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports {buttons[1]}]
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports {buttons[0]}]

## LEDs LD0..LD7 <- port 0x02, LD15 = halted
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {leds[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {leds[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {leds[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {leds[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {leds[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {leds[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {leds[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {leds[7]}]
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports halted]

## seven-segment display: seg = {g,f,e,d,c,b,a}, active low
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN W6   IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN U5   IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN V5   IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN U7   IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]
set_property -dict { PACKAGE_PIN U2   IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports {an[3]}]

## configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
