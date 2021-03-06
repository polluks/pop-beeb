; frameadv.asm
; Originally FRAMEADV.S
; Draw the screen

.frameadv
\org = $1290
\ lst off
\ tr on
\*-------------------------------
\ org org
\
IF _JMP_TABLE=FALSE
.sure jmp SURE
.fast jmp FAST
.getinitobj jmp GETINITOBJ
.calcblue jmp CALCBLUE
.zerored jmp ZERORED
ENDIF
\
\*-------------------------------
\ lst
\ put eq
\ lst
\ put gameeq
\ lst off
\ put bgdata
\ lst off

.initsettings
 EQUB gmaxval,gminval

\*-------------------------------
\*
\*  Draw entire 10 x 3 screen from scratch
\*
\*-------------------------------
.SURE
{
 lda #1
 sta genCLS ;clear screen

 jsr setback ;draw on bg plane

 jsr getprev ;get 3 rightmost blocks of screen to left

 lda SCRNUM
 jsr calcblue ;get blueprint base addr

\*  Draw 3 rows of 10 blocks (L-R, T-B)

 ldy #2
.row sty rowno ;0 = top row, 2 = bottom row

 lda BlockBot+1,y
 sta Dy ;get Y-coord for bottom of D-section
 sec
 sbc #3
 sta Ay ;& A-section

 lda Mult10,y
 sta yindex ;block # (0-29)

 lda PREV,y
 sta PRECED
 lda sprev,y
 sta spreced ;get objid & state of preceding block

 jsr getbelow ;get 10 topmost blocks of screen below

 lda #0
 sta colno ;0 = leftmost column, 9 = rightmost
.loop asl A
 asl A
 sta XCO
 sta blockxco ;get X-coord for A-section

 ldy yindex
 jsr getobjid
 sta objid ;get object id# of current block

 jsr RedBlockSure ;Redraw entire block

 lda objid
 sta PRECED
 lda state
 sta spreced ;Move on to next block

 inc yindex
 inc colno

 lda colno
 cmp #10
 bcc loop ;...until we've done 10 blocks

.nextln ldy rowno
 beq done
 dey
 jmp row ;...and 3 rows

\* Now draw bottom row of screen above (D-sections only)

.done ldy #2 ;bottom row of scrn above
 sty rowno

 lda #2
 sta Dy
 lda #LO(-1)
 sta Ay ;get screen Y-coords

 lda Mult10,y
 sta yindex

 lda #0
 sta PRECED

 lda scrnBelow
 pha
 lda scrnBelowL
 pha ;save current values on stack

 lda SCRNUM
 sta scrnBelow
 lda scrnLeft
 sta scrnBelowL ;& pretend we're on screen above

\* Draw 10 blocks, L-R

 jsr getbelow

 lda scrnAbove
 jsr calcblue

 lda #0
 sta colno
.dloop
 asl A
 asl A
 sta XCO
 sta blockxco

 lda scrnAbove
 bne label_1
 lda #floor ;If screen above is null screen,
 bne label_2 ;draw a row of solid floorpieces

.label_1 ldy yindex
 jsr getobjid1
.label_2 sta objid

 jsr RedDSure ;Draw D-section

 lda objid
 sta PRECED
 lda state
 sta spreced

 inc yindex
 inc colno

 lda colno
 cmp #10
 bcc dloop

 pla ;Restore original screen values
 sta scrnBelowL
 pla
 sta scrnBelow
.return
 rts
}

\*-------------------------------
\*
\*  Fast screen redraw
\*
\*  Same general structure as SURE, but redraws only those
\*  blocks specified by redraw buffers.
\*
\*-------------------------------
.FAST
{
 jsr getprev

 lda SCRNUM
 jsr calcblue

\ lda #0
\ ldy #20
\ jsr metbufs3 ;If strength meter is in danger of
\ sta redkidmeter ;being overwritten, mark it for redraw

\ lda #0
\ ldy #28
\ jsr metbufs2
\ sta redoppmeter ;opponent meter too

 lda #30
 sta yindex
 jsr drawobjs ;Draw o.s. characters first

\*  Draw 3 rows of 10 blocks (L-R, T-B)

 ldy #2
.row sty rowno

 lda BlockBot+1,y
 sta Dy
 sec
 sbc #3
 sta Ay

 lda Mult10,y
 sta yindex

 lda PREV,y
 sta PRECED
 lda sprev,y
 sta spreced

 jsr getbelow

 lda #0
 sta colno

.loop asl A
 asl A
 sta XCO
 sta blockxco

 ldy yindex
 jsr getobjid
 sta objid

 jsr RedBlockFast

 lda objid
 sta PRECED
 lda state
 sta spreced

 inc yindex
 inc colno

 lda colno
 cmp #10
 bcs nextln
 jmp loop

.nextln ldy rowno
 beq cont
 dey
 jmp row

\* Now draw bottom row of screen above (D-sections only)

.cont jsr setback

 ldy #2
 sty rowno

 lda #2
 sta Dy
 lda #LO(-1)
 sta Ay

 lda Mult10,y
 sta yindex

 lda #0
 sta PRECED

 lda scrnBelow
 pha
 lda scrnBelowL
 pha

 lda SCRNUM
 sta scrnBelow
 lda scrnLeft
 sta scrnBelowL

 jsr getbelow

 lda scrnAbove
 beq done
 jsr calcblue

 lda #0
 sta colno
.dloop
 asl A
 asl A
 sta blockxco
 sta XCO

 ldy yindex
 jsr getobjid1
 sta objid

 jsr RedDFast

 lda objid
 sta PRECED
 lda state
 sta spreced

 inc yindex
 inc colno

 lda colno
 cmp #10
 bcc dloop

.done
 pla
 sta scrnBelowL
 pla
 sta scrnBelow

\* Now draw comix (impact stars) & strength meters

 lda #$ff
 sta yindex
 jsr drawobjs ;draw comix (index = -1)

 IF EditorDisk
 lda inbuilder
 bne return
 ENDIF

 jmp updatemeters
}

