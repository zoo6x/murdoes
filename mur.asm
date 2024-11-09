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
	.equ	rlatest, r14

.macro	next
	jmp	rnext
.endm

	latest	= 0

.macro	word	name
\name\()_name:
	.byte	strlen
	str = .
	.ascii	"\name"
	strlen = . - str
	.align	16
\name\()_nfa:
	.quad	\name\()_name
\name\()_lfa:
	.quad	latest
\name\():
	latest = .
.endm

# Initialization
_start:
	xor	rtop, rtop
	xor	rstate, rstate
	lea	rlatest, last
	lea	rpc, qword ptr [$cold]
	lea	rnext, qword ptr [_next]

# Interpreter
_next:
	lodsq
	jmp	[rwork + rstate * 8]
_call:
	# rwork = word header 
	push	rnext
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


word	exit
	.quad	_exit, 0
	.quad	_noop, 0

word	noop
	.quad	_noop, 0
	.quad	_noop, 0
_noop:
	ret

	

word	print
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
	ret

word	bye
	.quad	_call, _bye
	.quad	_noop, 0	
_bye:
	mov	rdi, 42
	mov	rax, 60
	syscall

word	word1
	.quad	_exec, $word1	# interpret
	.quad 	_noop, 0	# compile
$word1:
	.quad	print
	.quad	print
	.quad	word2
	.quad	exit	
			
word	word2
	.quad	_exec, $word2
	.quad	_noop, 0
$word2:
	.quad	print
	.quad	exit

# Cold start
word	cold
$cold:
	.quad	word1
	.quad	word2
	.quad	bye

	.equ	last, latest
