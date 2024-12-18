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
	mov	r0, 1 

	mov	r1, r0 
	inc	r1 

	add	r1, r0 



	mov	r2, r0 
	inc	r2 

	add	r1, r2 



	inc	r0 


	inc	r0 


	inc	r0 

	add	r1, r0 


	inc	r1 


	inc	r1 


	mov	rdi, r1
	mov	rax, 60
_bye:
	syscall
