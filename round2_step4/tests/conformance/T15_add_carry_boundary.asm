; T15 -- ADD across the carry boundary: 0xFF+0x01, 0x80+0x80, 0x7F+0x01 (group T3)
; Expected (result, ZNCV): FF+01=00 1010; 80+80=00 1011; 7F+01=80 0101;
; FE+01=FF 0100; 01+FF=00 1010 (operand order swapped).
        LDI  R1, 0xFF
        LDI  R2, 0x01
        ADD  R3, R1, R2
        LDI  R4, 0x80
        ADD  R5, R4, R4
        LDI  R6, 0x7F
        ADD  R7, R6, R2
        LDI  R1, 0xFE
        ADD  R3, R1, R2
        LDI  R1, 0xFF
        ADD  R0, R2, R1
        HLT
