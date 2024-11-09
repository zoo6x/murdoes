.intel_syntax	noprefix

	.globl _start

.text

	.equ	rwork, rax	# Points to XT in code words. Needs not be preserved
	.equ	rtop, rcx
	.equ	rstate, rbx
	.equ	rtmp, rdx	# Needs no be preserved
	.equ	rpc, rsi	# Do no change! LODSx instructions are used
	.equ	rhere, rdi	# Do not change! STOSx instructions are used
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
	lea	rhere, here
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

# EXIT
# Exit current Forth word and return the the caller
word	exit
	.quad	_exit, 0
	.quad	_noop, 0

# NOOP
# No operation
word	noop
	.quad	_noop, 0
	.quad	_noop, 0
_noop:
	ret

# DUP ( a -- a a )
word	dup
	.quad	_call, _dup
	.quad	_noop, 0
_dup:
	store	rtop, 1
	dec	rstack
	ret

# DROP ( a -- )
word	drop
	.quad	_call, _drop
	.quad	_noop, 0
_drop:
	inc	rstack
	load	rtop, 1
	ret

# LIT ( -- n )
# Pushes compiled literal onto data stack
word	lit
	.quad	_call, _lit
	.quad	_noop, 0
_lit:
	call	_dup
	lodsq
	mov	rtop, rax
	ret

# ALIGN
# Aligns HERE to 16-byte boundary
word	align
	.quad	_call, _align
	.quad	_noop, 0
_align:
	add	rhere, 0xf
	and	rhere, -16
	ret

# EMIT ( c -- c )
# Prints a character to stdout
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

# READ ( -- c )
# Reads a character from stdin
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

word	parse

# TYPE ( c-addr u -- )
# Print string to stdout
	.quad	_call, _type
	.quad	_noop, 0
_type:
	push	rsi

	mov	rtmp, rtop	# count
	load	rsi, 1		# buffer
	inc	rstack
	inc	rstack	
	mov	rax, 0x1
	mov	rdi, 0x1
	syscall

	pop	rsi

	ret


# WORDS
# Prints all defined words to stdout
word	words
	.quad	_call, _words
	.quad	_noop, 0
_words:
	push	rtop
	push	rsi
	push	rdi

	mov	rtmp, rlatest

	1:
	test	rtmp, rtmp
	jz	9f

	push	rtmp			# current word

	mov	rwork, [rtmp - 16]	# NFA
	movzx	rtmp, byte ptr [rwork]	# count
	lea	rsi, [rwork + 1]	# buffer
	mov	rdi, 1			# stdout
	mov	rax, 1			# sys_write
	syscall

	mov	rtop, 0x20
	call	_emit

	pop	rtmp
	mov	rtmp, [rtmp - 8]	# LFA
	jmp	1b

	9:
	pop	rdi
	pop	rsi
	pop	rtop
	ret

# C, ( c -- )
# Reserve space for one character in the data space and store char in the space.
word	c_comma, "c,"
	.quad	_call, _c_comma
	.quad	_noop, 0
_c_comma:
	mov	rax, rtop
	stosb
	ret

# COUNT ( c-addr -- c-addr' u )
# Converts address to byte-counted string into string address and count
word	count
	.quad	_call, _count
	.quad	_noop, 0
_count:
	call	_dup
	mov	rwork, rtop
	store	rwork, 1
	movzx	rtop, byte ptr [rtop]
	ret

# WORD ( -- c-addr )
# Reads blank-separated word from stdin, places it as a byte-counted string at HERE
word	word
	.quad	_call, _word
	.quad	_noop, 0
_word:
	mov	rtmp, rhere
	call	_align

	1:
	call	_read
	cmp	rtop, 0x20
	je	2f
	cmp	rtop, 0xa
	je	2f
	mov	rax, rtop
	stosb
	jmp	1b

	2:
	mov	rwork, rhere
	sub	rwork, rtmp
	mov	byte ptr [rtmp], al	

	mov	rhere, rtmp

	call	_dup
	mov	rtop, rhere

	ret

# FIND ( -- xt | 0 )
# Searches for word name, placed at HERE, in the vocabulary
word	find
	.quad	_call, _find
	.quad	_noop, 0
_find:
	call	_dup

	push	rsi
	push	rdi

	mov	rtmp, rlatest

	1:
	test	rtmp, rtmp
	jz	6f

	mov	rsi, rhere

	mov	rwork, [rtmp - 16]	# NFA
	movzx	rcx, byte ptr [rwork]
	mov	rdi, rwork
	rep	cmpsb
	mov	rtop, rwork
	je	9f

	mov	rtmp, [rtmp - 8]	# LFA
	jmp	1b

	6:
	mov	rtop, 0

	9:
	pop	rdi
	pop	rsi
	ret

# QUIT ( -- )
# Interpret loop
word	quit
	.quad	_call, _quit
	.quad	_noop, 0
_quit:
	call	_word
	call	_count
	call	_find
	test	rtop, rtop
	jz	2f
	mov	rwork, rtop
	call	_drop
	call	_exec
	jmp	_quit				
	2:
	ret

# BYE
# Returns to OS
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

# COLD
# Cold start (in fact, just a test word that runs first)
word	cold
$cold:
	#.quad	words
	#.quad	lit, 0xa
	#.quad	emit
	.quad	quit
	.quad	word1
	.quad	word2
	.quad	bye

# LATEST
	.equ	last, latest
.align	16
here:

