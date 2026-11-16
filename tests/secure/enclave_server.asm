; enclave_server.asm -- processor A of dsd8_secure_top (responder)
; Secure two-way channel between two DSD-8 processors, each with an RSA enclave.
;   A's key: N = 0xEC4B, E = 0x0011, D = 0xA571  (D_LO from switches SW0-SW7: correct 0x71)
;   B's key: N = 0xD987, E = 0x0013, D = 0x662B  (D_LO from switches SW8-SW14: correct 0x2B)
; Everything after the public-key exchange is ENCRYPTED on the mailbox:
;   1. A -> B  A's public key (plain: public)     B -> A  B's public key (plain: public)
;   2. B -> A  Enc_A(challenge)
;      A -> B  Enc_B(Dec_A(...))       re-encrypted for B, never plaintext
;      B -> A  Enc_A(verdict)          0x600D = keys match, 0x0BAD = no match
;      (repeated, B decides when to retry, until the keys match)
;   3. channel open -- data, encrypted for the receiver:
;      A -> B  Enc_B("DS"), Enc_B("D8")      B decrypts and shows it
;      B -> A  Enc_A("OK"), Enc_A("!!")      A decrypts and shows it
; A's LEDs: verification rounds served, then the last word received (low 7 bits).
;; >>> MODE CHECK
; ---- MODE SELECTOR: enclave STATUS bit 4 = 1 -> DEBUG mode ----
        IN   R1, 0x59
        LDI  R2, 0x10
        AND  R3, R1, R2
        BEQ  SECURE
        JMP  DEBUG
SECURE: NOP          ; ---- secure communication mode ----
;; <<< MODE CHECK
        LDI  R5, 0x02       ; tx_full mask
        LDI  R6, 0x01       ; rx_valid mask, constant 1
        LDI  R7, 0          ; rounds served
        LDI  R1, 0x4B
        OUT  0x52, R1       ; own N
        LDI  R1, 0xEC
        OUT  0x53, R1
        LDI  R1, 0x11
        OUT  0x54, R1       ; own E
        LDI  R1, 0x00
        OUT  0x55, R1
        LDI  R1, 0xA5
        OUT  0x57, R1       ; own D_HI (write-only); D_LO comes from the switches
; ---- 1. exchange public keys ----
        IN   R1, 0x52
PK0: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  PK0            ; wait while tx_full
        OUT  0x60, R1
        IN   R1, 0x53
PK1: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  PK1            ; wait while tx_full
        OUT  0x60, R1
        IN   R1, 0x54
PK2: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  PK2            ; wait while tx_full
        OUT  0x60, R1
        IN   R1, 0x55
PK3: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  PK3            ; wait while tx_full
        OUT  0x60, R1
QK0: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  QK0            ; wait for rx_valid
        IN   R1, 0x61
        OUT  0x5C, R1       ; peer (B) public key
QK1: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  QK1            ; wait for rx_valid
        IN   R1, 0x61
        OUT  0x5D, R1       ; peer (B) public key
QK2: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  QK2            ; wait for rx_valid
        IN   R1, 0x61
        OUT  0x5E, R1       ; peer (B) public key
QK3: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  QK3            ; wait for rx_valid
        IN   R1, 0x61
        OUT  0x5F, R1       ; peer (B) public key
; ---- 2. key verification rounds ----
ROUND:  NOP
C1L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  C1L            ; wait for rx_valid
        IN   R1, 0x61
C1H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  C1H            ; wait for rx_valid
        IN   R4, 0x61
        IN   R0, 0x00       ; programmable private-key byte (SW0-SW7)
        OUT  0x56, R0       ; own D_LO
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x02
        OUT  0x58, R1       ; DECRYPT: with this processor's private key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x03
        OUT  0x58, R1       ; ENCRYPT_PEER: with the other processor's public key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
C2L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  C2L            ; wait while tx_full
        OUT  0x60, R1
C2H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  C2H            ; wait while tx_full
        OUT  0x60, R4
        ADD  R7, R7, R6
        OUT  0x02, R7       ; LEDs: rounds served
VL: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  VL            ; wait for rx_valid
        IN   R1, 0x61
VH: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  VH            ; wait for rx_valid
        IN   R4, 0x61
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x02
        OUT  0x58, R1       ; DECRYPT: with this processor's private key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
        LDI  R2, 0x60       ; verdict must decrypt to 0x600D
        CMP  R4, R2
        BNE  ROUND
        LDI  R2, 0x0D
        CMP  R1, R2
        BNE  ROUND
; ---- 3. secure channel open: send A's data, encrypted for B ----
        LDI  R1, 0x53
        LDI  R4, 0x44       ; plaintext word 0: "DS"
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x03
        OUT  0x58, R1       ; ENCRYPT_PEER: with the other processor's public key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
