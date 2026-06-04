start:
li t0, 0
li t1, 1
li t2, 0x2000
add t3, t0, t1
sw t3, (t2)
nop
addi t3, t3, -1
sw t3, (t2)
nop
j start
nop
nop
nop
