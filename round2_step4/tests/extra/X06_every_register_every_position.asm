; X06 -- every register as rd, as rs1 and as rs2 (coverage checklist, guide slide 55)
; Registers hold distinct powers of two so every sum identifies its sources.
        LDI  R0, 0x01
        LDI  R1, 0x02
        LDI  R2, 0x04
        LDI  R3, 0x08
        LDI  R4, 0x10
        LDI  R5, 0x20
        LDI  R6, 0x40
        LDI  R7, 0x80
        ADD  R0, R1, R3
        ADD  R1, R2, R4
        ADD  R2, R3, R5
        ADD  R3, R4, R6
        ADD  R4, R5, R7
        ADD  R5, R6, R0
        ADD  R6, R7, R1
        ADD  R7, R0, R2
        LDI  R0, 0x01
        LDI  R1, 0x02
        LDI  R2, 0x04
        LDI  R3, 0x08
        LDI  R4, 0x10
        LDI  R5, 0x20
        LDI  R6, 0x40
        LDI  R7, 0x80
        OR   R5, R0, R2
        OR   R6, R1, R3
        OR   R7, R2, R4
        OR   R0, R3, R5
        OR   R1, R4, R6
        OR   R2, R5, R7
        OR   R3, R6, R0
        OR   R4, R7, R1
        XOR  R6, R4, R0
        XOR  R7, R5, R1
        XOR  R0, R6, R2
        XOR  R1, R7, R3
        XOR  R2, R0, R4
        XOR  R3, R1, R5
        XOR  R4, R2, R6
        XOR  R5, R3, R7
        CMP  R0, R1
        ST   [R0], R7
        LD   R2, [R0]
        CMP  R1, R2
        ST   [R1], R0
        LD   R3, [R1]
        CMP  R2, R3
        ST   [R2], R1
        LD   R4, [R2]
        CMP  R3, R4
        ST   [R3], R2
        LD   R5, [R3]
        CMP  R4, R5
        ST   [R4], R3
        LD   R6, [R4]
        CMP  R5, R6
        ST   [R5], R4
        LD   R7, [R5]
        CMP  R6, R7
        ST   [R6], R5
        LD   R0, [R6]
        CMP  R7, R0
        ST   [R7], R6
        LD   R1, [R7]
        HLT