\*-------------------------------
\*
\*  Redraw entire block
\*
\*-------------------------------
.RedBlockSure
{
 jsr drawc ;C-section of piece below & to left
 jsr drawmc

 jsr drawb ;B-section of piece to left
 jsr drawmb

 jsr drawd ;D-section
 jsr drawmd

 jsr drawa ;A-section
 jsr drawma

 jmp drawfrnt ;A-section frontpiece
;(Note: This is necessary in case we do a
;layersave before we get to f.g. plane)
}

\*-------------------------------
\*
\* Redraw entire D-section
\*
\*-------------------------------
.RedDSure
{
 jsr drawc
 jsr drawmc
 jsr drawb
 jsr drawd
 jsr drawmd
 jmp drawfrnt
}

\*-------------------------------
\*
\*  Partial block redraw (as specified by redraw buffers)
\*
\*-------------------------------
.RedBlockFast
{
 lda wipebuf,y ;is wipebuf marked?
 beq skipwipe ;no--skip it
 sec
 sbc #1
 sta wipebuf,y ;decrement wipebuf

 jsr wipesq ;& wipe this block!

 ldy yindex

.skipwipe
 lda redbuf,y
 beq skipred
 sec
 sbc #1
 sta redbuf,y

 jsr setback
 jsr RedBlockSure

 ldy yindex
 bpl skipmove

.skipred
 lda movebuf,y
 beq skipmove
 sec
 sbc #1
 sta movebuf,y

 jsr setback
 jsr drawmc
 jsr drawmb
 jsr drawma

 ldy yindex

.skipmove
 lda floorbuf,y
 beq skipfloor
 sec
 sbc #1
 sta floorbuf,y

 jsr setmid
 jsr drawfloor

 ldy yindex
 bpl skiphalf

.skipfloor
 lda halfbuf,y
 beq skiphalf
 sec
 sbc #1
 sta halfbuf,y

 jsr setmid
 jsr drawhalf

 ldy yindex

.skiphalf
 lda objbuf,y
 beq skipobj

 lda #0
 sta objbuf,y

 jsr drawobjs ;draw all objects in this block

 lda blockxco
 sta XCO

 ldy yindex

.skipobj
 lda fredbuf,y
 beq skipfred
 sec
 sbc #1
 sta fredbuf,y

 jsr drawfrnt

 ldy yindex

.skipfred
 rts
}

\*-------------------------------
\*
\*  Partial D-section redraw
\*
\*-------------------------------
.RedDFast
{
 ldy colno
 lda topbuf,y ;is topbuf marked?
 beq skip ;no--skip it
 sec
 sbc #1
 sta topbuf,y

 jsr wiped
 jsr drawc
 jsr drawmc
 jsr drawb
 jsr redrawd ;(both bg and fg)
 jsr drawmd
 jsr drawfrnt
.skip
 rts
}

\*-------------------------------
\*
\*  Draw objects
\*
\*  Draw object/s with index # = yindex
\*  (Add appropriate images to mid list)
\*
\*-------------------------------
.drawobjs
{
\* Go through obj list looking for objINDX = yindex

 lda objX
 beq return

 ldy #0 ;y = sort list index
 ldx #1 ;x = object list index

.loop lda objINDX,x
 cmp yindex
 bne next
;Found a match--add object to sort list
 txa
 iny
 sta sortX,y

.next inx
 cpx objX
 bcc loop
 beq loop

 cpy #0
 beq return
 sty sortX ;# of objects in sort list

\* Sort them into back-to-front order

 jsr sortlist

\* Transfer sorted objects from obj list to mid list

 ldx #1
.loop2
 stx xsave

 lda sortX,x
 tax ;obj list index

 jsr drawobjx ;draw object #x

 ldx xsave
 inx
 cpx sortX
 bcc loop2
 beq loop2
;Done
.return rts
}

\*-------------------------------
\*
\*  Get objids & states of 3 rightmost blocks
\*  of left-neighboring screen
\*
\*  Out: PREV/sprev [0-2]
\*
\*-------------------------------
.getprev
{
 lda SCRNUM
 beq null

 lda scrnLeft
 beq blackscrn

.cont jsr calcblue ;screen to left

 ldy #9
 jsr getobjid1
 sta PREV
 lda state
 sta sprev

 ldy #19
 jsr getobjid1
 sta PREV+1
 lda state
 sta sprev+1

 ldy #29
 jsr getobjid1
 sta PREV+2
 lda state
 sta sprev+2

 rts

.null ;this scrn is null screen
 lda scrnLeft
 bne cont

.blackscrn ;screen to left is null scrn
 lda #block
 sta PREV
 sta PREV+1
 sta PREV+2
 lda #0
 sta sprev
 sta sprev+1
 sta sprev+2
 rts
}

