; T14 -- LD does not disturb the flags (group T2, R3, spec 2.3.3 callout)
; Load a non-zero byte after a CMP that set Z, and a zero byte after one that
; cleared it; the branches must test the OLD flags. Verdict on LEDs.
        LDI  R1, 0x10
        LDI  R2, 0x80
        ST   [R1], R2       ; DMEM[10] = 80 (non-zero, negative)
        LDI  R3, 9
        CMP  R3, R3         ; Z=1 N=0 C=1 V=0
        LD   R4, [R1]       ; 0x80 would give Z=0 N=1 if LD set flags
        BNE  FAIL
        BMI  FAIL
        LDI  R5, 0x20       ; DMEM[20] = 00 (never written)
        LDI  R6, 0x01
        CMP  R6, R3         ; 1-9: Z=0 N=1 C=0 V=0
        LD   R4, [R5]       ; 0x00 would give Z=1 N=0 if LD set flags
        BEQ  FAIL
        BPL  FAIL
        BCS  FAIL
        LDI  R7, 0x01
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
