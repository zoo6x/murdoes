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
	lea	rlatest, last
	lea	rhere, here0
_abort:
	xor	rtop, rtop
	xor	rstate, rstate
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
_run:
	mov	rstate, INTERPRETING
_forth:
_exec:
	push	rpc
	mov	rpc, [rwork + rstate * 8 - 16 + 8]
	jmp	rnext
_does:
	mov	qword ptr [rstack0 + rstack * 8], rtop
	dec	rstack
	mov	rtop, rwork
	push	rpc
	mov	rpc, [rwork + rstate * 8 - 16 + 8]
	jmp	rnext
_comp:
	mov	rwork, [rwork + rstate * 8 - 16 + 8]
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
	.ifc "\does", "forth"
		.quad	_run
	.else
		.quad	_\does
	.endif
	.ifc	"\param",""
		.quad	\name
	.else
		.quad	\param
	.endif
.else
	.quad	_comp
	.ifc	"\param",""
		.quad	\name
	.else
		.quad	\param
	.endif
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

# Words
.p2align	4, 0x90

# DUMMY
# For breakpoints
word	dummy
_dummy:
	ret

# EXIT
# Exit current Forth word and return the the caller
word	exit,,, exit, 0

# DUP ( a -- a a )
word	dup
_dup:
	mov	[rstack0 + rstack * 8], rtop
	dec	rstack
	ret

# DROP ( a -- )
word	drop
_drop:
	inc	rstack
	mov	rtop, [rstack0 + rstack * 8]
	ret

# LIT ( -- n )
# Pushes compiled literal onto data stack
word	lit
_lit:
	call	_dup
	lodsq
	mov	rtop, rax
	ret

# LITERAL ( n -- ) IMMEDIATE
# Compiles a literal
word	literal,, immediate, forth
_literal:
	.quad	compile, lit
	.quad	comma
	.quad	exit

# BRANCH ( -- )
# Changes PC by compiled offset (in cells)
word	branch
_branch:
	lodsq
	lea	rpc, [rpc + rwork * 8]
	ret

# ?BRANCH ( -- )
# Changes PC by compiled offset (in cells) if top element is not zero
word	qbranch, "?branch"
_qbranch:
	lodsq
	test	rtop, rtop
	jz	9f

	lea	rpc, [rpc + rwork * 8]

	9:
	call	_drop
	ret

# COMPILE ( -- )
# Compiles the next address in the threaded code into current definition
word	compile
_compile:
	lodsq
	stosq
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
	cmp	rtop, 0x0	# ^D
	jne	9f
	jmp	_bye

	9:
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
	call	_drop
	mov	rsi, rtop
	mov	rax, 0x1
	mov	rdi, 0x1
	syscall

	pop	rdi
	pop	rsi
	
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

	call	_dup
	mov	rtop, 0xa
	call	_emit
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
	inc	rtop
	call	_dup
	movzx	rtop, byte ptr [rwork]
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

	call	_dup
	1:
	call	_drop
	push	rtmp
	call	_read
.ifdef	DEBUG
	call	_dup
	call	_emit
.endif
	pop	rtmp
	cmp	rtop, rbx
	je	1b
	cmp	rtop, 0xa
	je	7f
	cmp	rtop, 0x9
	je	2f
	jmp	5f

	2:
	cmp	rbx, 0x20
	je	1b
	jmp	5f

	3:
	push	rtmp
	call	_read
.ifdef	DEBUG
	call	_dup
	call	_emit
.endif
	pop	rtmp
	cmp	rtop, rbx
	je	7f
	cmp	rtop, 0xa
	je	7f
	cmp	rtop, 0x9
	je	4f
	jmp	5f

	4:
	cmp	rbx, 0x20
	je	7f

	5:
	mov	rax, rtop
	stosb
	inc	rtmp
	call	_drop
	jmp	3b

	7:
	pop	rdi

	mov	al, dl
	mov	rtmp, qword ptr [_tib]
	push	rtmp
	mov	byte ptr [rtmp], al

	pop	rtop

	pop	rbx
	ret

