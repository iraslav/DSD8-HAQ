; T01 -- LDI into each of the eight registers in turn (spec 8.4, group T1)
; Proves: every register is independently writable (R1, R2 -- R0 is not special).
; After all eight writes, each register is read back with MOV Rn,Rn so the
; trace shows its value survived the other seven writes.
; Expected final state: R0..R7 = 11 22 33 44 55 66 77 88.
        LDI  R0, 0x11
        LDI  R1, 0x22
        LDI  R2, 0x33
        LDI  R3, 0x44
        LDI  R4, 0x55
        LDI  R5, 0x66
        LDI  R6, 0x77
        LDI  R7, 0x88
        MOV  R0, R0
        MOV  R1, R1
        MOV  R2, R2
        MOV  R3, R3
        MOV  R4, R4
        MOV  R5, R5
        MOV  R6, R6
        MOV  R7, R7
        HLT
