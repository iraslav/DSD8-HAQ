## basys3_secure.xdc -- pin constraints for the two-processor RSA enclave demo (dsd8_secure_top)
## ASSUMPTION: Digilent Basys 3 (Artix-7 XC7A35T-1CPG236C). The spec names
## the board signals (8 switches, 5 buttons U/D/L/R/C, 8 LEDs, 4-digit 7-seg)
## but not the board; change the PACKAGE_PINs if your lab uses another board.
##
## Mapping:  switches[7:0] = SW0..SW7 = private-key byte for core A (correct 0x71)
##           switches_b[6:0] = SW8..SW14 = private-key byte for core B (correct 0x2B)
##           rst_n = SW15, BTNC = retry after a key mismatch
##           MODE SELECTOR: hold BTNU while sliding SW15 up -> DEBUG mode,
##                          otherwise SECURE communication mode
##           buttons = {btnU,btnD,btnL,btnR,btnC}
##           leds[7:0] = LD0..LD7 (core B: failed attempts, FF = MATCH)
##           leds_a[6:0] = LD8..LD14 (core A: requests served)   halted = LD15 (both)
##           seg/an    = the on-board 4-digit display (active low)
## Programs: IMAGE_A = enclave_server.hex, IMAGE_B = enclave_client.hex (tb/data/)

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

## slide switches SW8..SW14 -> core B port 0x00
set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports {switches_b[0]}]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports {switches_b[1]}]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports {switches_b[2]}]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports {switches_b[3]}]
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports {switches_b[4]}]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports {switches_b[5]}]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports {switches_b[6]}]

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

## core A status LEDs LD8..LD14
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {leds_a[0]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {leds_a[1]}]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {leds_a[2]}]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {leds_a[3]}]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {leds_a[4]}]
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {leds_a[5]}]
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {leds_a[6]}]

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
