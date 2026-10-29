; T09 -- reading never-written data memory: every location must read 0x00 (group T2, R6, R16)
; Loops over all 256 addresses with LD; each LD line must show rf_data 00.
; R4 accumulates the OR of everything read: must end 0x00. Verdict on LEDs.
        LDI  R1, 0          ; address
        LDI  R2, 1          ; constant 1
        LDI  R4, 0          ; OR accumulator
LOOP:   LD   R3, [R1]
        OR   R4, R4, R3
        ADD  R1, R1, R2     ; wraps 0xFF -> 0x00, Z=1 after 256 iterations
        BNE  LOOP
        LDI  R5, 0
        CMP  R4, R5
        BNE  FAIL
        LDI  R7, 0x01
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
