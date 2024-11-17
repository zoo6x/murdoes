.intel_syntax	noprefix

# TODO: https://wiki.osdev.org/X86-64_Instruction_Encoding
# https://www.complang.tuwien.ac.at/forth/fth79std/FORTH-79.TXT
# https://www.complang.tuwien.ac.at/forth/fth83std/FORTH83.TXT
# https://forth-standard.org/standard/words

	.globl _start

.text
	.equ	STATES, 16	/* Number of possible address interpreter states */
	.equ	INTERPRETING, 0
	.equ	COMPILING, -2

	/* Before changing register assignment check usage of low 8-bit parts of these registers: al, bl, cl, dl, rXl etc. */
	/* TODO: define low byte aliases for needed address interpreter regsters */
	.equ	rwork, rax	/* Points to XT in code words. Needs not be preserved */
	.equ	rtop, rcx
	.equ	rstate, rbx
	.equ	rtmp, rdx	/* Needs not be preserved */
	.equ	rpc, rsi	/* Do not change! LODSx instructions are used */
	.equ	rhere, rdi	/* Do not change! STOSx instructions are used */
	.equ	rnext, r13
	.equ	rlatest, r14
	.equ	rstack, rbp
	.equ	rstack0, r15

# Initialization

_start:
	xor	rtop, rtop
	xor	rstate, rstate
	lea	rlatest, last
	lea	rhere, here0
	lea	rpc, qword ptr [_cold]
	lea	rnext, qword ptr [_next]
	/* TODO: In "hardened" version map stacks to separate pages, with gaps between them */
	lea	rstack0, [rsp - 0x1000]
	xor	rstack, rstack
	lea	rwork, [rsp - 0x2000]
	mov	qword ptr [_tib], rwork
	xor	rwork, rwork
	push	rpc

# Address Interpreter and Compiler

_exit:
	pop	rpc
_next:
	lodsq
_doxt:
	jmp	[rwork + rstate * 8 - 16]
_code:
_call:
	push	rnext
	jmp	[rwork + rstate * 8 - 16 + 8]	
_forth:
_exec:
	push	rpc
	mov	rpc, [rwork + rstate * 8 - 16 + 8]
	jmp	rnext
_comp:
	stosq
	jmp	rnext
_noop:
	ret

	.p2align	3, 0x90
_state:
	.quad	INTERPRETING

_tib:
	.quad	0

# Word definition

	latest_word	= 0

.macro	reserve_cfa does, reserve=(STATES - 2)
	# Execution semantics can be either code or Forth word
	# Compilation semantics inside Forth words is the same: compile adress of XT
	# Semantics for other states does nothing by default
	.rept \reserve
	.quad	_call, _noop
	.endr
.endm

.macro	word	name, fname, immediate, does=code, param
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
	.quad	\name\()_str0	/* NFA */
	.quad	latest_word	/* LFA */

	reserve_cfa

	# COMPILATION
.ifc	"\immediate", "immediate"
	.quad	_\does
	.ifc	"\param",""
		.quad	\name
	.else
		.quad	\param
	.endif
.else
	.quad	_comp, 0
.endif

	# INTERPRETATION
	.quad	_\does
.ifc	"\param",""
	.quad	\name
.else
	.quad	\param
.endif


	# TODO: Add a "canary"/hash to make sure an XT is actually an XT
\name\():
	latest_word = .
	latest_name = _\name
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
word	exit,,, exit, 0

# DUP ( a -- a a )
word	dup
_dup:
	store	rtop, 1
	dec	rstack
	ret

# DROP ( a -- )
word	drop
_drop:
	inc	rstack
	load	rtop, 1
	ret

# LIT ( -- n )
# Pushes compiled literal onto data stack
word	lit
_lit:
	call	_dup
	lodsq
	mov	rtop, rax
	ret

# JUMP ( -- )
# Changes PC by compliled offset (in cells)
word	jump
_jump:
	lodsq
	lea	rpc, [rpc + rwork * 8]
	ret

