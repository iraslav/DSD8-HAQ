; T26 -- a branch to itself, executed once then escaped (group T4)
; Each SELFn branches to its own address with a condition that is false,
; so it executes exactly once and falls through. If the condition were
; (wrongly) taken, the machine would spin forever on that address.
        LDI  R1, 7
        CMP  R1, R1         ; Z=1 N=0 C=1 V=0
SELF1:  BNE  SELF1
SELF2:  BCC  SELF2
SELF3:  BMI  SELF3
SELF4:  BVS  SELF4
        LDI  R2, 8
        CMP  R1, R2         ; 7-8: Z=0 N=1 C=0 V=0
SELF5:  BEQ  SELF5
SELF6:  BCS  SELF6
SELF7:  BPL  SELF7
        LDI  R7, 0x01
        OUT  0x02, R7
        HLT
