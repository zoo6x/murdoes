# Forth for AArch64
# Syscalls: https://arm64.syscall.sh/

	.global	_start

.text
	rwork	.req	x0
	rworkw	.req	w0
	rtop	.req	x1
	rtopw	.req	w1
	rstate	.req	x2
	rtmp	.req	x3
	rtmp2	.req	x4
	rtmp2w	.req	w4
	rpc	.req	x5
	rhere	.req	x6
	rnext	.req	lr
	rstack	.req	x7
	rtmp3	.req	x8
	rtmp3w	.req	w8
	rrstack	.req	x9
	rlatest	.req	x10

	latest_word	= 0

# Initialization
_start:
	mov	rwork, xzr
	mov	rtop, xzr
	mov	rstate, xzr
	adr	rlatest, last
	adr	rhere, here0
	adr	rpc, $cold
	adr	rnext, _next
	add	rstack, sp, -0x1000
	add	rrstack, sp, -0x2000

# Interpreter
_next:
	ldr	rwork, [rpc], 8
_doxt:
	add	rtmp, rwork, rstate, lsl 3
	ldp	rtmp, rtmp2, [rtmp]
	br	rtmp
_call:
	br	rtmp2 
_exit:
	ldr	rpc, [rrstack, 8]!
	b	_next
_exec:
	str	rpc, [rrstack], -8
	mov	rpc, rtmp2
_noop:
	b	_next

# Word definition
.macro	word	name, fname
	.align	4
\name\()_str0:
	.byte	\name\()_strend - \name\()_str
\name\()_str:
.ifc "\fname",""
	.ascii	"\name"
.else
	.ascii	"\fname"
.endif
\name\()_strend:
	.p2align	4, 0x00
	.quad	\name\()_str0
	.quad	latest_word
\name\():
	latest_word = .
	latest_name = _\name
.endm

.macro	reserve_cfa reserve=15
	# Execution semantics can be either code or Forth word
	# Compilation semantics inside Forth words is the same: compile adress of XT
	# Semantics for other states does nothing by default
	.rept \reserve
	.quad	_noop, 0
	.endr
.endm

.macro	.codeword
	.quad	_call, latest_name
	reserve_cfa
.endm

.macro	.forthword
	.quad	_exec, 0f
	reserve_cfa
	0:
.endm

.macro	dup_
	str	rtop, [rstack], -8
.endm

.macro	drop_
	ldr	rtop, [rstack, 8]!
.endm

.p2align	4

# EXIT
# Exit current Forth word and return the the caller
word	exit
	.quad	_exit, 0
	reserve_cfa

# DUP ( a -- a a )
word	dup
	.codeword
_dup:
	dup_
	ret

# DROP ( a -- )
word	drop
	.codeword
_drop:
	drop_
	ret

# LIT ( -- n )
# Pushes compiled literal onto data stack
word	lit
	.codeword
_lit:
	dup_
	ldr	rtop, [rpc], 8
	ret

# JUMP ( -- )
# Changes PC by compliled offset (in cells)
word	jump
	.codeword
_jump:
	ldr	rwork, [rpc], 8
	add	rpc, rpc, rwork, lsl 3
	ret

# ALIGN
# Aligns HERE to 16-byte boundary
word	align
	.codeword
_align:
	add	rhere, rhere, 0xf
	and	rhere, rhere, -16
	ret

# EMIT ( c -- )
# Prints a character to stdout
word	emit
	.codeword
_emit:
	stp	x0, x2, [sp, -16]!

	dup_
	mov	x2, 0x1
	add	x1, rstack, 8
	mov 	x0, 0x1
	mov	w8, 0x40
	svc	0

	drop_
	drop_
	
	ldp	x0, x2, [sp], 16

	ret

# READ ( -- c )
# Read a character from stdin
word	read
	.codeword
_read:
	stp	x2, x8, [sp, -16]!

	dup_
	mov	x2, 0x1
	add	x1, rstack, 0
	mov 	x0, 0x0
	mov	w8, 0x3f
	svc	0
	ldrb	rworkw, [rstack]
	mov	rtop, rwork

	ldp	x2, x8, [sp], 16

	ret

# TYPE ( c-addr u -- )
# Print string to stdout
word	type
	.codeword
_type:
	stp	x2, x8, [sp, -16]!

	dup_
	mov	x2, rtop
	drop_
	mov	x1, rtop
	mov 	x0, 0x1
	mov	w8, 0x40
	svc	0

	drop_

	ldp	x2, x8, [sp], 16

	ret

# WORDS
# Prints all defined words to stdout
word	words
	.codeword
_words:
	stp	x1, x2, [sp, -16]!
	stp	x8, lr, [sp, -16]!

	mov	rtmp, rlatest

	1:
	ands	xzr, rtmp, rtmp
	b.eq	9f

	mov	rtmp2, rtmp

	ldr	rwork, [rtmp, -16]	/* NFA */
	ldrsb	x2, [rwork]		/* count */
	add	x1, rwork, 1		/* buffer */
	mov	x0, 1			/* stdout */
	mov	w8, 0x40		/* sys_write */
	svc	0

	dup_
	mov	rtop, 0x20
	bl	_emit

	mov	rtmp, rtmp2
	ldr	rtmp, [rtmp, -8]	/* LFA */
	b	1b

	9:
	ldp	x8, lr, [sp], 16
	ldp	x1, x2, [sp], 16

	ret

