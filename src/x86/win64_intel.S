#define LIBFFI_ASM
#include <fficonfig.h>
#include <ffi.h>
#include <ffi_cfi.h>
#include "asmnames.h"

#if defined(HAVE_AS_CFI_PSEUDO_OP)
        .cfi_sections   .debug_frame
#endif

#ifdef X86_WIN64
#define SEH(...) __VA_ARGS__
#define arg0	rcx
#define arg1	rdx
#define arg2	r8
#define arg3	r9
#else
#define SEH(...)
#define arg0	rdi
#define arg1	rsi
#define arg2	rdx
#define arg3	rcx
#endif

/* This macro allows the safe creation of jump tables without an
   actual table.  The entry points into the table are all 8 bytes.
   The use of ORG asserts that we're at the correct location.  */
/* ??? The clang assembler doesn't handle .org with symbolic expressions.  */
#if defined(__clang__) || defined(__APPLE__) || (defined (__sun__) && defined(__svr4__))
# define E(BASE, X)	ALIGN 8
#else
# define E(BASE, X)	ALIGN 8; ORG BASE + X * 8
#endif

	.CODE
	extern PLT(C(abort)):near
	extern C(ffi_closure_win64_inner):near

/* ffi_call_win64 (void *stack, struct win64_call_frame *frame, void *r10)

   Bit o trickiness here -- FRAME is the base of the stack frame
   for this function.  This has been allocated by ffi_call.  We also
   deallocate some of the stack that has been alloca'd.  */

	ALIGN	8
	PUBLIC	C(ffi_call_win64)

C(ffi_call_win64) proc SEH(frame)
	cfi_startproc
	/* Set up the local stack frame and install it in rbp/rsp.  */
	mov	RAX, [RSP]
	mov	[arg1], RBP
	mov	[arg1 + 8], RAX
	mov	RBP, arg1
	cfi_def_cfa(rbp, 16)
	cfi_rel_offset(rbp, 0)
	SEH(.pushreg rbp)
	SEH(.setframe rbp, 0)
	SEH(.endprolog)
	mov	RSP, arg0

	mov	R10, arg2

	/* Load all slots into both general and xmm registers.  */
	mov	RCX, [RSP]
	movsd	XMM0, qword ptr [RSP]
	mov	RDX, [RSP + 8]
	movsd	XMM1, qword ptr [RSP + 8]
	mov	R8, [RSP + 16]
	movsd	XMM2, qword ptr [RSP + 16]
	mov	R9, [RSP + 24]
	movsd	XMM3, qword ptr [RSP + 24]

	call	qword ptr [RBP + 16]

	mov	ECX, [RBP + 24]
	mov	R8, [RBP + 32]
	lea	R10, ffi_call_win64_tab
	cmp	ECX, FFI_TYPE_SMALL_STRUCT_4B
	lea	R10, [R10 + RCX*8]
	ja	L99
	jmp	R10

/* Below, we're space constrained most of the time.  Thus we eschew the
   modern "mov, pop, ret" sequence (5 bytes) for "leave, ret" (2 bytes).  */
epilogue macro
	LEAVE
	cfi_remember_state
	cfi_def_cfa(rsp, 8)
	cfi_restore(rbp)
	RET
	cfi_restore_state
endm

	ALIGN 8
ffi_call_win64_tab LABEL NEAR
E(0b, FFI_TYPE_VOID)
	epilogue
E(0b, FFI_TYPE_INT)
	movsxd	RAX, EAX
	mov	qword ptr [R8], RAX
	epilogue
E(0b, FFI_TYPE_FLOAT)
	movss	dword ptr [R8], XMM0
	epilogue
E(0b, FFI_TYPE_DOUBLE)
	movsd	qword ptr[R8], XMM0
	epilogue
E(0b, FFI_TYPE_LONGDOUBLE)
	call	PLT(C(abort))
E(0b, FFI_TYPE_UINT8)
	movzx	EAX, AL
	mov	qword ptr[R8], RAX
	epilogue
E(0b, FFI_TYPE_SINT8)
	movsx	RAX, AL
	jmp	L98
E(0b, FFI_TYPE_UINT16)
	movzx	EAX, AX
	mov	qword ptr[R8], RAX
	epilogue
E(0b, FFI_TYPE_SINT16)
	movsx	RAX, AX
	jmp	L98
E(0b, FFI_TYPE_UINT32)
	mov	EAX, EAX
	mov	qword ptr[R8], RAX
	epilogue
E(0b, FFI_TYPE_SINT32)
	movsxd	RAX, EAX
	mov	qword ptr [R8], RAX
	epilogue
E(0b, FFI_TYPE_UINT64)
L98 LABEL near
	mov	qword ptr [R8], RAX
	epilogue
E(0b, FFI_TYPE_SINT64)
	mov	qword ptr [R8], RAX
	epilogue
E(0b, FFI_TYPE_STRUCT)
	epilogue
E(0b, FFI_TYPE_POINTER)
	mov	qword ptr [R8], RAX
	epilogue
