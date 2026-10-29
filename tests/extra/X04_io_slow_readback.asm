; X04 -- switches -> LEDs, SLOW_ECHO write then read back (guide slide 53)
; (harness switches = 0x00). Expected: R3 = 5A, LEDs = 0x01.
        IN   R1, 0x00
        OUT  0x02, R1
        LDI  R2, 0x5A
        OUT  0x40, R2
        IN   R3, 0x40
        CMP  R3, R2
        BNE  FAIL
        LDI  R7, 0x01
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
