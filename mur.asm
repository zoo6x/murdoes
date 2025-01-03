.intel_syntax	noprefix

# TODO: https://wiki.osdev.org/X86-64_Instruction_Encoding
# https://github.com/chip-red-pill/uCodeDisasm
# https://stackoverflow.com/questions/48046814/what-methods-can-be-used-to-efficiently-extend-instruction-length-on-modern-x86
# https://stackoverflow.com/questions/36510095/inc-instruction-vs-add-1-does-it-matter
# https://groups.google.com/g/llvm-dev/c/xwcJKiLcgnU?pli=1 Spilling to vector registers for LLVM
# https://www.forwardcom.info/
# https://jacobfilipp.com/DrDobbs/articles/DDJ/1988/8810/8810b/8810b.htm
# https://www.complang.tuwien.ac.at/forth/fth79std/FORTH-79.TXT
# https://www.complang.tuwien.ac.at/forth/fth83std/FORTH83.TXT
# https://forth-standard.org/standard/words
# https://www.mpeforth.com/resource-links/downloads/
# https://iforth.nl/
# TODO: Benchmarks
# https://github.com/quepas/Compiler-benchmark-suites
# https://github.com/embench/embench-iot/
# https://gist.github.com/FredEckert/3425429  Writing to framebuffer directly
# http://liujunming.top/2019/10/22/libdrm-samples/
# https://dvdhrm.wordpress.com/2012/09/13/linux-drm-mode-setting-api/
# https://gist.github.com/uobikiemukot/c2be4d7515e977fd9e85
	.globl _start

.text
	.equ	STATES, 16	/* Number of possible address interpreter states */
	.equ	INTERPRETING, 0
	.equ	COMPILING, -2
	.equ	DECOMPILING, -4

				/* Before changing register assignment check usage of low 8-bit parts of these registers: al, bl, cl, dl, rXl etc. */
				/* TODO: define low byte aliases for needed address interpreter regsters */
	.equ	rwork, rax	/* Points to XT in code words. Needs not be preserved */
	.equ	rtop, rcx
	.equ	rstate, rbx
	.equ	rtmp, rdx	/* Needs not be preserved */
	.equ	rpc, rsi	/* Do not change! LODSx instructions are used */
	.equ	rstack, rbp
	.equ	rhere, rdi	/* Do not change! STOSx instructions are used */
	.equ	rindex, r10	/* Loop end and index values */
				/* R11 is clobbered by syscalls ix x64 Linux ABI */
	.equ	rend, r12
	.equ	rnext, r13
	.equ	rstack0, r15

# Initialization

.p2align	16, 0x90
_start:
	lea	rwork, last
	mov	[forth_], rwork
	lea	rwork, [forth_]
	mov	[_current], rwork
	mov	[_context], rwork
	lea	rhere, here0
_abort:
_cold:
	xor	rtop, rtop
	xor	rstate, rstate
	mov	[_state], rstate
	lea	rpc, qword ptr [_warm]
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
.ifdef DEBUG
.ifdef TRACE
	cmp	qword ptr [_trace], 0
	jz	1f
	call	_dup
	mov	rtop, rstack
	push	rtmp
	push	rwork
	call	_dot
	pop	rwork
	call	_dup
	mov	rtop, rstate
	push	rwork
	call	_dot
	pop	rwork
	call	_dup
	mov	rtop, rwork
	push	rwork
	call	_decomp_print
	pop	rwork
	call	_dup
	mov	rtop, 0x1b
	call	_emit
	call	_dup
	mov	rtop, 0x5b
	call	_emit
	call	_dup
	mov	rtop, 0x33
	call	_emit
	call	_dup
	mov	rtop, 0x39
	call	_emit
	call	_dup
	mov	rtop, 0x47
	call	_emit
	call	_drop
	push	rwork
	call	dot_s
	pop	rwork
	call	_dup
	mov	rtop, 0xa
	call	_emit
	pop	rtmp
	1:
.endif
.endif
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
_interp:
	lea	rnext, qword ptr [_next]
	mov	rstate, INTERPRETING
	mov	qword ptr [_state], INTERPRETING
	jmp	rnext

	.p2align	3, 0x90
