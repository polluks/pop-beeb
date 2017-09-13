; pop-beeb
; Prince of Persia
; Port to the BBC Master
; Main build file

\*-------------------------------
; Defines
\*-------------------------------

CPU 1
_TODO = FALSE

; Original PoP global defines

EditorDisk = 0 ;1 = dunj, 2 = palace
CopyProtect = 0
DemoDisk = 0
FinalDisk = 1
ThreeFive = 0 ;3.5" disk?

; Platform includes

INCLUDE "lib/bbc.h.asm"
INCLUDE "lib/bbc_utils.h.asm"

; POP includes

locals = $d0                    ; VDU workspace
locals_top = $e3

ORG &0
GUARD locals
INCLUDE "game/eq.h.asm"
INCLUDE "game/gameeq.h.asm"

; POP defines

INCLUDE "game/soundnames.h.asm"
INCLUDE "game/seqdata.h.asm"

\*-------------------------------
; BEEB headers
\*-------------------------------

BEEB_SCREEN_WIDTH = 280
BEEB_SCREEN_HEIGHT = 192
BEEB_SCREEN_CHARS = (BEEB_SCREEN_WIDTH / 8)
BEEB_SCREEN_ROWS = (BEEB_SCREEN_HEIGHT / 8)
BEEB_SCREEN_SIZE = (BEEB_SCREEN_WIDTH * BEEB_SCREEN_HEIGHT)  / 8

beeb_screen_addr = &8000 - BEEB_SCREEN_SIZE

INCLUDE "game/beeb-plot.h.asm"

; Local ZP variables only

INCLUDE "game/frameadv.h.asm"
INCLUDE "game/hires.h.asm"
INCLUDE "game/master.h.asm"
INCLUDE "game/mover.h.asm"
INCLUDE "game/ctrl.h.asm"
INCLUDE "game/grafix.h.asm"
INCLUDE "game/coll.h.asm"
INCLUDE "game/auto.h.asm"

\*-------------------------------
; BSS data in lower RAM
\*-------------------------------

ORG &300                ; VDU and language workspace
GUARD &800              ; sound workspace

\ Move BSS here (e.g. imlists from eq.asm) when out of RAM

ORG &900                ; envelope / speech / CFS / soft key / char defs
GUARD &D00              ; NMI workspace

.disksys_scratch        SKIP &300
SCRATCH_RAM_ADDR = disksys_scratch


\*-------------------------------
; CORE RAM
\*-------------------------------

CORE_START=&E00
CORE_TOP=&3000

ORG CORE_START
GUARD CORE_TOP             ; bottom of SHADOW RAM

;GUARD &4B80             ; eventually shrunk MODE 1
;GUARD &5800             ; currently in full MODE 4
;GUARD &65C0             ; now in shrunk MODE 4!
;GUARD &8000             ; when testing high watermark

.pop_beeb_start
.pop_beeb_lib_start

INCLUDE "lib/disksys.asm"
INCLUDE "lib/swr.asm"
INCLUDE "lib/print.asm"

.pop_beeb_lib_end
.pop_beeb_core_start

.swr_fail_text EQUS "No SWR banks found.", 13, 10, 0
.swr_bank_text EQUS "Found %b", LO(swr_ram_banks_count), HI(swr_ram_banks_count), " SWR banks.", 13, 10, 0

.main_filename EQUS "Main   $"
.aux_filename  EQUS "Aux    $"

