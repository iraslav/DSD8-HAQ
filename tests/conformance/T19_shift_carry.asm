; T19 -- SHL out of bit 7 into carry, and SHR out of bit 0 into carry (group T3)
; Expected (result, ZNCV): SHL 81=02 0010; SHL 40=80 0100; SHL 80=00 1010;
; SHR 81=40 0010; SHR 02=01 0000; SHR 01=00 1010. V is always 0.
        LDI  R1, 0x81
        SHL  R2, R1
        LDI  R1, 0x40
        SHL  R2, R1
        LDI  R1, 0x80
        SHL  R2, R1
        LDI  R1, 0x81
        SHR  R3, R1
        LDI  R1, 0x02
        SHR  R3, R1
        LDI  R1, 0x01
        SHR  R3, R1
        LDI  R4, 0x7F       ; 7F+01 sets V=1 ...
        LDI  R5, 0x01
        ADD  R6, R4, R5
        SHL  R6, R5         ; ... and a shift must clear it: 02 0000
        HLT
