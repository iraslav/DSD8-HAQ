; T02 -- LDI with the boundary values 0x00, 0x01, 0x7F, 0x80, 0xFF (group T1)
; Each value is loaded into two different registers, then observed through
; OR Rn,Rn,Rn so Z and N are shown for each boundary value.
; Expected: flags after each OR: 00->Z=1, 01->0000, 7F->0000, 80->N=1, FF->N=1.
        LDI  R0, 0x00
        LDI  R1, 0x01
        LDI  R2, 0x7F
        LDI  R3, 0x80
        LDI  R4, 0xFF
        LDI  R5, 0x00
        LDI  R6, 0x80
        LDI  R7, 0xFF
        LDI  R5, 0x01
        LDI  R6, 0x7F
        OR   R0, R0, R0
        OR   R1, R1, R1
        OR   R2, R2, R2
        OR   R3, R3, R3
        OR   R4, R4, R4
        HLT