\*-------------------------------
\*
\*  Get objids & states of 10 blocks in row below,
\*  1 block to left
\*
\*  In:  rowno
\*  Out: BELOW/SBELOW [0-9]
\*
\*  Use getbelow1 to look at screens other than scrnBelow
\*  (In: A = scrn #)
\*
\*-------------------------------
.getbelow
{
 ldx rowno
 cpx #2
 bcc onscr

\* Looking below bottom row

 lda scrnBelow
 beq belowblack ;screen below is black
 jsr calcblue

 ldy #8 ;skip rmost
.loop
 jsr getobjid

 sta BELOW+1,y
 lda state
 sta SBELOW+1,y
 dey
 bpl loop
.cont1
 lda scrnBelowL
 beq llblack ;screen to l.l. is black
 jsr calcblue

 ldy #9 ;u.r. block
 jsr getobjid
 sta BELOW
 lda state
 sta SBELOW
.done
 lda SCRNUM
 jsr calcblue ;restore SCRNUM
 rts

\* "ONSCREEN": Looking below top or middle row

.onscr lda PREV+1,x
 sta BELOW
 lda sprev+1,x
 sta SBELOW

 lda yindex
 clc
 adc #10
 tay

 ldx #1

.loop1 stx xsave
 jsr getobjid
 ldx xsave

 sta BELOW,x

 lda state
 sta SBELOW,x

 iny
 inx
 cpx #10
 bcc loop1

 rts

\* Look below null screen

.belowblack
 lda #1
 tax
.loop2 sta BELOW,x
 inx
 cpx #10
 bcc loop2
 bcs cont1

.llblack
 lda level
 cmp #12
 beq label_2 ;sorry Lance!
 lda #block
.label_1 sta BELOW
 bpl done
.label_2 lda #space
 bpl label_1
}

\*-------------------------------
\*
\*  L O A D   O B J E C T
\*
\*  Load vars with object data
\*
\*  In:  x = object table index
\*       X, OFF, Y, IMG, FACE, TYP, CU, CD, CL, CR, TAB
\*
\*  Out: XCO, OFFSET, YCO, IMAGE, TABLE
\*       FCharFace, FCharCU-CD-CL-CR
\*       A = objTYP
\*
\*-------------------------------
.loadobj
{
 lda objX,x
 sta FCharX
 sta XCO

 lda objOFF,x
 sta OFFSET

 lda objY,x
 sta FCharY
 sta YCO

 lda objIMG,x
 sta IMAGE

 lda objTAB,x
 sta TABLE

 lda objFACE,x
 sta FCharFace

 lda objCU,x
 sta FCharCU
 lda objCD,x
 sta FCharCD
 lda objCL,x
 sta FCharCL
 lda objCR,x
 sta FCharCR

 lda objTYP,x
.return
 rts
}

\*-------------------------------
\*
\*  D R A W   F R O N T
\*
\*-------------------------------
.drawfrnt
{
 ldx PRECED
 cpx #gate
 bne label_a
 jsr DrawGateBF ;special case

.label_a ldx objid
 cpx #slicer
 bne label_11
 jmp drawslicerf

.label_11 cpx #flask
 bne label_1
 lda state
 and #%11100000
 cmp #%10100000 ;5
 beq label_1
 cmp #%01000000 ;2
 bcc label_1
 lda #specialflask
 bne label_12

.label_1 ldx objid
 lda fronti,x
 beq return_1

.label_12 sta IMAGE

 lda Ay
 clc
 adc fronty,x
 sta YCO

 lda blockxco
 clc
 adc frontx,x
 sta XCO

 cpx #archtop2
 bcs label_sta

IF EditorDisk
 lda #EditorDisk
 cmp #2
 beq :ndunj
ENDIF

 lda BGset1
 cmp #1 ;pal
 beq ndunj

 cpx #posts
 beq label_sta ;for dungeon bg set

.ndunj cpx #block
 beq local_block

 jmp maddfore

\* Special handling for block

.local_block
 ldy state
 cpy #numblox
 bcc label_2
 ldy #0

.label_2 lda blockfr,y
 sta IMAGE

\* Pieces that go to byte boundaries can be STA'd w/o masking

.label_sta ldx #enum_sta
 stx OPACITY
 jmp addfore
}

\*-------------------------------
\* Draw Gate B Front?
\* (only if kid is to the left of bars)
\*-------------------------------
.DrawGateBF
{
 lda rowno
 cmp KidBlockY
 bne return_1

 ldx colno
 dex
 cpx KidBlockX ;is kid in gate block?
 bne return_1
 lda scrnRight
 cmp KidScrn
 beq return_1

 jmp drawgatebf ;draw gate bars over char
}

\*-------------------------------
\*
\*  D R A W   M O V A B L E   ' B '
\*
\*-------------------------------
.drawmb
{
 lda PRECED

 cmp #gate ;check for special cases
 bne label_1
 jmp drawgateb ;draw B-section of moving gate

.label_1 cmp #spikes
 bne label_2
 jmp drawspikeb

.label_2 cmp #loose
 bne label_3
 jmp drawlooseb

.label_3 cmp #torch
 bne label_4
 jmp drawtorchb
.label_4
.label_5 cmp #exit
 bne label_6
 jmp drawexitb

.label_6
}
.return_1
 rts


\*-------------------------------
\*
\*  D R A W  M O V A B L E  ' C '
\*
\*-------------------------------
.drawmc
{
 lda objid ;is there a piece here?
 cmp #space
 beq ok
 cmp #panelwof
 beq ok
 cmp #pillartop
 beq ok

 bne return_1 ;if yes, its A-section will cover up
;the C-section of the piece below
.ok
 ldx colno
 lda BELOW,x ;objid of piece below & to left

 cmp #gate
 bne return_1

 ;That piece is a gate--
 jmp drawgatec ;special case (movable c)
}

\*-------------------------------
\*
\*  Draw C-section (if visible)
\*
\*-------------------------------
.drawc
{
 jsr checkc
 bcc return_1
 jsr dodrawc ;OR C-section of piece below & to left
 jmp domaskb ;Mask B-section of piece to left
}

\*-------------------------------
\*
\*  Return cs if C-section is visible, cc if hidden
\*
\*-------------------------------
.checkc
{
 lda objid ;Does this space contain solid floorpiece?
 beq vis
 cmp #pillartop
 beq vis
 cmp #panelwof
 beq vis
 cmp #archtop1
 bcs vis
 bcc return_2 ;C-section is hidden
.vis sec ;C-section is visible
}
.return_2
 rts

\*-------------------------------
\*
\*  Draw C-section of piece below & to left
\*
\*-------------------------------
.dodrawc
{
 ldx colno
 lda BELOW,x ;objid of piece below & to left
 tax
 cpx #block
 beq local_block
 lda piecec,x
 beq return_2 ;piece has no c-section
 cmp #panelc0
 beq panel ;special panel handling
.cont sta IMAGE
 lda blockxco
 sta XCO
 lda Dy
 sta YCO
 lda #enum_ora
 sta OPACITY
 jmp add

\* Special panel handling

.panel ldx colno
 lda SBELOW,x
 tay
 cpy #numpans ;# of different panels
 bcs return_2
 lda panelc,y
 bne cont
 rts

.local_block ldx colno
 lda SBELOW,x
 tay
 cpy #numblox
 bcc label_1
 ldy #0
.label_1 lda blockc,y
 bne cont
}
.return_3
 rts


\*-------------------------------
\*
\*  Mask B-section of piece to left
\*
\*-------------------------------
.domaskb
{
 ldx PRECED
 lda maskb,x
 beq return_3
 sta IMAGE

 lda Dy
 sta YCO
 lda #enum_and
 sta OPACITY
 jmp add
}

\*-------------------------------
\*
\*  Draw B-section of piece to left
\*
\*-------------------------------
.drawb
{
 lda objid
 cmp #block
 beq return_3 ;B-section hidden by solid block

 ldx PRECED
 cpx #space
 beq drawb_space
 cpx #floor
 beq drawb_floor
 cpx #block
 beq drawb_block
 lda pieceb,x
 beq stripe
 cmp #panelb0
 beq panel ;special panel handling

\* draw regular B-section

 jsr drawb_cont1

\* Add stripe (palace bg set only)

.stripe
IF EditorDisk
 lda #EditorDisk
 cmp #2
 beq :stripe
ENDIF

 lda BGset1
 cmp #1 ;pal
 bne return_4

.str1 ldx PRECED
 lda bstripe,x
 beq return_4
 sta IMAGE
 lda Ay
 sec
 sbc #32
 jmp drawb_cont2

\* Special panel handling

.panel ldy spreced
 cpy #numpans
 bcs return_4
 lda panelb,y
 bne drawb_cont1
}
.return_4
 rts

.drawb_block
{
 ldy spreced
 cpy #numblox
 bcc label_1
 ldy #0
.label_1 lda blockb,y
 bne drawb_cont1
}
.drawb_floor
{
 ldy spreced
 cpy #numbpans+1
 bcc label_3
 ldy #0
.label_3 lda floorb,y
 beq return_4
 sta IMAGE
 lda floorby,y
 jmp drawb_cont
}
.drawb_space
{
 ldy spreced
 cpy #numbpans+1
 bcs return_4
 lda spaceb,y
 beq return_4
 sta IMAGE
 lda spaceby,y
 jmp drawb_cont
}
\* Draw regular B-section

.drawb_cont1
{
 sta IMAGE
 lda pieceby,x
}
.drawb_cont
{
 clc
 adc Ay
}
.drawb_cont2
{
 sta YCO
 lda blockxco
 sta XCO
 lda #enum_ora
 sta OPACITY
 jmp add
}

\*-------------------------------
\*
\*  Draw D-section
\*
\*-------------------------------
.redrawd
{
 jsr drawd
 beq return_4
 jmp addfore
}

.drawd
{
 lda #enum_sta
 sta OPACITY
 ldx objid
 cpx #block
 beq local_block
 cpx #panelwof ;Do we need to mask this D-section?
 bne cont ;no
.mask lda #enum_ora
 sta OPACITY
.cont lda pieced,x
 beq return_5
.cont1 sta IMAGE
 lda blockxco
 sta XCO
 lda Dy
 sta YCO
 jsr add
 lda #$ff
.return_5
 rts

\* Block handling

.local_block
 ldy state
 cpy #numblox
 bcc label_1
 ldy #0
.label_1 lda blockd,y
 bne cont1
}

\*-------------------------------
\*
\*  D R A W   ' A '
\*
\*  (1) If piece to left has intrusive B-section (e.g., panel):
\*      MASK A-section
\*  (2) OR A-section
\*
\*-------------------------------
.drawa
{
 lda PRECED
 cmp #archtop1
 beq special
 cmp #panelwif
 beq needmask
 cmp #panelwof
 beq needmask
 cmp #pillartop
 beq needmask
 cmp #block
 bne nomask

.needmask jsr addamask

.nomask jmp adda

.special ldx objid
 cpx #panelwof
 bne nomask
 lda #archpanel ;arch ends to L of panel
 jmp adda1
}

\*-------------------------------
.addmidezfast
 lda #UseFastlay
 jmp addmidez
.add
 jmp addback ;self-mod

.setback
{
 lda #LO(addback)
 sta add+1
 lda #HI(addback)
 sta add+2
 rts
}

.setmid
{
 lda #LO(addmidezfast)
 sta add+1
 lda #HI(addmidezfast)
 sta add+2
}
.return_6
 rts

.maddfore
{
\ BEEB GFX PERF
; ldx #enum_mask
; stx OPACITY
; jsr addfore
\ I think I'm doing this in one operation?
\ In POP enum_mask means generate a mask from the pixel data but I need this for ORA anyway
 ldx #enum_ora
 stx OPACITY
 jmp addfore
}

.addamask
{
 ldx objid
 lda maska,x
 beq return_6
 sta IMAGE
 lda blockxco
 sta XCO
 lda Ay
 sta YCO
 lda #enum_and
 sta OPACITY
 jmp add
}

.adda
{
 ldx objid
 jsr getpiecea
 beq return_6 ;nothing here
}
.adda1
{
 sta IMAGE
 lda blockxco
 sta XCO
 lda Ay
 clc
 adc pieceay,x
 sta YCO
 lda #enum_ora
 sta OPACITY
 jmp add
}

\*-------------------------------
\*
\*  D R A W   M O V A B L E   ' A '
\*
\*-------------------------------
.drawma
{
 lda objid
 cmp #spikes
 bne label_2
 jmp drawspikea

.label_2 cmp #slicer
 bne label_3
 jmp drawslicera

.label_3 cmp #flask
 bne label_4
 jmp drawflaska

.label_4 cmp #sword
 bne label_5
 jmp drawsworda
.label_5
.return_7
 rts
}

\*-------------------------------
\*
\* D R A W   M O V A B L E  ' D '
\*
\*-------------------------------
.drawmd
{
 lda objid
 cmp #loose
 bne label_1
 jmp drawloosed

.label_1
}
.return_8
 rts

\*-------------------------------
\*
\*  D R A W   F L O O R
\*
\*-------------------------------
.drawfloor
 lda PRECED ;empty space to left?
 bne return_8
.drawfloor_drawflr
{
 jsr addamask
 jsr adda
 jsr drawma
 jmp drawd
}

\*-------------------------------
\*
\*  D R A W   H A L F
\*
\*  Special version of "drawfloor" for climbup
\*
\*-------------------------------
.drawhalf
{
 lda PRECED
 bne return_8

\* empty space to left -- mask & draw "A" section

 ldx objid
 cpx #floor
 beq flr
 cpx #torch
 beq flr
 cpx #dpressplate
 beq flr
 cpx #exit
 beq flr

 lda BGset1
 cmp #1 ;pal?
 bne drawfloor_drawflr ;if there's no halfpiece for this objid,
;redraw full floorpiece
 cpx #posts
 beq post
 cpx #archbot
 bne drawfloor_drawflr

.post ; Beeb doesn't require special masking for pillars when climbing up
 BRA drawfloor_drawflr
; jsr sub
; lda #CUpost
; bne cont

.flr jsr sub
 lda #CUpiece
.cont
 sta IMAGE
 lda #enum_ora
 sta OPACITY
 jsr add
 jmp drawd

.sub lda #CUmask
 sta IMAGE
 lda blockxco
 sta XCO
 lda Ay
 sta YCO
 ldx objid
 cpx #dpressplate
 bne label_1
 inc YCO ;quick trick for dpressplate
.label_1 lda #enum_and
 sta OPACITY
 jmp add
}

\*-------------------------------
\*
\*  S H O R T   W I P E
\*
\*  In: Y = buffer index
\*
\*-------------------------------
.wipesq
 lda whitebuf,y
.wipesq_wipe
{
 sta height

 lda #4
 sta width

 lda blockxco
 sta XCO

 lda Dy
 sta YCO

 lda #$00           \ BEEB (was $80)
 jmp addwipe
}
.return_21
 rts

\*-------------------------------
\*
\* Wipe D-section
\*
\*-------------------------------
.wiped
{
 lda objid
 cmp #pillartop
 beq return_21
 cmp #panelwif
 beq return_21
 cmp #panelwof
 beq return_21
 cmp #block
 beq return_21

 lda #3
 jmp wipesq_wipe
}

\*-------------------------------
\*  D R A W  L O O S E  F L O O R  " D "
\*-------------------------------
.drawloosed
{
 lda state
 jsr getloosey

 lda loosed,y
 beq return
 sta IMAGE

 lda blockxco
 sta XCO
 lda Dy
 sta YCO

 lda #enum_sta
 sta OPACITY

 jmp add
.return
 rts
}

\*-------------------------------
\*  D R A W  L O O S E  F L O O R  " B "
\*-------------------------------
.drawlooseb
{
 lda spreced
 jsr getloosey

 lda #looseb
 sta IMAGE

 lda Ay
 clc
 adc looseby,y
 sta YCO

 lda #enum_ora
 sta OPACITY

 jmp add
}

\*-------------------------------
\*
\* Get piece "A"
\*
\* In: state; X = objid
\* Out: A = A-section image #
\*
\*-------------------------------
.getpiecea
{
 cpx #loose
 beq local_loose

 lda piecea,x
 rts

.local_loose lda state
 jsr getloosey
 lda loosea,y
 rts
}

\*-------------------------------
\*
\* Get loose floor index
\*
\* In: A = state
\* Out: Y = index
\*
\*-------------------------------
.getloosey
{
IF EditorDisk
 ldy inbuilder
 beq label_1
 ldy #1
 rts
ENDIF

.label_1 tay ;state
 bpl return_11
 and #$7f
 cmp #Ffalling+1
 bcc ok
 lda #1
.ok tay
}
.return_11
 rts

\*-------------------------------
\*  Draw spikes A
\*-------------------------------
.drawspikea
{
 ldx state
 bpl label_1 ;hibit clear --> frame #
 ldx #spikeExt ;hibit set --> spikes extended
.label_1 lda spikea,x
 beq return_11
 sta IMAGE
 lda blockxco
 sta XCO
 lda Ay
 sec
 sbc #1
 sta YCO
 lda #enum_ora
 sta OPACITY
 jmp add
}

\*-------------------------------
\*  Draw spikes B
\*-------------------------------
.drawspikeb
{
 ldx spreced
 bpl label_1 ;hibit clear --> frame #
 ldx #spikeExt ;hibit set --> spikes extended
.label_1 lda spikeb,x
 beq return_11
 sta IMAGE
 lda blockxco
 sta XCO
 lda Ay
 sec
 sbc #1
 sta YCO
 lda #enum_ora
 sta OPACITY
 jmp add
}

\*-------------------------------
\*  Draw torch B (flame)
\*-------------------------------
.drawtorchb
{
IF EditorDisk
 lda inbuilder
 bne return
ENDIF

 lda blockxco
 beq return ;no flame on leftmost torch
 sta XCO
 lda Ay
 sta YCO
 ldx spreced
 jsr setupflame ;in gamebg
 jmp addback
.return rts
}

\*-------------------------------
\*  Draw flask A (bubbles)
\*-------------------------------
.drawflaska
{
IF EditorDisk
 lda inbuilder
 bne ]rts
ENDIF

 lda blockxco
 sta XCO
 lda Ay
 sta YCO
 ldx state
 jsr setupflask
 lda #UseLayrsave   ; was UseLay - BEEB uses Layrsave so can plot Mask
 jmp addmidezo
}