# CFA-ALLOT ( -- )
# Creates a default multi-CFA section at HERE
word	cfa_allot, "cfa-allot"
_cfa_allot:
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

	add	rhere, rtmp
	call	_align

	mov	qword ptr [rhere], rwork	# NFA
	add	rhere, 8
	mov	qword ptr [rhere], rlatest	# LFA
	add	rhere, 8

	call	_cfa_allot
	call	_drop

	mov	rlatest, rhere	# XT

	jmp	9f

	6:
	lea	rtop, qword ptr [_header_errm]
	call	_count
	call	_type
	jmp	_abort

	call	_drop
	call	_drop

	9:
	ret

_header_errm:
	.byte _header_errm$ - _header_errm - 1
	.ascii	"\r\n\x1b[31mERROR! \x1b[0m\x1b[7m\x1b[1m\x1b[33m Refusing to create word header with empty name \x1b[0m\r\n"
_header_errm$:


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

# [ ( -- ) IMMEDIATE
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

# (INTERPRETING) IMMEDIATE
# Switches address interpreter state to INTERPRETING
word	interpreting_, "(interpreting)", immediate
_interpreting_:
	mov	rstate, INTERPRETING
	ret

# DOES ( param code state xt -- )
# Sets semantics for a word defined by XT for given state to a given code:param pair
word	does
_does1:
	mov	rwork, rtop
	call	_drop
	mov	rtmp, rtop
	call	_drop

	mov	qword ptr [rwork + rtmp * 8 - 16], rtop
	call	_drop
	mov	qword ptr [rwork + rtmp * 8 - 16 + 8], rtop
	call	_drop

	ret

# IMMEDIATE ( -- )
# Sets latest ord's compilation semantics to execution semantics
word	immediate
_immediate:
	mov	rwork, rlatest
	lea	rtmp, _run
	mov	[rwork + COMPILING * 8 - 16], rtmp
	mov	rtmp, [rwork + INTERPRETING * 8 - 16 + 8]
	mov	[rwork + COMPILING * 8 - 16 + 8], rtmp
	ret

# CODEWORD ( xt -- )
# Specifies execution semantics for a word specified by XT as a code word
word	codeword, "code",, forth
_codeword:
	.quad	here
	.quad	lit, _code
	.quad	lit, INTERPRETING
	.quad	latest
	.quad	does

	.quad	here
	.quad	lit, _comp
	.quad	lit, COMPILING
	.quad	latest
	.quad	does

	.quad	exit

# FORTHWORD ( xt -- )
# Specifies execution semantics for a word specified by XT as a forth word with threaded code following at HERE
word	forthword,,, forth
_forthword:
	.quad	here
	.quad	lit, _exec
	.quad	lit, INTERPRETING
	.quad	latest
	.quad	does

	.quad	here
	.quad	lit, _comp
	.quad	lit, COMPILING
	.quad	latest
	.quad	does

	.quad	exit

# :: ( "<name>" -- )
# Synonym for HEADER
word	coloncolon, "::",, forth
_coloncolon:
	.quad	header
	.quad	exit

# (CREATE) ( -- xt )
# Pushes XT of the word being executed into stack
word	_create_, "(create)"
__create_:
	call	_dup
	mov	rtop, rwork
	jmp	rnext

# CREATE ( "<name> -- ) ( -- xt )
# Creates a new definition, which pushes XT in the stack
word	create,,, forth
_create:
	.quad	header

	.quad	here
	.quad	lit, __create_
	.quad	lit, INTERPRETING
	.quad	latest
	.quad	does

	.quad	here
	.quad	lit, _comp
	.quad	lit, COMPILING
	.quad	latest
	.quad	does
	.quad	exit

# (DOES>XT)
# Internal word that fixes HERE address, depends on DOES> implementation
word	_does_xt_, "(does>xt)"
__does_xt_:
	add	rtop, 3 * 8
	ret

# (DOES>) ( xt -- )
# Defines execution and compilation semantics for the latest word
word	_does_, "(does>)",, forth
__does_:
	.quad	_does_xt_

	.quad	lit, _does	
	.quad	lit, INTERPRETING
	.quad	latest
	.quad	does

	.quad	latest
	.quad	lit, _comp
	.quad	lit, COMPILING
	.quad	latest
	.quad	does

	.quad	exit

