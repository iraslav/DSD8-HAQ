; T06 -- writing a register then immediately reading it as a source operand (group T1)
; Every instruction consumes the register written by the one before it.
; Expected: R2 = 0x0A, R4 = 0x02, R5 = 0x0C, DMEM[0x0C] = 0x0C, R6 = 0x0C.
        LDI  R1, 5
        ADD  R2, R1, R1     ; reads R1 the instruction after it was written
        LDI  R3, 7
        SUB  R4, R3, R1     ; 7 - 5 = 2
        ADD  R5, R4, R2     ; 2 + 10 = 12
        ST   [R5], R5       ; address and data both just written
        LD   R6, [R5]       ; read back immediately
        XOR  R7, R6, R5     ; 0x0C ^ 0x0C = 0, Z=1
        SHL  R7, R6         ; 0x18
        SHR  R0, R7         ; 0x0C
        HLT
