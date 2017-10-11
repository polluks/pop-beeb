; beeb-plot
; BBC Micro plot functions
; Works directly on Apple II sprite data

; need to know where we're locating this code!

\*-------------------------------
\*
\*  Parameters passed to hires routines:
\*
\*  PAGE        $00 = hires page 1, $20 = hires page 2          - NOT BEEB UNLESS DOUBLE BUFFERING
\*  XCO         Screen X-coord (0=left, 39=right)
\*  YCO         Screen Y-coord (0=top, 191=bottom)
\*  OFFSET      # of bits to shift image right (0-6)
\*  IMAGE       Image # in table (1-127)
\*  TABLE       Starting address of image table (2 bytes)
\*  BANK        Memory bank of table (2 = main, 3 = aux)        BEEB = SWRAM slot
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

\ Implement special XOR - this will be done by using a different palette

.beeb_plot_start

.beeb_PREPREP
{
    \\ Must have a swram bank to select or assert
    LDA BANK
    JSR swr_select_slot

    \ Set a palette per swram bank
    \ Could set palette per sprite table or even per sprite

    LDY BANK
    LDA bank_to_palette_temp,Y
    JSR beeb_plot_sprite_SetExilePalette

    \ Turns TABLE & IMAGE# into IMAGE ptr
    \ Obtains WIDTH & HEIGHT
    
    JMP PREPREP
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

.beeb_plot_layrsave
{
    JSR beeb_PREPREP

    \ OK to page out sprite data now we have dimensions etc.

    \ Select MOS 4K RAM
    JSR swr_select_mos4k

    lda OPACITY
    bpl normal

    \ Mirrored
    LDA XCO
    SEC
    SBC WIDTH
    STA XCO

    .normal
    LDA OFFSET
    BEQ no_offset
    inc WIDTH ;extra byte to cover shift right
    .no_offset

    \ on Beeb we could skip a column of bytes if offset>3

    jsr CROP
    bmi skipit

;BBC_SETBGCOL PAL_red

    lda PEELBUF ;PEELBUF: 2-byte pointer to 1st
    sta PEELIMG ;available byte in peel buffer
    lda PEELBUF+1
    sta PEELIMG+1

    \ Mask off Y offset

    LDA YCO
    STA PEELYCO

    AND #&F8
    TAY    

    \ Look up Beeb screen address

    LDX XCO
    STX PEELXCO

    CLC
    LDA Mult16_LO,X
    ADC YLO,Y
    STA scrn_addr+1
    LDA Mult16_HI,X
    ADC YHI,Y
    STA scrn_addr+2

    \ Ignore clip for now
    
    \ Make sprite

    LDY #0
    LDA VISWIDTH
    BNE width_ok

    .skipit
    JMP SKIPIT

    \ Store visible width

    .width_ok
    STA (PEELBUF), Y

    \ Calculate visible height

    INY
    LDA YCO
    SEC
    SBC TOPEDGE
    STA (PEELBUF),y ;Height of onscreen portion ("VISHEIGHT")

    STA beeb_height

    \ Increment (w,h) header to start of image data

    CLC
    LDA PEELBUF
    ADC #2
    STA peel_addr+1         ; +1c
    LDA PEELBUF+1
    ADC #0
    STA peel_addr+2         ; +1c

    LDA VISWIDTH
    ASL A                   ; bytes_per_line_on_screen
    STA smWIDTH+1
    STA smYMAX+1

\ Y offset into character row

    LDA YCO
    AND #&7
    TAX

    .yloop
    STX beeb_yoffset

    LDY #0                  ; would be nice (i.e. faster) to do all of this backwards
    CLC

    .xloop

    .scrn_addr
    LDA &FFFF, X

\ 16c + 2c per line to save a cycle per byte copied - as player is > 16 lines high this is a win

    .peel_addr
    STA &FFFF, Y            ; -1c vs STA (PEELBUF),Y

    TXA                     ; next char column [6c]
    ADC #8    
    TAX

    INY

    .smYMAX
    CPY #0                  ; VISWIDTH*2
    BCC xloop
    
    \ Update PEELBUF as we go along
    CLC
    LDA peel_addr+1         ; +1c
    .smWIDTH
    ADC #0                  ; VISWIDTH=WIDTH*2
    STA peel_addr+1         ; +1c
    BCC no_carry
    INC peel_addr+2         ; +1c
    .no_carry

    \ Have we done all lines?
    DEC beeb_height
    BEQ done

    \ Next scanline
    LDX beeb_yoffset
    DEX
    BPL yloop

    \ Next character row
    SEC
    LDA scrn_addr+1
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA scrn_addr+1
    LDA scrn_addr+2
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA scrn_addr+2

    LDX #7
    BNE yloop
    .done

    \ Update PEELBUF
    LDA peel_addr+1         ; +4c
    STA PEELBUF             ; +3c
    LDA peel_addr+2         ; +4c
    STA PEELBUF+1           ; +3c

;BBC_SETBGCOL PAL_black

    JMP DONE                ; restore vars
}

\*-------------------------------
\*
\*  F A S T B L A C K
\*
\*  Wipe a rectangular area to black2
\*
\*  Width/height passed in IMAGE/IMAGE+1
\*  (width in bytes, height in pixels)
\*
\*-------------------------------

.beeb_plot_wipe
{
    \ OFFSET IGNORED
    \ OPACITY IGNORED
    \ MIRROR IGNORED
    \ CLIPPING IGNORED
    
    \ XCO & YCO are screen coordinates
    \ XCO (0-39) and YCO (0-191)

    \ Convert to Beeb screen layout

    \ Mask off Y offset

    LDA YCO
\ Bounds check YCO
IF _DEBUG
    CMP #192
    BCC y_ok
    BRK
    .y_ok
ENDIF
    AND #&F8
    TAY    

    \ Look up Beeb screen address

    LDX XCO
\ Bounds check XCO
IF _DEBUG
    CPX #70
    BCC x_ok
    BRK
    .x_ok
ENDIF
    CLC
    LDA Mult16_LO,X
    ADC YLO,Y
    STA scrn_addr+1
    LDA Mult16_HI,X
    ADC YHI,Y
    STA scrn_addr+2

    \ Simple Y clip
    SEC
    LDA YCO

    \ Store height

    TAY
    SBC height
    STA smTOP+1

    TYA

    \ Y offset into character row

    AND #&7
    TAX
    
    \ Set opacity

IF _DEBUG
    LDA OPACITY
;   STA smOPACITY+1
    BEQ is_black
    BRK
    .is_black
ENDIF

    \ Plot loop

    LDA width
    ASL A
    ASL A:ASL A: ASL A      ; x8
    STA smXMAX+1

    .yloop
    STX beeb_yoffset

    CLC

    .xloop

;    .smOPACITY
;    LDA #0                  ; OPACITY
\ ONLY BLACK
    .scrn_addr
    STZ &FFFF, X

    TXA                     ; next char column [6c]
    ADC #8    
    TAX

    .smXMAX
    CPX #0                  ; do this backwards...
    BCC xloop

    \ Should keep track of Y in a register

    DEY
    .smTOP
    CPY #0
    BEQ done_y

    \ Completed a line

    \ Next scanline

    LDX beeb_yoffset
    DEX
    BPL yloop

    \ Next character row

    SEC
    LDA scrn_addr+1
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA scrn_addr+1
    LDA scrn_addr+2
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA scrn_addr+2

    LDX #7
    BNE yloop
    .done_y

    RTS
}

\*-------------------------------
\*
\*  NOT QUITE F A S T L A Y
\*
\*  Streamlined LAY routine
\*
\*  No offset - no clipping - no mirroring - no masking -
\*  no EOR - trashes IMAGE - may crash if overtaxed -
\*  but it's fast.
\*
\*  10/3/88: OK for images to protrude PARTLY off top
\*  Still more streamlined version of FASTLAY (STA only)
\*
\*  This Beeb function has no direct original equivalent
\*  because it is copying Beeb screen data directly back
\*  to the screen rather than unrolled sprite data
\* 
\*-------------------------------

.beeb_plot_peel
{
    \ Select MOS 4K RAM as our sprite bank
    JSR swr_select_mos4k

;BBC_SETBGCOL PAL_green

    \ Can't use PREPREP or setimage here as no TABLE!
    \ Assume IMAGE has been set correctly

    ldy #0
    lda (IMAGE),y
    sta WIDTH

    iny
    lda (IMAGE),y
    sta HEIGHT

    \ OFFSET IGNORED
    \ OPACITY IGNORED
    \ MIRROR IGNORED
    \ CLIPPING IGNORED

    \ XCO & YCO are screen coordinates
    \ XCO (0-39) and YCO (0-191)

    \ Convert to Beeb screen layout

    \ Mask off Y offset

    LDA YCO
\ Bounds check YCO
IF _DEBUG
    CMP #192
    BCC y_ok
    BRK
    .y_ok
ENDIF
    AND #&F8
    TAY    

    \ Look up Beeb screen address

    LDX XCO
\ Bounds check XCO
IF _DEBUG
    CPX #70
    BCC x_ok
    BRK
    .x_ok
ENDIF
    CLC
    LDA Mult16_LO,X
    ADC YLO,Y
    STA scrn_addr+1
    LDA Mult16_HI,X
    ADC YHI,Y
    STA scrn_addr+2

    \ Set sprite data address 

    CLC
    LDA IMAGE
    ADC #2
    STA sprite_addr+1
    LDA IMAGE+1
    ADC #0
    STA sprite_addr+2

    \ Simple Y clip
    SEC
    LDA YCO
    SBC HEIGHT
    BCS no_yclip

    LDA #LO(-1)
    .no_yclip
    STA smTOP+1

    \ Store height

    LDA YCO
    STA beeb_height

    \ Y offset into character row

    AND #&7
    TAX

    \ Plot loop

    LDA WIDTH
    ASL A
    STA smYMAX+1
    STA smWIDTH+1

    .yloop
    STX beeb_yoffset

    LDY #0
    CLC

    .xloop

    .sprite_addr
    LDA &FFFF, Y

    .scrn_addr
    STA &FFFF, X

    TXA                     ; next char column [6c]
    ADC #8    
    TAX

    INY
    .smYMAX
    CPY #0
    BCC xloop
    
    LDY beeb_height
    DEY
    .smTOP
    CPY #0
    BEQ done_y
    STY beeb_height

    \ Completed a line - next row of sprite data

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                  ; WIDTH*2
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

    \ Next scanline

    LDX beeb_yoffset
    DEX
    BPL yloop

    \ Next character row

    SEC
    LDA scrn_addr+1
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA scrn_addr+1
    LDA scrn_addr+2
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA scrn_addr+2

    LDX #7
    BNE yloop
    .done_y

;BBC_SETBGCOL PAL_black

    RTS
}

\ IN: XCO, YCO
\ OUT: beeb_writeptr (to crtc character), beeb_yoffset, beeb_parity (parity)
.beeb_plot_calc_screen_addr
{
    \ XCO & YCO are screen coordinates
    \ XCO (0-39) and YCO (0-191)
    \ OFFSET (0-3) - maybe 0,1 or 8,9?

    \ Mask off Y offset to get character row

    LDA YCO
    AND #&F8
    TAY    

    LDX XCO
    CLC
    LDA Mult16_LO,X
    ADC YLO,Y
    STA beeb_writeptr
    LDA Mult16_HI,X
    ADC YHI,Y
    STA beeb_writeptr+1

    LDA YCO
    AND #&7
    STA beeb_yoffset            ; think about using y remaining counter cf Thrust

    \ Handle OFFSET

    LDA OFFSET
    LSR A
    STA beeb_mode2_offset

    AND #&1
    STA beeb_parity             ; this is parity

    ROR A                       ; return parity in C
    RTS
}

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

.beeb_plot_sprite_LAY
{
;BBC_SETBGCOL PAL_magenta

 lda OPACITY
 bpl notmirr

 and #$7f
 sta OPACITY
 jmp beeb_plot_sprite_MLAY

.notmirr
\ cmp #enum_eor
\ bne label_1
\ jmp LayXOR

.label_1 cmp #enum_and
 bne label_2
 jmp beeb_plot_sprite_LayAND

.label_2 cmp #enum_sta
 bne label_3
 jmp beeb_plot_sprite_LaySTA

.label_3
\\ DROP THROUGH TO MASK for ORA, EOR & MASK
}

\*-------------------------------
\* LAY MASK
\*-------------------------------

.beeb_plot_sprite_LayMask
{
    \ Get sprite data address 

    JSR beeb_PREPREP

    \ CLIP here

    JSR CROP
    bpl cont
    .nothing_to_do
    jmp DONE
    .cont

    \ Beeb screen address
    JSR beeb_plot_calc_screen_addr

    \ Returns parity in Carry
    BCC no_swap

\ L&R pixels need to be swapped over

    JSR beeb_plot_sprite_FlipPalette

    .no_swap

    \ Do we have a partial clip on left side?
    LDX #0
    LDA OFFLEFT
    BEQ no_partial_left
    LDA OFFSET
    BEQ no_partial_left
    INX
    DEC OFFLEFT
    .no_partial_left

    \ Calculate how many bytes of sprite data to unroll

    LDA VISWIDTH
    {
        CPX #0:BEQ no_partial_left
        INC A                   ; need extra byte of sprite data for left clip
        .no_partial_left
    }
    STA beeb_bytes_per_line_in_sprite       ; unroll all bytes
    CMP #0                      ; zero flag already set from CPX
    BEQ nothing_to_do        ; nothing to plot

    \ Self-mod code to save a cycle per line
    DEC A
    STA smSpriteBytes+1

    \ Calculate number of pixels visible on screen

    LDA VISWIDTH
    ASL A: ASL A
    {
        CPX #0:BEQ no_partial_left
        CLC
        ADC beeb_mode2_offset   ; have this many extra pixels on left side
        .no_partial_left
        LDY OFFRIGHT:BEQ no_partial_right
        SEC
        SBC beeb_mode2_offset
        .no_partial_right
    }
    ; A contains number of visible pixels

    \ Calculate how many bytes we'll need to write to the screen

    LSR A
    CLC
    ADC beeb_parity             ; vispixels/2 + parity
    ; A contains beeb_bytes_per_line_on_screen

    \ Self-mod code to save a cycle per line
    ASL A: ASL A: ASL A         ; x8
    STA smYMAX+1

    \ Calculate how deep our stack will be

    LDA beeb_bytes_per_line_in_sprite
    ASL A: ASL A                  ; we have W*4 pixels to unroll
    INC A
    STA beeb_stack_depth        ; stack will end up this many bytes lower than now

    \ Calculate where to start reading data from stack
    {
        CPX #0:BEQ no_partial_left        ; left partial clip

        \ If clipping left start a number of bytes into the stack

        SEC
        LDA #5
        SBC beeb_mode2_offset
        \ Self-mod code to save a cycle per line
        STA smStackStart+1
        BNE same_char_column

        .no_partial_left

        \ If not clipping left then stack start is based on parity

        LDA beeb_parity
        EOR #1
        \ Self-mod code to save a cycle per line
        STA smStackStart+1

        \ If we're on the next character column, move our write pointer

        LDA beeb_mode2_offset
        AND #&2
        BEQ same_char_column

        CLC
        LDA beeb_writeptr
        ADC #8
        STA beeb_writeptr
        BCC same_char_column
        INC beeb_writeptr+1
        .same_char_column
    }

    \ Set sprite data address skipping any bytes clipped off left

    CLC
    LDA IMAGE
    ADC OFFLEFT
    STA sprite_addr+1
    LDA IMAGE+1
    ADC #0
    STA sprite_addr+2

    \ Save a cycle per line - player typically min 24 lines
    LDA WIDTH
    STA smWIDTH+1
    LDA TOPEDGE
    STA smTOPEDGE+1

    \ Push a zero on the top of the stack in case of parity

    LDA #0
    PHA

    \ Remember where the stack is now
    
    TSX
    STX smSTACKTOP+1          ; use this to reset stack

    \ Calculate bottom of the stack and self-mod read address

    TXA
    SEC
    SBC beeb_stack_depth
    STA smSTACK1+1
    STA smSTACK2+1

.plot_lines_loop

\ Start at the end of the sprite data

    .smSpriteBytes
    LDY #0      ;beeb_bytes_per_line_in_sprite-1

\ Decode a line of sprite data using Exile method!
\ Current per pixel unroll: STA ZP 3c+ TAX 2c+ LDA,X 4c=9c
\ Exile ZP: TAX 2c+ STA 4c+ LDA zp 3c=9c am I missing something?
\ Save 2 cycles per loop when shifting bytes down TXA vs LDA zp

    .line_loop

    .sprite_addr
    LDA &FFFF, Y
    STA beeb_data

    AND #&11
    TAX
.smPIXELD
    LDA map_2bpp_to_mode2_pixel,X       ; could be in ZP ala Exile to save 2cx4=8c per sprite byte
    PHA                                 ; [3c]

    LDA beeb_data
    AND #&22
    TAX
.smPIXELC
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data                       ; +1c
    LSR A
    LSR A
    STA beeb_data                       ; +1c

    AND #&11
    TAX
.smPIXELB
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&22
    TAX
.smPIXELA
    LDA map_2bpp_to_mode2_pixel,X
    PHA

\ Stop when we reach the left edge of the sprite data

    DEY
    BPL line_loop

\ Always push the extra zero
\ Can't set it directly in case the loop gets interrupted and a return value pushed onto stack

    LDA #0
    PHA

\ Sort out where to start in the stack lookup

    .smStackStart
    LDX #0  ;beeb_stack_start

\ Now plot that data to the screen left to right

    LDY beeb_yoffset
    CLC

.plot_screen_loop

    INX
.smSTACK1
    LDA &100,X

    INX
.smSTACK2
    ORA &100,X

\ Convert pixel data to mask

    STA load_mask+1             \ 4c not storing in a register
    .load_mask
    LDA mask_table              ; 4c

\ AND mask with screen

    AND (beeb_writeptr), Y

\ OR in sprite byte

    ORA load_mask+1             ; 4c

\ Write to screen

    STA (beeb_writeptr), Y

\ Next screen byte across

    TYA
    ADC #8
    TAY                         ; do it all backwards?!

    .smYMAX
    CPY #0
    BCC plot_screen_loop

\ Reset the stack pointer

    .smSTACKTOP
    LDX #0                 ; beeb_stack_ptr
    TXS

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                 ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                  ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BMI next_char_row
    JMP plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr
    LDA beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    PLA
;BBC_SETBGCOL PAL_black
    JMP DONE
}

\*-------------------------------
\* LAY AND
\*-------------------------------

.beeb_plot_sprite_LayAND
{
    \ Get sprite data address 

    JSR beeb_PREPREP

    \ CLIP here

    JSR CROP
    bpl cont
    .nothing_to_do
    jmp DONE
    .cont

    \ Beeb screen address
    JSR beeb_plot_calc_screen_addr

    \ Returns parity in Carry
    BCC no_swap

\ L&R pixels need to be swapped over

    JSR beeb_plot_sprite_FlipPalette

    .no_swap

    \ Do we have a partial clip on left side?
    LDX #0
    LDA OFFLEFT
    BEQ no_partial_left
    LDA OFFSET
    BEQ no_partial_left
    INX
    DEC OFFLEFT
    .no_partial_left

    \ Calculate how many bytes of sprite data to unroll

    LDA VISWIDTH
    {
        CPX #0:BEQ no_partial_left
        INC A                   ; need extra byte of sprite data for left clip
        .no_partial_left
    }
    STA beeb_bytes_per_line_in_sprite       ; unroll all bytes
    CMP #0                      ; zero flag already set from CPX
    BEQ nothing_to_do        ; nothing to plot

    \ Self-mod code to save a cycle per line
    DEC A
    STA smSpriteBytes+1

    \ Calculate number of pixels visible on screen

    LDA VISWIDTH
    ASL A: ASL A
    {
        CPX #0:BEQ no_partial_left
        CLC
        ADC beeb_mode2_offset   ; have this many extra pixels on left side
        .no_partial_left
        LDY OFFRIGHT:BEQ no_partial_right
        SEC
        SBC beeb_mode2_offset
        .no_partial_right
    }
    ; A contains number of visible pixels

    \ Calculate how many bytes we'll need to write to the screen

    LSR A
    CLC
    ADC beeb_parity             ; vispixels/2 + parity
    ; A contains beeb_bytes_per_line_on_screen

    \ Self-mod code to save a cycle per line
    ASL A: ASL A: ASL A         ; x8
    STA smYMAX+1

    \ Calculate how deep our stack will be

    LDA beeb_bytes_per_line_in_sprite
    ASL A: ASL A                  ; we have W*4 pixels to unroll
    INC A
    STA beeb_stack_depth        ; stack will end up this many bytes lower than now

    \ Calculate where to start reading data from stack
    {
        CPX #0:BEQ no_partial_left        ; left partial clip

        \ If clipping left start a number of bytes into the stack

        SEC
        LDA #5
        SBC beeb_mode2_offset
        \ Self-mod code to save a cycle per line
        STA smStackStart+1
        BNE same_char_column

        .no_partial_left

        \ If not clipping left then stack start is based on parity

        LDA beeb_parity
        EOR #1
        \ Self-mod code to save a cycle per line
        STA smStackStart+1

        \ If we're on the next character column, move our write pointer

        LDA beeb_mode2_offset
        AND #&2
        BEQ same_char_column

        CLC
        LDA beeb_writeptr
        ADC #8
        STA beeb_writeptr
        BCC same_char_column
        INC beeb_writeptr+1
        .same_char_column
    }

    \ Set sprite data address skipping any bytes clipped off left

    CLC
    LDA IMAGE
    ADC OFFLEFT
    STA sprite_addr+1
    LDA IMAGE+1
    ADC #0
    STA sprite_addr+2

    \ Save a cycle per line - player typically min 24 lines
    LDA WIDTH
    STA smWIDTH+1
    LDA TOPEDGE
    STA smTOPEDGE+1

    \ Push a zero on the top of the stack in case of parity

    LDA #0
    PHA

    \ Remember where the stack is now
    
    TSX
    STX smSTACKTOP+1          ; use this to reset stack

    \ Calculate bottom of the stack and self-mod read address

    TXA
    SEC
    SBC beeb_stack_depth
    STA smSTACK1+1
    STA smSTACK2+1

.plot_lines_loop

\ Start at the end of the sprite data

    .smSpriteBytes
    LDY #0      ;beeb_bytes_per_line_in_sprite-1

\ Decode a line of sprite data using Exile method!
\ Current per pixel unroll: STA ZP 3c+ TAX 2c+ LDA,X 4c=9c
\ Exile ZP: TAX 2c+ STA 4c+ LDA zp 3c=9c am I missing something?

    .line_loop

    .sprite_addr
    LDA &FFFF, Y
    STA beeb_data

    AND #&11
    TAX
.smPIXELD
    LDA map_2bpp_to_mode2_pixel,X       ; could be in ZP ala Exile to save 2cx4=8c per sprite byte
    PHA                                 ; [3c]

    LDA beeb_data
    AND #&22
    TAX
.smPIXELC
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    LSR A
    LSR A
    STA beeb_data

    AND #&11
    TAX
.smPIXELB
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&22
    TAX
.smPIXELA
    LDA map_2bpp_to_mode2_pixel,X
    PHA

\ Stop when we reach the left edge of the sprite data

    DEY
    BPL line_loop

\ Always push the extra zero
\ Can't set it directly in case the loop gets interrupted and a return value pushed onto stack

    LDA #0
    PHA

\ Sort out where to start in the stack lookup

    .smStackStart
    LDX #0  ;beeb_stack_start

\ Now plot that data to the screen left to right

    LDY beeb_yoffset
    CLC

.plot_screen_loop

    INX
.smSTACK1
    LDA &100,X

    INX
.smSTACK2
    ORA &100,X

\ AND sprite data with screen

    AND (beeb_writeptr), Y

\ Write to screen

    STA (beeb_writeptr), Y

\ Next screen byte across

    TYA
    ADC #8
    TAY                         ; do it all backwards?!

    .smYMAX
    CPY #0
    BCC plot_screen_loop

\ Reset the stack pointer

    .smSTACKTOP
    LDX #0                 ; beeb_stack_ptr
    TXS

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                 ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                  ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BMI next_char_row
    JMP plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr
    LDA beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    PLA
;BBC_SETBGCOL PAL_black
    JMP DONE
}

\*-------------------------------
\* LAY STA
\*-------------------------------

.beeb_plot_sprite_LaySTA
{
    \ Get sprite data address 

    JSR beeb_PREPREP

    \ CLIP here

    JSR CROP
    bpl cont
    .nothing_to_do
    jmp DONE
    .cont

    \ Beeb screen address
    JSR beeb_plot_calc_screen_addr

    \ Returns parity in Carry
    BCC no_swap

\ L&R pixels need to be swapped over

    JSR beeb_plot_sprite_FlipPalette

    .no_swap

    \ Do we have a partial clip on left side?
    LDX #0
    LDA OFFLEFT
    BEQ no_partial_left
    LDA OFFSET
    BEQ no_partial_left
    INX
    DEC OFFLEFT
    .no_partial_left

    \ Calculate how many bytes of sprite data to unroll

    LDA VISWIDTH
    {
        CPX #0:BEQ no_partial_left
        INC A                   ; need extra byte of sprite data for left clip
        .no_partial_left
    }
    STA beeb_bytes_per_line_in_sprite       ; unroll all bytes
    CMP #0                      ; zero flag already set from CPX
    BEQ nothing_to_do        ; nothing to plot

    \ Self-mod code to save a cycle per line
    DEC A
    STA smSpriteBytes+1

    \ Calculate number of pixels visible on screen

    LDA VISWIDTH
    ASL A: ASL A
    {
        CPX #0:BEQ no_partial_left
        CLC
        ADC beeb_mode2_offset   ; have this many extra pixels on left side
        .no_partial_left
        LDY OFFRIGHT:BEQ no_partial_right
        SEC
        SBC beeb_mode2_offset
        .no_partial_right
    }
    ; A contains number of visible pixels

    \ Calculate how many bytes we'll need to write to the screen

    LSR A
    CLC
    ADC beeb_parity             ; vispixels/2 + parity
    ; A contains beeb_bytes_per_line_on_screen

    \ Self-mod code to save a cycle per line
    ASL A: ASL A: ASL A         ; x8
    STA smYMAX+1

    \ Calculate how deep our stack will be

    LDA beeb_bytes_per_line_in_sprite
    ASL A: ASL A                  ; we have W*4 pixels to unroll
    INC A
    STA beeb_stack_depth        ; stack will end up this many bytes lower than now

    \ Calculate where to start reading data from stack
    {
        CPX #0:BEQ no_partial_left        ; left partial clip

        \ If clipping left start a number of bytes into the stack

        SEC
        LDA #5
        SBC beeb_mode2_offset
        \ Self-mod code to save a cycle per line
        STA smStackStart+1
        BNE same_char_column

        .no_partial_left

        \ If not clipping left then stack start is based on parity

        LDA beeb_parity
        EOR #1
        \ Self-mod code to save a cycle per line
        STA smStackStart+1

        \ If we're on the next character column, move our write pointer

        LDA beeb_mode2_offset
        AND #&2
        BEQ same_char_column

        CLC
        LDA beeb_writeptr
        ADC #8
        STA beeb_writeptr
        BCC same_char_column
        INC beeb_writeptr+1
        .same_char_column
    }

    \ Set sprite data address skipping any bytes clipped off left

    CLC
    LDA IMAGE
    ADC OFFLEFT
    STA sprite_addr+1
    LDA IMAGE+1
    ADC #0
    STA sprite_addr+2

    \ Save a cycle per line - player typically min 24 lines
    LDA WIDTH
    STA smWIDTH+1
    LDA TOPEDGE
    STA smTOPEDGE+1

    \ Push a zero on the top of the stack in case of parity

    LDA #0
    PHA

    \ Remember where the stack is now
    
    TSX
    STX smSTACKTOP+1          ; use this to reset stack

    \ Calculate bottom of the stack and self-mod read address

    TXA
    SEC
    SBC beeb_stack_depth
    STA smSTACK1+1
    STA smSTACK2+1

    \ +14c vs using beeb_writeptr
    LDA beeb_writeptr
    STA scrn_addr+1
    LDA beeb_writeptr+1
    STA scrn_addr+2

.plot_lines_loop

\ Start at the end of the sprite data

    .smSpriteBytes
    LDY #0      ;beeb_bytes_per_line_in_sprite-1

\ Decode a line of sprite data using Exile method!
\ Current per pixel unroll: STA ZP 3c+ TAX 2c+ LDA,X 4c=9c
\ Exile ZP: TAX 2c+ STA 4c+ LDA zp 3c=9c am I missing something?

    .line_loop

    .sprite_addr
    LDA &FFFF, Y
    STA beeb_data

    AND #&11
    TAX
.smPIXELD
    LDA map_2bpp_to_mode2_pixel,X       ; could be in ZP ala Exile to save 2cx4=8c per sprite byte
    PHA                                 ; [3c]

    LDA beeb_data
    AND #&22
    TAX
.smPIXELC
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    LSR A
    LSR A
    STA beeb_data

    AND #&11
    TAX
.smPIXELB
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&22
    TAX
.smPIXELA
    LDA map_2bpp_to_mode2_pixel,X
    PHA

\ Stop when we reach the left edge of the sprite data

    DEY
    BPL line_loop

\ Always push the extra zero
\ Can't set it directly in case the loop gets interrupted and a return value pushed onto stack

    LDA #0
    PHA

\ Sort out where to start in the stack lookup

    .smStackStart
    LDX #0  ;beeb_stack_start

\ Now plot that data to the screen left to right

    LDY beeb_yoffset
    CLC

.plot_screen_loop

    INX
.smSTACK1
    LDA &100,X

    INX
.smSTACK2
    ORA &100,X

\ Write to screen

    .scrn_addr
    STA &FFFF, Y            ; -1c vs STA (beeb_writeptr), Y

\ Next screen byte across

    TYA
    ADC #8
    TAY                     ; do it all backwards?!

    .smYMAX
    CPY #0
    BCC plot_screen_loop

\ Reset the stack pointer

    .smSTACKTOP
    LDX #0                 ; beeb_stack_ptr
    TXS

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                 ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                  ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BMI next_char_row
    JMP plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA scrn_addr+1         ; +1c beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA scrn_addr+1         ; +1c beeb_writeptr
    LDA scrn_addr+2         ; +1c beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA scrn_addr+2         ; +1c beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    PLA
;BBC_SETBGCOL PAL_black
    JMP DONE
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

.beeb_plot_sprite_MLAY ;A = OPACITY
{
\ cmp #enum_eor
\ bne label_1
\ jmp MLayXOR

.label_1 cmp #enum_and
 bne label_2
 jmp beeb_plot_sprite_MLayAND

.label_2 cmp #enum_sta
 bne label_3
 jmp beeb_plot_sprite_MLaySTA

.label_3
\\ DROP THROUGH TO MASK for ORA, EOR & MASK
}

.beeb_plot_sprite_MLayMask
{
    \ Get sprite data address 

    JSR beeb_PREPREP

    \  Check we're in the right function :)

    LDA XCO
    SEC
    SBC WIDTH
    STA XCO

    \ CLIP here

    JSR CROP
    bpl cont
    .nothing_to_do
    jmp DONE
    .cont

    \ Beeb screen address

    JSR beeb_plot_calc_screen_addr

    \ Returns parity in Carry
    BCS no_swap     ; mirror reverses parity

\ L&R pixels need to be swapped over

    JSR beeb_plot_sprite_FlipPalette

    .no_swap

    \ Do we have a partial clip on left side?
    LDX #0
    LDA OFFLEFT
    BEQ no_partial_left
    LDA OFFSET
    BEQ no_partial_left
    INX
    DEC OFFLEFT
    .no_partial_left

    \ Calculate how many bytes of sprite data to unroll

    LDA VISWIDTH
    {
        CPX #0:BEQ no_partial_left
        INC A                   ; need extra byte of sprite data for left clip
        .no_partial_left
    }
    STA beeb_bytes_per_line_in_sprite       ; unroll all bytes
    CMP #0                      ; zero flag already set from CPX
    BEQ nothing_to_do        ; nothing to plot

    \ Self-mod code to save a cycle per line
    STA smSpriteBytes+1

    \ Calculate number of pixels visible on screen

    LDA VISWIDTH
    ASL A: ASL A
    {
        CPX #0:BEQ no_partial_left
        CLC
        ADC beeb_mode2_offset   ; have this many extra pixels on left side
        .no_partial_left
        LDY OFFRIGHT:BEQ no_partial_right
        SEC
        SBC beeb_mode2_offset
        .no_partial_right
    }
    ; A contains number of visible pixels

    \ Calculate how many bytes we'll need to write to the screen

    LSR A
    CLC
    ADC beeb_parity             ; vispixels/2 + parity
    ; A contains beeb_bytes_per_line_on_screen

    \ Self-mod code to save a cycle per line
    ASL A: ASL A: ASL A         ; x8
    STA smYMAX+1

    \ Calculate how deep our stack will be

    LDA beeb_bytes_per_line_in_sprite
    ASL A: ASL A                  ; we have W*4 pixels to unroll
    INC A
    STA beeb_stack_depth        ; stack will end up this many bytes lower than now

    {
        CPX #0:BEQ no_partial_left        ; left partial clip

        \ Left clip special stack start

        SEC
        LDA #5
        SBC beeb_mode2_offset
        \ Self-mod code to save a cycle per line
        STA smStackStart+1
        BNE same_char_column

        .no_partial_left
        LDA beeb_parity
        EOR #1
        \ Self-mod code to save a cycle per line
        STA smStackStart+1

        \ If we're on the next character column, move our write pointer

        LDA beeb_mode2_offset
        AND #&2
        BEQ same_char_column

        CLC
        LDA beeb_writeptr
        ADC #8
        STA beeb_writeptr
        BCC same_char_column
        INC beeb_writeptr+1
        .same_char_column
    }

    \ Set sprite data address 

    CLC
    LDA IMAGE
    ADC RMOST              ; NOT OFFLEFT because actually we want to lose our right-hand pixels
    STA sprite_addr+1
    LDA IMAGE+1
    ADC #0
    STA sprite_addr+2

    \ Save a cycle per line - player typically min 24 lines
    LDA WIDTH
    STA smWIDTH+1
    LDA TOPEDGE
    STA smTOPEDGE+1

    \ Push a zero on the end in case of parity

    LDA #0
    PHA

    \ Remember where the stack is now
    
    TSX
    STX smSTACKTOP+1          ; use this to reset stack

    \ Calculate bottom of the stack and self-mod read address

    TXA
    SEC
    SBC beeb_stack_depth
    STA smSTACK1+1
    STA smSTACK2+1

.plot_lines_loop

    LDY #0                  ; bytes_per_line_in_sprite

\ Decode a line of sprite data using Exile method!

    .line_loop

    .sprite_addr
    LDA &FFFF, Y
    STA beeb_data

\ For mirror sprites we decode pixels left to right and push them onto the stack
\ Therefore bottom of the stack will be the right-most pixel to be drawn on left hand side

    LSR A
    LSR A
    STA beeb_temp

    AND #&22
    TAX
.smPIXELA
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_temp
    AND #&11
    TAX
.smPIXELB
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&22
    TAX
.smPIXELC
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&11
    TAX
.smPIXELD
    LDA map_2bpp_to_mode2_pixel,X         ; could be in ZP ala Exile to save 2cx4=8c per sprite byte
    PHA                                 ; [3c]

    INY
    .smSpriteBytes
    CPY #0              ; beeb_bytes_per_line_in_sprite

\ Stop when we reach the left edge of the sprite data

    BNE line_loop

\ Always push the extra zero - can't set directly in case of interrupts

    LDA #0
    PHA

\ Sort out where to start in the stack lookup

    .smStackStart
    LDX #0  ;beeb_stack_start

\ Now plot that data to the screen

    LDY beeb_yoffset
    CLC

.plot_screen_loop

    INX
.smSTACK1
    LDA &100,X

    INX
.smSTACK2
    ORA &100,X

\ Convert sprite pixels to mask

    STA load_mask+1
    .load_mask
    LDA mask_table
    
\ AND mask with screen

    AND (beeb_writeptr), Y

\ OR in sprite byte

    ORA load_mask+1

\ Write to screen

    STA (beeb_writeptr), Y

\ Next screen byte across

    TYA
    ADC #8
    TAY

    .smYMAX
    CPY #0
    BCC plot_screen_loop

\ Reset the stack pointer

    .smSTACKTOP
    LDX #0                      ; beeb_stack_ptr
    TXS

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                      ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                      ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BMI next_char_row
    JMP plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr
    LDA beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    PLA
;BBC_SETBGCOL PAL_black
    JMP DONE
}

\*-------------------------------
\* MIRROR AND
\*-------------------------------

.beeb_plot_sprite_MLayAND
{
    \ Get sprite data address 

    JSR beeb_PREPREP

    \  Check we're in the right function :)

    LDA XCO
    SEC
    SBC WIDTH
    STA XCO

    \ CLIP here

    JSR CROP
    bpl cont
    .nothing_to_do
    jmp DONE
    .cont

    \ Beeb screen address

    JSR beeb_plot_calc_screen_addr

    \ Returns parity in Carry
    BCS no_swap     ; mirror reverses parity

\ L&R pixels need to be swapped over

    JSR beeb_plot_sprite_FlipPalette

    .no_swap

    \ Do we have a partial clip on left side?
    LDX #0
    LDA OFFLEFT
    BEQ no_partial_left
    LDA OFFSET
    BEQ no_partial_left
    INX
    DEC OFFLEFT
    .no_partial_left

    \ Calculate how many bytes of sprite data to unroll

    LDA VISWIDTH
    {
        CPX #0:BEQ no_partial_left
        INC A                   ; need extra byte of sprite data for left clip
        .no_partial_left
    }
    STA beeb_bytes_per_line_in_sprite       ; unroll all bytes
    CMP #0                      ; zero flag already set from CPX
    BEQ nothing_to_do        ; nothing to plot

    \ Self-mod code to save a cycle per line
    STA smSpriteBytes+1

    \ Calculate number of pixels visible on screen

    LDA VISWIDTH
    ASL A: ASL A
    {
        CPX #0:BEQ no_partial_left
        CLC
        ADC beeb_mode2_offset   ; have this many extra pixels on left side
        .no_partial_left
        LDY OFFRIGHT:BEQ no_partial_right
        SEC
        SBC beeb_mode2_offset
        .no_partial_right
    }
    ; A contains number of visible pixels

    \ Calculate how many bytes we'll need to write to the screen

    LSR A
    CLC
    ADC beeb_parity             ; vispixels/2 + parity
    ; A contains beeb_bytes_per_line_on_screen

    \ Self-mod code to save a cycle per line
    ASL A: ASL A: ASL A         ; x8
    STA smYMAX+1

    \ Calculate how deep our stack will be

    LDA beeb_bytes_per_line_in_sprite
    ASL A: ASL A                  ; we have W*4 pixels to unroll
    INC A
    STA beeb_stack_depth        ; stack will end up this many bytes lower than now

    {
        CPX #0:BEQ no_partial_left        ; left partial clip

        \ Left clip special stack start

        SEC
        LDA #5
        SBC beeb_mode2_offset
        \ Self-mod code to save a cycle per line
        STA smStackStart+1
        BNE same_char_column

        .no_partial_left
        LDA beeb_parity
        EOR #1
        \ Self-mod code to save a cycle per line
        STA smStackStart+1

        \ If we're on the next character column, move our write pointer

        LDA beeb_mode2_offset
        AND #&2
        BEQ same_char_column

        CLC
        LDA beeb_writeptr
        ADC #8
        STA beeb_writeptr
        BCC same_char_column
        INC beeb_writeptr+1
        .same_char_column
    }

    \ Set sprite data address 

    CLC
    LDA IMAGE
    ADC RMOST              ; NOT OFFLEFT because actually we want to lose our right-hand pixels
    STA sprite_addr+1
    LDA IMAGE+1
    ADC #0
    STA sprite_addr+2

    \ Save a cycle per line - player typically min 24 lines
    LDA WIDTH
    STA smWIDTH+1
    LDA TOPEDGE
    STA smTOPEDGE+1

    \ Push a zero on the end in case of parity

    LDA #0
    PHA

    \ Remember where the stack is now
    
    TSX
    STX smSTACKTOP+1          ; use this to reset stack

    \ Calculate bottom of the stack and self-mod read address

    TXA
    SEC
    SBC beeb_stack_depth
    STA smSTACK1+1
    STA smSTACK2+1

.plot_lines_loop

    LDY #0                  ; bytes_per_line_in_sprite

\ Decode a line of sprite data using Exile method!

    .line_loop

    .sprite_addr
    LDA &FFFF, Y
    STA beeb_data

\ For mirror sprites we decode pixels left to right and push them onto the stack
\ Therefore bottom of the stack will be the right-most pixel to be drawn on left hand side

    LSR A
    LSR A
    STA beeb_temp

    AND #&22
    TAX
.smPIXELA
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_temp
    AND #&11
    TAX
.smPIXELB
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&22
    TAX
.smPIXELC
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&11
    TAX
.smPIXELD
    LDA map_2bpp_to_mode2_pixel,X         ; could be in ZP ala Exile to save 2cx4=8c per sprite byte
    PHA                                 ; [3c]

    INY
    .smSpriteBytes
    CPY #0              ; beeb_bytes_per_line_in_sprite

\ Stop when we reach the left edge of the sprite data

    BNE line_loop

\ Always push the extra zero - can't set directly in case of interrupts

    LDA #0
    PHA

\ Sort out where to start in the stack lookup

    .smStackStart
    LDX #0  ;beeb_stack_start

\ Now plot that data to the screen

    LDY beeb_yoffset
    CLC

.plot_screen_loop

    INX
.smSTACK1
    LDA &100,X

    INX
.smSTACK2
    ORA &100,X

\ AND sprite data with screen

    AND (beeb_writeptr), Y

\ Write to screen

    STA (beeb_writeptr), Y

\ Next screen byte across

    TYA
    ADC #8
    TAY

    .smYMAX
    CPY #0
    BCC plot_screen_loop

\ Reset the stack pointer

    .smSTACKTOP
    LDX #0                      ; beeb_stack_ptr
    TXS

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                      ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                      ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BMI next_char_row
    JMP plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr
    LDA beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    PLA
;BBC_SETBGCOL PAL_black
    JMP DONE
}

\*-------------------------------
\* MIRROR STA
\*-------------------------------

.beeb_plot_sprite_MLaySTA
{
IF _DEBUG
    BRK             ; not convinced this function is used!
ENDIF

    \ Get sprite data address 

    JSR beeb_PREPREP

    \ Reverse XCO for MIRROR

    LDA XCO
    SEC
    SBC WIDTH
    STA XCO

    \ CLIP here

    JSR CROP
    bpl cont
    .nothing_to_do
    jmp DONE
    .cont

    \ Beeb screen address

    JSR beeb_plot_calc_screen_addr

    \ Returns parity in Carry
    BCS no_swap     ; mirror reverses parity

\ L&R pixels need to be swapped over

    JSR beeb_plot_sprite_FlipPalette

    .no_swap

    \ Do we have a partial clip on left side?
    LDX #0
    LDA OFFLEFT
    BEQ no_partial_left
    LDA OFFSET
    BEQ no_partial_left
    INX
    DEC OFFLEFT
    .no_partial_left

    \ Calculate how many bytes of sprite data to unroll

    LDA VISWIDTH
    {
        CPX #0:BEQ no_partial_left
        INC A                   ; need extra byte of sprite data for left clip
        .no_partial_left
    }
    STA beeb_bytes_per_line_in_sprite       ; unroll all bytes
    CMP #0                      ; zero flag already set from CPX
    BEQ nothing_to_do        ; nothing to plot

    \ Self-mod code to save a cycle per line
    STA smSpriteBytes+1

    \ Calculate number of pixels visible on screen

    LDA VISWIDTH
    ASL A: ASL A
    {
        CPX #0:BEQ no_partial_left
        CLC
        ADC beeb_mode2_offset   ; have this many extra pixels on left side
        .no_partial_left
        LDY OFFRIGHT:BEQ no_partial_right
        SEC
        SBC beeb_mode2_offset
        .no_partial_right
    }
    ; A contains number of visible pixels

    \ Calculate how many bytes we'll need to write to the screen

    LSR A
    CLC
    ADC beeb_parity             ; vispixels/2 + parity
    ; A contains beeb_bytes_per_line_on_screen

    \ Self-mod code to save a cycle per line
    ASL A: ASL A: ASL A         ; x8
    STA smYMAX+1

    \ Calculate how deep our stack will be

    LDA beeb_bytes_per_line_in_sprite
    ASL A: ASL A                  ; we have W*4 pixels to unroll
    INC A
    STA beeb_stack_depth        ; stack will end up this many bytes lower than now

    {
        CPX #0:BEQ no_partial_left        ; left partial clip

        \ Left clip special stack start

        SEC
        LDA #5
        SBC beeb_mode2_offset
        \ Self-mod code to save a cycle per line
        STA smStackStart+1
        BNE same_char_column

        .no_partial_left
        LDA beeb_parity
        EOR #1
        \ Self-mod code to save a cycle per line
        STA smStackStart+1

        \ If we're on the next character column, move our write pointer

        LDA beeb_mode2_offset
        AND #&2
        BEQ same_char_column

        CLC
        LDA beeb_writeptr
        ADC #8
        STA beeb_writeptr
        BCC same_char_column
        INC beeb_writeptr+1
        .same_char_column
    }

    \ Set sprite data address 

    CLC
    LDA IMAGE
    ADC RMOST              ; NOT OFFLEFT because actually we want to lose our right-hand pixels
    STA sprite_addr+1
    LDA IMAGE+1
    ADC #0
    STA sprite_addr+2

    \ Save a cycle per line - player typically min 24 lines
    LDA WIDTH
    STA smWIDTH+1
    LDA TOPEDGE
    STA smTOPEDGE+1

    \ Push a zero on the end in case of parity

    LDA #0
    PHA

    \ Remember where the stack is now
    
    TSX
    STX smSTACKTOP+1          ; use this to reset stack

    \ Calculate bottom of the stack and self-mod read address

    TXA
    SEC
    SBC beeb_stack_depth
    STA smSTACK1+1
    STA smSTACK2+1

.plot_lines_loop

    LDY #0                  ; bytes_per_line_in_sprite

\ Decode a line of sprite data using Exile method!

    .line_loop

    .sprite_addr
    LDA &FFFF, Y
    STA beeb_data

\ For mirror sprites we decode pixels left to right and push them onto the stack
\ Therefore bottom of the stack will be the right-most pixel to be drawn on left hand side

    LSR A
    LSR A
    STA beeb_temp

    AND #&22
    TAX
.smPIXELA
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_temp
    AND #&11
    TAX
.smPIXELB
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&22
    TAX
.smPIXELC
    LDA map_2bpp_to_mode2_pixel,X
    PHA

    LDA beeb_data
    AND #&11
    TAX
.smPIXELD
    LDA map_2bpp_to_mode2_pixel,X         ; could be in ZP ala Exile to save 2cx4=8c per sprite byte
    PHA                                 ; [3c]

    INY
    .smSpriteBytes
    CPY #0              ; beeb_bytes_per_line_in_sprite

\ Stop when we reach the left edge of the sprite data

    BNE line_loop

\ Always push the extra zero - can't set directly in case of interrupts

    LDA #0
    PHA

\ Sort out where to start in the stack lookup

    .smStackStart
    LDX #0  ;beeb_stack_start

\ Now plot that data to the screen

    LDY beeb_yoffset
    CLC

.plot_screen_loop

    INX
.smSTACK1
    LDA &100,X

    INX
.smSTACK2
    ORA &100,X

\ Write to screen

    STA (beeb_writeptr), Y

\ Next screen byte across

    TYA
    ADC #8
    TAY

    .smYMAX
    CPY #0
    BCC plot_screen_loop

\ Reset the stack pointer

    .smSTACKTOP
    LDX #0                      ; beeb_stack_ptr
    TXS

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                      ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                      ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BMI next_char_row
    JMP plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr
    LDA beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    PLA
;BBC_SETBGCOL PAL_black
    JMP DONE
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

.beeb_plot_sprite_FASTLAY
{
 lda OPACITY

.label_1 cmp #enum_and
 bne label_2
 jmp beeb_plot_sprite_FASTLAYAND

.label_2 cmp #enum_sta
 bne label_3
 jmp beeb_plot_sprite_FASTLAYSTA

.label_3
\\ DROP THROUGH TO MASK for ORA, EOR & MASK
}

.beeb_plot_sprite_FASTMASK
{
    \ Get sprite data address 

    JSR beeb_PREPREP

    \ Beeb screen address

    JSR beeb_plot_calc_screen_addr      ; can still lose OFFSET calcs

    \ Don't carry about Carry

    \ Calculate how many bytes of sprite data to unroll

    LDA WIDTH
    STA smWIDTH+1
    STA smXMAX+1

    \ Set sprite data address skipping any bytes NO CLIP

    LDA IMAGE
    STA sprite_addr+1
    LDA IMAGE+1
    STA sprite_addr+2

\ Simple Y clip

    SEC
    LDA YCO
    SBC HEIGHT
    BCS no_yclip
    LDA #LO(-1)
    .no_yclip
    STA smTOPEDGE+1

.plot_lines_loop

\ Start at the end of the sprite data

    LDY beeb_yoffset
    LDX #0
    CLC

    .line_loop
    STX beeb_temp

\ Load 4 pixels of sprite data

    .sprite_addr
    LDA &FFFF, X
    STA beeb_data                   ; 3c

\ Lookup pixels D & C

    AND #&CC                        ; 2c
    TAX

\ Convert pixel data to mask

    LDA map_2bpp_to_mask, X

\ AND mask with screen

    AND (beeb_writeptr), Y

\ OR in sprite byte

    ORA map_2bpp_to_mode2_palN, X

\ Write to screen

    STA (beeb_writeptr), Y

\ Increment write pointer

    TYA:ADC #8:TAY

\ Lookup pixels B & A

    LDA beeb_data                   ; 3c
    AND #&33                        ; 2c
    TAX                             ; 2c

\ Convert pixel data to mask

    LDA map_2bpp_to_mask, X

\ AND mask with screen

    AND (beeb_writeptr), Y

\ OR in sprite byte

    ORA map_2bpp_to_mode2_palN, X

\ Write to screen

    STA (beeb_writeptr), Y

\ Next screen byte across

    TYA:ADC #8:TAY

\ Increment sprite index

    LDX beeb_temp
    INX

    .smXMAX
    CPX #0
    BCC line_loop

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                 ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                  ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BPL plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr
    LDA beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    JMP DONE
}

.beeb_plot_sprite_FASTLAYAND
{
    \ Get sprite data address 

    JSR beeb_PREPREP

    \ Beeb screen address

    JSR beeb_plot_calc_screen_addr      ; can still lose OFFSET calcs

    \ Don't carry about Carry

    \ Calculate how many bytes of sprite data to unroll

    LDA WIDTH
    STA smWIDTH+1
    STA smXMAX+1

    \ Set sprite data address skipping any bytes NO CLIP

    LDA IMAGE
    STA sprite_addr+1
    LDA IMAGE+1
    STA sprite_addr+2

\ Simple Y clip

    SEC
    LDA YCO
    SBC HEIGHT
    BCS no_yclip
    LDA #LO(-1)
    .no_yclip
    STA smTOPEDGE+1

.plot_lines_loop

\ Start at the end of the sprite data

    LDY beeb_yoffset
    LDX #0
    CLC

    .line_loop
    STX beeb_temp

\ Load 4 pixels of sprite data

    .sprite_addr
    LDA &FFFF, X
    STA beeb_data

\ Lookup pixels D & C

    AND #&CC
    TAX
    LDA map_2bpp_to_mode2_palN, X

\ AND sprite data with screen

    AND (beeb_writeptr), Y

\ Write to screen

    STA (beeb_writeptr), Y

\ Increment write pointer

    TYA:ADC #8:TAY

\ Lookup pixels B & A

    LDA beeb_data
    AND #&33
    TAX
    LDA map_2bpp_to_mode2_palN, X

\ AND sprite data with screen

    AND (beeb_writeptr), Y

\ Write to screen

    STA (beeb_writeptr), Y

\ Next screen byte across

    TYA:ADC #8:TAY

\ Increment sprite index

    LDX beeb_temp
    INX

    .smXMAX
    CPX #0
    BCC line_loop

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                 ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                  ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BPL plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr
    LDA beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    JMP DONE
}

.beeb_plot_sprite_FASTLAYSTA
{
    \ Get sprite data address 

    JSR beeb_PREPREP

    \ Beeb screen address

    JSR beeb_plot_calc_screen_addr      ; can still lose OFFSET calcs

    \ Don't carry about Carry

    \ Calculate how many bytes of sprite data to unroll

    LDA WIDTH
    STA smWIDTH+1
    STA smXMAX+1

    \ Set sprite data address skipping any bytes NO CLIP

    LDA IMAGE
    STA sprite_addr+1
    LDA IMAGE+1
    STA sprite_addr+2

\ Simple Y clip

    SEC
    LDA YCO
    SBC HEIGHT
    BCS no_yclip
    LDA #LO(-1)
    .no_yclip
    STA smTOPEDGE+1

.plot_lines_loop

\ Start at the end of the sprite data

    LDY beeb_yoffset
    LDX #0
    CLC

    .line_loop
    STX beeb_temp

\ Load 4 pixels of sprite data

    .sprite_addr
    LDA &FFFF, X
    STA beeb_data

\ Lookup pixels D & C

    AND #&CC
    TAX
    LDA map_2bpp_to_mode2_palN, X

\ Write to screen

    STA (beeb_writeptr), Y

\ Increment write pointer

    TYA:ADC #8:TAY

\ Lookup pixels B & A

    LDA beeb_data
    AND #&33
    TAX
    LDA map_2bpp_to_mode2_palN, X

\ Write to screen

    STA (beeb_writeptr), Y

\ Next screen byte across

    TYA:ADC #8:TAY

\ Increment sprite index

    LDX beeb_temp
    INX

    .smXMAX
    CPX #0
    BCC line_loop

\ Have we completed all rows?

    LDY YCO
    DEY
    .smTOPEDGE
    CPY #0                 ; TOPEDGE
    STY YCO
    BEQ done_y

\ Move to next sprite data row

    CLC
    LDA sprite_addr+1
    .smWIDTH
    ADC #0                  ; WIDTH
    STA sprite_addr+1
    BCC no_carry
    INC sprite_addr+2
    .no_carry

\ Next scanline

    DEC beeb_yoffset
    BPL plot_lines_loop

\ Need to move up a screen char row

    .next_char_row
    SEC
    LDA beeb_writeptr
    SBC #LO(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr
    LDA beeb_writeptr+1
    SBC #HI(BEEB_SCREEN_ROW_BYTES)
    STA beeb_writeptr+1

    LDY #7
    STY beeb_yoffset
    JMP plot_lines_loop

    .done_y

\ Reset stack before we leave

    JMP DONE
}


\*-------------------------------
; Clear Beeb screen buffer

.beeb_CLS
{
\\ Ignore PAGE as no page flipping yet

  ldx #HI(BEEB_SCREEN_SIZE)
  lda #HI(beeb_screen_addr)

  sta loop+2
  lda #0
  ldy #0
  .loop
  sta &3000,Y
  iny
  bne loop
  inc loop+2
  dex
  bne loop
  rts
}

\*-------------------------------
\*
\* Palette functions
\*
\*-------------------------------

\ Top 4-bits are colour 3
\ Bottom 4-bits are lookup into pixel pairs for colours 1 & 2
\ Colour 0 always black
.beeb_plot_sprite_SetExilePalette
{
    TAX
    LSR A                     
    LSR A
    LSR A
    LSR A
    TAY                         ; Y = primary colour 

    LDA pixel_table,Y           ; map primary colour (0-15) to Mode 2
                                ; pixel value with that colour in both
                                ; pixels
    AND #$55                    
    STA map_2bpp_to_mode2_pixel+$11                     ; &11 - primary colour right pixel
    ASL A                       
    STA map_2bpp_to_mode2_pixel+$22                     ; &22 - primary colour left pixel
    
    TXA
    AND #$0F                    ; Y = (palette>>0)&15 - pair index
    TAY
    LDA palette_value_to_pixel_lookup,Y ; get pair
    TAY                         
    AND #$55                    ; get right pixel
    STA map_2bpp_to_mode2_pixel+$01                     ; right 1
    ASL A
    STA map_2bpp_to_mode2_pixel+$02                     ; left 1
    TYA
    AND #$AA                    ; get left pixel
    STA map_2bpp_to_mode2_pixel+$20                     ; left 2
    LSR A
    STA map_2bpp_to_mode2_pixel+$10                     ; right 2
    
    RTS
}

.beeb_plot_sprite_FlipPalette
{
\ L&R pixels need to be swapped over

    LDA map_2bpp_to_mode2_pixel+&02: LDY map_2bpp_to_mode2_pixel+&01
    STA map_2bpp_to_mode2_pixel+&01: STY map_2bpp_to_mode2_pixel+&02

    LDA map_2bpp_to_mode2_pixel+&20: LDY map_2bpp_to_mode2_pixel+&10
    STA map_2bpp_to_mode2_pixel+&10: STY map_2bpp_to_mode2_pixel+&20

    LDA map_2bpp_to_mode2_pixel+&22: LDY map_2bpp_to_mode2_pixel+&11
    STA map_2bpp_to_mode2_pixel+&11: STY map_2bpp_to_mode2_pixel+&22

    RTS    
}


\*-------------------------------
; Exile palette tables

PAGE_ALIGN
.map_2bpp_to_mode2_pixel            ; background
{
    EQUB &00                        ; 00000000 either pixel logical 0
    EQUB &10                        ; 000A000a right pixel logical 1
    EQUB &20                        ; 00B000b0 left pixel logical 1

    skip &0D

    EQUB &40                        ; 000A000a right pixel logical 2
    EQUB &50                        ; 000A000a right pixel logical 3

    skip &0E

    EQUB &80                        ; 00B000b0 left pixel logical 2
    skip 1
    EQUB &A0                        ; 00B000b0 left pixel logical 3
}
\\ Flip entries in this table when parity changes

.palette_value_to_pixel_lookup
{
    EQUB &07                        ; red / yellow
    EQUB &34                        ; blue / cyan
    EQUB &23                        ; magenta / red
\    equb $CA                        ; yellow bg, black bg
\    equb $C9                        ; green bg, red bg
\    equb $E3                        ; magenta bg, red bg
    equb $E9                        ; cyan bg, red bg
    equb $EB                        ; white bg, red bg
    equb $CE                        ; yellow bg, green bg
    equb $F8                        ; cyan bg, blue bg
    equb $E6                        ; magenta bg, green bg
    equb $CC                        ; green bg, green bg
    equb $EE                        ; white bg, green bg
    equb $30                        ; blue fg, blue fg
    equb $DE                        ; yellow bg, cyan bg
    equb $EF                        ; white bg, yellow bg
    equb $CB                        ; yellow bg, red bg
    equb $FB                        ; white bg, magenta bg
    equb $FE                        ; white bg, cyan bg
}

.pixel_table
{
    ;                                 ABCDEFGH
    equb $00                        ; 00000000 0  0  
    equb $03                        ; 00000011 1  1  
    equb $0C                        ; 00001100 2  2  
    equb $0F                        ; 00001111 3  3  
    equb $30                        ; 00110000 4  4  
    equb $33                        ; 00110011 5  5  
    equb $3C                        ; 00111100 6  6  
    equb $3F                        ; 00111111 7  7  
    equb $C0                        ; 11000000 8  8  
    equb $C3                        ; 11000011 9  9  
    equb $CC                        ; 11001100 10 10
    equb $CF                        ; 11001111 11 11
    equb $F0                        ; 11110000 12 12
    equb $F3                        ; 11110011 13 13
    equb $FC                        ; 11111100 14 14
    equb $FF                        ; 11111111 15 15
}

\*-------------------------------
; Set palette per swram bank
; Needs to be a palette per image bank
; Or even better per sprite

.bank_to_palette_temp
{
    EQUB &71            \ bg
    EQUB &72            \ chtab13
    EQUB &72            \ chtab25
    EQUB &72            \ chtab467
}

\*-------------------------------
; Beeb screen multiplication tables

.Mult16_LO
FOR n,0,39,1
EQUB LO(n*16)
NEXT
.Mult16_HI          ; or shift...
FOR n,0,39,1
EQUB HI(n*16)
NEXT

\*-------------------------------
; Very lazy table for turning MODE 2 black pixels into MASK

PAGE_ALIGN
.mask_table
FOR byte,0,255,1
left=byte AND &AA
right=byte AND &55

IF left = 0

    IF right = 0
        EQUB &FF
    ELSE
        EQUB &AA
    ENDIF

ELSE

    IF right = 0
        EQUB &55
    ELSE
        EQUB &00
    ENDIF

ENDIF

NEXT

PAGE_ALIGN
.map_2bpp_to_mode2_palN
FOR byte,0,&CC,1
D=(byte AND &80)>>6 OR (byte AND &8)>>3
C=(byte AND &40)>>5 OR (byte AND &4)>>2
B=(byte AND &20)>>4 OR (byte AND &2)>>1
A=(byte AND &10)>>3 OR (byte AND &1)>>0
; Pixels DCBA (0,3)
; Map pairs DC and BA of left & right pixels
IF D=0
    pD=0
ELIF D=1
    pD=&02          ; red left
ELIF D=2
    pD=&08          ; yellow left
ELSE
    pD=&2A          ; white left
ENDIF

IF C=0
    pC=0
ELIF C=1
    pC=&01          ; red right
ELIF C=2
    pC=&04          ; yellow right
ELSE
    pC=&15          ; white right
ENDIF

IF B=0
    pB=0
ELIF B=1
    pB=&02          ; red left
ELIF B=2
    pB=&08          ; yellow left
ELSE
    pB=&2A          ; white left
ENDIF

IF A=0
    pA=0
ELIF A=1
    pA=&01          ; red right
ELIF A=2
    pA=&04          ; yellow right
ELSE
    pA=&15          ; white right
ENDIF

EQUB pA OR pB OR pC OR pD
NEXT

; This table turns MODE 5 2bpp packed data directly into MODE 2 mask bytes

PAGE_ALIGN
.map_2bpp_to_mask
FOR byte,0,&CC,1
left=(byte AND &88) OR (byte AND &22)
right=(byte AND &44) OR (byte AND &11)

IF left = 0

    IF right = 0
        EQUB &FF
    ELSE
        EQUB &AA
    ENDIF

ELSE

    IF right = 0
        EQUB &55
    ELSE
        EQUB &00
    ENDIF

ENDIF

NEXT


.beeb_plot_end