_state:
	.quad	INTERPRETING
_current:
	.quad	0
_context:
	.quad	0
_trace:
	.quad	0

_state_notimpl:
	push	rstate
	push	rwork

	call	_dup
	lea	rtop, qword ptr [_state_notimpl_errm1]
	call	_count
	call	_type
	
	pop	rwork
	
	call	_dup
	mov	rwork, [rwork - STATES * 16 - 16]	/* XT > NFA */
	mov	rtop, rwork
	call	_count
	call	_type

	call	_dup
	lea	rtop, qword ptr [_state_notimpl_errm2]
	call	_count
	call	_type

	pop	rstate

	call	_dup
	mov	rtop, rstate
	call	_dot

	call	_dup
	lea	rtop, qword ptr [_state_notimpl_errm3]
	call	_count
	call	_type

.ifdef	DEBUG
	call	_bye
.endif
	jmp	_abort

	9:
	ret
_state_notimpl_errm1:
	.byte _state_notimpl_errm1$ - _state_notimpl_errm1 - 1
	.ascii	"\r\n\x1b[31mERROR! \x1b[0m\x1b[33mWord \x1b[1m\x1b[7m "
_state_notimpl_errm1$:

_state_notimpl_errm2:
	.byte _state_notimpl_errm2$ - _state_notimpl_errm2 - 1
	.ascii	" \x1b[0m does not implement state \x1b[7m "
_state_notimpl_errm2$:

_state_notimpl_errm3:
	.byte _state_notimpl_errm3$ - _state_notimpl_errm3 - 1
	.ascii	"\x1b[0m\r\n"
_state_notimpl_errm3$:

_tib:
	.quad	0

# Word definition

	latest_word	= 0

.macro	reserve_cfa does, reserve=(STATES - 3)
	# Execution semantics can be either code or Forth word

	# Compilation semantics inside Forth words is the same: compile adress of XT
	# Semantics for other states does nothing by default
	.rept \reserve
	.quad	_state_notimpl, 0
	.endr
.endm

.macro	word	name, fname, immediate, does=code, param, decomp, decomp_param, regalloc, regalloc_param
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

	# DECOMPILING
.ifc "\decomp", ""
	.ifc "\does", "forth"
		.quad	_decomp
		.quad	0
	.else
		.quad	_decomp_code
		.quad	0
	.endif
.else
	.quad	\decomp
	.quad	\decomp_param
.endif

	# COMPILING
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

	# INTERPRETING
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

# FORTH
# The root vocabulary
word	forth_, "forth", immediate, code, _forth_
	.quad	last
_forth_:
	mov	[_context], rwork
	ret

# DUMMY
# For breakpoints
word	dummy
_dummy:
	ret

# CURRENT ( -- v )
# Returns current vocabulary
word	current
	call	_dup
	lea	rtop, [_current]
	ret

# CONTEXT ( -- v )
# Returns context vocabulary
word	context
	call	_dup
	lea	rtop, [_context]
	ret

# LATEST ( -- xt )
# Returns XT of the latest defined word in current vocabulary
word	latest
	call	current
	mov	rtop, [rtop]
	mov	rtop, [rtop]
	ret

# TRACE
# Turn tracing on
word	trace
	mov	qword ptr [_trace], 1
	ret

# NOTRACE
word	notrace
	mov	qword ptr [_trace], 0
	ret

# EXECUTE ( xt -- )
# Executes word, specified by XT
word	execute
	mov	rwork, rtop
	call	_drop
	pop	rtmp	# Skip return address (=NEXT)

	mov	rstate, [_state]

	jmp	_doxt

# EXIT
# Exit current Forth word and return the the caller
word	exit,,, exit, exit, _decomp_exit, 0, _exit_regalloc, 0
_exit_regalloc:
	jmp	_exit

# SUMMON
# Summons Forth word from assembly
word	summon
_summon:
	push	rpc
	lea	rpc, qword ptr [forsake]
	jmp	_doxt

