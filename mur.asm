.intel_syntax	noprefix

	.globl _start

.text

	# Beore changing register assignment check usage of low 8-bit parts of these registers: al, bl, cl, dl, rXl etc.
	.equ	rwork, rax	# Points to XT in code words. Needs not be preserved
	.equ	rtop, rcx
	.equ	rstate, rbx
	.equ	rtmp, rdx	# Needs not be preserved
	.equ	rpc, rsi	# Do no change! LODSx instructions are used
	.equ	rhere, rdi	# Do not change! STOSx instructions are used
	.equ	rnext, r13
	.equ	rlatest, r14
	.equ	rstack, rbp
	.equ	rstack0, r15

	latest_word	= 0

# Initialization
_start:
	xor	rtop, rtop
	xor	rstate, rstate
	lea	rlatest, last
	lea	rhere, here0
	lea	rpc, qword ptr [$cold]
	lea	rnext, qword ptr [_next]
	lea	rstack0, [rsp - 0x1000]
	xor	rstack, rstack
	push	rpc

# Address Interpreter
_exit:
	pop	rpc
_noop:
_next:
	lodsq
_doxt:
	jmp	[rwork + rstate * 8]
_call:
	push	rnext
	jmp	[rwork + rstate * 8 + 8]	
_exec:
	push	rpc
	mov	rpc, [rwork + rstate * 8 + 8]
	jmp	_next

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
	.quad	\name\()_str0	# NFA
	.quad	latest_word	# LFA
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

# Data stack access
.macro	load	reg, i
	mov	\reg, qword ptr [rstack0 + rstack * 8 + 8 * (\i - 1)]
.endm

.macro	store	regval, i
	mov	qword ptr [rstack0 + rstack * 8 + 8 * (\i - 1)], \regval
.endm


# Words
.p2align	4, 0x90

# EXIT
# Exit current Forth word and return the the caller
word	exit
	.quad	_exit, 0
	reserve_cfa

# DUP ( a -- a a )
word	dup
	.codeword
_dup:
	store	rtop, 1
	dec	rstack
	ret

# DROP ( a -- )
word	drop
	.codeword
_drop:
	inc	rstack
	load	rtop, 1
	ret

# LIT ( -- n )
# Pushes compiled literal onto data stack
word	lit
	.codeword
_lit:
	call	_dup
	lodsq
	mov	rtop, rax
	ret

# JUMP ( -- )
# Changes PC by compliled offset (in cells)
word	jump
	.codeword
_jump:
	lodsq
	lea	rpc, [rpc + rwork * 8]
	ret

# ALIGN
# Aligns HERE to 16-byte boundary
word	align
	.codeword
_align:
	add	rhere, 0xf
	and	rhere, -16
	ret

# EMIT ( c -- )
# Prints a character to stdout
word	emit
	.codeword
_emit:
	push	rtop
	push	rwork
	push	rdx
	push	rsi
	push	rdi
	
	mov	rwork, rtop
	push	rax
	mov	rdx, 0x1	# count
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
	
	call	_drop

	ret

# READ ( -- c )
# Reads a character from stdin
word	read
	.codeword
_read:
	call	_dup

	push	rsi
	push	rdi

	xor	rwork, rwork
	push	rwork
	mov	rdx, 0x1	# count
	mov	rsi, rsp	# buffer
	mov 	rdi, 0x0	# stdin
	mov	rax, 0x0	# sys_read
	syscall
	pop	rtop

	pop	rdi
	pop	rsi
	ret

# TYPE ( c-addr u -- )
# Print string to stdout
word	type
	.codeword
_type:
	push	rsi
	push	rdi

	mov	rtmp, rtop	# count
	load	rsi, 1		# buffer
	mov	rax, 0x1
	mov	rdi, 0x1
	syscall

	pop	rdi
	pop	rsi
	
	call	_drop
	call	_drop

	ret

# WORDS
# Prints all defined words to stdout
word	words
	.codeword
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

	call	_dup
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

