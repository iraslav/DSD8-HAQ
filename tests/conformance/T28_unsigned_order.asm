; T28 -- unsigned ordering with BCS/BCC across 0x7F/0x80 (group T4)
; After CMP a,b: C=1 <=> a >= b unsigned. 0x80 > 0x7F unsigned (although
; negative when signed). R7 counts correct decisions: must end 6 (LEDs 0x06).
        LDI  R6, 1
        LDI  R7, 0
        LDI  R1, 0x80
        LDI  R2, 0x7F
        CMP  R1, R2         ; 80 >= 7F unsigned: C=1
        BCC  FAIL
        ADD  R7, R7, R6
        CMP  R2, R1         ; 7F < 80: C=0
        BCS  FAIL
        ADD  R7, R7, R6
        LDI  R3, 0xFF
        LDI  R4, 0x00
        CMP  R3, R4         ; FF >= 00: C=1
        BCC  FAIL
        ADD  R7, R7, R6
        CMP  R4, R3         ; 00 < FF: C=0
        BCS  FAIL
        ADD  R7, R7, R6
        CMP  R2, R2         ; equal: C=1 (>=)
        BCC  FAIL
        ADD  R7, R7, R6
        LDI  R5, 0x81
        CMP  R1, R5         ; 80 < 81: C=0
        BCS  FAIL
        ADD  R7, R7, R6
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