\*-------------------------------
\*  Draw sword A
\*-------------------------------
.drawsworda
{
 lda #swordgleam0
 ldx state
 cpx #1
 bne label_0
 lda #swordgleam1
.label_0 sta IMAGE
 lda blockxco
 sta XCO
 lda Ay
 sta YCO
 lda #enum_sta
 sta OPACITY
 jmp add
}

\*-------------------------------
\*  Draw slicer A
\*-------------------------------
.drawslicera
{
 lda state
 and #$7f
 tax
 cpx #slicerRet
 bcc label_1
 ldx #slicerRet ;fully retracted
.label_1 lda slicerseq,x
 tax
 dex
 stx xsave

 lda blockxco
 sta XCO
 lda Ay
 sta YCO
 lda state ;hibit set = smeared
 bpl clean
 lda slicerbot2,x
 bne label_3
.clean lda slicerbot,x
 beq label_2
.label_3 sta IMAGE
 lda #enum_ora
 sta OPACITY
 jsr add
 ldx xsave

.label_2 lda slicertop,x
 beq return_9
 sta IMAGE
 lda Ay
 sec
 sbc slicergap,x
 sta YCO
 lda #enum_ora
 sta OPACITY
 jmp add
}

\*-------------------------------
\* Draw slicer front
\*-------------------------------
.drawslicerf
{
 lda state
 and #$7f
 tax
 cpx #slicerRet
 bcc label_1
 ldx #slicerRet ;fully retracted
.label_1 lda slicerseq,x
 tax
 dex
 stx xsave

 lda blockxco
 sta XCO
 lda Ay
 sta YCO
 lda slicerfrnt,x
 beq label_2
 sta IMAGE
 jmp maddfore
.label_2
}
.return_9
 rts


