# Extension: RSA security enclave — secure channel or hardware debugger

## Mode selector

Every enclave has a **mode selector** with two options:

| Mode | How to select it on the board | What the enclave does |
|---|---|---|
| **SECURE COMMUNICATION** (default) | release reset (SW15 up) normally | Private key write-only, debugger locked out. The two processors verify each other's keys and then exchange **encrypted** data: the sender's enclave encrypts, the receiver's enclave decrypts. |
| **DEBUG** | **hold BTNU while sliding SW15 up**, then release BTNU | Debugger unlocked. Each processor runs a debug session on its own enclave (self-test cases, breakpoints, stepping, …) and reports the result. No secure communication takes place. |

The selector is a **boot strap**: it is sampled while reset is held and frozen
when reset is released. The mode can therefore only change through a reset,
and **reset clears every key**, so a private key loaded in SECURE mode can never
be seen by the debugger. Real secure chips use the same rule (debug only after
zeroisation). Both programs read the mode from STATUS bit 4 at start-up and
branch to the secure protocol or to the debug session.

# Part 1 — SECURE mode: encrypted channel between two DSD-8 processors

Two DSD-8 processors, each with its own **RSA security enclave**, talk through
a byte mailbox. **They only exchange data once both private keys are verified
to match their public keys**, and then **every message is encrypted by the
sender's enclave and decrypted by the receiver's enclave**, in both directions.

**Nothing frozen was changed.** The ISA, the eleven core modules, `dsd8_top`,
the harness and the 40 conformance tests are untouched, and all still pass.
The extension uses the I/O ports the spec leaves free for extensions (0x41–0xFF).

> Teaching demonstration only. 16-bit RSA keys can be factored instantly. The
> point is the structure: keys held in hardware, encryption co-processors, and
> a channel that opens only for matching keys.

## The two key pairs (programmable)

| | Processor A | Processor B |
|---|---|---|
| Modulus N | 0xEC4B (241 × 251) | 0xD987 (233 × 239) |
| Public exponent E | 0x0011 (17) | 0x0013 (19) |
| Private exponent D | 0xA571 | 0x662B |
| D high byte | fixed in A's program | fixed in B's program |
| **D low byte (programmable)** | **switches SW0–SW7**, correct **0x71** | **switches SW8–SW14**, correct **0x2B** |

Each processor re-reads its own switches before every decryption, so changing
a switch changes that processor's private key.

## What travels on the mailbox

```
  Processor A                                   Processor B
  -----------                                   -----------
1 public key N_A, E_A  ------ plaintext ----->  stores as peer key
  stores as peer key  <------ plaintext ------  public key N_B, E_B
                    (public keys are the ONLY plaintext ever sent)

2 key check (repeats until it passes; BTNC starts a new attempt)
                      <-- Enc_A(challenge) ---  B picks a challenge
  x = Dec_A(...)
  re-encrypt for B    --- Enc_B(x) ---------->  y = Dec_B(...)
                                                y == challenge ?  -> match
                      <-- Enc_A(0x600D) -----   "keys match"     (or Enc_A(0x0BAD))
  channel opens only if the verdict decrypts to 0x600D

3 channel open: data, always encrypted for the receiver
  "DS","D8" --------- Enc_B(data) ---------->  Dec_B -> "DS","D8"  (B shows it)
  "OK","!!" <-------- Enc_A(data) -----------  "OK","!!"           (A shows it)
```

