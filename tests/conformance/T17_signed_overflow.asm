; T17 -- signed overflow: 0x7F+0x01 sets V; 0xFF+0x01 does not (group T3, spec 2.3.2)
; Expected V: 7F+01 1; FF+01 0; 80+FF 1 (-128 + -1); 40+40 1; C0+C0 0;
; 80+7F 0 (opposite signs never overflow).
        LDI  R1, 0x7F
        LDI  R2, 0x01
        ADD  R3, R1, R2
        LDI  R1, 0xFF
        ADD  R3, R1, R2
        LDI  R1, 0x80
        LDI  R2, 0xFF
        ADD  R3, R1, R2
        LDI  R4, 0x40
        ADD  R5, R4, R4
        LDI  R4, 0xC0
        ADD  R5, R4, R4
        LDI  R6, 0x80
        LDI  R7, 0x7F
        ADD  R0, R6, R7
        HLT