\*-------------------------------
\* Draw exit "b" (stairs)
\*-------------------------------
.drawexitb
{
 lda #stairs
 sta IMAGE

 lda Ay
 sec
 sbc #12
 sta YCO

 lda blockxco
 cmp #36
 bcs return ;can't protrude off R
 clc
 adc #1
 sta XCO

 lda #enum_sta
 sta OPACITY

 lda SCRNUM
 cmp KidStartScrn
 beq nostairs ;assume it's an entrance
 jsr add
.nostairs

\* draw door, bottom to top

 lda Dy
 sec
 sbc #67
 cmp #192
 bcs return
 sta blockthr ;topmost usable line

 lda spreced
 lsr A
 lsr A
 sta gateposn ;gateposn := spreced/4

 lda Ay
 sec
 sbc #13     ; was 14
 sbc gateposn
 sta doortop ;for CROPCHAR
.loop sta YCO

\ BEEB can mask pixel directly
\ lda #doormask
\ sta IMAGE
\ lda #enum_and
\ sta OPACITY
\ jsr add

 lda #door
 sta IMAGE
 lda #enum_mask
 sta OPACITY
 jsr add

 lda YCO
 sec
 sbc #4
 cmp blockthr
 bcs loop

\* repair top

 lda Ay
 sec
 sbc #64 ;Technically part of C-section
 cmp #192 ;but who cares
 bcs return

 sta YCO

 lda #toprepair
 sta IMAGE
 lda #enum_sta
 sta OPACITY
 jmp add

.return rts
}