# RETREAT
# Retreats from Forth back into assembly
word	retreat
_retreat:
	pop	rtmp
	pop	rpc
	ret

# FORSAKE
# Forsakes Forth for assembly
word	forsake
	.quad	retreat
	.quad	exit

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

# PICK ( # -- a )
word	pick
	add	rtop, rstack
	inc	rtop
	mov	rtop, [rstack0 + rtop * 8]
	ret

# LIT ( -- n )
# Pushes compiled literal onto data stack
word	lit,,,,, _lit_decomp, 0
_lit:
	call	_dup
	lodsq
	mov	rtop, rax
	ret
_lit_decomp:
	call	_dup
	mov	rtop, rwork
	call	_decomp_print
	call	_dup
	mov	rtop, 0x9
	call	_emit

	lodsq
	call	_dup
	mov	rtop, rwork
	call	_dot
	mov	rtop, 0xa
	call	_emit
	jmp	rnext

# LITERAL ( n -- ) IMMEDIATE
# Compiles a literal
word	literal,, immediate, forth
_literal:
	.quad	compile, lit
	.quad	comma
	.quad	exit

# BRANCH ( -- )
# Changes PC by compiled offset (in cells)
word	branch,,,,, _branch_decomp, 0
_branch:
	lodsq
	lea	rpc, [rpc + rwork * 8]
	ret
_branch_decomp:
	call	_dup
	mov	rtop, rwork
	call	_decomp_print
	call	_dup
	mov	rtop, 0x9
	call	_emit

	lodsq
	mov	rtmp, rpc
	sal	rwork, 3
	add	rtmp, rwork
	call	_dup
	mov	rtop, rtmp
	call	_dot
	mov	rtop, 0xa
	call	_emit
	jmp	rnext

# ?BRANCH ( f -- )
# Changes PC by compiled offset (in cells) if top element is zero
word	qbranch, "?branch",,,, _branch_decomp, 0
_qbranch:
	lodsq
	test	rtop, rtop
	jnz	9f

	lea	rpc, [rpc + rwork * 8]

	9:
	call	_drop
	ret

# -?BRANCH ( f -- )
# Changes PC by compiled offset (in cells) if top element is not zero
word	mqbranch, "-?branch",,,, _branch_decomp, 0
_mqbranch:
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

# CMOVE ( as ad n -- )
# Move N bytes from as to ad
word	cmove
	push	rsi
	push	rdi
	mov	rtmp, rtop
	call	_drop
	mov	rdi, rtop
	call	_drop
	mov	rsi, rtop
	mov	rcx, rtmp
	rep	movsb

	call	_drop
	pop	rdi
	pop	rsi
	ret

# (") ( -- a )
# Returns address of a compiled string
word	_quot_, "(\")"
	lodsb
	movzx	rax, al
	call	_dup
	mov	rtop, rpc
	dec	rtop
	add	rpc, rax
	add	rpc, 0xf
	and	rpc, -16
	ret	

# " ( "ccc" -- )
# Compiles a string
word	quot, "\"", immediate
	lea	rwork, qword ptr [_quot_]	/* compile (") */
	stosq

	call	_dup
	mov	rtop, 0x22
	call	_word
	call	_count
	mov	rtmp, rtop
	inc	rtmp
	push	rtmp
	call	_drop
	dec	rtop
	call	_dup
	mov	rtop, rhere
	call	_dup
	mov	rtop, rtmp
	call	cmove
	pop	rtmp
	add	rhere, rtmp
	call	_align
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
	call	context
	mov	rtop, [rtop]
	mov	rtop, [rtop]
	call	_words_

	call	current
	mov	rtop, [rtop]
	cmp	rtop, [_context]
	je	2f
	mov	rtop, [rtop]
	call	_dup
	mov	rtop, 0xa
	call	_emit
	call	_words_
	jmp	3f
	2:
	call	_drop
	3:
	call	_dup
	lea	rtop, [forth_]
	cmp	rtop, [_context]
	je	4f
	cmp	rtop, [_current]
	je	4f
	mov	rtop, [rtop]
	call	_dup
	mov	rtop, 0xa
	call	_emit
	call	_words_
	jmp	5f
	4:
	call	_drop
	5:
	ret

