; hires.asm
; Originally HIRES.S
; Low-level Apple II rendering functions

.hires
\org = $ee00
\ tr on
\ lst off
\*-------------------------------
\*
\*  PRINCE OF PERSIA
\*  Copyright 1989 Jordan Mechner
\*
\*-------------------------------
 \org org

.cls jmp beeb_CLS
.lay jmp hires_lay
.fastlay jmp hires_fastlay
.layrsave jmp hires_layrsave

.lrcls BRK         ;jmp hires_lrcls    \ is implemented but not safe to call!
.fastmask jmp hires_fastmask
.fastblack jmp hires_fastblack
.peel jmp hires_peel
.getwidth jmp hires_getwidth

.copy2000 BRK      ;jmp copyscrnMM
.copy2000aux BRK   ;jmp copyscrnAA
.setfastaux BRK    ;jmp hires_SETFASTAUX
.setfastmain BRK   ;jmp hires_SETFASTMAIN
.copy2000ma BRK    ;jmp copyscrnMA

.copy2000am BRK    ;jmp copyscrnAM
\.inverty jmp INVERTY

\ Moved from grafix.asm
.rnd jmp RND
.movemem BRK        ;jmp MOVEMEM
.copyscrn BRK       ;jmp COPYSCRN
.vblank jmp beeb_wait_vsync    ;VBLvect jmp VBLANK ;changed by InitVBLANK if IIc
.vbli BRK           ;jmp VBLI ;VBL interrupt

\ Moved from subs.asm
.PageFlip jmp PAGEFLIP

\.normspeed RTS  ;jmp NORMSPEED         ; NOT BEEB
\.checkIIGS BRK  ;jmp CHECKIIGS         ; NOT BEEB
\.fastspeed RTS  ;jmp FASTSPEED         ; NOT BEEB


\*-------------------------------
\ put hrparams
\
\*-------------------------------
\boot3 = $f880 ;stage 3 boot
\
\peelbuf1 = $d000
\peelbuf2 = $d600
\
\* Local vars
\
\locals = $f0
\locals2 = $18
\
\ moved to hires.h.asm

\* OPACITY codes
\ Already defined in eq.h.asm
\and = 0
\ora = 1
\sta = 2
\eor = 3 ;OR/shift/XOR
\mask = 4 ;mask/OR

\*-------------------------------
\*
\* Assume hires routines are called from auxmem
\* (Exit with RAMRD, RAMWRT, ALTZP on)
\*
\*-------------------------------

IF _NOT_BEEB
.hires_cls
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM
 jsr beeb_CLS
\ jsr hires_CLS
\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 RTS
}
ENDIF

.hires_lay
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM
 jsr beeb_plot_sprite_LAY
\ jsr hires_LAY
\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 RTS
}

.hires_fastlay
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM
 \ OFFSET not guaranteed to be set in Apple II (not used by hires_FASTLAY)
 LDA #0
 STA OFFSET
 jsr beeb_plot_sprite_FASTLAY
\ jsr hires_FASTLAY
\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 RTS
}

.hires_layrsave
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM
 jsr beeb_plot_layrsave
\ jsr hires_LAYRSAVE
\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 RTS
}

.hires_lrcls
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM
 BRK
\ jsr hires_LRCLS
\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 RTS
}

.hires_fastmask
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM
\ OFFSET not guaranteed to be set in Apple II (not used by hires_FASTLAY)
 LDA #0
 STA OFFSET
 jsr beeb_plot_sprite_FASTMASK
\ jsr hires_FASTMASK
\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 RTS
}

.hires_fastblack
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM
 jsr beeb_plot_wipe
\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 RTS
}

.hires_peel
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM
 jsr beeb_plot_peel
\ jsr hires_PEEL
\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 RTS
}

.hires_getwidth
{
\ jsr mainmem
 BEEB_SELECT_MAIN_MEM

 jsr hires_GETWIDTH

\\ must preserve A&X
 STA regA+1

\\ must preserve callers SWRAM bank

\ jmp auxmem
 BEEB_SELECT_AUX_MEM
 
 .regA
 LDA #0
 RTS
}

\*-------------------------------
\*
\*  Generate random number
\*
\*  RNDseed := (5 * RNDseed + 23) mod 256
\*
\*-------------------------------
.RND
{
 lda RNDseed
 asl A
 asl A
 clc
 adc RNDseed
 clc
 adc #23
 sta RNDseed
.return rts
}

\*-------------------------------
\*
\*  P A G E F L I P
\*
\*-------------------------------

.PAGEFLIP
{
\ jsr normspeed ;IIGS
\ lda PAGE
\ bne :1
\
\ lda #$20
\ sta PAGE
\ lda $C054 ;show page 1
\
\:3 lda $C057 ;hires on
\ lda $C050 ;text off
\ lda vibes
\ beq :rts
\ lda $c05e
\]rts rts
\:rts lda $c05f
\ rts
\
\:1 lda #0
\ sta PAGE
\ lda $C055 ;show page 2
\ jmp :3

    LDA PAGE
    EOR #&20
    STA PAGE

    JMP shadow_swap_buffers
}

