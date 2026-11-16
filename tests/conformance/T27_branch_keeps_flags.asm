; T27 -- branches do not modify flags: branch, then branch again on the same condition (group T4)
; Expected: flags field unchanged across every branch line; LEDs = 0x01.
        LDI  R1, 0x80
        LDI  R2, 0x01
        CMP  R1, R2         ; 80-01 = 7F: Z=0 N=0 C=1 V=1
        BVS  A1             ; taken
        JMP  FAIL
A1:     BVS  A2             ; taken again -- V still 1
        JMP  FAIL
A2:     BEQ  FAIL           ; not taken
        BEQ  FAIL           ; still not taken
        BCS  A3
        JMP  FAIL
A3:     BCS  A4
        JMP  FAIL
A4:     BMI  FAIL
        BMI  FAIL
        LDI  R7, 0x01
        OUT  0x02, R7
        HLT
FAIL:   LDI  R7, 0xEE
        OUT  0x02, R7
        HLT
