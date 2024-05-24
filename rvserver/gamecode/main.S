.section .initial_jump
.global _start
.global asm_demo_func
.global ENVCTRL
.global HOSTDAT

.align 4

_start:
	la	sp, _sstack
	addi	sp,sp,-16

	la      t0, ENVCTRL
	sw      a2, 0(t0)
	// A3 (HOSTDAT) comes from .ld file.

	sw	ra,12(sp)
	jal	ra, main

done:
	j done

.align 4

// Keep these in this order
ENVCTRL:
	.long 0x00000000


