; T24 -- each of the eight branch conditions TAKEN (group T4)
; For each condition: CMP sets known flags, then the branch is executed.
; R7 counts conditions that behaved correctly; must end at 8 (LEDs = 0x08).
; Any wrong decision reaches FAIL (LEDs = 0xEE) -- visible in the pc field.
        LDI  R6, 1
        LDI  R7, 0
        LDI  R1, 0x05
        LDI  R2, 0x05
        CMP  R1, R2         ; Z=1 C=1
        BEQ  OK0
        JMP  FAIL
OK0:    ADD  R7, R7, R6
        LDI  R1, 0x06
        LDI  R2, 0x05
        CMP  R1, R2         ; Z=0 C=1
        BNE  OK1
        JMP  FAIL
OK1:    ADD  R7, R7, R6
        LDI  R1, 0x06
        LDI  R2, 0x05
        CMP  R1, R2         ; C=1
        BCS  OK2
        JMP  FAIL
OK2:    ADD  R7, R7, R6
        LDI  R1, 0x05
        LDI  R2, 0x06
        CMP  R1, R2         ; C=0 N=1
        BCC  OK3
        JMP  FAIL
OK3:    ADD  R7, R7, R6
        LDI  R1, 0x05
        LDI  R2, 0x06
        CMP  R1, R2         ; N=1
        BMI  OK4
        JMP  FAIL
OK4:    ADD  R7, R7, R6
        LDI  R1, 0x06
        LDI  R2, 0x05
        CMP  R1, R2         ; N=0
        BPL  OK5
        JMP  FAIL
OK5:    ADD  R7, R7, R6
        LDI  R1, 0x80
        LDI  R2, 0x01
        CMP  R1, R2         ; V=1 C=1
        BVS  OK6
        JMP  FAIL
OK6:    ADD  R7, R7, R6
        LDI  R1, 0x06
        LDI  R2, 0x05
        CMP  R1, R2         ; V=0
        BVC  OK7
        JMP  FAIL
OK7:    ADD  R7, R7, R6
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