_words_:
	push	rtop
	push	rsi
	push	rdi

	mov	rtmp, rtop
	call	_drop

	7:
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
	jmp	7b

	9:
	pop	rdi
	pop	rsi
	pop	rtop

	call	_dup
	mov	rtop, 0xa
	call	_emit
	ret

# STATE! ( state -- )
# Sets address interpreter state for the next word from the text interpreter
word	state_, "state!"
	mov	rwork, rtop
	call	_drop
	mov	qword ptr [_state], rwork
	ret

# STATE!! ( state -- )
# Sets address interpreter state for the next word from the address interpterer
word	state__, "state!!"
	mov	rwork, rtop
	call	_drop
	mov	rstate, rwork
	ret

# SEE ( -- )
# Sets STATE to DECOMPILING
word	see
_see:
	mov	qword ptr [_state], DECOMPILING
	ret

# DECOMP ( -- )
# Decompile XT being currently interpreted
_decomp_code:
	cmp	qword ptr [_decompiling], 1
	je	1f
	call	_dup
	mov	rtop, rwork
	call	_decomp_print
	mov	rtop, 0xa
	call	_emit
	call	_bracket_open
	call	_interpreting_
	jmp	rnext
_decomp:
	cmp	qword ptr [_decompiling], 1
	je	1f
_decomp1:
	push	rpc
	mov	rpc, rwork
	mov	qword ptr [_decompiling], 1
	jmp	7f
	1:
	call	_dup
	mov	rtop, rwork
	call	_decomp_print
	call	_dup
	mov	rtop, 0xa
	call	_emit
	7:
	call	_drop
	jmp	rnext
_decomp_exit:
	mov	qword ptr [_decompiling], 0
	call	_bracket_open
	call	_interpreting_
	call	_dup
	mov	rtop, rwork
	call	_decomp_print
	call	_dup
	mov	rtop, 0xa
	call	_emit
	pop	rpc
	jmp	rnext
_decomp_print:
	call	_dup
	mov	rtop, rpc
	sub	rtop, 8
	call	_dot
	call	_dup
	call	_dot
	call	_dup
	mov	rtop, [rtop - STATES * 16 - 16]	# NFA
	call	_count
	call	_type
	ret
_decompiling:	.quad	0

# BL ( -- c )
# Returns blank character code
word	bl_, "bl"
_bl_:
	call	_dup
	mov	rtop, 0x20
	ret

# ALLOT ( n -- )
# Reserves n bytes in data space
word	allot
	add	rhere, rtop
	call	_drop
	ret
# @ ( a -- n )
# FETCH
word	fetch, "@"
	mov	rtop, [rtop]
	ret

# ! ( n a -- )
# STORE
word	store, "\!"
	mov	rtmp, rtop
	call	_drop
	mov	[rtmp], rtop
	call	_drop
	ret

# , ( v -- )
# Reserve space for one cell in the data space and store value in the pace
word	comma, ","
_comma:
	mov	rax, rtop
	stosq
	call	_drop
	ret

# 4, ( v -- )
# Reserve space for 4 bytes in the data space and store value in the pace
word	four_comma, "4,"
_four_comma:
	mov	rax, rtop
	stosd
	call	_drop
	ret

# 2, ( v -- )
# Reserve space for 2 bytes in the data space and store value in the pace
word	two_comma, "2,"
_two_comma:
	mov	rax, rtop
	stosw
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
# TODO: BUG: If \ is the last character on the line (just before 0a), the next line is skipped (?)
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
	lea	rtmp, qword ptr [_state_notimpl]
	mov	rwork, 0

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
	call	_word		# ( tib ) 
	call	_dup		# ( tib tib )
	call	_count		# ( tib tib+1 count ) 
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

	call	latest
	mov	rtmp, rtop
	call	_drop

	mov	qword ptr [rhere], rwork	# NFA
	add	rhere, 8
	mov	qword ptr [rhere], rtmp		# LFA
	add	rhere, 8

	call	_cfa_allot
	call	_drop

	call	current
	mov	rtop, [rtop]
	mov	[rtop], rhere	# XT
	call	_drop

	jmp	9f

	6:
	lea	rtop, qword ptr [_header_errm]
	call	_count
	call	_type
