; T39 -- find the maximum and minimum of a block of memory (group T6)
; Block of 10 unsigned bytes at DMEM[0x20..0x29] written by a prologue:
;   3C 91 07 FE 40 00 7F 80 C5 12
; Expected: max = FE -> LEDs, min = 00 -> 7-seg value, stored to DMEM[0x30]/[0x31].
        LDI  R7, 1
        LDI  R1, 0x20
        LDI  R2, 0x3C
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0x91
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0x07
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0xFE
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0x40
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0x00
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0x7F
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0x80
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0xC5
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 0x12
        ST   [R1], R2
; ---- scan ----
        LDI  R1, 0x20       ; pointer
        LDI  R6, 0x2A       ; end pointer (one past the block)
        LD   R3, [R1]       ; max = a[0]
        MOV  R4, R3         ; min = a[0]
        ADD  R1, R1, R7
SCAN:   LD   R5, [R1]
        CMP  R5, R3
        BCC  NOTMAX         ; a[i] < max (unsigned)
        MOV  R3, R5
NOTMAX: CMP  R5, R4
        BCS  NOTMIN         ; a[i] >= min
        MOV  R4, R5
NOTMIN: ADD  R1, R1, R7
        CMP  R1, R6
        BNE  SCAN
        LDI  R1, 0x30
        ST   [R1], R3
        ADD  R1, R1, R7
        ST   [R1], R4
        OUT  0x02, R3
        OUT  0x10, R4
        HLT