.pop_beeb_entry
{
    \\ Should be MASTER test and exit with nice message

    \\ SWRAM init
    jsr swr_init
    bne swr_ok

    MPRINT swr_fail_text
    rts

.swr_ok

    MPRINT    swr_bank_text

    \\ Should be some sort of BEEB system init

    \\ MODE
    LDA #22
    JSR oswrch
    LDA #BEEB_SCREEN_MODE
    JSR oswrch

    \\ Special MODE
    JSR beeb_set_screen_mode

    \\ Load executable overlays

    \\ Load Main

    JSR beeb_shadow_select_main

    LDX #LO(main_filename)
    LDY #HI(main_filename)
    LDA #HI(pop_beeb_main_start)
    JSR disksys_load_file

    \\ Load Aux

    JSR beeb_shadow_select_aux

    LDX #LO(aux_filename)
    LDY #HI(aux_filename)
    LDA #HI(pop_beeb_aux_start)
    JSR disksys_load_file

    \\ Remain in AUX...

IF 0
    LDX #1
    STX level
    JSR LoadLevelX

    JSR beeb_shadow_select_main

    LDA #1
    STA beeb_sprite_no

    .sprite_loop
    LDA beeb_sprite_no
    AND #&1F
    STA XCO

    LDA #127
    STA YCO

    LDA beeb_sprite_no
    STA IMAGE

    LDA #LO(bgtable2)
    STA TABLE

    LDA #HI(bgtable2)
    STA TABLE+1

    LDA #0
    STA BANK

    LDA #2
    STA OPACITY

    JSR beeb_plot_apple_mode_4

    ldx#100:ldy#0:lda#&81:jsr osbyte	

    LDX beeb_sprite_no
    INX
    CPX #128
    BCS finished
    STX beeb_sprite_no
    JMP sprite_loop

    .finished
    RTS
ENDIF

IF 1
    \\ Level load & plot test
    LDX #1

    .level_loop
    STX level
    JSR LoadLevelX

    LDX #1
    STX VisScrn

    .scrn_loop
    JSR getscrns
    JSR DoSure

    ldx#100:ldy#0:lda#&81:jsr osbyte	

    LDX VisScrn
    INX
    CPX #25
    STX VisScrn
    BNE scrn_loop

    LDX level
    INX
    CPX #15
    BNE level_loop
ELSE
    \\ Actual POP
    \\ Would have been entered directly by the boot loader on Apple II

    JSR _firstboot

    \\ Not supposed to return but start our game directly

    JSR _dostartgame

ENDIF

    .return
    RTS
}

; Beeb source in CORE

INCLUDE "game/beeb-plot.asm"

; PoP source in CORE memory (always present)

INCLUDE "game/master.asm"
INCLUDE "game/topctrl.asm"
INCLUDE "game/grafix.asm"
INCLUDE "game/hires_core.asm"

.pop_beeb_core_end

; Data in CORE memory (always present)

.pop_beeb_data_start

; This data could be dumped after boot!

.beeb_crtcregs
{
	EQUB 63 			; R0  horizontal total
	EQUB BEEB_SCREEN_CHARS				; R1  horizontal displayed
	EQUB 49				; R2  horizontal position
	EQUB &24			; R3  sync width
	EQUB 38				; R4  vertical total
	EQUB 0				; R5  vertical total adjust
	EQUB BEEB_SCREEN_ROWS				; R6  vertical displayed
	EQUB 34				; R7  vertical position; 35=top of screen
	EQUB 0				; R8  interlace
	EQUB 7				; R9  scanlines per row
	EQUB 32				; R10 cursor start
	EQUB 8				; R11 cursor end
	EQUB HI(beeb_screen_addr/8)		; R12 screen start address, high
	EQUB LO(beeb_screen_addr/8)		; R13 screen start address, low
}

.pop_beeb_data_end
.pop_beeb_end

; Save Core executable

SAVE "Core", pop_beeb_start, pop_beeb_end, pop_beeb_entry

; Run time initalised data in Core

.pop_beeb_bss_start

INCLUDE "game/eq.asm"
INCLUDE "game/gameeq.asm"

.pop_beeb_bss_end

; Core RAM stats

PRINT "Core lib size = ", ~(pop_beeb_lib_end - pop_beeb_lib_start)
PRINT "Core code size = ", ~(pop_beeb_core_end - pop_beeb_core_start)
PRINT "Core data size = ", ~(pop_beeb_data_end - pop_beeb_data_start)
PRINT "Core BSS size = ", ~(pop_beeb_bss_end - pop_beeb_bss_start)
PRINT "Core high watermark = ", ~P%
PRINT "Core RAM free = ", ~(CORE_TOP - P%)


\*-------------------------------
; Construct MAIN RAM (video & screen)
\*-------------------------------