DA0L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  DA0L            ; wait while tx_full
        OUT  0x60, R1
DA0H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  DA0H            ; wait while tx_full
        OUT  0x60, R4
        LDI  R1, 0x38
        LDI  R4, 0x44       ; plaintext word 1: "D8"
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x03
        OUT  0x58, R1       ; ENCRYPT_PEER: with the other processor's public key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
DA1L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  DA1L            ; wait while tx_full
        OUT  0x60, R1
DA1H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  DA1H            ; wait while tx_full
        OUT  0x60, R4
; ---- receive B's data, decrypt, store at DMEM[0x20..], show ----
DB0L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  DB0L            ; wait for rx_valid
        IN   R1, 0x61
DB0H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  DB0H            ; wait for rx_valid
        IN   R4, 0x61
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x02
        OUT  0x58, R1       ; DECRYPT: with this processor's private key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
        LDI  R0, 0x20
        ST   [R0], R1
        LDI  R0, 0x21
        ST   [R0], R4
        OUT  0x02, R1       ; LEDs: last word received (low byte)
DB1L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  DB1L            ; wait for rx_valid
        IN   R1, 0x61
DB1H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  DB1H            ; wait for rx_valid
        IN   R4, 0x61
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x02
        OUT  0x58, R1       ; DECRYPT: with this processor's private key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
        LDI  R0, 0x22
        ST   [R0], R1
        LDI  R0, 0x23
        ST   [R0], R4
        OUT  0x02, R1       ; LEDs: last word received (low byte)
        HLT
;; >>> DEBUG SESSION
; ======================= DEBUG MODE SESSION =======================
; (generated by scripts/gen_debug_session.py -- edit there)
DEBUG:  LDI  R6, 1
        LDI  R7, 0          ; one bit per passed debug check
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
; bit 0: DEBUG mode -> the (debug) private key can be read back
        IN   R1, 0x56
        LDI  R2, 0x71
        CMP  R1, R2
        BNE  DBC1
        IN   R1, 0x57
        LDI  R2, 0xA5
        CMP  R1, R2
        BNE  DBC1
        LDI  R2, 0x01
        OR   R7, R7, R2
; bit 1: built-in self-test, 8 known-answer test cases
DBC1:   NOP
        LDI  R1, 0x08
        OUT  0x70, R1
        LDI  R0, 0
DBW1:  IN   R1, 0x71
        LDI  R2, 0x80
        AND  R3, R1, R2
        CMP  R3, R2
        BEQ  DBK2
        NOP
        NOP
        SUB  R0, R0, R6
        BNE  DBW1
        JMP  DBC2
DBK2:  NOP
        IN   R1, 0x7D
        LDI  R2, 0xFF
        CMP  R1, R2
        BNE  DBC2
        LDI  R2, 0x02
        OR   R7, R7, R2
; bit 2: breakpoint when 8 exponent bits are left; inspect res and bits_left
DBC2:   NOP
        LDI  R1, 0x08
        OUT  0x73, R1
        LDI  R1, 0x01
        OUT  0x72, R1
        LDI  R1, 0x0B
        OUT  0x50, R1
        LDI  R1, 0x4A
        OUT  0x51, R1
        LDI  R1, 0x01
        OUT  0x58, R1
        LDI  R0, 0
DBW3:  IN   R1, 0x71
        LDI  R2, 0x14
        AND  R3, R1, R2
        CMP  R3, R2
        BEQ  DBK4
        NOP
        NOP
        SUB  R0, R0, R6
        BNE  DBW3
        JMP  DBC3
DBK4:  NOP
        LDI  R1, 0x03
        OUT  0x76, R1
        IN   R1, 0x77
        LDI  R2, 0x04
        CMP  R1, R2
        BNE  DBC3
        IN   R1, 0x78
        LDI  R2, 0x84
        CMP  R1, R2
        BNE  DBC3
        LDI  R1, 0x01
        OUT  0x76, R1
        IN   R1, 0x77
        LDI  R2, 0x08
        CMP  R1, R2
        BNE  DBC3
        LDI  R2, 0x04
        OR   R7, R7, R2
; bit 3: single-step three times = three engine cycles
DBC3:   NOP
        LDI  R1, 0x0A
        OUT  0x76, R1
        IN   R4, 0x77       ; cycle counter before
        LDI  R1, 0x04
        OUT  0x70, R1
        OUT  0x70, R1
        OUT  0x70, R1
        IN   R1, 0x77
        LDI  R2, 3
        ADD  R4, R4, R2
        CMP  R1, R4
        BNE  DBC4
        LDI  R2, 0x08
        OR   R7, R7, R2
