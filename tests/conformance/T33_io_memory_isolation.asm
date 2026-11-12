; T33 -- I/O does not disturb data memory, and data memory does not disturb I/O (group T5)
; Same numeric address/port 0x40 used in both spaces: DMEM[40] and SLOW_ECHO.
; Expected: LD DMEM[40] = 11 after OUT 0x40 = 22; IN 0x40 = 22 after ST DMEM[40] = 33.
        LDI  R1, 0x40
        LDI  R2, 0x11
        ST   [R1], R2       ; DMEM[40] = 11
        LDI  R3, 0x22
        OUT  0x40, R3       ; SLOW_ECHO = 22 (may stall)
        LD   R4, [R1]       ; 11, not 22
        LDI  R5, 0x33
        ST   [R1], R5       ; DMEM[40] = 33
        IN   R6, 0x40       ; 22, not 33
        LD   R7, [R1]       ; 33
        LDI  R0, 0x02
        OUT  0x02, R5       ; LEDs = 33
        LD   R0, [R0]       ; DMEM[02] still 00
        HLT