\*-------------------------------
\*  D R A W   G A T E   " C "
\*-------------------------------
.drawgatec
{
 lda Dy
 sta YCO
 lda #gatecmask
 sta IMAGE
 lda #enum_and
 sta OPACITY
 jsr add ;mask out triangular area

 ldx colno
 lda SBELOW,x ;gate state
 cmp #gmaxval
 bcc label_1
 lda #gmaxval
.label_1 lsr A
 lsr A
 sta gateposn
 and #$f8
 eor #$ff
 clc
 adc #1
 clc
 adc gateposn
 tay ;Y:= (state/4) mod 8
 lda gate8c,y
 sta IMAGE

 lda #enum_ora
 sta OPACITY
 jmp add
}

\*-------------------------------
\*
\*  D R A W   G A T E   " B "
\*
\*  Lay down (STA) the gate in sections, bottom
\*  to top.  The bottom piece has two blank lines that
\*  erase its trail as the gate rises.
\*  Topmost section has 8 separate shapes, 1-8 pixels high.
\*
\*-------------------------------
.setupdgb
{
 lda Dy
 sec
 sbc #62
 sta blockthr ;topmost line of B-section

 lda spreced
 cmp #gmaxval
 bcc label_1
 lda #gmaxval
.label_1 lsr A
 lsr A
 clc
 adc #1
 sta gateposn ;gateposn:= state/4 + 1
;(gatebottom height off floor)
 lda Ay
 sec
 sbc gateposn
 sta gatebot ;gatebottom YCO
.return
 rts
}