.ifdef	DEBUG
	call	_bye
.endif
	jmp	_abort

	call	_drop
	call	_drop

	9:
	ret

_header_errm:
	.byte _header_errm$ - _header_errm - 1
	.ascii	"\r\n\x1b[31mERROR! \x1b[0m\x1b[7m\x1b[1m\x1b[33m Refusing to create word header with empty name \x1b[0m\r\n"
_header_errm$:

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
word	interpreting_, "(interpreting)", immediate,,,,, _code, _interpreting_
_interpreting_:
	mov	rstate, INTERPRETING
	ret

# INTERPRETING!
# Switches address interpreter state to INTERPRETING
word	interpreting__, "interpreting!",,,,,, _code, _interpreting__
_interpreting__:
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
# Sets latest word's compilation semantics to execution semantics
word	immediate
_immediate:
	call	latest
	mov	rwork, rtop
	call	_drop

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

	.quad	lit, 0
	.quad	lit, _decomp
	.quad	lit, DECOMPILING
	.quad	latest
	.quad	does

	.quad	exit

# FORTHWORD ( xt -- )
# Specifies execution semantics for a word specified by XT as a forth word with threaded code following at HERE
word	forthword, "fun",, forth
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

	.quad	lit, 0
	.quad	lit, _decomp
	.quad	lit, DECOMPILING
	.quad	latest
	.quad	does

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

	.quad	lit, 0
	.quad	lit, _decomp
	.quad	lit, DECOMPILING
	.quad	latest
	.quad	does

	.quad	exit

# :: ( "<name>" -- )
# Synonym for CREATE
word	coloncolon, "::",, forth
_coloncolon:
	.quad	create
	.quad	exit

# (DOES>XT)
# Internal word that fixes HERE address, depends on DOES> implementation
word	_does_xt_, "(does>xt)"
__does_xt_:
	add	rtop, 3 * 8
	ret

# (DOES) ( -- _does )
# Returns address of the _does primitive entry point
word	_does_, "(does)",, forth
	.quad	lit, _does
	.quad	exit

# (EXEC) ( -- _once )
# Returns address of the _once primitive entry point
word	_exec_, "(exec)",, forth
	.quad	lit, _exec
	.quad	exit

# (DOES>) ( xt -- )
# Defines execution and compilation semantics for the latest word
word	_does__, "(does>)",, forth
__does_:
	.quad	_does_xt_

	.quad	_does_
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
	.quad	compile, _does__
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
# Searches for word name, placed at TIB, in the vocabularies CONTEXT, CURRENT and FORTH
word	find
_find:
	call	_dup
	mov	rtop, [_context]
	call	_find_
	test	rtop, rtop
	jnz	3f

	mov	rtop, [_current]
	cmp	rtop, [_context]
	je	1f
	call	_find_
	test	rtop, rtop
	jnz	3f

	1:
	lea	rtop, [forth_]
	cmp	rtop, [_current]
	je	2f
	cmp	rtop, [_context]
	je	2f
	call	_find_
	test	rtop, rtop
	jnz	3f

	2:
	xor	rtop, rtop

	3:
	ret

_find_:
	push	rsi
	push	rdi
	push	rbx

	mov	rtmp, [rtop]

	mov	rbx, qword ptr [_tib]

	5:
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
	jmp	5b

	6:
	mov	rtop, 0

	9:
	pop	rbx
	pop	rdi
	pop	rsi
	ret

