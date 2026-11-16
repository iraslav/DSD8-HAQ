; T22 -- an arithmetic right shift constructed from the available instructions (group T3)
; ASR(x) = SHR(x) OR (x AND 0x80). Applied to A4 (-92) -> D2 (-46),
; 64 (100) -> 32 (50), FF (-1) -> FF (-1), 80 (-128) -> C0 (-64).
; Results stored to DMEM[0..3] so each is visible as a store line.
        LDI  R6, 0x80       ; sign mask
        LDI  R5, 0          ; result address
        LDI  R4, 1
        LDI  R1, 0xA4
        SHR  R2, R1
        AND  R3, R1, R6
        OR   R2, R2, R3
        ST   [R5], R2
        ADD  R5, R5, R4
        LDI  R1, 0x64
        SHR  R2, R1
        AND  R3, R1, R6
        OR   R2, R2, R3
        ST   [R5], R2
        ADD  R5, R5, R4
        LDI  R1, 0xFF
        SHR  R2, R1
        AND  R3, R1, R6
        OR   R2, R2, R3
        ST   [R5], R2
        ADD  R5, R5, R4
        LDI  R1, 0x80
        SHR  R2, R1
        AND  R3, R1, R6
        OR   R2, R2, R3
        ST   [R5], R2
        HLT
