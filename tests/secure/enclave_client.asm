; enclave_client.asm -- processor B of dsd8_secure_top (initiator / verifier)
; See enclave_server.asm for the whole protocol.
; The 8 challenges 0x4Axx have maximal multiplicative order modulo BOTH
; moduli, and scripts/check_enclave_keys.py proves exhaustively that no
; combination of wrong key bytes (256 x 128) passes the check for any of them.
; B's display: mismatch -> LEDs = failed attempts, 7-seg "EE"; press BTNC to
; retry (e.g. after correcting a key). Match -> LEDs = 0xFF (channel open),
; 7-seg = last data byte received from A.
; DMEM[0..7] challenge low bytes, [0x11] current challenge, [0x20..] data from A.
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
        LDI  R6, 0x01       ; rx_valid mask, constant 1, BTNC mask
        LDI  R0, 0
        LDI  R1, 0x0B
        ST   [R0], R1
        ADD  R0, R0, R6
        LDI  R1, 0x11
        ST   [R0], R1
        ADD  R0, R0, R6
        LDI  R1, 0x19
        ST   [R0], R1
        ADD  R0, R0, R6
        LDI  R1, 0x28
        ST   [R0], R1
        ADD  R0, R0, R6
        LDI  R1, 0x38
        ST   [R0], R1
        ADD  R0, R0, R6
        LDI  R1, 0x54
        ST   [R0], R1
        ADD  R0, R0, R6
        LDI  R1, 0x6C
        ST   [R0], R1
        ADD  R0, R0, R6
        LDI  R1, 0x72
        ST   [R0], R1
        ADD  R0, R0, R6
        LDI  R1, 0x87
        OUT  0x52, R1       ; own N = 0xD987
        LDI  R1, 0xD9
        OUT  0x53, R1
        LDI  R1, 0x13
        OUT  0x54, R1       ; own E = 0x0013
        LDI  R1, 0x00
        OUT  0x55, R1
        LDI  R1, 0x66
        OUT  0x57, R1       ; own D_HI (write-only); D_LO comes from the switches
; ---- 1. exchange public keys (A sends first) ----
QK0: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  QK0            ; wait for rx_valid
        IN   R1, 0x61
        OUT  0x5C, R1       ; peer (A) public key
QK1: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  QK1            ; wait for rx_valid
        IN   R1, 0x61
        OUT  0x5D, R1       ; peer (A) public key
QK2: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  QK2            ; wait for rx_valid
        IN   R1, 0x61
        OUT  0x5E, R1       ; peer (A) public key
QK3: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  QK3            ; wait for rx_valid
        IN   R1, 0x61
        OUT  0x5F, R1       ; peer (A) public key
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
        LDI  R7, 0          ; failed attempts
; ---- 2. key verification ----
ATTEMPT: LDI R1, 0x07
        AND  R1, R7, R1     ; challenge index = attempts mod 8
        LD   R1, [R1]
        LDI  R0, 0x11
        ST   [R0], R1       ; remember the challenge low byte
        LDI  R4, 0x4A       ; challenge high byte
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x03
        OUT  0x58, R1       ; ENCRYPT_PEER: with the other processor's public key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
C1L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  C1L            ; wait while tx_full
        OUT  0x60, R1
C1H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  C1H            ; wait while tx_full
        OUT  0x60, R4
C2L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  C2L            ; wait for rx_valid
        IN   R1, 0x61
C2H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  C2H            ; wait for rx_valid
        IN   R4, 0x61
        IN   R0, 0x00       ; programmable private-key byte (SW8-SW14)
        OUT  0x56, R0       ; own D_LO
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x02
        OUT  0x58, R1       ; DECRYPT: with this processor's private key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
        LDI  R2, 0x4A
        CMP  R4, R2         ; challenge high byte back?
        BNE  BAD
        LDI  R2, 0x11
        LD   R2, [R2]
        CMP  R1, R2         ; challenge low byte back?
        BNE  BAD
; ---- keys match: tell A (encrypted) and open the channel ----
        LDI  R1, 0x0D
        LDI  R4, 0x60       ; verdict 0x600D
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x03
        OUT  0x58, R1       ; ENCRYPT_PEER: with the other processor's public key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
VGL: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  VGL            ; wait while tx_full
        OUT  0x60, R1
VGH: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  VGH            ; wait while tx_full
        OUT  0x60, R4
        JMP  OPEN
; ---- keys do not match ----
BAD:    LDI  R1, 0xAD
        LDI  R4, 0x0B       ; verdict 0x0BAD
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x03
        OUT  0x58, R1       ; ENCRYPT_PEER: with the other processor's public key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
VBL: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  VBL            ; wait while tx_full
        OUT  0x60, R1
VBH: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  VBH            ; wait while tx_full
        OUT  0x60, R4
        ADD  R7, R7, R6
        OUT  0x02, R7       ; LEDs: failed attempts
        LDI  R1, 0xEE
        OUT  0x10, R1       ; 7-seg "EE": keys do not match, channel closed
        LDI  R1, 0x03
        OUT  0x11, R1
WAITP:  IN   R1, 0x01       ; wait for BTNC (buttons bit 0) to be pressed ...
        AND  R1, R1, R6
        BEQ  WAITP
WAITR:  IN   R1, 0x01       ; ... and released
        AND  R1, R1, R6
        BNE  WAITR
        JMP  ATTEMPT
; ---- 3. secure channel open ----
OPEN:   LDI  R1, 0xFF
        OUT  0x02, R1       ; LEDs: all on = keys match, channel open
        LDI  R1, 0x03
        OUT  0x11, R1
DA0L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  DA0L            ; wait for rx_valid
        IN   R1, 0x61
DA0H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  DA0H            ; wait for rx_valid
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
        OUT  0x10, R1       ; 7-seg: data byte received from A
DA1L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  DA1L            ; wait for rx_valid
        IN   R1, 0x61
DA1H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R6
        BEQ  DA1H            ; wait for rx_valid
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
        OUT  0x10, R1       ; 7-seg: data byte received from A
        LDI  R1, 0x4B
        LDI  R4, 0x4F       ; plaintext word 0: "OK"
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x03
        OUT  0x58, R1       ; ENCRYPT_PEER: with the other processor's public key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
DB0L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  DB0L            ; wait while tx_full
        OUT  0x60, R1
DB0H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  DB0H            ; wait while tx_full
        OUT  0x60, R4
        LDI  R1, 0x21
        LDI  R4, 0x21       ; plaintext word 1: "!!"
        OUT  0x50, R1
        OUT  0x51, R4
        LDI  R1, 0x03
        OUT  0x58, R1       ; ENCRYPT_PEER: with the other processor's public key
        IN   R1, 0x5A       ; RES_LO (stalls until the enclave is done)
        IN   R4, 0x5B       ; RES_HI
DB1L: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  DB1L            ; wait while tx_full
        OUT  0x60, R1
DB1H: IN   R2, 0x62        ; mailbox STATUS
        AND  R3, R2, R5
        BNE  DB1H            ; wait while tx_full
        OUT  0x60, R4
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
