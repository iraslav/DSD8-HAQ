; T21 -- CMP sets flags and writes no register (group T3)
; Every CMP line must show rf fields 0 0 00. The registers are then read back
; with MOV to prove nothing was clobbered (including R0 = rd field of CMP).
; Expected CMP flags: 5:3 0010; 3:5 0100; 5:5 1010; 80:01 0011.
        LDI  R0, 0x42
        LDI  R1, 5
        LDI  R2, 3
        CMP  R1, R2
        CMP  R2, R1
        CMP  R1, R1
        LDI  R3, 0x80
        LDI  R4, 0x01
        CMP  R3, R4
        MOV  R0, R0         ; still 42
        MOV  R1, R1         ; still 05
        MOV  R2, R2         ; still 03
        MOV  R3, R3         ; still 80
        MOV  R4, R4         ; still 01
        HLT