MAIN_START = &3000
MAIN_TOP = &8000

CLEAR 0, &FFFF
ORG MAIN_START
GUARD beeb_screen_addr

.pop_beeb_main_start

; Code & data in MAIN RAM (rendering)

INCLUDE "game/hires.asm"
INCLUDE "game/hrtables.asm"

.pop_beeb_main_end

; Save executable code for Main RAM

SAVE "Main", pop_beeb_main_start, pop_beeb_main_end, 0

PRINT "Main code & data size = ", ~(pop_beeb_main_end - pop_beeb_main_start)
PRINT "Main high watermark = ", ~P%

; BSS in MAIN RAM
; (screen buffers)

; Main RAM stats
PRINT "Screen buffer address = ", ~beeb_screen_addr
PRINT "Screen buffer size = ", ~BEEB_SCREEN_SIZE
PRINT "Main RAM free = ", ~(MAIN_TOP - P%)

\*-------------------------------
; Construct  AUX (SHADOW) RAM
\*-------------------------------

AUX_START = &3000
AUX_TOP = &8000

CLEAR 0, &FFFF
ORG AUX_START
GUARD AUX_TOP

.pop_beeb_aux_start

; Code in AUX RAM (gameplay)

INCLUDE "game/frameadv.asm"
INCLUDE "game/gamebg.asm"
INCLUDE "game/bgdata.asm"
INCLUDE "game/subs.asm"
INCLUDE "game/specialk.asm"
INCLUDE "game/mover.asm"
INCLUDE "game/misc.asm"
INCLUDE "game/auto.asm"
INCLUDE "game/ctrlsubs.asm"
INCLUDE "game/ctrl.asm"
INCLUDE "game/coll.asm"

; Data in AUX RAM (gameplay)

INCLUDE "game/tables.asm"
INCLUDE "game/framedefs.asm"
INCLUDE "game/seqtable.asm"

.pop_beeb_aux_end

; Save executable code for Aux RAM

SAVE "Aux", pop_beeb_aux_start, pop_beeb_aux_end, 0

; BSS in AUX RAM (gameplay)

ALIGN &100
.blueprnt
SKIP &900           ; all blueprints same size

; High watermark for Main RAM
PRINT "Aux code & data size = ", ~(pop_beeb_aux_end - pop_beeb_aux_start)
PRINT "Aux high watermark = ", ~P%
PRINT "Aux RAM free = ", ~(AUX_TOP - P%)

\*-------------------------------
; Construct MOS RAM
\*-------------------------------

CLEAR 0, &FFFF
ORG &8000
GUARD &9000
.peelbuf1
SKIP &800
.peelbuf2
SKIP &800


\*-------------------------------
; Construct ROMS
\*-------------------------------

CLEAR 0, &FFFF
ORG &8000
GUARD &C000

BEEB_BUFFER_RAM_SOCKET = &80            ; 4K MOS RAM used for buffers

BEEB_SWRAM_SLOT_LEVELBG = 0
BEEB_SWRAM_SLOT_CHTAB13 = 1
BEEB_SWRAM_SLOT_CHTAB25 = 2
BEEB_SWRAM_SLOT_CHTAB4 = 3
BEEB_SWRAM_SLOT_CHTAB67 = 3             ; BEEB - NOT SURE WHERE THIS WILL GO YET!

; BANK 0

.bank0_start
.bgtable1
SKIP 9185           ; max size of IMG.BGTAB1.XXX        BEEB ACTUALLY LESS
ALIGN &100
.bgtable2
SKIP 4593           ; max size of IMG.BGTAB2.XXX        BEEB ACTUALLY LESS
.bank0_end

; BANK 1

CLEAR 0, &FFFF
ORG &8000
GUARD &C000

.bank1_start
.chtable1
SKIP 9165           ; size of IMG.CHTAB1        BEEB ACTUALLY LESS
ALIGN &100
.chtable3
SKIP 5985           ; size of IMG.CHTAB3        BEEB ACTUALLY LESS
ALIGN &100
.bank1_end

; BANK 2

CLEAR 0, &FFFF
ORG &8000
GUARD &C000