# BL ( -- c )
# Returns blank character code
word	bl
	.codeword
_bl:
	call	_dup
	mov	rtop, 0x20
	ret

# , ( v -- )
# Reserve space for one cell in the data space and store value in the pace
word	comma, ","
	.codeword
_comma:
	mov	rax, rtop
	stosq
	call	_drop
	ret

# C, ( c -- )
# Reserve space for one character in the data space and store char in the space
word	c_comma, "c,"
	.codeword
_c_comma:
	mov	rax, rtop
	stosb
	call	_drop
	ret

# COUNT ( c-addr -- c-addr' u )
# Converts address to byte-counted string into string address and count
word	count
	.codeword
_count:
	mov	rwork, rtop
	#TODO: Looks wrong, seems to damage 2nd element in the stack
	inc	rwork
	store	rwork, 1
	dec	rstack
	movzx	rtop, byte ptr [rtop]
	ret

# WORD ( c "<chars>ccc<char>" -- c-addr )
# Reads char-separated word from stdin, places it as a byte-counted string at HERE, aligns HERE at 16 bytes before that
word	word
	.codeword
_word:
	call	_align
	mov	rtmp, rhere
	push	rbx

	mov	rbx, rtop
	call	_drop

	xor	al, al
	stosb
	1:
	push	rtmp
	call	_read
	pop	rtmp
	cmp	rtop, rbx
	je	2f
	cmp	rtop, 0xa
	je	2f
	cmp	rtop, 0x9
	je	2f
	mov	rax, rtop
	stosb
	call	_drop
	jmp	1b

	2:
	mov	rwork, rhere
	sub	rwork, rtmp
	dec	rwork
	mov	byte ptr [rtmp], al	

	mov	rhere, rtmp

	mov	rtop, rhere

	pop	rbx
	ret

# HEADER ( "<name>" -- ) : ( -- )
# Reads word name from input stream and creates a default header for the new word. The new word does nothing
word	header
	.codeword
_header:
	call	_bl		# ( bl )
	call	_word		# ( here ) 
	call	_dup		# ( here here )
	call	_count		# ( here here+1 count ) 
	test	rtop, rtop
	jz	6f

	call	_drop
	call	_drop
	# TODO: ASSERT(rtop == rhere)
	cmp	rhere, rtop
	jz 0f
	int3

	0:
	movzx	rax, byte ptr [rtop] # name
	add	rhere, rax
	add	rhere, 0xf
	and	rhere, -16

	mov	qword ptr [rhere], rtop		# NFA
	add	rhere, 8
	mov	qword ptr [rhere], rlatest	# LFA
	add	rhere, 8

	mov	rwork, rhere	# XT
	mov	rlatest, rhere

	mov	rcx, 16
	lea	rtmp, qword ptr [_noop]

	1:
	mov	qword ptr [rhere], rtmp
	add	rhere, 8
	mov	qword ptr [rhere], 0
	add	rhere, 8
	dec	rcx
	jnz	1b

	call	_drop
	jmp	9f

	6:
	# TODO: ABORT
	call	_drop
	call	_drop
	call	_drop

	9:
	ret

# LATEST ( -- xt )
# Returns the latest defined word
word	latest
	.codeword
_latest:
	call	_dup
	mov	rtop, rlatest
	ret

# HERE ( -- a )
# Returns address of the first available byte of the code space
word	here
	.codeword
_here:
	call	_dup
	mov	rtop, rhere
	ret

# DOES ( code param state xt -- )
# Sets semantics for a word defined by XT for given state to a given code:param pair
word	does
	.codeword
_does:
	mov	rtmp, rtop
	call	_drop
	mov	rwork, rtop
	call	_drop

	mov	qword ptr [rtmp + rwork * 8 + 8], rtop
	call	_drop
	mov	qword ptr [rtmp + rwork * 8], rtop
	call	_drop

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

