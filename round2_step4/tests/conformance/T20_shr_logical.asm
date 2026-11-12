; T20 -- SHR is logical: shifting 0x80 gives 0x40, never 0xC0 (group T3)
; Expected: 80->40 0000; FF->7F 0010; C1->60 0010; 40->20 0000.
        LDI  R1, 0x80
        SHR  R2, R1
        LDI  R1, 0xFF
        SHR  R2, R1
        LDI  R1, 0xC1
        SHR  R2, R1
        SHR  R2, R2         ; 0x60 -> 0x30
        LDI  R1, 0x40
        SHR  R2, R1
        HLT