# DOES> ( -- ) IMMEDIATE
# Defines defining word
word	does_, "does>", immediate, forth
_does1_:
	.quad	compile, lit
	.quad	here, comma
	.quad	compile, _does_	
	.quad	compile, exit
	.quad	exit

# : ( "<name>" -- )
# Creates a Forth word
word	colon, ":",, forth
_colon:
	.quad	header
	.quad	forthword
	.quad	bracket_close
	.quad	exit

# ; ( -- ) IMMEDIATE
# Finished Forth definition
word	semicolon, "\x3b", immediate, forth
_semicolon:
	.quad	compile, exit
	.quad	bracket_open
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
	call	_bl_
	call	_word
	call	_count
	or	rtop, rtop
	jz	7f
	call	_drop
	call	_drop
	call	_find
	test	rtop, rtop
	jz	2f
	mov	rwork, rtop
	call	_drop

	mov	rstate, qword ptr [_state]

	pop	rtmp
	jmp	_doxt

	2:
	mov	rtop, qword ptr [_tib]
	call	_number
	test	rtop, rtop
	jz	6f

	call	_drop
	# TODO: Explicit STATE check in NUMBER, move to compilation CFA
	cmp	qword ptr [_state], COMPILING
	jne	9f

	lea	rax, qword ptr [lit]
	stosq
	mov	rax, rcx
	stosq
	call	_drop

	jmp	9f

	6:
	lea	rtop, qword ptr [_quit_errm1]
	call	_count
	call	_type
	call	_dup
	mov	rtop, qword ptr [_tib]
	call	_count
	call	_type
	call	_dup
	lea	rtop, qword ptr [_quit_errm2]
	call	_count
	call	_type
	jmp	_abort

	7:
	call	_drop
	call	_drop

	9:
	ret
_quit_errm1:
	.byte _quit_errm1$ - _quit_errm1 - 1
	.ascii	"\r\n\x1b[31mERROR! \x1b[0m\x1b[33mWord \x1b[1m\x1b[7m "
_quit_errm1$:
_quit_errm2:
	.byte _quit_errm2$ - _quit_errm2 - 1
	.ascii	" \x1b[27m\x1b[22m not found, or invalid hex number\x1b[0m\r\n"
_quit_errm2$:

# QUIT
# Interpret loop
word	quit,,, forth
	.quad	quit_
	.quad	interpreting_
	.quad	qcsp
	.quad	branch, -5

# ?CSP ( -- )
# Aborts on stack underflow
word	qcsp, "?csp"
_qcsp:
	cmp	rstack, 0
	jle	9f

	lea	rtop, qword ptr [_qcsp_errm]
	call	_count
	call	_type
	jmp	_abort

	9:
	ret
_qcsp_errm:
	.byte _qcsp_errm$ - _qcsp_errm - 1
	.ascii	"\r\n\x1b[31mERROR! \x1b[33m\x1b[7m Stack underflow \x1b[0m\r\n"
_qcsp_errm$:

# .\ ( "ccc<EOL>" -- )
# Prints string till the end of line
word	dot_comment, ".\\"
_dot_comment:
	call	_dup
	mov	rtop, 0
	call	_word
	call	_count
	call	type
	ret

# DUMP ( a u -- )
# Prints hexadecimal bytes at address
word	dump
_dump:
	mov	rtmp, rtop	# count
	call	_drop
	mov	rwork, rtop	# address

	1:
	test	rtmp, rtmp
	jz	9f

	call	_dup
	movzx	rtop, byte ptr [rwork]
	push	rwork
	push	rtmp
	call	_dot
	pop	rtmp
	pop	rwork
	dec	rtmp
	inc	rwork
	jmp	1b

	9:
	call	_drop
	ret

# BYE
# Returns to OS
word	bye
_bye:
	mov	rdi, 42
	mov	rax, 60
	syscall

# COLD
# Cold start (in fact, just a test word that runs first)
word	cold,,, forth
_cold:
	.quad	quit
	.quad	bye

# LATEST
	.equ	last, latest_word
.align	16
here0:
	.rep	0x4000
	.quad	0
	.endr
