#!/usr/bin/env python3
"""
check_enclave_keys.py -- number-theory check of the secure-channel demo keys.

Proves, exhaustively, that with the 8 challenges used by
tests/secure/enclave_client.asm NO combination of wrong private-key bytes
(A: 256 values of D_LO from SW0-7, B: 128 values of D_LO from SW8-14)
passes the mutual check, i.e. the channel opens only for the correct pair.
Also checks the verdict tokens and data words fit under the moduli.
"""
nA,eA,dA=60491,17,0xA571
nB,eB,dB=55687,19,0x662B
assert (eB*dB)%((233-1)*(239-1))==1
LA,LB=6000,27608   # lcm(240,250), lcm(232,238)
def full(m,n,L,fs):
    from math import gcd
    return gcd(m,n)==1 and pow(m,L,n)==1 and all(pow(m,L//f,n)!=1 for f in fs)
cands=[m for m in range(0x4A00,0x4B00) if full(m,nA,LA,(2,3,5)) and full(m,nB,LB,(2,7,17,29))]
print(len(cands),[hex(c) for c in cands])
ch=[0x4a0b,0x4a11,0x4a19,0x4a28,0x4a38,0x4a54,0x4a6c,0x4a72]
def enc(m,e,n): return 0 if m>=n else pow(m,e,n)
bad=0
for m in ch:
    c1=enc(m,eA,nA)
    for la in range(256):
        x=pow(c1,(dA&0xFF00)|la,nA)
        c2=enc(x,eB,nB)
        for lb in range(128):
            y=pow(c2,(dB&0xFF00)|lb,nB)
            if y==m and not (la==dA&0xFF and lb==dB&0xFF): bad+=1; print("FALSE PASS",hex(m),hex(la),hex(lb))
print("false passes:",bad)
GOOD,BAD=0x600D,0x0BAD
print("token clash:",[hex(la) for la in range(256) if pow(enc(BAD,eA,nA),(dA&0xFF00)|la,nA)==GOOD])
print("check tokens < nA:",GOOD<nA,BAD<nA, "data<nB:", all(w<nB for w in (0x4453,0x4438)), all(w<nA for w in (0x4F4B,0x2121)))
