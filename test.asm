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
	mov	r0, rdi

	test	r0, r0 
	jz 	11f 
	mov	r1, 0 
	mov	r2, 1 

9:
	add	r2, r1 

	mov	r3, r2 	
	mov	r2, r1 	
	mov	r1, r3 	

	dec	r0 	
	jnz	9b
11:
	mov	rdi, r2
	mov	rax, 60
_bye:
	syscall