; bit 4: remove the breakpoint, resume, check result and cycle count
DBC4:   NOP
        LDI  R1, 0x00
        OUT  0x72, R1
        LDI  R1, 0x02
        OUT  0x70, R1
        LDI  R0, 0
DBW5:  IN   R1, 0x59
        LDI  R2, 0x02
        AND  R3, R1, R2
        CMP  R3, R2
        BEQ  DBK6
        NOP
        NOP
        SUB  R0, R0, R6
        BNE  DBW5
        JMP  DBC5
DBK6:  NOP
        IN   R1, 0x5A
        LDI  R2, 0x04
        CMP  R1, R2
        BNE  DBC5
        IN   R1, 0x5B
        LDI  R2, 0x84
        CMP  R1, R2
        BNE  DBC5
        LDI  R1, 0x0A
        OUT  0x76, R1
        IN   R1, 0x77
        LDI  R2, 0x31
        CMP  R1, R2
        BNE  DBC5
        IN   R1, 0x78
        LDI  R2, 0x01
        CMP  R1, R2
        BNE  DBC5
        LDI  R2, 0x10
        OR   R7, R7, R2
; bit 5: trace buffer of multiply results
DBC5:   NOP
        IN   R1, 0x7C
        LDI  R2, 0x12
        CMP  R1, R2
        BNE  DBC6
        LDI  R1, 0x01
        OUT  0x79, R1
        IN   R1, 0x7A
        LDI  R2, 0x3D
        CMP  R1, R2
        BNE  DBC6
        IN   R1, 0x7B
        LDI  R2, 0x67
        CMP  R1, R2
        BNE  DBC6
        LDI  R2, 0x20
        OR   R7, R7, R2
; bit 6: watchpoint -- halt when a multiply writes res = 8404
DBC6:   NOP
        LDI  R1, 0x04
        OUT  0x74, R1
        LDI  R1, 0x84
        OUT  0x75, R1
        LDI  R1, 0x02
        OUT  0x72, R1
        LDI  R1, 0x0B
        OUT  0x50, R1
        LDI  R1, 0x4A
        OUT  0x51, R1
        LDI  R1, 0x01
        OUT  0x58, R1
        LDI  R0, 0
DBW7:  IN   R1, 0x71
        LDI  R2, 0x24
        AND  R3, R1, R2
        CMP  R3, R2
        BEQ  DBK8
        NOP
        NOP
        SUB  R0, R0, R6
        BNE  DBW7
        JMP  DBC7
DBK8:  NOP
        LDI  R1, 0x01
        OUT  0x76, R1
        IN   R1, 0x77
        LDI  R2, 0x0C
        CMP  R1, R2
        BNE  DBC7
        LDI  R1, 0x00
        OUT  0x72, R1
        LDI  R1, 0x02
        OUT  0x70, R1
        LDI  R0, 0
DBW9:  IN   R1, 0x59
        LDI  R2, 0x02
        AND  R3, R1, R2
        CMP  R3, R2
        BEQ  DBK10
        NOP
        NOP
        SUB  R0, R0, R6
        BNE  DBW9
        JMP  DBC7
DBK10:  NOP
        LDI  R2, 0x40
        OR   R7, R7, R2
; bit 7: inject a stuck-at fault -> self-test must FAIL; remove it -> PASS
DBC7:   NOP
        LDI  R1, 0x10
        OUT  0x72, R1
        LDI  R1, 0x08
        OUT  0x70, R1
        LDI  R0, 0
DBW11:  IN   R1, 0x71
        LDI  R2, 0x80
        AND  R3, R1, R2
        CMP  R3, R2
        BEQ  DBK12
        NOP
        NOP
        SUB  R0, R0, R6
        BNE  DBW11
        JMP  DBEND
DBK12:  NOP
        IN   R1, 0x7E
        LDI  R2, 0x00
        CMP  R1, R2
        BEQ  DBEND       ; fault not detected
        LDI  R1, 0x00
        OUT  0x72, R1
        LDI  R1, 0x08
        OUT  0x70, R1
        LDI  R0, 0
DBW13:  IN   R1, 0x71
        LDI  R2, 0x80
        AND  R3, R1, R2
        CMP  R3, R2
        BEQ  DBK14
        NOP
        NOP
        SUB  R0, R0, R6
        BNE  DBW13
        JMP  DBEND
DBK14:  NOP
        IN   R1, 0x7D
        LDI  R2, 0xFF
        CMP  R1, R2
        BNE  DBEND
        LDI  R2, 0x80
        OR   R7, R7, R2
; report: LEDs = passed checks (FF = debugger and enclave healthy), 7-seg 'dB'
DBEND:  OUT  0x02, R7
        LDI  R1, 0xDB
        OUT  0x10, R1
        LDI  R1, 0x03
        OUT  0x11, R1
        HLT
;; <<< DEBUG SESSION