E(0b, FFI_TYPE_COMPLEX)
	call	PLT(C(abort))
E(0b, FFI_TYPE_SMALL_STRUCT_1B)
	mov	byte ptr [R8], AL
	epilogue
E(0b, FFI_TYPE_SMALL_STRUCT_2B)
	mov	word ptr [R8], AX
	epilogue
E(0b, FFI_TYPE_SMALL_STRUCT_4B)
	mov	dword ptr [R8], EAX
	epilogue

	align	8
L99 LABEL near
	call	PLT(C(abort))

	epilogue

	cfi_endproc
	C(ffi_call_win64) endp


/* 32 bytes of outgoing register stack space, 8 bytes of alignment,
   16 bytes of result, 32 bytes of xmm registers.  */
#define ffi_clo_FS	(32+8+16+32)
#define ffi_clo_OFF_R	(32+8)
#define ffi_clo_OFF_X	(32+8+16)

	align	8
	PUBLIC	C(ffi_go_closure_win64)

C(ffi_go_closure_win64) proc
	cfi_startproc
	/* Save all integer arguments into the incoming reg stack space.  */
	mov qword ptr [rsp + 8], rcx; movq	%rcx, 8(%rsp)
	mov qword ptr [rsp + 16], rdx; movq	%rdx, 16(%rsp)
	mov qword ptr [rsp + 24], r8; movq	%r8, 24(%rsp)
	mov qword ptr [rsp + 32], r9 ;movq	%r9, 32(%rsp)

	mov rcx, qword ptr [r10 + 8]; movq	8(%r10), %rcx			/* load cif */
	mov rdx, qword ptr [r10 + 16];  movq	16(%r10), %rdx			/* load fun */
	mov r8, r10 ; movq	%r10, %r8			/* closure is user_data */
	jmp	ffi_closure_win64_2
	cfi_endproc
	C(ffi_go_closure_win64) endp

	align	8
	
PUBLIC C(ffi_closure_win64)
C(ffi_closure_win64) PROC FRAME
	cfi_startproc
	/* Save all integer arguments into the incoming reg stack space.  */
	mov qword ptr [rsp + 8], rcx; movq	%rcx, 8(%rsp)
	mov qword ptr [rsp + 16], rdx;	movq	%rdx, 16(%rsp)
	mov qword ptr [rsp + 24], r8; 	movq	%r8, 24(%rsp)
	mov qword ptr [rsp + 32], r9;	movq	%r9, 32(%rsp)

	mov rcx, qword ptr [FFI_TRAMPOLINE_SIZE + r10]	;movq	FFI_TRAMPOLINE_SIZE(%r10), %rcx		/* load cif */
	mov rdx, qword ptr [FFI_TRAMPOLINE_SIZE + 8 + r10] ;	movq	FFI_TRAMPOLINE_SIZE+8(%r10), %rdx	/* load fun */
	mov r8, qword ptr [FFI_TRAMPOLINE_SIZE+16+r10] ;movq	FFI_TRAMPOLINE_SIZE+16(%r10), %r8	/* load user_data */
ffi_closure_win64_2 LABEL near
	sub rsp, ffi_clo_FS ;subq	$ffi_clo_FS, %rsp
	cfi_adjust_cfa_offset(ffi_clo_FS)
	SEH(.allocstack ffi_clo_FS)
	SEH(.endprolog)

	/* Save all sse arguments into the stack frame.  */
	movsd qword ptr [ffi_clo_OFF_X + rsp], xmm0	; movsd	%xmm0, ffi_clo_OFF_X(%rsp)
	movsd qword ptr [ffi_clo_OFF_X+8+rsp], xmm1 ; movsd	%xmm1, ffi_clo_OFF_X+8(%rsp)
	movsd qword ptr [ffi_clo_OFF_X+16+rsp], xmm2 ; movsd %xmm2, ffi_clo_OFF_X+16(%rsp)
	movsd qword ptr [ffi_clo_OFF_X+24+rsp], xmm3 ; movsd %xmm3, ffi_clo_OFF_X+24(%rsp)

	lea	r9, [ffi_clo_OFF_R + rsp] ; leaq	ffi_clo_OFF_R(%rsp), %r9
	call C(ffi_closure_win64_inner)

	/* Load the result into both possible result registers.  */
	
	mov rax, qword ptr [ffi_clo_OFF_R + rsp] ;movq    ffi_clo_OFF_R(%rsp), %rax
	movsd xmm0, qword ptr [rsp + ffi_clo_OFF_R] ;movsd   ffi_clo_OFF_R(%rsp), %xmm0

	add rsp, ffi_clo_FS ;addq	$ffi_clo_FS, %rsp
	cfi_adjust_cfa_offset(-ffi_clo_FS)
	ret

	cfi_endproc
	C(ffi_closure_win64) endp

#if defined __ELF__ && defined __linux__
	.section	.note.GNU-stack,"",@progbits
#endif
_text ends
end
