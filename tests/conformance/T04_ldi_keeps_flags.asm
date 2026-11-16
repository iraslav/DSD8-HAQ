; T04 -- LDI does not disturb the flags (group T1, R3)
; Set flags, LDI values that would set different flags if LDI touched them,
; then branch on the OLD flags. Verdict on LEDs: 0x01 pass, 0xEE fail.
        LDI  R1, 5
        LDI  R2, 5
        CMP  R1, R2         ; Z=1 N=0 C=1 V=0
        LDI  R3, 0x80       ; would give N=1, Z=0 if LDI set flags
        LDI  R4, 0x01
        BNE  FAIL           ; Z must still be 1
        BCC  FAIL           ; C must still be 1
        BMI  FAIL           ; N must still be 0
        LDI  R5, 0x01
        LDI  R6, 0x02
        CMP  R5, R6         ; 1-2 = FF: Z=0 N=1 C=0 V=0
        LDI  R3, 0x00       ; would give Z=1, N=0 if LDI set flags
        BEQ  FAIL
        BPL  FAIL
        BCS  FAIL
        LDI  R7, 0x01
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