\*-------------------------------
.drawgatebf
{
 jsr setupdgb

\* Gate bottom

 lda #enum_ora
 sta OPACITY

 lda gatebot
 sec
 sbc #2
 sta YCO ;no 2 blank lines at bottom

 lda #gatebotORA
 sta IMAGE

 jsr addfore

\* Middle pieces

.cont
 lda #gateB1
 sta IMAGE

 lda gatebot
 sec
 sbc #12

.loop sta YCO
 cmp #192
 bcs return

 sec
 sbc #7 ;grill mid piece is 8 lines high--
 bcc done ;will it stick up out of block area?
 cmp blockthr
 bcc done
;no, we're still safe--keep going
 jsr addfore

 lda YCO
 sec
 sbc #8
 bne loop
.done
 ;Skip top piece to save a little time
.return
 rts
}

\*-------------------------------
.drawgateb
{
 jsr setupdgb

\*  First, draw bottom piece

 clc
 adc #12
 cmp Ay ;over floor/wall boundary?
 bcc storit

\* Bottom piece is partly below floor line -- STA won't work.
\* We need to redraw b.g., then OR gate bottom on top.

.orit
 jsr restorebot

 lda gatebot
 sec
 sbc #2
 sta YCO ;no 2 blank lines at bottom

 lda #gatebotORA
 sta IMAGE

 lda #enum_ora
 sta OPACITY

 jsr addback

 jmp cont

\*  Gate is above floor line -- STA it

.storit lda gatebot
 sta YCO

 lda #gatebotSTA
 sta IMAGE

 lda #enum_sta
 sta OPACITY

 jsr addback

\*  Next, draw as many middle pieces as we need to make
\*  up rest of grill

.cont
 lda #enum_sta
 sta OPACITY

 lda #gateB1
 sta IMAGE

 lda gatebot
 sec
 sbc #12

.loop sta YCO
 cmp #192
 bcs return

 sec
 sbc #7 ;grill mid piece is 8 lines high--
 bcc done ;will it stick up out of block area?
 cmp blockthr
 bcc done
;no, we're still safe--keep going
 jsr addback

 lda YCO
 sec
 sbc #8
 bne loop

\* now add final piece at top

.done lda YCO
 sec
 sbc blockthr
 clc
 adc #1 ;desired height (0-8 pixels)

 beq return
 cmp #9
 bcs return

 tay
 lda gate8b-1,y
 sta IMAGE

 jsr addback

.return rts
}

\*-------------------------------
.restorebot
{
 ldx #gate
 lda pieceb,x
 sta IMAGE
 lda pieceby,x
 clc
 adc Ay
 sta YCO
 lda blockxco
 sta XCO
 lda #enum_sta
 sta OPACITY
 jsr add

 jsr checkc
 bcc label_1
 jsr dodrawc
.label_1 jmp drawa
}

\*-------------------------------
\*
\*  Draw object #x
\*  (Add appropriate images to mid table)
\*
\*  In: x = object table index
\*
\*-------------------------------
.drawobjx
{
 jsr loadobj ;Load vars with object data
;A = object type
 cmp #TypeKid
 beq kid
 cmp #TypeReflect
 bne label_1
.kid jmp DrawKid

.label_1 cmp #TypeShad
 bne label_2
 jmp DrawShad

.label_2 cmp #TypeFF
 bne label_3
 jmp DrawFF

.label_3 cmp #TypeSword
 beq label_5
 cmp #TypeComix

; KC decided only to have red hit fx - blue ones don't look good for guards
; beq label_5
; cmp #TypeComixAlt          ; alternate palette for comix
 bne label_4
; jmp DrawShifted
.label_5 jmp DrawSword

.label_4 cmp #TypeGd
 bne label_6
 jmp DrawGuard
.label_6
 rts
}

\*-------------------------------
\* Draw Falling Floor
\*-------------------------------
.DrawFF
{
 lda #LO(-1) ;normal
 sta FCharFace

 lda IMAGE ;mobframe #
 sta FCharImage ;use as temp store

\* A-section

 lda FCharY
 sec
 sbc #3
 sta YCO
 ldx #floor
 lda maska,x
 sta IMAGE
 lda #enum_and
 sta OPACITY
 lda #UseLayrsave
 jsr addmid

 ldx FCharImage
 lda loosea,x
 sta IMAGE
 lda #enum_ora
 sta OPACITY
 lda #UseLay
 jsr addmid

\* D-section

 ldx FCharImage
 lda loosed,x
 sta IMAGE
 lda FCharY
 sta YCO
 lda #enum_sta
 sta OPACITY
 lda #UseLayrsave
 jsr addmid

\* B-section

 lda FCharX
 clc
 adc #4
 sta XCO

 lda FCharY
 sec
 sbc #4
 sta YCO

 lda #looseb
 sta IMAGE
 lda #enum_ora
 sta OPACITY
 lda #UseLayrsave
 jmp addmid
}

\*-------------------------------
\*
\*  Get objid & state
\*
\*  In: BlueType/Spec,Y
\*
\*  Out: A = objid
\*       state = state
\*
\*  Preserves X & Y
\*
\*-------------------------------
.getobjid
 lda SCRNUM
 beq GOnull ;null scrn has no blueprint

\* Use getobjid1 for screen #s other than SCRNUM

