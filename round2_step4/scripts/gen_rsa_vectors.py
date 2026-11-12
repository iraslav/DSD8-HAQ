#!/usr/bin/env python3
"""
gen_rsa_vectors.py -- reference vectors for tb/tb_rsa_modexp.v

Each line of tb/data/rsa_vectors.hex is one 80-bit word:
    {flag[15:0], m[15:0], e[15:0], n[15:0], expected[15:0]}
flag = 0001 when the engine must report an error (n < 2 or m >= n),
       0000 otherwise, with expected = pow(m, e, n) from Python.
The reference is Python's built-in pow(), entirely independent of the RTL.
"""
import random

rng = random.Random(20261103)
vec = []

def add(m, e, n):
    if n < 2 or m >= n:
        vec.append((1, m, e, n, 0))
    else:
        vec.append((0, m, e, n, pow(m, e, n)))

# the demo key: p = 241, q = 251, n = 60491, e = 17, d = 42353
N, E, D = 60491, 17, 42353
for m in (0, 1, 2, 0x4A03, 0x4A92, N - 1, 0x1234):
    add(m, E, N)
    add(pow(m, E, N), D, N)                     # decrypt round trip
# corner exponents and moduli
for e in (0, 1, 2, 3, 0x8000, 0xFFFF):
    add(0x1234, e, N)
add(1, 0xFFFF, 2); add(0, 5, 2)                 # smallest legal modulus
add(0xFFFE, 0xFFFF, 0xFFFF)                     # largest operands
add(0x7FFF, 0xFFFF, 0x8000)                     # even modulus
add(5, 3, 0); add(5, 3, 1)                      # illegal modulus -> error
add(N, E, N); add(0xFFFF, E, N)                 # m >= n -> error
# random
while len(vec) < 400:
    n = rng.choice([rng.randrange(2, 256), rng.randrange(256, 1 << 16), rng.randrange(1 << 15, 1 << 16)])
    m = rng.randrange(0, n)
    e = rng.randrange(0, 1 << 16)
    add(m, e, n)

with open("tb/data/rsa_vectors.hex", "w") as f:
    for flag, m, e, n, r in vec:
        f.write(f"{flag:04X}{m:04X}{e:04X}{n:04X}{r:04X}\n")
print(f"wrote {len(vec)} vectors to tb/data/rsa_vectors.hex")
