; X03 -- both sides of BCC / BCS after CMP with known operands (guide slide 52)
; Expected: 14 lines, ends at pc 00F with R7 = 02 (LEDs = 0x02).
        LDI  R7, 0
        LDI  R1, 1
        LDI  R2, 3
        LDI  R3, 5
        CMP  R2, R3
        BEQ  FAIL
        BCC  OK1
        JMP  FAIL
OK1:    ADD  R7, R7, R1
        CMP  R3, R2
        BCC  FAIL
        BCS  OK2
        JMP  FAIL
OK2:    ADD  R7, R7, R1
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