# ALIGN
# Aligns HERE to 16-byte boundary
word	align
_align:
	add	rhere, 0xf
	and	rhere, -16
	ret

# EMIT ( c -- )
# Prints a character to stdout
word	emit
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
_words:
	push	rtop
	push	rsi
	push	rdi

	mov	rtmp, rlatest

	1:
	test	rtmp, rtmp
	jz	9f

	push	rtmp					# current word

	mov	rwork, [rtmp - STATES * 16 - 16]	# NFA
	movzx	rtmp, byte ptr [rwork]			# count
	lea	rsi, [rwork + 1]			# buffer
	mov	rdi, 1					# stdout
	mov	rax, 1					# sys_write
	syscall

	call	_dup
	mov	rtop, 0x20
	call	_emit

	pop	rtmp
	mov	rtmp, [rtmp - STATES * 16 - 8]		# LFA
	jmp	1b

	9:
	pop	rdi
	pop	rsi
	pop	rtop
	ret

# BL ( -- c )
# Returns blank character code
word	bl_, "bl"
_bl_:
	call	_dup
	mov	rtop, 0x20
	ret

# , ( v -- )
# Reserve space for one cell in the data space and store value in the pace
word	comma, ","
_comma:
	mov	rax, rtop
	stosq
	call	_drop
	ret

# C, ( c -- )
# Reserve space for one character in the data space and store char in the space
word	c_comma, "c,"
_c_comma:
	mov	rax, rtop
	stosb
	call	_drop
	ret

# COUNT ( c-addr -- c-addr' u )
# Converts address to byte-counted string into string address and count
word	count
_count:
	mov	rwork, rtop
	#TODO: Looks wrong, seems to damage 2nd element in the stack
	inc	rwork
	store	rwork, 1
	dec	rstack
	movzx	rtop, byte ptr [rtop]
	ret

# WORD ( c "<chars>ccc<char>" -- c-addr )
# Reads char-separated word from stdin, places it as a byte-counted string at TIB
word	word,,, code, _word
_word:
	mov	rtmp, qword ptr [_tib]
	push	rbx

	mov	rbx, rtop
	call	_drop

	push	rdi
	mov	rdi, rtmp
	mov	rtmp, 0
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
	inc	rtmp
	call	_drop
	jmp	1b

	2:
	pop	rdi

	mov	al, dl
	mov	rtmp, qword ptr [_tib]
	push	rtmp
	mov	byte ptr [rtmp], al

	pop	rtop

	pop	rbx
	ret

# HEADER ( "<name>" -- ) : ( -- )
# Reads word name from input stream and creates a default header for the new word. The new word does nothing
word	header
_header:
	call	_bl_		# ( bl )
	call	_word		# ( here ) 
	call	_dup		# ( here here )
	call	_count		# ( here here+1 count ) 
	test	rtop, rtop
	jz	6f

	push	rsi
	mov	rtmp, rtop	# count
	inc	rtmp
	mov	rsi, qword ptr [_tib]

	call	_drop
	call	_drop
	mov	rcx, rtmp
	call	_align
	mov	rwork, rhere
	rep	movsb		# copy name from TIB to HERE

	pop	rsi

	0:
	add	rhere, rtmp
	call	_align

	mov	qword ptr [rhere], rwork	# NFA
	add	rhere, 8
	mov	qword ptr [rhere], rlatest	# LFA
	add	rhere, 8

	mov	rcx, 16
	lea	rtmp, qword ptr [_call]
	lea	rwork, qword ptr [_noop]

	1:
	mov	qword ptr [rhere], rtmp
	add	rhere, 8
	mov	qword ptr [rhere], rwork
	add	rhere, 8
	dec	rcx
	jnz	1b

	call	_drop

	mov	rlatest, rhere	# XT

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
_latest:
	call	_dup
	mov	rtop, rlatest
	ret

# HERE ( -- a )
# Returns address of the first available byte of the code space
word	here
_here:
	call	_dup
	mov	rtop, rhere
	ret

# [ ( -- )
# Switches text interpreter STATE to INTERPRETING
word	bracket_open, "[", immediate
_bracket_open:
	mov	qword ptr [_state], INTERPRETING
	ret

