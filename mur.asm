.intel_syntax	noprefix

	.globl _start

.text

	.equ	rwork, rax	# Points to XT in code words. Needs not be preserved
	.equ	rtop, rcx
	.equ	rstate, rbx
	.equ	rtmp, rdx	# Needs no be preserved
	.equ	rpc, rsi	# Do no change! LODSx instructions are used
	.equ	rhere, rdi
	.equ	rparam, r12
	.equ	rnext, r13
	.equ	rlatest, r14
	.equ	rstack, rbp
	.equ	rstack0, r15

	latest	= 0

# Word definition
.macro	word	name, fname
	.align	16
\name\()_name:
	.byte	\name\()_strend - \name\()_str
\name\()_str:
.ifc \fname,
	.ascii	"\name"
.else
	.ascii	"\fname"
.endif
\name\()_strend:
	.p2align	4, 0x00
\name\()_nfa:
	.quad	\name\()_name
\name\()_lfa:
	.quad	latest
\name\():
	latest = .
.endm

# Data stack access
.macro	load	reg, i
	mov	\reg, qword ptr [rstack0 + rstack * 8 + 8 * (\i - 1)]
.endm

.macro	store	regval, i
	mov	qword ptr [rstack0 + rstack * 8 + 8 * (\i - 1)], \regval
.endm


# Initialization
_start:
	xor	rtop, rtop
	xor	rstate, rstate
	lea	rlatest, last
	lea	rpc, qword ptr [$cold]
	lea	rnext, qword ptr [_next]
	lea	rstack0, [rsp - 0x1000]
	xor	rstack, rstack

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

word	dup
	.quad	_call, _dup
	.quad	_noop, 0
_dup:
	store	rtop, 1
	dec	rstack
	ret

word	lit
	.quad	_call, _lit
	.quad	_noop, 0
_lit:
	call	_dup
	lodsq
	mov	rtop, rax
	ret

word	emit
	.quad	_call, _emit
	.quad	_noop, 0
_emit:
	push	rtop
	push	rwork
	push	rdx
	push	rsi
	push	rdi
	
	mov	rwork, rtop
	push	rax
	mov	rdx, 0x8	# count
	mov	rsi, rsp	# buffer
	mov 	rdi, 0x1	# stdout
	mov	rax, 0x1	# sys_write
	syscall
	pop	rwork

	pop	rdi
	pop	rsi
	pop	rdx
	pop	rwork
	pop	rtop
	ret

word	read
	.quad	_call, _read
	.quad	_noop, 0
_read:
	call	_dup

	push	rax
	push	rdx
	push	rsi
	push	rdi

	xor	rwork, rwork
	push	rwork
	mov	rdx, 0x1	# count
	mov	rsi, rsp	# buffer
	mov 	rdi, 0x1	# stdin
	mov	rax, 0x0	# sys_read
	syscall
	pop	rtop

	pop	rdi
	pop	rsi
	pop	rdx
	pop	rax
	ret

word	words
	.quad	_call, _words
	.quad	_noop, 0
_words:
	push	rtop
	push	rsi
	push	rdi

	mov	rtmp, rlatest

	Lloop:
	test	rtmp, rtmp
	jz	Lexit

	push	rtmp			# current word

	mov	rwork, [rtmp - 16]	# NFA
	movzx	rtmp, byte ptr [rwork]
	lea	rsi, [rwork + 1]
	mov	rax, 1
	mov	rdi, 1
	syscall

	mov	rtop, 0x20
	call	_emit

	pop	rtmp
	mov	rtmp, [rtmp - 8]	# LFA
	jmp	Lloop

	Lexit:
	pop	rdi
	pop	rsi
	pop	rtop
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
	.quad	emit
	.quad	emit
	.quad	word2
	.quad	exit	
			
word	word2
	.quad	_exec, $word2
	.quad	_noop, 0
$word2:
	.quad	emit
	.quad	exit

# Cold start
word	cold
$cold:
	.quad	words
	.quad	lit, 0xa
	.quad	emit
	.quad	read, emit
	.quad	word1
	.quad	word2
	.quad	bye

	.equ	last, latest