\*-------------------------------
\*
\*  Parameters passed to hires routines:
\*
\*  PAGE        $00 = hires page 1, $20 = hires page 2
\*  XCO         Screen X-coord (0=left, 39=right)
\*  YCO         Screen Y-coord (0=top, 191=bottom)
\*  OFFSET      # of bits to shift image right (0-6)
\*  IMAGE       Image # in table (1-127)
\*  TABLE       Starting address of image table (2 bytes)
\*  BANK        Memory bank of table (2 = main, 3 = aux)
\*  OPACITY     Bits 0-6:
\*                0    AND
\*                1    OR
\*                2    STA
\*                3    special XOR (OR/shift/XOR)
\*                4    mask/OR
\*              Bit 7: 0 = normal, 1 = mirror
\*  LEFTCUT     Left edge of usable screen area
\*                (0 for full screen)
\*  RIGHTCUT    Right edge +1 of usable screen area
\*                (40 for full screen)
\*  TOPCUT      Top edge of usable screen area
\*                (0 for full screen)
\*  BOTCUT      Bottom edge +1 of usable screen area
\*                (192 for full screen)
\*
\*-------------------------------
\*
\*  Image table format:
\*
\*  Byte 0:    width (# of bytes)
\*  Byte 1:    height (# of lines)
\*  Byte 2-n:  image bytes (read left-right, top-bottom)
\*
\*-------------------------------
\*
\*  To preserve the background behind an animated character,
\*  call LAYERSAVE before LAYing down each character image.
\*  Afterwards, call PEEL to "peel off" the character &
\*  restore the original background.
\*
\*  Peel buffer stores background images sequentially, in
\*  normal image table format, & is cleared after every frame.
\*
\*-------------------------------
\*
\*  C L S
\*
\*  Clear hi-res screen to black2
\*
\*-------------------------------

IF _NOT_BEEB
.hires_CLS
{
 lda PAGE ;00 = page 1; 20 = page 2
 clc
 adc #$20
 sta loop+2
 adc #$10
 sta smod+2

 lda #$80 ;black2

 ldx #$10

 ldy #0

.loop sta $2000,y
.smod sta $3000,y
 iny
 bne loop

 inc loop+2
 inc smod+2

 dex
 bne loop

 rts
}
ENDIF

\*-------------------------------
\*
\*  L O - R E S   C L S
\*
\*  Clear lo-res/text screen (page 1)
\*
\*  In: A = color
\*
\*-------------------------------

IF _NOT_BEEB
.hires_LRCLS
{
 LDY #$F7
.label_2 STA $400,Y
 STA $500,Y
 STA $600,Y
 STA $700,Y
 DEY
 CPY #$7F
 BNE label_3
 LDY #$77
.label_3 CPY #$FF
 BNE label_2
 RTS
}
ENDIF

\*-------------------------------
\*
\*  S E T   I M A G E
\*
\*  In: TABLE (2 bytes), IMAGE (image #)
\*  Out: IMAGE = image start address (2 bytes)
\*
\*-------------------------------

.setimage
{
\\ Bounds check that image# is not out of range of the table
IF _DEBUG
 LDA IMAGE
 BNE not_zero
 BRK
 .not_zero

 LDA (TABLE)
 CMP IMAGE
 BCS image_ok
 BRK
 .image_ok
ENDIF

 lda IMAGE
 asl A
 sec
 sbc #1

 tay
 lda (TABLE),y
 sta IMAGE

 iny
 lda (TABLE),y
 sta IMAGE+1

\\ Bounds check that sprite data pointer is in swram
IF _DEBUG
 BMI addr_ok
 CMP #HI(small_font+1)      ; only image table not in SWRAM
 BEQ addr_ok
 CMP #HI(small_font+1)+1    ; only image table not in SWRAM
 BEQ addr_ok
 BRK
 .addr_ok
ENDIF

 rts
}

\*-------------------------------
\*
\*  G E T   W I D T H
\*
\*  In: BANK, TABLE, IMAGE
\*  Out: A = width, X = height
\*
\*-------------------------------
.hires_GETWIDTH
{
\ NOT BEEB
\ lda BANK
\ sta RAMRD+1
\
\.RAMRD sta $c003

 \\ Select swram bank for sprite data
 LDA BANK
 JSR swr_select_slot

 jsr setimage

 ldy #1
 lda (IMAGE),y ;height
 tax

 dey
 lda (IMAGE),y ;width
 rts
}

\*-------------------------------
\*
\*  P R E P R E P
\*
\*  In: IMAGE, XCO, YCO
\*
\*-------------------------------

.PREPREP
{
\* Save IMAGE, XCO, YCO

 LDA IMAGE

\\ Bounds check that image# is not zero
IF _DEBUG
 BNE image_ok
 BRK
.image_ok
ENDIF

 STA IMSAVE
 LDA XCO
 STA XSAVE
 LDA YCO
 STA YSAVE

\* Get image data start address

\ NOT BEEB
\ lda BANK
\ sta RAMRD+1
\
\.RAMRD sta $c003

 jsr setimage

\* Read first two bytes (width, height) of image table

 LDY #0
 LDA (IMAGE),Y
 STA WIDTH

\\ Bounds check that width <=16 bytes
IF _DEBUG
 CMP #16
 BCC width_ok
 BRK
 .width_ok
ENDIF

 INY
 LDA (IMAGE),Y
 STA HEIGHT

 INY
 LDA (IMAGE),Y
 STA PALETTE

\\ Bounds check
IF _DEBUG
 BMI pal_ok
 AND #&BF
 CMP #BEEB_PALETTE_MAX
 BEQ pal_ok
 BCC pal_ok
 BRK
 .pal_ok
ENDIF

 LDA IMAGE
 CLC
 ADC #3
 STA IMAGE
 BCC label_3
 INC IMAGE+1

.label_3
\ NOT BEEB
\ sta $c002 ;RAMRD off (read mainmem)

.return rts
}

\*-------------------------------
\*
\*  C R O P
\*
\*  In:  Results of PREPREP (XCO, YCO, HEIGHT, WIDTH)
\*       Screen area cutoffs (LEFTCUT, RIGHTCUT, TOPCUT, BOTCUT)
\*
\*  Out:
\*
\*  TOPEDGE   Top line -1
\*  VISWIDTH  Width, in bytes, of visible (onscreen) portion
\*               of image
\*  XCO       X-coord of leftmost visible byte of image
\*               (must be 0-39)
\*  YCO       Y-coord of lowest visible line of image
\*               (must be 0-191)
\*  OFFLEFT   # of bytes off left edge
\*  OFFRIGHT  # of bytes off right edge (including carry byte)
\*  RMOST     # of bytes off right edge (excluding carry byte)
\*
\*  Return - if entire image is offscreen, else +
\*
\*-------------------------------
.CROP
{
\* (1) Crop top & bottom

 lda YCO
 cmp BOTCUT
 bcs botoff ;Bottom o.s.

\* Bottom is onscreen--check top

 sec
 sbc HEIGHT ;top line -1
 cmp #191
 bcc topok ;Top is onscreen

 lda TOPCUT ;Top is offscreen
 sec
 sbc #1
 sta TOPEDGE
 jmp done

.topok sta TOPEDGE ;Top line -1 (0-191)

 lda TOPCUT ;top line of image area (forced mask)
 beq done ;no top cutoff

 sec
 sbc #1
 cmp TOPEDGE
 bcc done

 sta TOPEDGE
 bcs done

\* Bottom is o.s.--advance IMAGE pointer past o.s. portion

.botoff ;A = YCO
 sec
 sbc HEIGHT\
 clc
 adc #1 ;top line
 cmp BOTCUT

 bcc not_os
 JMP cancel
 .not_os

 sec
 sbc #1
 sta TOPEDGE ;top line -1

\\ BEEBHACK for half res sprites

    LDA BEEBHACK
    BEQ no_beebhack

    \ The ugliest hack :(
    LDA WIDTH
    STA smEOR+1
    LDA #0
    STA smWIDTH+1
    BEQ done_beebhack

    .no_beebhack
    LDA WIDTH
    STA smWIDTH+1
    LDA #0
    STA smEOR+1

    .done_beebhack

 ldx YCO
.loop
 lda IMAGE
 clc

\\ BEEBHACK for half res sprites
 .smWIDTH
 adc #0

 sta IMAGE
 bcc label_1
 inc IMAGE+1
.label_1

\\ BEEBHACK for half res sprites

 LDA smWIDTH+1
 .smEOR
 EOR #0
 STA smWIDTH+1

 dex
 cpx BOTCUT
 bcs loop

 stx YCO

\* (2) Crop sides

.done
 lda XCO
 bmi leftoff
 cmp LEFTCUT
 bcs leftok ;XCO >= LEFTCUT

\* XCO < LEFTCUT: left edge is offscreen

.leftoff
 lda LEFTCUT
 sec
 sbc XCO
 sta OFFLEFT ;Width of o.s. portion

 lda WIDTH
 sec
 sbc OFFLEFT
 bmi cancel ;Entire image is o.s. -- skip it
 sta VISWIDTH ;Width of onscreen portion (can be 0)

 lda LEFTCUT
 sta XCO

\* Assume image is <=40 bytes wide --> right edge is onscreen

 lda #0
 sta OFFRIGHT
 sta RMOST
 rts

\* Left edge is onscreen; what about right edge?

.leftok ;A = XCO
 cmp RIGHTCUT ;normally 40
 bcs cancel ;Entire image is o.s. - skip it

 clc
 adc WIDTH ;rightmost byte +1
 cmp RIGHTCUT
 bcc bothok ;Entire image is onscreen

 sec
 sbc RIGHTCUT
 sta RMOST ;Width of o.s. portion

 clc
 adc #1
 sta OFFRIGHT ;+1

 lda RIGHTCUT
 sec
 sbc XCO
 sta VISWIDTH ;Width of onscreen portion

 lda #0
 sta OFFLEFT
 rts

.bothok lda WIDTH
 sta VISWIDTH

 lda #0
 sta OFFLEFT
 sta OFFRIGHT
 sta RMOST
 rts

.cancel lda #LO(-1) ;Entire image is o.s. - skip it
.return rts
}

IF _NOT_BEEB
\*-------------------------------
\*
\* Shift offset 1 bit right or left
\* (for special XOR)
\*
\* In/out: X = offset
\*
\*-------------------------------
.shiftoffset
{
 cpx #6
 bcs left

 inx
 rts

.left dex
.return rts
}

\*-------------------------------
\*
\*  L A Y E R S A V E
\*
\*  In:  Same as for LAY, plus PEELBUF (2 bytes)
\*  Out: PEELBUF (updated), PEELIMG (2 bytes), PEELXCO, PEELYCO
\*
\*  PEELIMG is 2-byte pointer to beginning of image table.
\*  (Hi byte = 0 means no image has been stored.)
\*
\*  PEELBUF is 2-byte pointer to first available byte in
\*  peel buffer.
\*
\*-------------------------------

.hires_LAYRSAVE
{
 jsr PREPREP

 lda OPACITY
 bpl normal

 LDA XCO
 SEC
 SBC WIDTH
 STA XCO

.normal
 inc WIDTH ;extra byte to cover shift right

 jsr CROP
 bmi SKIPIT

 lda PEELBUF ;PEELBUF: 2-byte pointer to 1st
 sta PEELIMG ;available byte in peel buffer
 lda PEELBUF+1
 sta PEELIMG+1

 lda XCO
 sta PEELXCO
 sta smXCO+1

 lda YCO
 sta PEELYCO

 lda PAGE ;spend 7 cycles now --
 sta smPAGE+1 ;save 1 in loop

 ldy #0

 lda VISWIDTH
 beq SKIPIT
 sta (PEELBUF),y
 sta smWIDTH+1

 sec
 sbc #1
 sta smSTART+1

\* Continue

.cont iny

 LDA YCO
 SEC
 SBC TOPEDGE
 STA (PEELBUF),y ;Height of onscreen portion ("VISHEIGHT")

 LDA PEELBUF
 CLC
 ADC #2
 STA PEELBUF
 BCC ok
 INC PEELBUF+1
.ok

\* Like FASTLAY in reverse

 ldx YCO

.loop LDA YLO,X
 CLC
.smXCO ADC #0 ;XCO
 STA smBASE+1

 LDA YHI,X
.smPAGE ADC #0 ;PAGE
 STA smBASE+2

.smSTART ldy #0 ;VISWIDTH-1

.inloop
.smBASE lda $2000,y
 STA (PEELBUF),Y

 dey
 bpl inloop

.smWIDTH LDA #0 ;VISWIDTH
 ADC PEELBUF ;assume cc
 STA PEELBUF
 BCC label_2
 INC PEELBUF+1
.label_2
 DEX
 CPX TOPEDGE
 BNE loop

 JMP DONE
}
ENDIF

.SKIPIT
{
 lda #0
 sta PEELIMG+1 ;signal that peelbuf is empty

 JMP DONE
}

IF _NOT_BEEB
\*-------------------------------
\*
\*  L A Y
\*
\*  General routine to lay down an image on hi-res screen
\*  (Handles edge-clipping, bit-shifting, & mirroring)
\*
\*  Calls one of the following routines:
\*
\*    LayGen    General (OR, AND, STA)
\*    LayMask   Mask & OR
\*    LayXOR    Special XOR
\*
\*  Transfers control to MLAY if image is to be mirrored
\*
\*-------------------------------

.hires_LAY
{
 lda OPACITY
 bpl notmirr

 and #$7f
 sta OPACITY
 jmp MLAY

.notmirr cmp #enum_eor
 bne label_1
 jmp LayXOR

.label_1 cmp #enum_mask
 bcc label_2
 jmp LayMask

.label_2 jmp LayGen
}

\*-------------------------------
\*
\*   General (AND/OR/STORE)
\*
\*-------------------------------
.LayGen
{
 jsr PREPREP

 jsr CROP
 bpl cont
 jmp DONE
.cont
 lda BANK
 sta RAMRD1+1
 sta RAMRD2+1

 LDX OFFSET

 LDA SHIFTL,X
 STA label_91+1
 LDA SHIFTH,X
 STA label_91+2

 LDA CARRYL,X
 STA label_90+1
 STA label_92+1
 LDA CARRYH,X
 STA label_90+2
 STA label_92+2

.testme

 LDA AMASKS,X
 STA label_AMASK+1
 LDA BMASKS,X
 STA label_BMASK+1

 LDX OPACITY
 LDA OPCODE,X
 STA label_80
 STA label_81

\* Preparation completed -- Lay down shape

 LDY YCO

.LayGen_nextline
 LDA YLO,Y
 CLC
 ADC XCO
 STA BASE

 LDA YHI,Y
 ADC PAGE
 STA BASE+1

 LDY OFFLEFT
 BEQ label_2

\* (a) Left edge of image is offscreen
\* Take initial carry byte from image table

 DEY

.RAMRD1 sta $c003 ;aux/main
 lda (IMAGE),y
 sta $c002 ;main

 TAX
.label_90 LDA $FFFF,X ;CARRYn
 STA CARRY

 LDA IMAGE
 CLC
 ADC OFFLEFT
 STA IMAGE
 BCC label_1
 INC IMAGE+1
.label_1
 LDY #0

 LDA VISWIDTH
 STA WIDTH
 BNE label_3
 BEQ label_4 ;Zero width

\* (b) Left edge of image is onscreen
\* Take initial carry byte from screen

.label_2 LDA (BASE),Y
.label_AMASK AND #0
 STA CARRY

\* Lay line down left-to-right fast as you can

.label_3
.RAMRD2 sta $c003 ;aux/main
 lda (IMAGE),y
 sta $c002 ;main

 TAX
.label_91 LDA $FFFF,X ;SHIFTn
 ORA CARRY ;Combine with carryover from previous byte

.label_80 STA (BASE),Y ;STA/ORA/AND/EOR depending on OPACITY
 STA (BASE),Y

.label_92 LDA $FFFF,X ;CARRYn
 STA CARRY ;Carry over to next byte

 INY
 CPY VISWIDTH
 BCC label_3

\*  Extra byte on right (carryover)

 LDA OFFRIGHT
 BNE label_5 ;Rightmost byte is offscreen

.label_4 LDA (BASE),Y

.label_BMASK AND #0
 ORA CARRY
.label_81 STA (BASE),Y
 STA (BASE),Y

\*  Next line up

.label_5 LDA WIDTH
 CLC
 ADC IMAGE
 STA IMAGE
 BCC label_6
 INC IMAGE+1

.label_6 DEC YCO
 LDY YCO
 CPY TOPEDGE
 BNE LayGen_nextline

\*  Restore parameters
}
ENDIF

\\ Drop through!
.DONE
{
 LDA IMSAVE
 STA IMAGE

 LDA XSAVE
 STA XCO
 LDA YSAVE
 STA YCO

 RTS
}

IF _NOT_BEEB
\*-------------------------------
\*
\*  Mask, then OR
\*
\*-------------------------------
.label_done jmp DONE

.LayMask
{
 ldx OPACITY ;4 = mask, 5 = visible mask
 lda OPCODE,x ;4 = and, 5 = sta
 sta masksm1
 sta masksm2

 jsr PREPREP

 jsr CROP
 bmi label_done

 lda BANK
 sta RAMRD1+1
 sta RAMRD2+1

 LDX OFFSET

 LDA SHIFTL,X
 STA label_91+1
 sta label_93+1

 LDA SHIFTH,X
 STA label_91+2
 sta label_93+2

 LDA CARRYL,X
 STA label_90+1
 STA label_92+1
 sta label_94+1
 sta label_96+1

 LDA CARRYH,X
 STA label_90+2
 STA label_92+2
 sta label_94+2
 sta label_96+2

 LDA AMASKS,X
 STA label_AMASK+1

 LDA BMASKS,X
 STA label_BMASK+1

 LDY YCO

.LayMask_nextline
 LDA YLO,Y
 CLC
 ADC XCO
 STA BASE

 LDA YHI,Y
 ADC PAGE
 STA BASE+1

 LDY OFFLEFT
 BEQ label_2

\* (a) Left edge of image is offscreen
\* Take initial carry byte from image table

 dey

.RAMRD1 sta $c003
 lda (IMAGE),y
; eor #$ff ;TEMP
; ora #$80 ;TEMP
 sta $c002

 tax
.label_96 lda $FFFF,x ;CARRYn
 sta carryim

 lda MASKTAB-$80,x
 tax
.label_90 lda $FFFF,x ;CARRYn
 sta CARRY

 LDA IMAGE
 CLC
 ADC OFFLEFT
 STA IMAGE
 BCC label_1
 INC IMAGE+1
.label_1
 ldy #0

 LDA VISWIDTH
 STA WIDTH
 BNE inloop
 BEQ label_4 ;Zero width

\* (b) Left edge of image is onscreen
\* Take initial carry byte from screen

.label_2
.label_AMASK lda #0 ;AMASK
 sta CARRY

 and (BASE),y
 sta carryim

\* Lay line down left-to-right fast as you can

.inloop

.RAMRD2 sta $c003
 lda (IMAGE),y
; eor #$ff ;TEMP
; ora #$80 ;TEMP
 sta $c002

 tax

.label_93 lda $FFFF,x ;SHIFTn
 ora carryim
 sta imbyte ;shifted image byte

.label_94 lda $FFFF,x ;CARRYn
 sta carryim

 lda MASKTAB-$80,x
 tax

.label_91 lda $FFFF,x ;SHIFTn
 ora CARRY
.masksm1 and (BASE),y ;AND with mask byte
 ora imbyte ;OR with original image byte
 sta (BASE),y

.label_92 lda $FFFF,x ;CARRYn
 sta CARRY ;Carry over to next byte

 iny
 cpy VISWIDTH
 bcc inloop

\*  Extra byte on right (carryover)

 lda OFFRIGHT
 bne label_5 ;Rightmost byte is offscreen

.label_4
.label_BMASK lda #0 ;BMASK
 ora CARRY
.masksm2 and (BASE),y
 ora carryim
 sta (BASE),y

\*  Next line up

.label_5 LDA WIDTH
 CLC
 ADC IMAGE
 STA IMAGE
 BCC label_6
 INC IMAGE+1

.label_6 DEC YCO
 LDY YCO
 CPY TOPEDGE
 beq done

 jmp LayMask_nextline

.done jmp DONE
}

\*-------------------------------
\*
\*  Special XOR
\*
\*  (OR, then shift 1 bit and XOR)
\*
\*-------------------------------

.LayXOR
{
 JSR PREPREP

 jsr CROP
 bpl cont
 jmp DONE
.cont
 lda BANK
 sta RAMRD1+1
 sta RAMRD2+1

 LDX OFFSET

 LDA SHIFTL,X
 STA label_91+1
 LDA SHIFTH,X
 STA label_91+2

 LDA CARRYL,X
 STA label_90+1
 STA label_92+1
 LDA CARRYH,X
 STA label_90+2
 STA label_92+2

 jsr shiftoffset ;shift 1 bit right

 lda SHIFTL,x
 sta s1+1
 lda SHIFTH,x
 sta s1+2

 lda CARRYL,x
 sta c1+1
 sta c2+1
 lda CARRYH,x
 sta c1+2
 sta c2+2

 LDA AMASKS,X
 STA label_AMASK+1

\* Omit opcode setting

 LDY YCO

.label_0 LDA YLO,Y
 CLC
 ADC XCO
 STA BASE

 LDA YHI,Y
 ADC PAGE
 STA BASE+1

 LDY OFFLEFT
 BEQ label_2

\*  (a) Left edge offscreen
\*  Take CARRY from off left edge

 DEY

.RAMRD1 sta $c003
 lda (IMAGE),y
 sta $c002

 TAX
.c2 lda $FFFF,x ;CARRYn+1
 sta carryim

.label_90 LDA $FFFF,X ;CARRYn
 STA CARRY

 LDA IMAGE
 CLC
 ADC OFFLEFT
 STA IMAGE
 BCC label_1
 INC IMAGE+1

.label_1 LDY #0

 LDA VISWIDTH
 STA WIDTH
 BNE inloop
 BEQ label_4 ;Zero width

\* (b) Left edge onscreen
\* Start a new line at left edge

.label_2 lda (BASE),y
.label_AMASK and #0 ;AMASK
 sta CARRY

 lda #0 ;0 XOR X == X
 sta carryim

\* Lay line down left-to-right fast as you can

.inloop

.RAMRD2 sta $c003
 lda (IMAGE),y
 sta $c002

 tax

.s1 lda $FFFF,x ;SHIFTn+1
 ora carryim
 sta imbyte

.c1 lda $FFFF,x ;CARRYn+1
 sta carryim

.label_91 lda $FFFF,x ;SHIFTn
 ora CARRY ;Combine with carryover from previous byte

 ora (BASE),y
 eor imbyte

 ora #$80 ;set hibit
 sta (BASE),y

.label_92 LDA $FFFF,X ;CARRYn
 STA CARRY ;Carry over to next byte

 INY
 CPY VISWIDTH
 BCC inloop

\*  Extra byte on right (carryover)

 LDA OFFRIGHT
 BNE label_5 ;Rightmost byte is offscreen

.label_4 lda CARRY ;0's in unused part of byte

 ora (BASE),y
 eor carryim

 ora #$80
 sta (BASE),y

\*  Next line up

.label_5 LDA WIDTH
 CLC
 ADC IMAGE
 STA IMAGE
 BCC label_6
 INC IMAGE+1

.label_6 DEC YCO
 LDY YCO
 CPY TOPEDGE
 beq done

 jmp label_0

\*  Restore parameters

.done jmp DONE
}

\*-------------------------------
\*
\*  M I R R O R    L A Y
\*
\*  Called by LAY
\*
\*  Specified starting byte (XCO, YCO) is image's bottom
\*  right corner, not bottom left; bytes are read off image
\*  table R-L, T-B and mirrored before printing.
\*
\*  In:  A = OPACITY, sans bit 7
\*
\*-------------------------------

.MLAY ;A = OPACITY
{
 cmp #enum_eor
 bne label_1
 jmp MLayXOR

.label_1 cmp #enum_mask
 bcc label_2
 jmp MLayMask

.label_2 jmp MLayGen
}

\*-------------------------------
\*
\*  General (AND/OR/STORE)
\*
\*-------------------------------
.MLayGen
{
 JSR PREPREP

 LDA XCO
 SEC
 SBC WIDTH
 STA XCO

 jsr CROP
 bpl cont
 jmp DONE
.cont
 lda BANK
 sta RAMRD1+1
 sta RAMRD2+1

 LDX OFFSET

 LDA SHIFTL,X
 STA label_91+1
 LDA SHIFTH,X
 STA label_91+2

 LDA CARRYL,X
 STA label_90+1
 STA label_92+1
 LDA CARRYH,X
 STA label_90+2
 STA label_92+2

 LDA AMASKS,X
 STA AMASK
 LDA BMASKS,X
 STA BMASK

 LDX OPACITY
 LDA OPCODE,X
 STA label_80
 STA label_81

\* Lay on

 LDY YCO

.label_0 LDA YLO,Y
 STA BASE

 LDA YHI,Y
 CLC
 ADC PAGE
 STA BASE+1

 LDY OFFLEFT
 BEQ label_2

\* Take CARRY from off left edge

 LDY VISWIDTH

.RAMRD1 sta $c003
 lda (IMAGE),y
 sta $c002

 TAX

 LDA MIRROR-$80,X
 TAX

.label_90 LDA $FFFF,X ;CARRYn
 STA CARRY

.label_1 DEY
 BPL label_3
 BMI label_4

\* Start a new line at left edge

.label_2 LDY XCO
 LDA (BASE),Y
 AND AMASK
 STA CARRY

 LDY WIDTH
 DEY

\* Lay line down left-to-right fast as you can

.label_3 STY YREG

.RAMRD2 sta $c003
 lda (IMAGE),y
 sta $c002

 TAX

 LDA MIRROR-$80,X
 TAX

.label_91 LDA $FFFF,X ;SHIFTn
 ORA CARRY ;Combine with carryover from previous byte

 LDY XCO
.label_80 STA (BASE),Y ;STA/ORA/AND/EOR depending on OPACITY
 STA (BASE),Y

.label_92 LDA $FFFF,X ;CARRYn
 STA CARRY ;Carry over to next byte

 INC BASE

 LDY YREG
 CPY RMOST
 BEQ label_7

 DEY
 BPL label_3

\*  Extra byte on right (carryover)

.label_7 LDA OFFRIGHT
 BNE label_5 ;Rightmost byte is offscreen

.label_4 LDY XCO
 LDA (BASE),Y

 AND BMASK
 ORA CARRY
.label_81 STA (BASE),Y
 STA (BASE),Y

\*  Next line up

.label_5 LDA WIDTH
 CLC
 ADC IMAGE
 STA IMAGE
 BCC label_6
 INC IMAGE+1

.label_6 DEC YCO
 LDY YCO
 CPY TOPEDGE

 beq done
 jmp label_0

.done JMP DONE
}

\*-------------------------------
\*
\*  Mask, then OR
\*
\*-------------------------------

.MLayMask
{
 ldx OPACITY ;4 = mask, 5 = visible mask
 lda OPCODE,x ;4 = and, 5 = sta
 sta masksm1
 sta masksm2

 JSR PREPREP

 LDA XCO
 SEC
 SBC WIDTH
 STA XCO

 jsr CROP
 bpl cont
 jmp DONE
.cont
 lda BANK
 sta RAMRD1+1
 sta RAMRD2+1

 LDX OFFSET

 LDA SHIFTL,X
 STA label_91+1
 sta label_93+1

 LDA SHIFTH,X
 STA label_91+2
 sta label_93+2

 LDA CARRYL,X
 STA label_90+1
 STA label_92+1
 sta label_94+1
 sta label_96+1

 LDA CARRYH,X
 STA label_90+2
 STA label_92+2
 sta label_94+2
 sta label_96+2

 LDA AMASKS,X
 STA label_AMASK+1
 LDA BMASKS,X
 STA label_BMASK+1

\* Lay on

 LDY YCO

.label_0 LDA YLO,Y
 STA BASE

 LDA YHI,Y
 CLC
 ADC PAGE
 STA BASE+1

 LDY OFFLEFT
 BEQ label_2

\* (a) Left edge offscreen
\* Take CARRY from off left edge

 LDY VISWIDTH

.RAMRD1 sta $c003
 lda (IMAGE),y
; eor #$ff ;TEMP
; ora #$80 ;TEMP
 sta $c002

 TAX
 LDA MIRROR-$80,X
 TAX

.label_96 lda $FFFF,x ;CARRYn
 sta carryim

 lda MASKTAB-$80,x
 tax
.label_90 LDA $FFFF,X ;CARRYn
 STA CARRY

.label_1 DEY
 BPL label_3
 BMI label_4

\* (b) Left edge onscreen
\* Start a new line at left edge

.label_2 LDY XCO
.label_AMASK lda #0 ;AMASK
 sta CARRY

 and (BASE),y
 sta carryim

 LDY WIDTH
 DEY

\* Lay line down left-to-right fast as you can

.label_3 STY YREG

.RAMRD2 sta $c003
 lda (IMAGE),y
; eor #$ff ;TEMP
; ora #$80 ;TEMP
 sta $c002

 TAX
 LDA MIRROR-$80,X
 TAX

.label_93 lda $FFFF,x ;SHIFTn
 ora carryim
 sta imbyte

.label_94 lda $FFFF,x ;CARRYn
 sta carryim

 lda MASKTAB-$80,x
 tax

.label_91 LDA $FFFF,X ;SHIFTn
 ORA CARRY ;Combine with carryover from previous byte

 LDY XCO
.masksm1 and (BASE),y
 ora imbyte
 STA (BASE),Y

.label_92 LDA $FFFF,X ;CARRYn
 STA CARRY ;Carry over to next byte

 INC BASE

 LDY YREG
 CPY RMOST
 BEQ label_7

 DEY
 BPL label_3

\*  Extra byte on right (carryover)

.label_7 LDA OFFRIGHT
 BNE label_5 ;Rightmost byte is offscreen

.label_4 LDY XCO
 LDA (BASE),Y

.label_BMASK AND #0 ;BMASK
 ORA CARRY
.masksm2 and (BASE),y
 ora carryim
 STA (BASE),Y

\*  Next line up

.label_5 LDA WIDTH
 CLC
 ADC IMAGE
 STA IMAGE
 BCC label_6
 INC IMAGE+1

.label_6 DEC YCO
 LDY YCO
 CPY TOPEDGE
 beq done

 jmp label_0

.done jmp DONE
}

\*-------------------------------
\*
\*  Special XOR
\*
\*-------------------------------

.MLayXOR
{
 JSR PREPREP

 LDA XCO
 SEC
 SBC WIDTH
 STA XCO

 jsr CROP
 bpl cont
 jmp DONE
.cont
 lda BANK
 sta RAMRD1+1
 sta RAMRD2+1

 LDX OFFSET

 LDA SHIFTL,X
 STA label_91+1
 LDA SHIFTH,X
 STA label_91+2

 LDA CARRYL,X
 STA label_90+1
 STA label_92+1
 LDA CARRYH,X
 STA label_90+2
 STA label_92+2

 jsr shiftoffset

 lda SHIFTL,x
 sta s1+1
 lda SHIFTH,x
 sta s1+2

 lda CARRYL,x
 sta c1+1
 sta c2+1
 lda CARRYH,x
 sta c1+2
 sta c2+2

 LDA AMASKS,X
 STA label_AMASK+1

\* Lay on

 LDY YCO

.label_0 LDA YLO,Y
 STA BASE

 LDA YHI,Y
 CLC
 ADC PAGE
 STA BASE+1

 LDY OFFLEFT
 BEQ label_2

\* (a) Left edge offscreen
\* Take CARRY from off left edge

 LDY VISWIDTH

.RAMRD1 sta $c003
 lda (IMAGE),y
 sta $c002

 TAX
 LDA MIRROR-$80,X
 TAX

.c2 lda $FFFF,x ;CARRYn+1
 sta carryim

.label_90 LDA $FFFF,X ;CARRYn
 STA CARRY

.label_1 DEY
 BPL label_3
 BMI label_4

\* (b) Left edge onscreen
\* Start a new line at left edge

.label_2 ldy XCO
.label_AMASK lda #0 ;AMASK
 and (BASE),y
 sta CARRY

 lda #0
 sta carryim

 LDY WIDTH
 DEY

\* Lay line down left-to-right fast as you can

.label_3 STY YREG

.RAMRD2 sta $c003
 lda (IMAGE),y
 sta $c002

 TAX

 LDA MIRROR-$80,X
 TAX

.s1 lda $FFFF,x ;SHIFTn
 ora carryim
 sta imbyte

.c1 lda $FFFF,x ;CARRYn
 sta carryim

.label_91 LDA $FFFF,X ;SHIFTn
 ORA CARRY ;Combine with carryover from previous byte

 LDY XCO

 ora (BASE),y
 eor imbyte

 ora #$80
 sta (BASE),Y

.label_92 LDA $FFFF,X ;CARRYn
 STA CARRY ;Carry over to next byte

 INC BASE

 LDY YREG
 CPY RMOST
 BEQ label_7

 DEY
 BPL label_3

\*  Extra byte on right (carryover)

.label_7 LDA OFFRIGHT
 BNE label_5 ;Rightmost byte is offscreen

.label_4 LDY XCO

 lda CARRY

 ora (BASE),Y
 eor carryim

 ora #$80
 STA (BASE),Y

\*  Next line up

.label_5 LDA WIDTH
 CLC
 ADC IMAGE
 STA IMAGE
 BCC label_6
 INC IMAGE+1

.label_6 DEC YCO
 LDY YCO
 CPY TOPEDGE
 beq done

 jmp label_0

.done JMP DONE
}

\*-------------------------------
\*
\* Peel
\*
\*-------------------------------
.hires_PEEL
{
 sta $c004
.ramrd1 sta $c003

 jmp fastlaySTA
}

\*-------------------------------
\*
\*  F A S T L A Y
\*
\*  Streamlined LAY routine
\*
\*  No offset - no clipping - no mirroring - no masking -
\*  no EOR - trashes IMAGE - may crash if overtaxed -
\*  but it's fast.
\*
\*  10/3/88: OK for images to protrude PARTLY off top
\*
\*-------------------------------
.hires_FASTLAY
{
 sta $c004 ;RAMWRT main
.ramrd2 sta $c003 ;RAMRD aux

 jsr setimage

 ldx OPACITY ;hi bit off!
 cpx #enum_sta
 beq fastlaySTA

 lda OPCODE,x
 sta  smod

 lda PAGE
 sta smPAGE+1

 lda XCO
 sta  smXCO+1

 ldy #0
 lda (IMAGE),y
 sta smWIDTH+1

 sec
 sbc #1
 sta smSTART+1

 lda YCO
 tax
 iny
 sbc (IMAGE),y
 bcs ok
 lda #LO(-1) ;limited Y-clipping
.ok sta  smTOP+1

 lda IMAGE
 clc
 adc #2
 sta IMAGE
 bcc label_1
 inc IMAGE+1
.label_1

.outloop
 lda YLO,x
 clc
.smXCO adc #0
 sta BASE

 lda YHI,x
.smPAGE adc #$20
 sta BASE+1

.smSTART ldy #3

.inloop
.ramrd3 sta $c003 ;RAMRD aux

 lda (IMAGE),y

 sta $c002 ;RAMRD main

.smod ora (BASE),y
 sta (BASE),y

 dey
 bpl inloop

.smWIDTH lda #4
 adc IMAGE ;assume cc
 sta IMAGE
 bcc label_2
 inc IMAGE+1
.label_2
 dex
.smTOP cpx #$ff
 bne outloop

 rts
}

\*-------------------------------
\*
\*  Still more streamlined version of FASTLAY (STA only)
\*
\*-------------------------------
.fastlaySTA
{
 lda PAGE
 sta smPAGE+1

 lda XCO
 sta smXCO+1

 ldy #0
 lda (IMAGE),y
 sta smWIDTH+1

 sec
 sbc #1
 sta smSTART+1

 lda YCO
 tax
 iny
 sbc (IMAGE),y
 bcs ok
 lda #LO(-1) ;limited Y-clipping
.ok sta  smTOP+1

 lda IMAGE
 clc
 adc #2
 sta IMAGE
 bcc label_1
 inc IMAGE+1
.label_1

.outloop
 lda YLO,x
 clc
.smXCO adc #0
 sta smod+1

 lda YHI,x
.smPAGE adc #$20
 sta smod+2

.smSTART ldy #3

.inloop
 lda (IMAGE),y
.smod sta $2000,y ;BASE

 dey
 bpl inloop

.smWIDTH lda #4
 adc IMAGE ;cc
 sta IMAGE
 bcc label_2
 inc IMAGE+1
.label_2
 dex
.smTOP cpx #$ff
 bne outloop

 rts
}

\*-------------------------------
\*
\*  F A S T M A S K
\*
\*-------------------------------
.hires_FASTMASK
{
\ NOT BEEB
\ sta $c004 ;RAMWRT main
\]ramrd4 sta $c003 ;RAMRD aux

 jsr setimage

 lda PAGE
 sta smPAGE+1

 lda XCO
 sta smXCO+1

 ldy #0
 lda (IMAGE),y
 sta smWIDTH+1

 sec
 sbc #1
 sta smSTART+1

 lda YCO
 tax
 iny
 sbc (IMAGE),y
 bcs ok
 lda #LO(-1) ;limited Y-clipping
.ok sta  smTOP+1

 lda IMAGE
 clc
 adc #2
 sta IMAGE
 bcc label_1
 inc IMAGE+1
.label_1

.outloop
 stx hires_index

 lda YLO,x
 clc
.smXCO adc #0
 sta BASE

 lda YHI,x
.smPAGE adc #$20
 sta BASE+1

.smSTART ldy #3

.inloop
\ NOT BEEB
\]ramrd5 sta $c003 ;RAMRD aux

 lda (IMAGE),y

\ NOT BEEB
\ sta $c002 ;RAMRD main

 tax
 lda MASKTAB-$80,X

 and (BASE),Y
 sta (BASE),y

 dey
 bpl inloop

.smWIDTH lda #4
 adc IMAGE ;cc
 sta IMAGE
 bcc label_2
 inc IMAGE+1
.label_2
 ldx hires_index
 dex
.smTOP cpx #$ff
 bne outloop

 rts
}
ENDIF

IF _NOT_BEEB
*-------------------------------
*
*  S E T F A S T   M A I N / A U X
*
*  Modify FASTLAY routines to expect image tables to
*  be in main/auxmem.  SETFAST need be called only once
*  (e.g., when switching between game & builder).
*
*-------------------------------
SETFASTMAIN
 lda #$02 ;RAMRD main
]setfast
 sta ]ramrd1+1
 sta ]ramrd2+1
 sta ]ramrd3+1
 sta ]ramrd4+1
 sta ]ramrd5+1
 rts

