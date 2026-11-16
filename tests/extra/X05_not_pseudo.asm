; X05 -- the NOT pseudo-op (XOR with a register holding 0xFF) and MOV
; Expected: NOT 0x5A = 0xA5 (N=1); NOT 0xFF = 0x00 (Z=1); MOV copies.
        LDI  R7, 0xFF
        LDI  R1, 0x5A
        NOT  R2, R1, R7
        NOT  R3, R7, R7
        MOV  R4, R2
        HLT
