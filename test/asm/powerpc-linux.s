	.text
	.file	"tmp.c"
	.type	___hsc2hs_BOM___,@object # @___hsc2hs_BOM___
	.data
	.globl	___hsc2hs_BOM___
	.p2align	3
___hsc2hs_BOM___:
	.long	1                       # 0x100000000
	.long	0
	.size	___hsc2hs_BOM___, 8

	.type	x___hsc2hs_sign___,@object # @x___hsc2hs_sign___
	.section	.bss,"aw",@nobits
	.globl	x___hsc2hs_sign___
	.p2align	3
x___hsc2hs_sign___:
	.long	0                       # 0x0
	.long	0
	.size	x___hsc2hs_sign___, 8

	.type	x,@object               # @x
	.data
	.globl	x
	.p2align	3
x:
	.long	0                       # 0x1
	.long	1
	.size	x, 8

	.type	y___hsc2hs_sign___,@object # @y___hsc2hs_sign___
	.section	.bss,"aw",@nobits
	.globl	y___hsc2hs_sign___
	.p2align	3
y___hsc2hs_sign___:
	.long	0                       # 0x0
	.long	0
	.size	y___hsc2hs_sign___, 8

	.type	y,@object               # @y
	.data
	.globl	y
	.p2align	3
y:
	.long	0                       # 0xffffffff
	.long	4294967295
	.size	y, 8

	.type	z___hsc2hs_sign___,@object # @z___hsc2hs_sign___
	.globl	z___hsc2hs_sign___
	.p2align	3
z___hsc2hs_sign___:
	.long	0                       # 0x1
	.long	1
	.size	z___hsc2hs_sign___, 8

	.type	z,@object               # @z
	.globl	z
	.p2align	3
z:
	.long	4294967295              # 0xffffffffffffffff
	.long	4294967295
	.size	z, 8

	.type	.L.str,@object          # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"Hello World\" 12345"
	.size	.L.str, 19

	.type	t,@object               # @t
	.data
	.globl	t
	.p2align	2
t:
	.long	.L.str
	.size	t, 4


	.ident	"clang version 5.0.1 (tags/RELEASE_501/final)"
	.section	".note.GNU-stack","",@progbits
