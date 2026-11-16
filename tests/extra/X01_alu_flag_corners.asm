; X01 -- ALU flag corners, one corner per instruction (guide slide 51)
; Each ALU line writes a distinct value and shows its flags, so a wrong
; carry or overflow is pinned to one line. Expected (golden model):
; 7F+01=80 0101, FF+01=00 1010, 1-1=00 1010, 1-FF=02 0000, 80-1=7F 0011,
; SHR 80=40 0000, SHL 80=00 1010, HLT keeps 1010.
        LDI  R1, 0x7F
        LDI  R2, 0x01
        ADD  R3, R1, R2
        LDI  R4, 0xFF
        ADD  R5, R4, R2
        SUB  R6, R2, R2
        SUB  R6, R2, R4
        LDI  R7, 0x80
        SUB  R6, R7, R2
        SHR  R6, R7
        SHL  R6, R7
        HLT
