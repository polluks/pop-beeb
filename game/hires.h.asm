; hires.h.asm

\* Local vars
\

CLEAR locals, locals_top
ORG locals
GUARD locals_top

.BASE skip 2
.IMSAVE skip 2
.XSAVE skip 1
.YSAVE skip 1
.WIDTH skip 1
.HEIGHT skip 1
.TOPEDGE skip 1
.OFFLEFT skip 1
.OFFRIGHT skip 1
.YREG skip 1
.CARRY skip 1

\ORG $18
;.hires_index
.ztemp SKIP 1
;.AMASK skip 1
;.BMASK skip 1
.VISWIDTH skip 1
.RMOST skip 1
;.carryim skip 1
;.imbyte skip 1