**Why one round trip checks both keys.** B's answer `y` equals its challenge
only if A decrypted correctly (A's key is right) *and* B decrypted correctly
(B's key is right). The verdict goes back encrypted for A, so A believes
"match" only if it can decrypt the token 0x600D with its own key.

**No wrong key can pass.** The 8 challenges have the maximum multiplicative
order modulo both N_A and N_B. `scripts/check_enclave_keys.py` tries every
combination of wrong key bytes, 256 (A) × 128 (B) = 32,768 combinations, for
all 8 challenges, and finds no false pass. Two other candidate challenges did
let a pair of wrong keys through and were removed (bug log #14).

## What the board shows (Basys 3)

| Output | During key check | After keys match |
|---|---|---|
| LD0–LD7 (B) | number of failed attempts | all on (0xFF) = channel open |
| 7-segment (B) | `EE` = keys do not match, channel closed | last data byte received from A (`38` = "8") |
| LD8–LD14 (A) | verification rounds served | last data byte received from B (`21` = "!") |
| LD15 | off | on when both processors finish (halted) |

# Part 2 — DEBUG mode: the hardware debugger

The debugger sits inside the enclave on a second port window, **0x70–0x7F**.
It is available **only in DEBUG mode**: in SECURE mode every debug port reads
0x00, writes are ignored, and error code 5 is recorded.

| Feature | How it works | Port(s) |
|---|---|---|
| Run control | HALT, RESUME, **single-STEP** (exactly one engine clock) | DBG_CTRL 0x70 bits 0–2 |
| Breakpoint | halt when the engine reaches a chosen exponent bit (bits left = BP_BIT) | BP_CTRL 0x72 bit 0, BP_BIT 0x73 |
| Watchpoint | halt right after a multiply writes the watched value into `res` | BP_CTRL bit 1, WP 0x74/0x75 |
| Register inspection | read any internal register: state, bits left, steps left, res, b, exponent, mx, my, mr, modulus, cycle counter, multiply counter, error code, BIST index | REG_SEL 0x76, REG 0x77/0x78 |
| Register deposit | write res, b or the exponent while halted (for "what if" debugging); refused while running (error 6) | DBG_CTRL bit 5 |
| Trace buffer | last 8 multiply results (circular) and a count | TRACE_IDX 0x79, TRACE 0x7A/0x7B, TRACE_CNT 0x7C |
| Performance counters | engine busy cycles and number of multiplies of the last operation | REG 10, 11 |
| **Built-in self-test (test cases)** | runs 8 known-answer test vectors through the engine (both demo keys, encrypt and decrypt, all exponent bits, a single top bit, an illegal modulus) and reports pass/fail per vector | DBG_CTRL bit 3, BIST_PASS 0x7D, BIST_FAIL 0x7E |
| Fault injection | stuck-at-0 on the multiplier output, to prove the self-test finds a hardware problem | BP_CTRL bit 4 |
| Error codes | 1 modulus < 2, 2 message ≥ modulus, 3 command while busy, 4 key write while locked, 5 debug access in SECURE mode, 6 deposit while running | ERR_CODE 0x7F |
| Status | {BIST done, BIST running, watchpoint hit, breakpoint hit, fault armed, halted, engine busy, debug mode} | DBG_STATUS 0x71 |

In DEBUG mode the private-key ports can be read back (they can only hold a
debug key), and a RES read never stalls, because the debugger may have halted
the engine.

### The on-board debug session (both processors, `scripts/gen_debug_session.py`)

Each processor debugs its own enclave and lights one LED per passed check:

| LED bit | Check | Expected (from Python) |
|---|---|---|
| 0 | mode really is DEBUG: the debug private key reads back | D = A571 |
| 1 | built-in self-test: all 8 test cases pass | BIST_PASS = FF |
| 2 | breakpoint at "8 exponent bits left" halts; inspect registers | res = m¹⁷ = 8404, bits left = 8 |
| 3 | three single-steps | cycle counter + 3 |
| 4 | remove breakpoint, resume to the end | result 8404, 305 busy cycles |
| 5 | trace buffer | 18 multiplies, last = m^(2¹⁶) = 673D |
| 6 | watchpoint on res = 8404 | halts at exponent bit 4 (bits left = 12) |
| 7 | inject a fault → self-test must FAIL; remove it → PASS | fail mask ≠ 0, then FF |

**Board result:** LD0–LD7 all on (`FF`), display `dB`, LD8–LD14 all on (A),
LD15 on. A missing LED tells you exactly which feature failed. Every wait is
bounded, so a broken debugger shows a missing bit instead of hanging.

## Hardware

| File | What it is |
|---|---|
| `rtl/rsa_modexp.v` | `base^exp mod n`, 16-bit, square-and-multiply with bit-serial modular multiply (adders and comparators only). At most 530 cycles. Rejects `n < 2` and `m ≥ n`. Debug hooks: hold, deposit, fault, live register view, multiply events. |
| `rtl/rsa_enclave.v` | Mode selector input, own key pair (N, E, write-only D), peer public key (PN, PE), engine, and the debug unit (run control, breakpoint, watchpoint, registers, trace, counters, BIST, fault injection, error codes). |
| `rtl/cpu_mailbox.v` | One-byte channel each way, with status flags. (Not named `mailbox`: that is a SystemVerilog keyword.) |
| `rtl/dsd8_secure_top.v` | Two processors, two enclaves, one mailbox; separate key switches for each processor; the mode-selector strap (BTNU at reset). |
| `fpga/basys3_secure.xdc` | Basys 3 pins: SW0–7 key A, SW8–14 key B, SW15 reset, BTNC retry. |

### Enclave ports (each processor, 0x50–0x5F)

| Port | Name | Access | Meaning |
|---|---|---|---|
| 0x50 / 0x51 | MSG | r/w | message (must be < the modulus used) |
| 0x52 / 0x53 | N | r/w | own public modulus |
| 0x54 / 0x55 | E | r/w | own public exponent |
| 0x56 / 0x57 | D | **write-only** (SECURE) | own private exponent; reads return 0x00 in SECURE mode (readable in DEBUG mode, where it can only be a debug key) |
| 0x58 | CTRL | w | 0x01 encrypt with own key, **0x02 decrypt with own private key**, **0x03 encrypt for the peer (PN, PE)**; bit 7 LOCK (N, E, D read-only until reset). Ignored while busy. |
| 0x59 | STATUS | r | {3'b0, debug mode, locked, error, done, busy} |
| 0x5A / 0x5B | RES | r | result; in SECURE mode **a read while busy stalls** until done (≤ 530 cycles, so rule R21 holds); never stalls in DEBUG mode |
| 0x5C / 0x5D | PN | r/w | peer public modulus |
| 0x5E / 0x5F | PE | r/w | peer public exponent |

### Mailbox ports (each processor sees its own end, 0x60–0x63)

| Port | Name | Access | Meaning |
|---|---|---|---|
| 0x60 | TX | w | send a byte (discarded and overflow bit set if the channel is full) |
| 0x61 | RX | r | received byte; reading empties the channel |
| 0x62 | STATUS | r | {5'b0, overflow, tx_full, rx_valid} |

The mailbox never stalls, because the partner might never answer. Programs
poll STATUS.

## Security properties, and their limits

| Property | Enforced by | Tested by |
|---|---|---|
| Private keys can never be read by software | D ports return 0x00 | `tb_rsa_enclave`, `tb_rsa_cpu`, `tb_dsd8_secure_top`; mutation M21 |
| After the public keys, nothing goes on the mailbox in plaintext | programs encrypt every word for the receiver | `tb_dsd8_secure_top` checks every mailbox word against all plaintext values; mutation M28 |
| No data is sent unless both keys match | protocol + verdict token | `tb_dsd8_secure_top` counts mailbox bytes during mismatched rounds |
| No wrong key (or pair of wrong keys) opens the channel | full-order challenges, both bytes compared | exhaustive `check_enclave_keys.py`; testbench tries A wrong, B wrong, both wrong; mutation M26 |
| Encryption for the peer really uses the peer's key | separate PN/PE slot | `tb_rsa_enclave`; mutation M27 |
| Own key can be frozen | LOCK bit | `tb_rsa_enclave`, `tb_rsa_cpu`; mutation M24 |

Not claimed: textbook RSA without padding, which is deterministic and
malleable; no authentication of the public keys (a man-in-the-middle could
substitute them, and the peer key is deliberately not locked); no protection
against timing or power analysis; keys far too small. These are the honest
limits of a teaching design.

## Tests (self-checking; run by `make test`, `run_icarus_tests.bat` or `run_enclave_demo.bat`)

| Testbench | What it proves |
|---|---|
| `tb/tb_rsa_modexp.v` | 400 vectors vs Python `pow()`: both demo keys, corner exponents/moduli, illegal inputs, random; inputs captured at start; latency bound 530. |
| `tb/tb_rsa_enclave.v` | SECURE mode: debugger locked (all debug ports read 0, a debug HALT has no effect), decode, never ready without request, key read-back, write-only D, encrypt/decrypt, **ENCRYPT_PEER with PN/PE**, m ≥ modulus errors, RES stall, LOCK (own key locked, peer key not), reset. |
| `tb/tb_cpu_mailbox.v` | both directions, status, delivered once, overflow, simultaneous traffic, stream, reset. |
| `tb/tb_rsa_cpu.v` | one DSD-8 runs a 9-check enclave self-test program. |
| `tb/tb_rsa_debug.v` | **every debugger feature** at bus level in DEBUG mode: mode visible, key readable, BIST, breakpoint + register inspection (values from Python), no RES stall, 3 single-steps = 3 cycles, resume (result, 305 cycles, 18 multiplies, trace contents), watchpoint (fires on res, not on b), deposit (changes the result; refused while running), HALT freezes the engine, fault injection detected by BIST, error codes 1–4 and clear. |
| `tb/tb_dsd8_secure_debug.v` | the two-processor system booted in **DEBUG mode**: both processors pass all 8 on-chip debug checks (B LEDs FF, display dB, A LEDs FF), no mailbox traffic. |
| `tb/tb_dsd8_secure_top.v` | **the demo**: A wrong / B wrong / both wrong keys keep the channel closed with no data sent; correct keys open it; "DS","D8" go A→B and "OK","!!" go B→A, only as ciphertext, and are decrypted correctly on the other side. |

Fifteen injected bugs (M21–M35 in `scripts/mutation_check.py`: crypto, mailbox, protocol, debugger and mode selector) are all caught by these testbenches.

## How to run it

**Simulation (Icarus, Windows):** double-click `run_enclave_demo.bat`. Section 6 is the SECURE-mode demo, section 7 the debugger test, section 8 the DEBUG-mode demo. Section 6 prints:

```
step 1: key A = 00, key B = 2b  ->  B LEDs = 01, 7-seg = ee  -> MISMATCH: channel closed, no data sent
step 2: key A = 71, key B = 2a  ->  B LEDs = 02, 7-seg = ee  -> MISMATCH: channel closed, no data sent
step 3: key A = 07, key B = 25  ->  B LEDs = 03, 7-seg = ee  -> MISMATCH: channel closed, no data sent
step 4: key A = 71, key B = 2b  ->  B LEDs = ff, 7-seg = 38  -> KEYS MATCH: channel opened, encrypted data exchanged
data A->B on the mailbox (encrypted): 6e34 37f1 -> B decrypted: 4453 4438 ("DS" "D8")
data B->A on the mailbox (encrypted): b47c 40b0 -> A decrypted: 4f4b 2121 ("OK" "!!")
```

**Board (Vivado, Basys 3):**

1. New project, part `xc7a35tcpg236-1`. Add every file in `rtl/`. Top module `dsd8_secure_top`. Constraints `fpga/basys3_secure.xdc`.
2. Add `tb/data/enclave_server.hex` and `tb/data/enclave_client.hex` to the project and set the parameters `IMAGE_A = "enclave_server.hex"` and `IMAGE_B = "enclave_client.hex"`.
3. Synthesise, implement, program.
4. Set wrong keys and slide SW15 up. The display shows `EE` and LD0 lights.
5. Set **SW0–SW7 = 0111 0001 (0x71)** and **SW8–SW14 = 010 1011 (0x2B)**: SW8, SW9, SW11 and SW13 up. Press **BTNC**.
6. LD0–LD7 all light (channel open), the display shows `38`, LD8–LD14 show `0100001` (0x21 = "!"), and LD15 lights.
7. To start again: SW15 down, then up.
8. **DEBUG mode:** SW15 down, **hold BTNU**, SW15 up, release BTNU. Both processors debug their enclaves: LD0–LD14 all on, the display shows `dB`, and LD15 lights. Any dark LED in LD0–LD7 names the failed check (table in Part 2).

To change the keys, see the constants in `tests/secure/enclave_server.asm` /
`enclave_client.asm`, then re-run `python3 scripts/check_enclave_keys.py`
after updating the moduli and challenges in it.
