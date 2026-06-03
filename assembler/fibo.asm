li t0, 0
li t1, 1
li t4, 0x2000

loop_start:
sw t0, 0(t4)
add t2, t0, t1
addi t0, t1, 0
addi t1, t2, 0

li t3, 100000000
wait_start:
addi t3, t3, -1 
bnez t3, wait_start

j loop_start
