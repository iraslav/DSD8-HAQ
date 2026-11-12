; T08 -- rd equal to rs1 equal to rs2, e.g. ADD R3,R3,R3 (group T1)
; Expected: R3 doubles 3 -> 6 -> 12 -> 24 -> 48; R5 cleared by XOR R5,R5,R5.
        LDI  R3, 3
        ADD  R3, R3, R3
        ADD  R3, R3, R3
        ADD  R3, R3, R3
        ADD  R3, R3, R3
        LDI  R5, 0xA5
        XOR  R5, R5, R5     ; 0, Z=1
        LDI  R6, 0x81
        SUB  R6, R6, R6     ; 0, Z=1 C=1
        LDI  R7, 0xC0
        ADD  R7, R7, R7     ; 0x80, C=1
        AND  R7, R7, R7
        OR   R7, R7, R7
        HLT
