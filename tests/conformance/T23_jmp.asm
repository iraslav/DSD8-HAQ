; T23 -- JMP forwards, backwards, to address 0x000 and to the last used address (group T4)
; Third bring-up test: proves the branch path into the PC.
; Path: 000..005 -> FWD (forward) -> BACK (backward) -> 0x000 (second visit)
;       -> LAST (forward to the last used address) -> HLT.
; Lines at addresses SKIPn must never appear in the trace.
        LDI  R1, 1          ; 000
        ADD  R7, R7, R1     ; 001  visit counter (R7 = 0 at reset)
        LDI  R2, 2          ; 002
        CMP  R7, R2         ; 003
        BEQ  TOLAST         ; 004  second visit -> jump to the end
        JMP  FWD            ; 005  forwards
SKIP1:  LDI  R5, 0xEE       ; 006  never executed
BACK:   LDI  R4, 0xBB       ; 007  reached by a backward jump
        JMP  0x000          ; 008  jump to address zero
SKIP2:  LDI  R5, 0xEE       ; 009  never executed
FWD:    LDI  R3, 0xAA       ; 00A
        JMP  BACK           ; 00B  backwards
TOLAST: JMP  LAST           ; 00C  forwards to the last used address
SKIP3:  LDI  R5, 0xEE       ; 00D  never executed
        LDI  R5, 0xEE       ; 00E  never executed
LAST:   HLT                 ; 00F  last used address