# BL ( -- c )
# Returns blank character code
word	bl
	.codeword
_bl:
	dup_
	mov	rtop, 0x20
	ret

# , ( v -- )
# Reserve space for one cell in the data space and store value in the pace
word	comma, ","
	.codeword
_comma:
	str	rtop, [rhere], 8
	drop_
	ret

# C, ( c -- )
# Reserve space for one character in the data space and store char in the space
word	c_comma, "c,"
	.codeword
_c_comma:
	strb	rtopw, [rhere], 1
	drop_
	ret

# COUNT ( c-addr -- c-addr' u )
# Converts address to byte-counted string into string address and count
word	count
	.codeword
_count:
	mov	rwork, rtop
	add	rwork, rwork, 1
	ldrsb	rtmp, [rtop]
	mov	rtop, rwork
	dup_
	mov	rtop, rtmp
	ret

# WORD ( c "<chars>ccc<char>" -- c-addr )
# Reads char-separated word from stdin, places it as a byte-counted string at HERE, aligns HERE at 16 bytes before that
word	word
	.codeword
_word:
	stp	xzr, lr, [sp, -16]!

	bl	_align
	mov	rtmp, rhere

	mov	rtmp2, rtop
	drop_

	strb	wzr, [rhere], 1
	1:
	bl	_read
	cmp	rtop, rtmp2
	b.eq	2f
	cmp	rtop, 0xa
	b.eq	2f
	cmp	rtop, 0x9
	b.eq	2f
	strb	rtopw, [rhere], 1
	drop_
	b	1b

	2:
	sub	rwork, rhere, rtmp
	sub	rwork, rwork, 1
	strb	rworkw, [rtmp]

	mov	rhere, rtmp

	mov	rtop, rhere

	ldp	xzr, lr, [sp], 16
	ret

# HEAD ( "<name>" -- )
# Reads word name from input stream and creates default header
word	head
	.codeword
_head:
	stp	xzr, lr, [sp, -16]!

	bl	_bl		/* ( bl ) */
	bl	_word		/* ( here ) */
	dup_			/* ( here here ) */
	bl	_count		/* ( here here+1 count ) */
	ands	xzr, rtop, rtop
	b.eq	6f

	drop_
	drop_
	# TODO: ASSERT(rtop == rhere)
	cmp	rhere, rtop
	b.eq	0f
	brk	42

	0:
	ldrb	rworkw, [rtop]			/* name */
	add	rhere, rhere, rwork
	add	rhere, rhere, 0xf
	and	rhere, rhere, -16

	str	rtop, [rhere]			/* NFA */
	add	rhere, rhere, 8
	str	rlatest, [rhere]		/* LFA */
	add	rhere, rhere, 8

	mov	rwork, rhere			/* XT */
	mov	rlatest, rhere

	mov	rtmp2, 16
	adr	rtmp, _noop

	1:
	str	rtmp, [rhere]
	add	rhere, rhere, 8
	str	xzr, [rhere]
	add	rhere, rhere, 8
	sub	rtmp2, rtmp2, 1
	b.ne	1b

	drop_
	#mov	rtop, rwork 
	b	9f

	6:
	# TODO: ABORT
	drop_
	drop_
	drop_

	9:
	ldp	xzr, lr, [sp], 16
	ret

# LATEST ( -- xt )
# Returns the latest defined word
word	latest
	.codeword
_latest:
	dup_
	mov	rtop, rlatest
	ret

# HERE ( -- a )
# Returns address of the first available byte of the code space
word	here
	.codeword
_here:
	dup_
	mov	rtop, rhere
	ret

# DOES ( code param state xt -- )
# Sets semantics for a word defined by XT for given state to a given code:param pair
word	does
	.codeword
_does:
	mov	rtmp, rtop
	drop_
	mov	rwork, rtop
	drop_

	add	rtmp2, rtmp, rwork, lsl 3
	add	rtmp2, rtmp2, 8
	str	rtop, [rtmp2]
	drop_
	add	rtmp2, rtmp, rwork, lsl 3
	str	rtop, [rtmp2]
	drop_

	ret

# CODEWORD ( xt -- )
# Specifies execution semantics for a word specified by XT as a code word
word	codeword
	.forthword
$codeword:
	.quad	lit, _call
	.quad	here
	.quad	lit, 0
	.quad	latest
	.quad	does
	.quad	exit

# FORTHWORD ( xt -- )
# Specifies execution semantics for a word specified by XT as a forth word with threaded code following at HERE
word	forthword
	.forthword
$forthword:
	.quad	lit, _exec
	.quad	here
	.quad	lit, 0
	.quad	latest
	.quad	does
	.quad	exit

# : ( "<name>" -- )
word	colon, ":"
	.forthword
_colon:
	.quad	head
	.quad	forthword
	.quad	exit

