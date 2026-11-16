; T05 -- NOP changes nothing at all (group T1). First bring-up test:
; proves fetch, the PC increment and the trace path before anything else.
; Expected: eight lines 0000 with all write fields zero and flags 0000,
; then the HLT line at pc 008.
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        HLT
