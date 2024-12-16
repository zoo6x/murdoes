.intel_syntax	noprefix

	.global	_start

	.equ	r0, rax
	.equ	r1, rcx
	.equ	r2, rdx
	.equ	r3, rbx
	.equ	r5, rbp
	.equ	r6, rsi
	.equ	r7, rdi

.text

_start:
	mov	r0, 9

	test	r0, r0 
	jz 	19f 

	mov	r1, 0 
	mov	r2, 1 
	mov	r3, 2 

1:
	mov	r5, r2 
	add	r5, r3 
	add	r1, r5 
	dec	r0 
	jz	15f
	mov	r5, r3 
	mov	r3, r1 
	mov	r2, r5 
	mov	r1, r2 
	jmp	1b 

15:
	mov	r0, r1 

19:
	mov	rdi, r0
	mov	rax, 60
_bye:
	syscall
