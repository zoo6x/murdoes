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
	mov	r0, 0

	mov	r1, 11 
	mov	r2, 22 
	mov	r3, 33 

	test	r0, r0 
	jz 	1f

	mov	r0, r3 
	mov	r3, r2 
	mov	r2, r1 
	mov	r1, r0 
1:
	sub	r2, r1 
	add	r3, r2 

	mov	rdi, r1
	mov	rax, 60
_bye:
	syscall
