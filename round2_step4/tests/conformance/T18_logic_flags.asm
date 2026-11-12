; T18 -- AND, OR, XOR clear C and V and set Z and N from the result (group T3)
; Before each logic op, 80+80 sets C=1 V=1 Z=1; the logic op must clear C and V.
; Expected: AND F0&0F=00 1000; OR F0|0F=FF 0100; XOR AA^55=FF 0100;
;           XOR AA^AA=00 1000; AND F0&80=80 0100; OR 01|02=03 0000.
        LDI  R1, 0x80
        LDI  R2, 0xF0
        LDI  R3, 0x0F
        ADD  R0, R1, R1
        AND  R4, R2, R3
        ADD  R0, R1, R1
        OR   R4, R2, R3
        LDI  R5, 0xAA
        LDI  R6, 0x55
        ADD  R0, R1, R1
        XOR  R4, R5, R6
        ADD  R0, R1, R1
        XOR  R4, R5, R5
        ADD  R0, R1, R1
        AND  R4, R2, R1
        LDI  R5, 0x01
        LDI  R6, 0x02
        ADD  R0, R1, R1
        OR   R4, R5, R6
        HLT
