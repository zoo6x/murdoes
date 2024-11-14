# Forth for AArch64

	.global	_start

.text
	rwork	.req	x0
	rtop	.req	x1
	rstate	.req	x2
	rtmp	.req	x3
	rtmp2	.req	x4
	rpc	.req	x5
	rhere	.req	x6
	rnext	.req	lr
	rlatest	.req	x14
	rstack	.req	x7
	# w8 is used in syscall ABI
	rrstack	.req	x9

	latest_word	= 0

# Initialization
_start:
	mov	rwork, xzr
	mov	rtop, xzr
	mov	rstate, xzr
	mov	rlatest, last
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
	.align	16
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
	add	rpc, xzr, rwork, lsl 3
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
	stp	x0, x1, [sp, -16]!
	stp	x2, x8, [sp, -16]!

	dup_
	mov	x2, 0x1
	add	x1, rstack, 8
	mov 	x0, 0x1
	mov	w8, 0x40
	svc	0

	drop_
	drop_
	
	ldp	x2, x8, [sp], 16
	ldp	x0, x1, [sp], 16

	ret


# BYE
# Exit to OS
.align	4
_bye_str0:
	.byte	_bye_strend - _bye_str
_bye_str:
	.ascii	"bye"
_bye_strend:
	.p2align	4, 0x00
	.quad	_bye_str0
	.quad	latest_word
bye:
	latest_word = .
	latest_name = _bye
	.quad	_call, _bye
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
	.quad	word1
	.quad	dup
	.quad	drop
	.quad	bye

# LATEST
	.equ	last, 0
#latest_word
.align	4
here0:
	.rep	0x10
	.quad	0
	.endr