.getobjid1
{
 IF EditorDisk
 lda inbuilder
 bne getobjbldr
 ENDIF

 lda (BlueSpec),y
 sta state

 lda (BlueType),y
 and #idmask

 cmp #pressplate
 beq plate

 cmp #upressplate
 beq upp

 rts

\* Handle depressed pressplate

.plate lda state ;LINKLOC index
 tax
 lda LINKMAP,x

 and #%00011111 ;bits 0-4
 cmp #2
 bcc local_up

 lda #dpressplate ;plate depressed
 rts

.local_up lda #pressplate ;plate up
 rts

\* Handle depressed upressplate

.upp lda state
 tax
 lda LINKMAP,x
 and #%00011111
 cmp #2
 bcc up1

 lda #0
 sta state
 lda #floor ;depressed upp looks just like floor
 rts

.up1 lda #upressplate
 rts
}

\* Null screen is black

.GOnull
{
 IF EditorDisk
 lda inmenu
 bne getobjbldr
 ENDIF

 lda #space
 rts
}

\*-------------------------------
\*
\* In builder: BlueSpec contains initial gadget settings
\*
\*-------------------------------
IF EditorDisk
.getobjbldr
{
 lda (BlueType),y
 and #idmask
 pha
 jsr getinitobj1
 bcs ok
 lda (BlueSpec),y
.ok sta state
 pla
 rts
}
ENDIF

\*-------------------------------
\*
\*  Sort objects in sort list into back-to-front order
\*  (Foremost object should be at bottom of list)
\*
\*-------------------------------
.sortlist
{
.newpass
 lda #0
 sta switches ;no switches yet this pass

 ldx sortX ;start at bottom of list

.loop cpx #1 ;at top of list?
 beq attop ;yes--pass complated

 stx xsave

 jsr compare ;Is obj[X] in front of obj[X-1]?

 ldx xsave

 bcc ok ;Yes--continue
;No--switch objects
 lda sortX,x
 pha
 lda sortX-1,x
 sta sortX,x
 pla
 sta sortX-1,x ;switch [X] with [X-1]

.ok dex
 bne loop ;move up in list

\* At top of list--pass completed

.attop
 lda switches ;Any switches this pass?
 bne newpass ;Yes--do it again

\* No switches made--objects are in order

.return rts
}

\*-------------------------------
\*
\*  Compare object [xsave] with object [xsave-1]
\*
\*  If X is IN FRONT OF X-1, or if it doesn't matter, return cc;
\*  If X is BEHIND X-1, return cs (switch 'em).
\*
\*-------------------------------
.compare
{
 lda sortX,x
 sta obj1 ;obj index [X]
 lda sortX-1,x
 sta obj2 ;obj index [X-1]

 ldx obj1
 ldy obj2

 lda objTYP,x
 cmp #TypeShad
 beq xinfront ;enemy is always in front

 lda objY,x
 cmp objY,y
 beq same
 bcc xinfront
 bcs yinfront

.same
.xinfront clc
 rts

.yinfront sec
 rts
}

\*-------------------------------
\*
\*  Get initial state of object
\*
\*  In: BlueType, BlueSpec, Y
\*
\*  Return cs if it matters, else cc
\*
\*-------------------------------
.GETINITOBJ
 lda (BlueType),y
 and #idmask ;get objid

.getinitobj1
{
 cmp #gate
 beq okgate
 cmp #loose
 beq okloose
 cmp #flask
 beq okflask
 bne skip ;if it isn't a gadget, leave it alone

.okgate lda (BlueSpec),y ;1=gate up, 2=gate down, etc.
 tax
 lda initsettings-1,x
 sec
 rts

.okloose lda #0 ;loose floor
 rts

.okflask lda (BlueSpec),y
 asl A
 asl A
 asl A
 asl A
 asl A;5x
 sec
 rts

.skip clc
.return rts
}

\*-------------------------------
.metbufs3 jsr mbsub
 iny
.metbufs2 jsr mbsub
 iny
.mbsub ora redbuf,y
 ora floorbuf,y
 ora halfbuf,y
 ora fredbuf,y
 ora wipebuf,y
 rts

\*-------------------------------
\ lst
\ ds 1
\ usr $a9,3,$490,*-org
\ lst off

\*-------------------------------
\* The following routines properly belong to FRAMEADV
\* but have been moved here for lack of space
\\ BEEB moved back to FRAMEADV module as do have space...
\*-------------------------------
\*
\*  C A L C   B L U E
\*
\*  Given:  screen #, 1-24 (in acc)
\*  Return: start of BLUETYPE table (in BlueType)
\*          start of BLUESPEC table (in BlueSpec)
\*
\*  If A = 0...
\*    In game: returns garbage
\*    In builder: returns menu data
\*
\*-------------------------------
.CALCBLUE
{
IF EditorDisk
 cmp #0
 beq calcmenu
ENDIF

 sec
 sbc #1 ;reduce to 0-23
 asl A
 tax ;x2

 lda Mult30,x
 clc
 adc #LO(blueprnt)
 sta BlueType

 lda Mult30+1,x
 adc #HI(blueprnt)
 sta BlueType+1

 lda BlueType
 clc
 adc #LO(24*30)
 sta BlueSpec

 lda BlueType+1
 adc #HI(24*30)
 sta BlueSpec+1

.return rts
}

IF EditorDisk
.calcmenu
{
 lda #LO(menutype)
 sta BlueType
 lda #HI(menutype)
 sta BlueType+1

 lda #LO(menuspec)
 sta BlueSpec
 lda #HI(menuspec)
 sta BlueSpec+1
 rts
}
ENDIF

\*-------------------------------
\*
\*  Z E R O   R E D
\*
\*  zero redraw buffers
\*
\*-------------------------------
.ZERORED
{
 lda #0
 ldy #29
.loop sta redbuf,y
 sta fredbuf,y
 sta floorbuf,y
 sta halfbuf,y
 sta wipebuf,y
 sta movebuf,y
 sta objbuf,y
 dey
 bpl loop

 ldy #9
.loop2 sta topbuf,y
 dey
 bpl loop2

 rts
}
