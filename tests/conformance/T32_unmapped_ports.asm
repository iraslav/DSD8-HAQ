; T32 -- IN from an unmapped port returns 0x00; OUT to one is harmless (group T5, R21)
; Every IN target register is pre-loaded non-zero so a returned 0x00 is visible.
        LDI  R1, 0xA5
        OUT  0x03, R1       ; unmapped: discarded
        OUT  0x12, R1
        OUT  0x3F, R1
        OUT  0x80, R1
        OUT  0xFF, R1
        LDI  R2, 0xFF
        IN   R2, 0x03
        LDI  R3, 0xFF
        IN   R3, 0x12
        LDI  R4, 0xFF
        IN   R4, 0x3F
        LDI  R5, 0xFF
        IN   R5, 0x80
        LDI  R6, 0xFF
        IN   R6, 0xFF
        LDI  R7, 0xFF
        IN   R7, 0x02       ; LEDS is write-only: reads 00
        MOV  R1, R1         ; R1 untouched by any of the OUTs
        HLT
