; buttons -> LEDs echo loop (board self-test)
LOOP:   IN   R1, 0x01
        OUT  0x02, R1
        JMP  LOOP
