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

20 / 20 mutations killed by at least one suite.
