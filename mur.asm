.intel_syntax	noprefix

	.globl _start

.text

	.equ	rwork, rax
	.equ	rtop, rcx
	.equ	rstate, rbx
	.equ	rtmp, rdx
	.equ	rpc, rsi
	.equ	rhere, rdi
	.equ	rparam, r12
	.equ	rnext, r13

.macro	next
	jmp	rnext
.endm

_start:
	xor	rtop, rtop
	xor	rstate, rstate
	lea	rpc, qword ptr [$cold]
	lea	rnext, qword ptr [_next]
_next:
	lodsq
	jmp	[rwork + rstate * 8]
_call:
	# rwork = word header 
	jmp	[rwork + rstate * 8 + 8]	
_exit:
	pop	rpc
	jmp	_next
_exec:
	# rwork = word header 
	push	rpc
	mov	rpc, [rwork + rstate * 8 + 8]
	jmp	_next

# Words
.p2align	4, 0x90

.align 16
exit:
	.quad	_exit, 0
	.quad	_noop, 0

.align	16
noop:
	.quad	_noop, 0
	.quad	_noop, 0
_noop:
	next

	

.align 16
print:
	.quad	_call, _print
	.quad	_noop, 0
_print:
	push	rax
	push	rdx
	push	rsi
	push	rdi
	
	mov	rax, 0x41
	push	rax
	mov	rdx, 0x8
	mov	rsi, rsp
	mov	rax, 0x1
	mov 	rdi, 0x1
	syscall
	pop	rax

	pop	rdi
	pop	rsi
	pop	rdx
	pop	rax
	next

.align	16
bye:
	.quad	_call, _bye
	.quad	_noop, 0	
_bye:
	mov	rdi, 42
	mov	rax, 60
	syscall

.align	16
word1:
	.quad	_exec, $word1	# interpret
	.quad 	_noop, 0	# compile
$word1:
	.quad	print
	.quad	print
	.quad	word2
	.quad	exit	
			
.align	16
word2:
	.quad	_exec, $word2
	.quad	_noop, 0
$word2:
	.quad	print
	.quad	exit

# Cold start
.align	16
$cold:
	.quad	word1
	.quad	word2
	.quad	bye
