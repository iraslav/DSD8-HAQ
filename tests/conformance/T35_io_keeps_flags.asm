; T35 -- IN and OUT leave the flags unchanged (group T5, R3)
; CMP 80,01 sets Z=0 N=0 C=1 V=1; IN of 0x00 (would set Z) and OUT of a
; negative value must not change them. Every I/O line must show flags 0011.
        LDI  R1, 0x80
        LDI  R2, 0x01
        CMP  R1, R2
        IN   R3, 0x00       ; 00
        OUT  0x02, R1
        OUT  0x40, R1       ; slow port, stalls
        IN   R4, 0x40       ; 80
        IN   R5, 0x99       ; unmapped -> 00
        BVC  FAIL
        BCC  FAIL
        BEQ  FAIL
        BMI  FAIL
        LDI  R7, 0x01
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