# TODO: BUG: Input -?branch causes stack underflow
# NUMBER ( c-addr -- n -1 | 0 )
# Parses string as a number (in HEX base)
word	number
_number:
	push	rsi
	push	rbx
	xor	rbx, rbx	# Positive number
	mov	rsi, rtop
	movzx	rcx, byte ptr [rtop]
	test	rcx, rcx
	jz	8f

	xor	rtmp, rtmp
	xor	rwork, rwork
	inc	rsi
	1:
	lodsb
	cmp	bl, 1
	je	2f
	cmp	al, 0x2d # "-"
	jne	2f
	inc	bl
	jmp	5f
	2:
	cmp	al, 0x30
	jb	8f
	cmp	al, 0x39
	jbe	3f
	or	al, 0x20
	cmp	al, 0x61
	jb	8f
	cmp	al, 0x66
	ja	8f
	sub	al, 0x61 - 10
	jmp	4f
	3:
	sub	al, 0x30
	4:
	shl	rtmp, 4
	add	rtmp, rwork
	5:
	dec	rcx
	jnz	1b

	mov	rtop, rtmp
	cmp	bl, 1
	jne	7f
	or	rtop, rtop	# Single "-", "-0", "-0[0...]" is considered an errorneous input
	jz	8f
	neg	rtop
	7:
	call	_dup
	mov	rtop, -1
	jmp	9f

	8:
	mov	rtop, 0
	jmp	9f

	9:
	pop	rbx
	pop	rsi
	ret

# . ( n -- )
# Print number on the top of the stack (hexadecimal)
word	dot, "."
_dot:
	mov	rtmp, 16

	cmp	rtop, 0
	jge	1f

	neg	rtop
	call	_dup
	mov	rtop, 0x2d
	call	_emit

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

# .0 ( n -- )
# Prints number with a leading '0', if it's < 10h (for dump)
word	dot0, ".0"
	cmp	rtop, 0x10
	jnb	3f
	
	call	_dup
	mov	rtop, 0x30
	call	_emit

	3:
	call	_dot
	ret

# .S ( -- )
# Prints stacks
word	dot_s, ".S"
	call	_qcsp

	call	_dup
	mov	rtop, 0x53
	call	emit
	call	_dup
	mov	rtop, 0x3a
	call	emit
	call	_dup
	mov	rtop, 0x20
	call	emit

	test	rstack, rstack
	jz	5f
	mov	rwork, 0
	1:
	dec	rwork
	cmp	rwork, rstack
	je	3f
	call	_dup
	mov	rtop, [rstack0 + rwork * 8]
	push	rwork
	call	dot
	pop	rwork
	jmp	1b
	3:
	test	rstack, rstack
	jz	5f
	call	_dup
	call	dot

	5:
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
.ifdef	DEBUG
	call	_bye
.endif
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
	.quad	exit	# Needed here only for decompilation

# ?CSP ( -- )
# Aborts on stack underflow
word	qcsp, "?csp"
_qcsp:
	cmp	rstack, 0
	jnle	6f
	jmp	9f

	6:
	lea	rtop, qword ptr [_qcsp_errm]
	call	_count
	call	_type
.ifdef	DEBUG
	call	_bye
.endif
	jmp	_abort

	9:
	ret
_qcsp_errm:
	.byte _qcsp_errm$ - _qcsp_errm - 1
	.ascii	"\r\n\r\n\x1b[31mERROR! \x1b[33m\x1b[7m Stack underflow \x1b[0m\r\n"
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
	call	dot0
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
	mov	rdi, rtop
	mov	rax, 60
	syscall

# ABORT
# Reinitializes the system, or quits to OS in debug build
word	abort
_abort1:
.ifdef	DEBUG
	jmp	_bye
.else
	jmp	_abort
.endif

# DARK LORD
# Dark Lord to be summoned
word	darklord,,, forth
	.quad	lit, 42
	.quad	dup
	.quad	emit, emit
	.quad	exit

# SUMMONER
# Dark Lord, I summon Thee!
word	summoner
_summoner:
	lea	rwork, qword ptr [darklord]
	call	summon
	call	_dup
	mov	rtop, 43
	call	_emit
	ret

# COLD
# Cold start
word	cold
	jmp	_abort

# WARM
# Warm start
word	warm,,, forth
_warm:
	.quad	quit
	.quad	bye
	.quad	exit # Not needed here, for decompiler only for now

# LATEST
	.equ	last, latest_word
.align	16
here0:
	.rep	0x10000
	.quad	0
	.endr