# :: ( "<name>" -- )
# Synonym for HEADER
word	coloncolon, "::"
	.forthword
_coloncolon:
	.quad	header
	.quad	exit

# : ( "<name>" -- )
# Creates a Forth word
word	colon, ":"
	.forthword
_colon:
	.quad	header
	.quad	forthword
	.quad	exit

# FIND ( -- xt | 0 )
# Searches for word name, placed at HERE, in the vocabulary
word	find
	.codeword
_find:
	call	_dup

	push	rsi
	push	rdi
	push	rbx

	mov	rtmp, rlatest
	mov	rbx, rhere

	1:
	test	rtmp, rtmp
	jz	6f

	mov	rsi, rbx

	mov	rwork, [rtmp - 16]	# NFA
	movzx	rcx, byte ptr [rwork]
	inc	rcx
	mov	rdi, rwork
	rep	cmpsb
	mov	rtop, rtmp
	je	9f

	mov	rtmp, [rtmp - 8]	# LFA
	jmp	1b

	6:
	mov	rtop, 0

	9:
	pop	rbx
	pop	rdi
	pop	rsi
	ret

# NUMBER ( c-addr -- n -1 | 0 )
# Parses string as a number (in HEX base)
word	number
	.codeword
_number:
	push	rsi
	mov	rsi, rtop
	movzx	rcx, byte ptr [rtop]
	test	rcx, rcx
	jz	6f

	xor	rtmp, rtmp
	xor	rwork, rwork
	inc	rsi
	1:
	lodsb
	cmp	al, 0x30
	jb	6f
	cmp	al, 0x39
	jbe	3f
	or	al, 0x20
	cmp	al, 0x61
	jb	6f
	cmp	al, 0x66
	ja	6f
	sub	al, 0x61 - 10
	jmp	4f
	3:
	sub	al, 0x30
	4:
	shl	rtmp, 4
	add	rtmp, rwork
	dec	rcx
	jnz	1b

	mov	rtop, rtmp
	call	_dup
	mov	rtop, -1
	jmp	9f

	6:
	mov	rtop, 0

	9:
	pop	rsi
	ret

# . ( n -- )
# Print number on the top of the stack (hexadecimal)
word	dot, "."
	.codeword
_dot:
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
	ret

# (QUIT) ( -- )
# Read one word from input stream and interpret it
word	quit_, "(quit)"
	.codeword
_quit_:
	call	_bl
	call	_word
	call	_drop
	call	_find
	test	rtop, rtop
	jz	2f
	mov	rwork, rtop
	call	_drop

	pop	rtmp
	jmp	_doxt

	2:
	call	_drop
	call	_here
	call	_number
	test	rtop, rtop
	jz	6f

	call	_drop
	jmp	9f

	6:
	# TODO: ABORT
	call	_drop
	9:
	ret

# QUIT
# Interpret loop
word	quit
	.forthword
_quit:
	.quad	quit_
	.quad	jump, -3

# BYE
# Returns to OS
word	bye
	.codeword
_bye:
	mov	rdi, 42

	mov	rax, 60
	syscall

word	word1
	.forthword
$word1:
	.quad	lit, 0x41, emit
	.quad	word2
	.quad	exit	
			
word	word2
	.forthword
$word2:
	.quad	lit, 0x42, emit
	.quad	exit

# COLD
# Cold start (in fact, just a test word that runs first)
word	cold
	.forthword
$cold:
	#.quad	words
	.quad	lit, 0x39
	.quad	lit, 0x38
	.quad	lit, 0x37
	.quad	lit, 0x36
	.quad	lit, 0x35
	.quad	lit, 0x34
	.quad	lit, 0x33
	.quad	emit
	.quad	lit, 0x3e, emit
	.quad	quit
	.quad	lit, 0x21, emit
	.quad	word1
	.quad	word2
	.quad	bye

# LATEST
	.equ	last, latest_word
.align	16
here0:
	.rep	0x4000
	.quad	0
	.endr
