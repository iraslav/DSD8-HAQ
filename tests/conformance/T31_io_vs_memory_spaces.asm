; T31 -- OUT to LEDS then IN from SWITCHES; the two spaces are independent (group T5)
; The harness drives switches = 0x00. Port 0x02 (LEDS) and DMEM[0x02] are
; different things; port 0x00 (SWITCHES) and DMEM[0x00] likewise.
; Expected: IN R2,0x00 = 00 (switches) although DMEM[00] = 66; LD from
; DMEM[02] = 00 although LEDs were written 5A.
        LDI  R1, 0x5A
        OUT  0x02, R1       ; LEDs = 5A
        IN   R2, 0x00       ; switches
        LDI  R3, 0x02
        LD   R4, [R3]       ; DMEM[02]: untouched by the OUT -> 00
        LDI  R5, 0x00
        LDI  R6, 0x66
        ST   [R5], R6       ; DMEM[00] = 66
        IN   R7, 0x00       ; still the switches, not 66
        IN   R0, 0x01       ; buttons = 00
        HLT
