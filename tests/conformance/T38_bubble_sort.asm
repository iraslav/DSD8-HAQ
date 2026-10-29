; T38 -- bubble sort of eight bytes held in data memory (group T6; spec Appendix B.3)
; The harness cannot preload DMEM, so a prologue stores 5 3 9 1 7 2 8 4 into
; DMEM[0..7] first; the sort itself is Appendix B.3 verbatim. An epilogue
; loads DMEM[0..7] back so the sorted order appears as eight LD lines and
; shows DMEM[0] (smallest) and DMEM[7] (largest) on the LEDs / 7-seg.
; Expected: DMEM[0..7] = 1 2 3 4 5 7 8 9.
        LDI  R1, 0
        LDI  R7, 1
        LDI  R2, 5
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 3
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 9
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 1
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 7
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 2
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 8
        ST   [R1], R2
        ADD  R1, R1, R7
        LDI  R2, 4
        ST   [R1], R2
; ---- Appendix B.3 ----
        LDI  R1, 8          ; n
        LDI  R7, 1          ; the constant 1
OUTER:  LDI  R2, 0          ; i = 0
        LDI  R6, 0          ; "a swap happened" flag
INNER:  MOV  R3, R2         ; assembles to OR R3, R2, R2
        ADD  R4, R3, R7     ; R4 = i + 1
        CMP  R4, R1
        BCS  ENDIN          ; i+1 >= n, so this pass is finished
        LD   R5, [R3]       ; a[i]
        LD   R0, [R4]       ; a[i+1]
        CMP  R5, R0
        BCC  NOSWAP         ; a[i] < a[i+1], already in order
        BEQ  NOSWAP         ; equal, nothing to do
        ST   [R3], R0       ; swap them
        ST   [R4], R5
        LDI  R6, 1
NOSWAP: ADD  R2, R2, R7
        JMP  INNER
ENDIN:  LDI  R0, 0
        CMP  R6, R0
        BNE  OUTER          ; repeat while any swap occurred
; ---- epilogue: read the sorted array back ----
        LDI  R2, 0
CHECK:  LD   R5, [R2]
        ADD  R2, R2, R7
        CMP  R2, R1
        BNE  CHECK
        LDI  R2, 0
        LD   R3, [R2]
        OUT  0x02, R3       ; LEDs = smallest (1)
        OUT  0x10, R5       ; 7-seg = largest (9)
        LDI  R4, 0x01
        OUT  0x11, R4
        HLT