# FIND ( -- xt | 0 )
# Searches for word name, placed at HERE, in the vocabulary
word	find
	.codeword
_find:
	stp	x11, x12, [sp, -16]!
	stp	x13, x14, [sp, -16]!

	dup_

	mov	rtmp, rlatest		/* XT */
	mov	rtmp2, rhere

	1:
	mov	rtop, rtmp
	ands	xzr, rtmp, rtmp
	b.eq	6f

	mov	x11, rtmp2

	ldr	rwork, [rtmp, -16]	/* NFA */
	ldrb	w12, [rwork]
	add	x12, x12, 1

	2:
	ldrb	w13, [x11]
	ldrb	w14, [rwork]
	add	x11, x11, 1
	add	rwork, rwork, 1
	cmp	w13, w14
	b.ne	4f
	subs	x12, x12, 1
	b.eq	9f
	b	2b

	4:
	ldr	rtmp, [rtmp, -8]	/* LFA */
	b	1b

	6:

	9:
	ldp	x13, x14, [sp], 16
	ldp	x11, x12, [sp], 16
	ret

# NUMBER ( c-addr -- n -1 | 0 )
# Parses string as a number (in HEX base)
word	number
	.codeword
_number:
	mov	rtmp3, rtop
	ldrb	rtmp2w, [rtop]
	tst	rtmp2, rtmp2
	b.eq	6f

	mov	rtmp, 0
	add	rtmp3, rtmp3, 1
	1:
	ldrb	rworkw, [rtmp3], 1
	cmp	rworkw, 0x30
	b.lo	6f
	cmp	rworkw, 0x39
	b.ls	3f
	orr	rworkw, rworkw, 0x20
	cmp	rworkw, 0x61
	b.lo	6f
	cmp	rworkw, 0x66
	b.hi	6f
	sub	rworkw, rworkw, 0x61 - 10
	b	4f
	3:
	sub	rworkw, rworkw, 0x30
	4:
	lsl	rtmp, rtmp, 4
	add	rtmp, rtmp, rwork
	subs	rtmp2, rtmp2, 1
	b.ne	1b

	mov	rtop, rtmp
	dup_
	mov	rtop, -1
	b	9f

	6:
	mov	rtop, 0

	9:
	ret

# . ( n -- )
# Print number on the top of the stack (hexadecimal)
word	dot, "."
	.codeword
_dot:
/*
	mov	rtmp, 16

	1:
	rol	rtop, 4
	test	rtop, 0xf
	jnz	3f
	dec	rtmp
	jnz	1b

	call	_drop
	mov	rtop, 0x30
	call	_emit
	jmp	9f

	3:
	mov	al, cl
	and	al, 0xf
	cmp	al, 0x9
	jbe	4f
	add	al, 0x61 - 0x30 - 0xa
	4:
	add	al, 0x30
	push	rtop
	push	rwork
	call	_dup
	movzx	rtop, al
	call	_emit
	pop	rwork
	pop	rtop
	rol	rtop, 4
	dec	rtmp
	jnz	3b
	call	_drop

	9:
	call	_bl
	call	_emit
	*/
	ret

# (QUIT) ( -- )
# Read one word from input stream and interpret it
word	quit_, "(quit)"
	.codeword
_quit_:
	stp	xzr, lr, [sp, -16]!

	bl	_bl
	bl	_word
	drop_
	bl	_find
	tst	rtop, rtop
	b.eq	2f
	mov	rwork, rtop
	drop_

	ldp	xzr, lr, [sp], 16
	b	_doxt

	2:

	drop_
	bl	_here
	bl	_number
	tst	rtop, rtop
	b.eq	6f

	drop_
	b	9f

	6:
	# TODO: ABORT
	drop_
	9:

	ldp	xzr, lr, [sp], 16

	ret

# QUIT
# Interpret loop
word	quit
	.forthword
_quit:
	.quad	quit_
	.quad	jump, -3

# BYE
# Exit to OS
word	bye
	.codeword
_bye:
	mov	x0, rtop
	mov	w8, 93
	svc	0

# Test words
word	word1
	.forthword
word1$:
	.quad	lit, 42
	.quad	emit
	.quad	read
	.quad	emit
	.quad	word2
	.quad	exit

word	word2
	.forthword
word2$:
	.quad	drop
	.quad	lit, 43
	.quad	emit
	.quad	exit

$cold:
	.quad	lit, 0x39
	.quad	lit, 0x38
	.quad	lit, 0x37
	.quad	lit, 0x36
	.quad	lit, 0x35
	.quad	lit, 0x34
	.quad	lit, 0x33
	.quad	lit, 42, emit
	.quad	emit, emit, emit
	.quad	read, read
	.quad	emit, emit

	.quad	bl, emit
	.quad	lit, 43, emit
	.quad	lit, 0x3e, emit
	.quad	quit
	.quad	word1
	.quad	dup
	.quad	drop
	.quad	bye

# LATEST
	.equ	last, latest_word
#latest_word
.align	4
here0:
	.rep	0x10
	.quad	0
	.endr

