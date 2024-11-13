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
	rrstack	.req	x8
	rstack0	.req	x15

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
	add	rstack0, sp, #-0x1000
	add	rrstack, sp, #-0x2000
	mov	rstack, xzr

# Interpreter
_next:
	ldr	rwork, [rpc], #8
_doxt:
	add	rtmp, rwork, rstate, lsl #3
	ldp	rtmp, rtmp2, [rtmp]
	br	rtmp
_call:
	blr	rtmp2 
_exit:
	ldr	rpc, [rstack, #-8]!
	b	_next
_exec:
	str	rpc, [rstack], #-8
	mov	rpc, rtmp2
	b	_next

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
	mov	x0, #42
	mov	w8, #93
	svc	#0

$cold:
	.quad	bye

# LATEST
	.equ	last, 0
#latest_word
.align	4
here0:
	.rep	0x10
	.quad	0
	.endr

