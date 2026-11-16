; X02 -- never-written read, write, read back, top address (guide slide 52)
; Expected: LD [10] = 00; ST [10] <- A5; LD = A5; ST [FF] <- FF; LD = FF.
        LDI  R1, 0x10
        LD   R2, [R1]
        LDI  R3, 0xA5
        ST   [R1], R3
        LD   R4, [R1]
        LDI  R1, 0xFF
        ST   [R1], R1
        LD   R5, [R1]
        HLT
