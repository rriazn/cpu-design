li t0, 0
li t1, 1
lui t4, 2
nop
nop
nop
loop_start: sw t0, 0(t4)
add t2, t0, t1
addi t0, t1, 0
nop
nop
addi t1, t2, 0
li t3, 2
nop
nop
nop
wait_start: addi t3, t3, -1 
nop
nop
nop
bnez t3, wait_start
nop
nop
j loop_start
nop
nop
