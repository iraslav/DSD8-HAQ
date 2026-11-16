; S01_enclave_selftest.asm -- one DSD-8 + one rsa_enclave (tb/tb_rsa_cpu.v)
; Each check increments R7 first; on failure LEDs = R7 (0xE1.. = check number),
; on success LEDs = 0x01.
        LDI  R6, 1
        LDI  R7, 0xE0
        LDI  R1, 0x4B
        OUT  0x52, R1
        LDI  R1, 0xEC
        OUT  0x53, R1
        LDI  R1, 0x11
        OUT  0x54, R1
        LDI  R1, 0x00
        OUT  0x55, R1
        LDI  R1, 0x71
        OUT  0x56, R1
        LDI  R1, 0xA5
        OUT  0x57, R1
; E1: public modulus reads back
        ADD  R7, R7, R6
        IN   R1, 0x52
        LDI  R2, 0x4B
        CMP  R1, R2
        BNE  FAIL
        IN   R1, 0x53
        LDI  R2, 0xEC
        CMP  R1, R2
        BNE  FAIL
; E2: public exponent reads back
        ADD  R7, R7, R6
        IN   R1, 0x54
        LDI  R2, 0x11
        CMP  R1, R2
        BNE  FAIL
; E3: private exponent is write-only (reads 0x00)
        ADD  R7, R7, R6
        LDI  R2, 0x00
        IN   R1, 0x56
        CMP  R1, R2
        BNE  FAIL
        IN   R1, 0x57
        CMP  R1, R2
        BNE  FAIL
; E4: encrypt 0x4A01 -> 0x0F61
        ADD  R7, R7, R6
        LDI  R1, 0x01
        OUT  0x50, R1
        LDI  R1, 0x4A
        OUT  0x51, R1
        LDI  R1, 0x01
        OUT  0x58, R1
        IN   R1, 0x5A       ; stalls until done
        LDI  R2, 0x61
        CMP  R1, R2
        BNE  FAIL
        IN   R1, 0x5B
        LDI  R2, 0x0F
        CMP  R1, R2
        BNE  FAIL
; E5: status = done, not busy, no error
        ADD  R7, R7, R6
        IN   R1, 0x59
        LDI  R2, 0x02
        CMP  R1, R2
        BNE  FAIL
; E6: decrypt 0x0F61 -> 0x4A01
        ADD  R7, R7, R6
        LDI  R1, 0x61
        OUT  0x50, R1
        LDI  R1, 0x0F
        OUT  0x51, R1
        LDI  R1, 0x02
        OUT  0x58, R1
        IN   R1, 0x5A
        LDI  R2, 0x01
        CMP  R1, R2
        BNE  FAIL
        IN   R1, 0x5B
        LDI  R2, 0x4A
        CMP  R1, R2
        BNE  FAIL
; E7: a wrong private key (D_LO = 0x70) does NOT recover the message
        ADD  R7, R7, R6
        LDI  R1, 0x70
        OUT  0x56, R1
        LDI  R1, 0x02
        OUT  0x58, R1
        IN   R1, 0x5A
        IN   R2, 0x5B
        LDI  R3, 0x01
        CMP  R1, R3
        BNE  OK7
        LDI  R3, 0x4A
        CMP  R2, R3
        BEQ  FAIL
OK7:    LDI  R1, 0x71
        OUT  0x56, R1       ; restore the correct key
; E8: message >= modulus is rejected (status = error + done)
        ADD  R7, R7, R6
        LDI  R1, 0xFF
        OUT  0x50, R1
        OUT  0x51, R1
        LDI  R1, 0x01
        OUT  0x58, R1
        IN   R1, 0x5A
        IN   R1, 0x59
        LDI  R2, 0x06
        CMP  R1, R2
        BNE  FAIL
; E9: lock -- key writes ignored afterwards, status shows locked
        ADD  R7, R7, R6
        LDI  R1, 0x80
        OUT  0x58, R1
        LDI  R1, 0x00
        OUT  0x52, R1
        IN   R1, 0x52
        LDI  R2, 0x4B
        CMP  R1, R2
        BNE  FAIL
        IN   R1, 0x59
        LDI  R2, 0x0E
        CMP  R1, R2
        BNE  FAIL
PASS:   LDI  R7, 0x01
        OUT  0x02, R7
        HLT
FAIL:   OUT  0x02, R7
        HLT
