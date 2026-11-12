| ID | Injected bug | Unit TBs | Conformance T01-T40 | Extra + random |
|---|---|---|---|---|
| M01 | rf_we asserted for CMP | **killed** | **killed** | **killed** |
| M02 | SUB/CMP carry = borrow (inverted convention) | **killed** | **killed** | **killed** |
| M03 | SHR arithmetic instead of logical | **killed** | **killed** | **killed** |
| M04 | overflow uses b instead of effective b (SUB V wrong) | **killed** | **killed** | **killed** |
| M05 | Format M/P routing: read port 2 always rs2 | **killed** | **killed** | **killed** |
| M06 | trace flags sampled before update (lag) | survived | **killed** | **killed** |
| M07 | no zero-forcing of rf_addr (R23) | **killed** | **killed** | **killed** |
| M08 | io_ready ignored for the state (no stall) | **killed** | survived | survived |
| M09 | I/O commits without waiting for io_ready | **killed** | **killed** | **killed** |
| M10 | data memory not cleared (R16) | **killed** | **killed** | **killed** |
| M11 | LD and ST also write flags | **killed** | **killed** | **killed** |
| M12 | BCS tests C = 0 | **killed** | **killed** | **killed** |
| M13 | rs1 / rs2 slices swapped | **killed** | **killed** | **killed** |
| M14 | unmapped low ports read the switches | **killed** | survived | survived |
| M15 | PC advances past HLT | **killed** | survived | survived |
| M16 | OUT sends R[rs1] instead of R[rd] | **killed** | **killed** | **killed** |
| M17 | write-through forwarding (violates R14) | **killed** | **killed** | **killed** |
| M18 | PC increments by 2 | **killed** | **killed** | **killed** |
| M19 | HLT does not halt | **killed** | **killed** | **killed** |
| M20 | flags register ignores flags_we | **killed** | **killed** | **killed** |
| M21 | enclave: private key D_LO readable | **killed** | survived | survived |
| M22 | engine: missing reduction after doubling | **killed** | survived | survived |
| M23 | enclave: RES read does not wait for the engine | **killed** | survived | survived |
| M24 | enclave: LOCK does not protect N | **killed** | survived | survived |
| M25 | mailbox: reading does not empty the A->B channel | **killed** | survived | survived |
| M26 | client program: low byte of the answer not checked | **killed** | survived | survived |
| M27 | enclave: ENCRYPT_PEER uses its own key | **killed** | survived | survived |
| M28 | server program: answers in plaintext (skips re-encryption) | **killed** | survived | survived |
| M29 | debugger: breakpoint ignores the bit number | **killed** | not run | not run |
| M30 | debugger readable in SECURE mode | **killed** | not run | not run |
| M31 | debugger: STEP never stops (runs freely) | **killed** | not run | not run |
| M32 | debugger: fault injection disconnected | **killed** | not run | not run |
| M33 | debugger: BIST compares before the engine finishes | **killed** | not run | not run |
| M34 | mode selector not latched at reset (follows the button live) | **killed** | not run | not run |
| M35 | debugger: watchpoint also fires on writes to b | **killed** | not run | not run |

35 / 35 mutations killed by at least one suite. M29-M35 were run with
`--suites unit` (the conformance suites cannot see the enclave). (M21-M35 are in the
security-enclave extension, which the conformance suite never exercises --
as intended, since the core and its trace are unchanged.)
