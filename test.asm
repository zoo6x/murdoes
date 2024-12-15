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
	mov	r0, 5


	mov	r1, 0 
	mov	r2, 1 
	mov	r3, 2 

9:

	add	r3, r0 

	mov	r5, r3 
	mov	r3, r2 
	mov	r2, r1 
	mov	r1, r5 
	dec	r0 
	jnz	9b

	add	r2, r1 
	add	r3, r2 


	mov	rdi, r3
	mov	rax, 60
_bye:
	syscall
