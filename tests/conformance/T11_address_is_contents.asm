; T11 -- the address register is the CONTENTS of rs1, not the register number (group T2)
; R3 holds 0x40: ST [R3] must write DMEM[0x40], never DMEM[3].
; Expected: DMEM[40]=A5, DMEM[03] stays 00, DMEM[05]=77 via R6=5.
        LDI  R3, 0x40
        LDI  R5, 0xA5
        ST   [R3], R5       ; mem fields: 1 40 A5
        LDI  R7, 3
        LD   R1, [R7]       ; DMEM[3] -> 00
        LD   R2, [R3]       ; DMEM[40] -> A5
        LDI  R6, 5
        LDI  R0, 0x77
        ST   [R6], R0       ; DMEM[05] = 77, not DMEM[6]
        LDI  R4, 6
        LD   R4, [R4]       ; DMEM[6] -> 00
        LD   R5, [R6]       ; DMEM[5] -> 77
        HLT