# ] ( -- )
# Switches text interpterer STATE to COMPILING
word	bracket_close, "]"
_bracket_close:
	mov	qword ptr [_state], COMPILING
	ret

# (INTERPRETING)
# Switches address interpreter state to INTERPRETING
word	interpreting_, "(interpreting)", immediate
_interpreting_:
	mov	rstate, INTERPRETING
	ret

# DOES ( code param state xt -- )
# Sets semantics for a word defined by XT for given state to a given code:param pair
word	does
_does:
	mov	rwork, rtop
	call	_drop
	mov	rtmp, rtop
	call	_drop

	mov	qword ptr [rwork + rtmp * 8 - 16 + 8], rtop
	call	_drop
	mov	qword ptr [rwork + rtmp * 8 - 16], rtop
	call	_drop

	ret

# CODEWORD ( xt -- )
# Specifies execution semantics for a word specified by XT as a code word
word	codeword,,, forth
_codeword:
	.quad	lit, _code
	.quad	here
	.quad	lit, 0
	.quad	latest
	.quad	does
	.quad	exit

# FORTHWORD ( xt -- )
# Specifies execution semantics for a word specified by XT as a forth word with threaded code following at HERE
word	forthword,,, forth
_forthword:
	.quad	lit, _exec
	.quad	here
	.quad	lit, 0
	.quad	latest
	.quad	does
	.quad	exit

# :: ( "<name>" -- )
# Synonym for HEADER
word	coloncolon, "::",, forth
_coloncolon:
	.quad	header
	.quad	exit

# : ( "<name>" -- )
# Creates a Forth word
word	colon, ":",, forth
_colon:
	.quad	header
	.quad	forthword
	.quad	exit

# FIND ( -- xt | 0 )
# Searches for word name, placed at TIB, in the vocabulary
word	find
_find:
	call	_dup

	push	rsi
	push	rdi
	push	rbx

	mov	rtmp, rlatest
	mov	rbx, qword ptr [_tib]

	1:
	test	rtmp, rtmp
	jz	6f

	mov	rsi, rbx

	mov	rwork, [rtmp - STATES * 16 - 16]	# NFA
	movzx	rcx, byte ptr [rwork]
	inc	rcx
	mov	rdi, rwork
	rep	cmpsb
	mov	rtop, rtmp
	je	9f

	mov	rtmp, [rtmp - STATES * 16 - 8]		# LFA
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
_dot:
	mov	rtmp, 16

	1:
	rol	rtop, 4
	test	rtop, 0xf
	jnz	3f
	dec	rtmp
	jnz	1b

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
	call	_bl_
	call	_emit
	ret

# (QUIT) ( -- )
# Read one word from input stream and interpret it
word	quit_, "(quit)"
_quit_:
	/*
	call	_dup
	mov	rtop, rstack
	call	_dot
	call	_dup
	mov	rtop, rsp
	call	_dot
	*/
	call	_bl_
	call	_word
	call	_drop
	call	_find
	test	rtop, rtop
	jz	2f
	mov	rwork, rtop
	call	_drop

	#push	rstate
	mov	rstate, qword ptr [_state]

	#push	rnext
	#lea	rnext, qword ptr [_quit_ret]
	pop	rtmp
	jmp	_doxt

_quit_ret:
	pop	rnext
	pop	rstate

	jmp	9f

	2:
	mov	rtop, qword ptr [_tib]
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
word	quit,,, forth
	.quad	quit_
	.quad	interpreting_
	.quad	jump, -4

# BYE
# Returns to OS
word	bye
_bye:
	mov	rdi, 42

	mov	rax, 60
	syscall

word	word1,,, forth
_word1:
	.quad	lit, 0x41, emit
	.quad	word2
	.quad	exit	
			
word	word2,,, forth
_word2:
	.quad	lit, 0x42, emit
	.quad	exit

# COLD
# Cold start (in fact, just a test word that runs first)
word	cold,,, forth
_cold:
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
