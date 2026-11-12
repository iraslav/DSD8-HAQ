; T12 -- ST [Rx], Rx: storing a register using itself as the address (group T2)
; Expected: DMEM[37]=37, DMEM[C8]=C8, DMEM[99]=99 (via R0), each read back.
        LDI  R4, 0x37
        ST   [R4], R4
        LD   R1, [R4]
        LDI  R7, 0xC8
        ST   [R7], R7
        LD   R2, [R7]
        LDI  R0, 0x99
        ST   [R0], R0
        LD   R3, [R0]
        LDI  R5, 0xFF
        ST   [R5], R5
        LD   R6, [R5]
        HLT
