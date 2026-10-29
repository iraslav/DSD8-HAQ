; T34 -- the io_ready handshake: repeated access to SLOW_ECHO (port 0x40), which
; stalls 0-7 cycles (group T5, R11, R19). The CPU must wait and must not lose or
; duplicate a transfer: every value written is read back exactly, in order, and
; every IN/OUT produces exactly one trace line however long it stalled.
; 32 OUT/IN round trips with a changing value, then back-to-back OUTs and INs.
; Expected: R7 (error count) = 0, LEDs = 0x00.
        LDI  R1, 0x00       ; value
        LDI  R2, 0x25       ; increment (odd, so all 32 values differ)
        LDI  R3, 32         ; iterations
        LDI  R4, 1
        LDI  R7, 0          ; errors
LOOP:   OUT  0x40, R1
        IN   R5, 0x40
        CMP  R5, R1
        BEQ  OK
        ADD  R7, R7, R4
OK:     ADD  R1, R1, R2
        SUB  R3, R3, R4
        BNE  LOOP
        LDI  R1, 0x3C
        LDI  R2, 0xC3
        OUT  0x40, R1       ; back-to-back writes: the last one wins
        OUT  0x40, R2
        IN   R5, 0x40       ; back-to-back reads: same value twice
        IN   R6, 0x40
        CMP  R5, R2
        BEQ  OK2
        ADD  R7, R7, R4
OK2:    CMP  R6, R2
        BEQ  OK3
        ADD  R7, R7, R4
OK3:    OUT  0x02, R7
        HLT
