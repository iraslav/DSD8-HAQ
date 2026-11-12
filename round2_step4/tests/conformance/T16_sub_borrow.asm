; T16 -- SUB and the borrow convention: C=1 must mean NO borrow (group T3, spec 2.3.1)
; Expected (result, ZNCV): 5-3=02 0010; 3-5=FE 0100; 5-5=00 1010;
; 0-1=FF 0100; 80-01=7F 0011; 7F-FF=80 0101; FF-7F=80 0110.
        LDI  R1, 5
        LDI  R2, 3
        SUB  R3, R1, R2
        SUB  R3, R2, R1
        SUB  R3, R1, R1
        LDI  R4, 0
        LDI  R5, 1
        SUB  R6, R4, R5
        LDI  R4, 0x80
        SUB  R6, R4, R5
        LDI  R4, 0x7F
        LDI  R5, 0xFF
        SUB  R7, R4, R5
        SUB  R7, R5, R4
        HLT
