; T13 -- a walking-ones pattern written across all 256 locations and read back (group T2)
; DMEM[a] = 1 << (a mod 8). Write pass, then read pass counting mismatches in R7.
; Expected: R7 = 0 at the end; LEDs = 0x00 (error count).
        LDI  R1, 0          ; address
        LDI  R2, 1          ; pattern
        LDI  R3, 1          ; constant 1
WLOOP:  ST   [R1], R2
        SHL  R2, R2         ; Z=1 once the one has walked out of bit 7
        BNE  WNEXT
        LDI  R2, 1
WNEXT:  ADD  R1, R1, R3     ; Z=1 when the address wraps to 0
        BNE  WLOOP
        LDI  R2, 1
        LDI  R7, 0          ; error count
RLOOP:  LD   R4, [R1]
        CMP  R4, R2
        BEQ  ROK
        ADD  R7, R7, R3
ROK:    SHL  R2, R2
        BNE  RNEXT
        LDI  R2, 1
RNEXT:  ADD  R1, R1, R3
        BNE  RLOOP
        OUT  0x02, R7
        HLT