.bank2_start
.chtable2
SKIP 9189           ; size of IMG.CHTAB2        BEEB ACTUALLY LESS
ALIGN &100
.chtable5
SKIP 6134           ; size of IMG.CHTAB5        BEEB ACTUALLY LESS
ALIGN &100
.bank2_end

; BANK 3

CLEAR 0, &FFFF
ORG &8000
GUARD &C000

.bank3_start
.chtable4
SKIP 5281           ; size of largest IMG.CHTAB4.X internal file pointer - file size 8999b?
ALIGN &100
.chtable6
SKIP 9201           ; size of largest IMG.CHTAB6.X        BEEB ACTUALLY LESS
ALIGN &100
.chtable7
SKIP 1155           ; size of IMG.CHTAB7
ALIGN &100
.bank3_end


\*-------------------------------
; Construct overlay files
\*-------------------------------

CLEAR 0, &FFFF

ORG blueprnt
.BLUETYPE skip 24*30
.BLUESPEC skip 24*30
.LINKLOC skip 256
.LINKMAP skip 256
.MAP skip 24*4
.INFO
 skip 64                ; not sure why this is skipped, unused?
.KidStartScrn skip 1
.KidStartBlock skip 1
.KidStartFace skip 1
 skip 1
.SwStartScrn skip 1
.SwStartBlock skip 1
 skip 1
.GdStartBlock skip 24
.GdStartFace skip 24
.GdStartX skip 24
.GdStartSeqL skip 24
.GdStartProg skip 24
.GdStartSeqH skip 24


\*-------------------------------
; Put files on the disk
\*-------------------------------

PUTFILE "Levels/LEVEL0", "LEVEL0", 0, 0
PUTFILE "Levels/LEVEL1", "LEVEL1", 0, 0
PUTFILE "Levels/LEVEL2", "LEVEL2", 0, 0
PUTFILE "Levels/LEVEL3", "LEVEL3", 0, 0
PUTFILE "Levels/LEVEL4", "LEVEL4", 0, 0
PUTFILE "Levels/LEVEL5", "LEVEL5", 0, 0
PUTFILE "Levels/LEVEL6", "LEVEL6", 0, 0
PUTFILE "Levels/LEVEL7", "LEVEL7", 0, 0
PUTFILE "Levels/LEVEL8", "LEVEL8", 0, 0
PUTFILE "Levels/LEVEL9", "LEVEL9", 0, 0
PUTFILE "Levels/LEVEL10", "LEVEL10", 0, 0
PUTFILE "Levels/LEVEL11", "LEVEL11", 0, 0
PUTFILE "Levels/LEVEL12", "LEVEL12", 0, 0
;PUTFILE "Levels/LEVEL13", "LEVEL13", 0, 0
;PUTFILE "Levels/LEVEL14", "LEVEL14", 0, 0
PUTFILE "Images/BEEB.IMG.BGTAB1.DUN.bin", "DUN1", 0, 0
PUTFILE "Images/BEEB.IMG.BGTAB2.DUN.bin", "DUN2", 0, 0
PUTFILE "Images/BEEB.IMG.BGTAB1.PAL.bin", "PAL1", 0, 0
PUTFILE "Images/BEEB.IMG.BGTAB2.PAL.bin", "PAL2", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB4.FAT.bin", "FAT", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB4.GD.bin", "GD", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB4.SHAD.bin", "SHAD", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB4.SKEL.bin", "SKEL", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB4.VIZ.bin", "VIZ", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB1.bin", "CHTAB1", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB2.bin", "CHTAB2", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB3.bin", "CHTAB3", 0, 0
PUTFILE "Images/BEEB.IMG.CHTAB5.bin", "CHTAB5", 0, 0
;PUTFILE "Images/IMG.CHTAB6.A.bin", "CHTAB6A", 0, 0
;PUTFILE "Images/IMG.CHTAB6.B.bin", "CHTAB6B", 0, 0
;PUTFILE "Images/IMG.CHTAB7.bin", "CHTAB7", 0, 0

PUTBASIC "chkimg.bas", "CHKIMG"