SETFASTAUX
 lda #$03 ;RAMRD aux
 bne ]setfast
ENDIF

IF _NOT_BEEB
*-------------------------------
*
*  F A S T B L A C K
*
*  Wipe a rectangular area to black2
*
*  Width/height passed in IMAGE/IMAGE+1
*  (width in bytes, height in pixels)
*
*-------------------------------

FASTBLACK
 lda color
 sta :smCOLOR+1

 lda PAGE
 sta :smPAGE+1

 lda XCO
 sta  :smXCO+1

 lda width
 sec
 sbc #1
 sta :smSTART+1

 lda YCO
 tax
 sbc height ;cs
 sta :smTOP+1

:outloop
 lda YLO,x
 clc
:smXCO adc #0
 sta :smod+1

 lda YHI,x
:smPAGE adc #$20
 sta :smod+2

:smCOLOR lda #$80

:smSTART ldy #3

:inloop
:smod sta $2000,y ;BASE
 dey
 bpl :inloop

 dex
:smTOP cpx #$ff
 bne :outloop

 rts
ENDIF

IF _TODO
*-------------------------------
*
*  C O P Y   S C R E E N
*
*  Copy $2000 bytes
*
*  In: IMAGE+1 = dest scrn, IMAGE = org scrn
*      (use hi byte of actual memory address)
*
*-------------------------------
COPYSCRN
 lda IMAGE+1
 sta :dst1+2
 clc
 adc #$10
 sta :dst2+2

 lda IMAGE
 sta :org1+2
 adc #$10
 sta :org2+2

 ldx #$10

 ldy #0
:loop
:org1 lda $2000,y
:dst1 sta $4000,y

:org2 lda $3000,y
:dst2 sta $5000,y

 iny
 bne :loop

 inc :org1+2
 inc :org2+2
 inc :dst1+2
 inc :dst2+2

 dex
 bne :loop

 rts
ENDIF

\*-------------------------------
\ lst
\ ds 1
\ usr $a9,1,$0000,*-org
\ lst off
