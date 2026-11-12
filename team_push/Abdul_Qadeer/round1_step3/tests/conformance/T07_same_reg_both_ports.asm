; T07 -- reading the same register on both ALU input ports (group T1)
; Expected: ADD R1,R2,R2 = 2*R2; SUB of a register from itself = 0 with Z=1,C=1.
        LDI  R2, 0x21
        ADD  R1, R2, R2     ; 0x42
        LDI  R3, 0x90
        ADD  R4, R3, R3     ; 0x20, C=1, V=1
        SUB  R5, R3, R3     ; 0x00, Z=1, C=1
        AND  R6, R3, R3     ; 0x90
        XOR  R7, R3, R3     ; 0x00
        OR   R0, R2, R2     ; 0x21
        CMP  R4, R4         ; Z=1 C=1
        HLT
