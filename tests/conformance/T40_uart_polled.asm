; T40 -- polled UART, scripted stimulus (group T6; spec Appendix B.4)
; DEVIATION, documented: the supplied reference peripheral model never has
; a received byte (UART_STATUS.rx_valid = 0 forever) and the harness stops a
; non-halting program at a cycle limit that the instruction-count-based
; golden model cannot reproduce. This bounded version therefore:
;   1. polls UART_STATUS a fixed 16 times with the B.4 idiom, echoing any
;      received byte to UART_TX (the receive path is never taken here);
;   2. transmits "Hi!" through UART_TX, polling tx_busy before each byte;
;   3. halts, so the trace is fully deterministic.
; Replace with the instructor's T40 when the official suite (and an RX
; stimulus driver) is distributed.
; Expected: three OUT 0x20 lines carrying 48 69 21, LEDs = 0x03.
        LDI  R2, 0x02       ; rx_valid mask
        LDI  R6, 0x01       ; tx_busy mask / constant 1
        LDI  R7, 16         ; poll budget
WAIT:   IN   R1, 0x22       ; UART status
        AND  R3, R1, R2     ; Z set if rx_valid clear
        BEQ  NORX
        IN   R4, 0x21       ; take the received byte
        OUT  0x20, R4       ; echo it straight back
NORX:   SUB  R7, R7, R6
        BNE  WAIT
        LDI  R5, 0          ; bytes sent
        LDI  R4, 0x48       ; 'H'
TX1:    IN   R1, 0x22
        AND  R3, R1, R6
        BNE  TX1            ; wait while tx_busy
        OUT  0x20, R4
        ADD  R5, R5, R6
        LDI  R4, 0x69       ; 'i'
TX2:    IN   R1, 0x22
        AND  R3, R1, R6
        BNE  TX2
        OUT  0x20, R4
        ADD  R5, R5, R6
        LDI  R4, 0x21       ; '!'
TX3:    IN   R1, 0x22
        AND  R3, R1, R6
        BNE  TX3
        OUT  0x20, R4
        ADD  R5, R5, R6
        OUT  0x02, R5
        HLT
