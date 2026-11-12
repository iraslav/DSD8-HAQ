; T29 -- signed ordering built from N and V (group T4, spec 3.3 callout)
; a <s b is true exactly when N != V after CMP a, b. For each pair the result
; (1 = less, 0 = not less) is stored to DMEM[i] so it appears as a store line.
; Expected DMEM[0..7] = 1 0 1 0 0 1 0 0
        LDI  R5, 0          ; result address
        LDI  R4, 1
        LDI  R1, 0x80       ; -128
        LDI  R2, 0x7F       ; 127
        CMP  R1, R2
        BVS  OVF0
        BMI  LT0         ; V=0: less iff N=1
        JMP  GE0
OVF0:   BPL  LT0         ; V=1: less iff N=0
        JMP  GE0
LT0:    LDI  R6, 1
        JMP  ST0
GE0:    LDI  R6, 0
ST0:    ST   [R5], R6
        ADD  R5, R5, R4
        LDI  R1, 0x7F       ; 127
        LDI  R2, 0x80       ; -128
        CMP  R1, R2
        BVS  OVF1
        BMI  LT1         ; V=0: less iff N=1
        JMP  GE1
OVF1:   BPL  LT1         ; V=1: less iff N=0
        JMP  GE1
LT1:    LDI  R6, 1
        JMP  ST1
GE1:    LDI  R6, 0
ST1:    ST   [R5], R6
        ADD  R5, R5, R4
        LDI  R1, 0xFF       ; -1
        LDI  R2, 0x01       ; 1
        CMP  R1, R2
        BVS  OVF2
        BMI  LT2         ; V=0: less iff N=1
        JMP  GE2
OVF2:   BPL  LT2         ; V=1: less iff N=0
        JMP  GE2
LT2:    LDI  R6, 1
        JMP  ST2
GE2:    LDI  R6, 0
ST2:    ST   [R5], R6
        ADD  R5, R5, R4
        LDI  R1, 0x01       ; 1
        LDI  R2, 0xFF       ; -1
        CMP  R1, R2
        BVS  OVF3
        BMI  LT3         ; V=0: less iff N=1
        JMP  GE3
OVF3:   BPL  LT3         ; V=1: less iff N=0
        JMP  GE3
LT3:    LDI  R6, 1
        JMP  ST3
GE3:    LDI  R6, 0
ST3:    ST   [R5], R6
        ADD  R5, R5, R4
        LDI  R1, 0x05       ; 5
        LDI  R2, 0x05       ; 5
        CMP  R1, R2
        BVS  OVF4
        BMI  LT4         ; V=0: less iff N=1
        JMP  GE4
OVF4:   BPL  LT4         ; V=1: less iff N=0
        JMP  GE4
LT4:    LDI  R6, 1
        JMP  ST4
GE4:    LDI  R6, 0
ST4:    ST   [R5], R6
        ADD  R5, R5, R4
        LDI  R1, 0x90       ; -112
        LDI  R2, 0xA0       ; -96
        CMP  R1, R2
        BVS  OVF5
        BMI  LT5         ; V=0: less iff N=1
        JMP  GE5
OVF5:   BPL  LT5         ; V=1: less iff N=0
        JMP  GE5
LT5:    LDI  R6, 1
        JMP  ST5
GE5:    LDI  R6, 0
ST5:    ST   [R5], R6
        ADD  R5, R5, R4
        LDI  R1, 0xA0       ; -96
        LDI  R2, 0x90       ; -112
        CMP  R1, R2
        BVS  OVF6
        BMI  LT6         ; V=0: less iff N=1
        JMP  GE6
OVF6:   BPL  LT6         ; V=1: less iff N=0
        JMP  GE6
LT6:    LDI  R6, 1
        JMP  ST6
GE6:    LDI  R6, 0
ST6:    ST   [R5], R6
        ADD  R5, R5, R4
        LDI  R1, 0x40       ; 64
        LDI  R2, 0xC0       ; -64
        CMP  R1, R2
        BVS  OVF7
        BMI  LT7         ; V=0: less iff N=1
        JMP  GE7
OVF7:   BPL  LT7         ; V=1: less iff N=0
        JMP  GE7
LT7:    LDI  R6, 1
        JMP  ST7
GE7:    LDI  R6, 0
ST7:    ST   [R5], R6
        ADD  R5, R5, R4
        HLT
