; T10 -- store then load from the same address; store to 0x00 and to 0xFF (group T2)
; Expected: DMEM[00]=3C, DMEM[FF]=C3, DMEM[80]=5A, each read back unchanged;
; DMEM[01] and DMEM[FE] (neighbours) still read 00.
        LDI  R1, 0x00
        LDI  R2, 0x3C
        ST   [R1], R2
        LD   R3, [R1]
        LDI  R4, 0xFF
        LDI  R5, 0xC3
        ST   [R4], R5
        LD   R6, [R4]
        LDI  R1, 0x80
        LDI  R2, 0x5A
        ST   [R1], R2
        LD   R7, [R1]
        LDI  R1, 0x01
        LD   R3, [R1]       ; neighbour of 0x00: still 00
        LDI  R1, 0xFE
        LD   R3, [R1]       ; neighbour of 0xFF: still 00
        LDI  R1, 0x00
        LD   R0, [R1]       ; 0x00 still 3C after the other stores
        HLT
