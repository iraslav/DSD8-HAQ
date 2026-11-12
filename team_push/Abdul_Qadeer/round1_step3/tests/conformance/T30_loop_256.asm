; T30 -- a loop that executes exactly 256 times and terminates (group T4)
; R1 counts 1, 2, ... 255, 0: ADD sets Z on the 256th iteration and BNE falls through.
; R3 counts completed blocks of 64 iterations and stores the count each time.
; Expected: 256 iterations, R1 = 0 at exit, R3 = 4, last store writes 04 to DMEM[F0].
        LDI  R1, 0
        LDI  R2, 1
        LDI  R3, 0          ; completed blocks of 64
        LDI  R4, 0x3F
        LDI  R5, 0xF0
LOOP:   ADD  R1, R1, R2
        AND  R6, R1, R4     ; Z=1 every 64th iteration
        BNE  NEXT
        ADD  R3, R3, R2
        ST   [R5], R3
NEXT:   CMP  R1, R0         ; R0 = 0: Z=1 only when R1 wrapped to 0
        BNE  LOOP
        HLT
