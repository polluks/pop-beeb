; gameeq.h.asm
; Originally GAMEEQ.S
; Contains game definitions and memory addresses

\* gameeq
\*-------------------------------
\*
\*  Equates
\*
\*-------------------------------

\ BEEB DEFINED IN pop-beeb.asm AS SWRAM BANKS
\chtable1 = $6000
\chtable2 = $8400
\chtable3 = $0800
\chtable4 = $9600
\chtable5 = $a800
\chtable6 = $6000
\chtable7 = $9f00

\bgtable1 = $6000
\bgtable2 = $8400

\topctrl = $2000                  ; location determined by assembler
seqtable = $2800
seqtab = $3000
ctrl = $3a00
coll = $4500
\gamebg = $4c00                  ; location determined by assembler
auto = $5400

mobtables = $b600
savedgame = $b6f0

msys = $d400
ctrlsubs = $d000
\specialk = $d900               ; location determined by assembler
textline = $dfd8
subs = $e000
sound = $ea00
mover = $ee00
misc = $f900
debugs = $fc00

\*-------------------------------
\*
\*  Jump tables
\*
\*-------------------------------

trobspace = $20
mobspace = $10
maxsfx = $20

IF _TODO
 dum mobtables

trloc ds trobspace
trscrn ds trobspace
trdirec ds trobspace

mobx ds mobspace
moby ds mobspace
mobscrn ds mobspace
mobvel ds mobspace
mobtype ds mobspace
moblevel ds mobspace

soundtable ds maxsfx

trobcount ds 1
ENDIF

IF _TODO
 dum savedgame

SavLevel ds 1
SavStrength ds 1
SavMaxed ds 1
SavTimer ds 2
 ds 1
SavNextMsg ds 1
ENDIF

IF _TODO
 dum topctrl

start ds 3
restart ds 3
startresume ds 3
initsystem ds 3
 ds 3

docrosscut ds 3
goattract ds 3
ENDIF

IF _TODO
 dum ctrl

PlayerCtrl ds 3
checkfloor ds 3
ShadCtrl ds 3
rereadblocks ds 3
checkpress ds 3

DoImpale ds 3
GenCtrl ds 3
checkimpale ds 3
ENDIF

\dum auto
\ Moved to auto.asm

IF _TODO
 dum coll

checkbarr ds 3
collisions ds 3
getfwddist ds 3
checkcoll ds 3
animchar ds 3

checkslice ds 3
checkslice2 ds 3
 ds 3
checkgate ds 3
 ds 3

enemycoll ds 3
ENDIF

\dum gamebg
\ jump table moved to gamebg.asm

\dum specialk
\ jump table moved to specialk.asm

IF _TODO
 dum mover

animtrans ds 3
trigspikes ds 3
pushpp ds 3
breakloose1 ds 3
breakloose ds 3

animmobs ds 3
addmobs ds 3
closeexit ds 3
getspikes ds 3
shakem ds 3

trigslicer ds 3
trigtorch ds 3
getflameframe ds 3
smashmirror ds 3
jamspikes ds 3

trigflask ds 3
getflaskframe ds 3
trigsword ds 3
jampp ds 3
ENDIF

IF _TODO
 dum ctrlsubs

getframe ds 3
getseq ds 3
getbasex ds 3
getblockx ds 3
getblockxp ds 3

getblocky ds 3
getblockej ds 3
addcharx ds 3
getdist ds 3
getdist1 ds 3

getabovebeh ds 3
rdblock ds 3
rdblock1 ds 3
setupsword ds 3
getscrns ds 3

addguardobj ds 3
opjumpseq ds 3
getedges ds 3
indexchar ds 3
quickfg ds 3

cropchar ds 3
getleft ds 3
getright ds 3
getup ds 3
getdown ds 3

cmpspace ds 3
cmpbarr ds 3
addkidobj ds 3
addshadobj ds 3
addreflobj ds 3

LoadKid ds 3
LoadShad ds 3
SaveKid ds 3
SaveShad ds 3
setupchar ds 3

GetFrameInfo ds 3
indexblock ds 3
markred ds 3
markfred ds 3
markwipe ds 3

markmove ds 3
markfloor ds 3
unindex ds 3
quickfloor ds 3
unevenfloor ds 3

markhalf ds 3
addswordobj ds 3
getblocky1 ds 3
checkledge ds 3
get2infront ds 3

checkspikes ds 3
rechargemeter ds 3
addfcharx ds 3
facedx ds 3
jumpseq ds 3

GetBaseBlock ds 3
LoadKidwOp ds 3
SaveKidwOp ds 3
getopdist ds 3
LoadShadwOp ds 3

SaveShadwOp ds 3
boostmeter ds 3
getunderft ds 3
getinfront ds 3
getbehind ds 3

getabove ds 3
getaboveinf ds 3
cmpwall ds 3
ENDIF

IF _TODO
 dum subs

addtorches ds 3
doflashon ds 3
PageFlip ds 3
demo ds 3
showtime ds 3

doflashoff ds 3
lrclse ds 3
 ds 3
 ds 3
 ds 3

addslicers ds 3
pause ds 3
 ds 3
deadenemy ds 3
playcut ds 3

addlowersound ds 3
RemoveObj ds 3
addfall ds 3
setinitials ds 3
startkid ds 3

startkid1 ds 3
gravity ds 3
initialguards ds 3
mirappear ds 3
crumble ds 3
ENDIF

IF _TODO
 dum sound

playback ds 3
ENDIF

IF _TODO
 dum msys

_minit ds 3
_mplay ds 3
ENDIF

IF _TODO
 dum seqtable

Fdef ds 1200
altset1 ds 200
altset2 ds 450
swordtab ds 192
ENDIF

\dum misc
\ Moved to misc.asm

IF _TODO
 dum debugs

showpage ds 3
debugkeys ds 3
 ds 3
titlescreen ds 3
ENDIF

\*-------------------------------
\*
\*  Zero page
\*
\*-------------------------------

\*-------------------------------
\*  $40-e7: Game globals
\*-------------------------------

\ BEEB let assembler assign ZP addresses
\ORG $40

;.Char skip $10

.Kid
.KidPosn skip 1
.KidX skip 1
.KidY skip 1
.KidFace skip 1
.KidBlockX skip 1
.KidBlockY skip 1
.KidAction skip 1
.KidXVel skip 1
.KidYVel skip 1
.KidSeq skip 2
.KidScrn skip 1
.KidRepeat skip 1
.KidID skip 1
.KidSword skip 1
.KidLife skip 1

.Shad
.ShadPosn skip 1
.ShadX skip 1
.ShadY skip 1
.ShadFace skip 1
.ShadBlockX skip 1
.ShadBlockY skip 1
.ShadAction skip 1
.ShadXVel skip 1
.ShadYVel skip 1
.ShadSeq skip 2
.ShadScrn skip 1
.ShadRepeat skip 1
.ShadID skip 1
.ShadSword skip 1
.ShadLife skip 1

;.FCharVars skip 12
;.yellowflag skip 1
;.timebomb skip 1
;.justblocked skip 1
;.gdtimer skip 1
;.framepoint skip 2
;.Fimage skip 1
;.Fdx skip 1
;.Fdy skip 1
;.Fcheck skip 1
.exitopen skip 1
;.collX skip 1
.lightning skip 1
;.lightcolor skip 1
;.offguard skip 1
;.blockid skip 1
;.blockx skip 1
;.blocky skip 1
;.infrontx skip 1
;.behindx skip 1
;.abovey skip 1
;.tempblockx skip 1
;.tempblocky skip 1
;.tempscrn skip 1
;.tempid skip 1
.numtrans skip 1
;.tempnt skip 1
.redrawflg skip 1
;.xdiff skip 2
;.ydiff skip 2
;.xdir skip 1
;.ydir skip 1
;.RNskipeed skip 1
.invert skip 1
.PlayCount skip 1
;.refract skip 1
;.backtolife skip 1
.cutplan skip 1
;.lastcmd skip 1
;.distfallen skip 1
.cutscrn skip 1
;.waitingtojump skip 1
;.trigppabove skip 1
;.direcpp skip 1
;.blockaddr skip 2
;.delay skip 1
;.XCOORD skip 2
;.savekidx skip 1
;.mirrx skip 1
;.dmirr skip 1
;.barrdist skip 1
;.barrcode skip 1
;.imwidth skip 1
;.imheight skip 1
;.leadedge skip 1
;.leftej skip 1
;.rightej skip 1
;.topej skip 1
;.leftblock skip 1
;.rightblock skip 1
;.topblock skip 1
;.bottomblock skip 1
;.CDLeftEj skip 1
;.CDRightEj skip 1
;.endrange skip 1
;.bufindex skip 1
;.blockedge skip 1
;.collideL skip 1
;.collideR skip 1
;.weightless skip 1
.cutorder skip 1
.AMtimer skip 1
;.begrange skip 1
;.scrn skip 1
;.keybufptr skip 1
.VisScrn skip 1
.OppStrength skip 1
;.jarabove skip 1
;.Kiskiptrength skip 1
.ChgKidStr skip 1
.MaxKidStr skip 1
.EnemyAlert skip 1
.ChgOppStr skip 1
.heroic skip 1
;.clrF skip 1
;.clrB skip 1
;.clrU skip 1
;.clrD skip 1
;.clrbtn skip 1
;.Fsword skip 1
;.purpleflag skip 1 ;$da
.msgtimer skip 1
;.MaxOppStr skip 1
;.guardprog skip 1
.ManCtrl skip 1
.mergetimer skip 1
;.lastpotion skip 1
.origstrength skip 1
;.jmpaddr skip 2
;.alertguard skip 1
.createshad skip 1
.stunned skip 1
;.droppedout skip 1

\*-------------------------------
\*
\*  Page 2-3 - AUX MEM
\*
\*-------------------------------

IF _TODO
 dum $320

CDthisframe ds $10
CDlastframe ds $10
CDbelow ds $10
CDabove ds $10
SNthisframe ds $10
SNlastframe ds $10
SNbelow ds $10
SNabove ds 10
BlockYthis ds 1
BlockYlast ds 1

Op ds $10

keybuflen = 10
keybuf ds keybuflen
ENDIF

\*-------------------------------
\*
\*  Character data
\*
\*-------------------------------

IF _TODO
 dum Char
CharPosn ds 1
CharX ds 1
CharY ds 1
CharFace ds 1
CharBlockX ds 1
CharBlockY ds 1
CharAction ds 1
CharXVel ds 1
CharYVel ds 1
CharSeq ds 2
CharScrn ds 1
CharRepeat ds 1
CharID ds 1
CharSword ds 1
CharLife ds 1
ENDIF

IF _TODO
 dum Op
OpPosn ds 1
OpX ds 1
OpY ds 1
OpFace ds 1
OpBlockX ds 1
OpBlockY ds 1
OpAction ds 1
OpXVel ds 1
OpYVel ds 1
OpSeq ds 2
OpScrn ds 1
OpRepeat ds 1
OpID ds 1
OpSword ds 1
OpLife ds 1
ENDIF

IF _TODO
 dum Shad
ShadPosn ds 1
ShadX ds 1
ShadY ds 1
ShadFace ds 1
ShadBlockX ds 1
ShadBlockY ds 1
ShadAction ds 1
ShadXVel ds 1
ShadYVel ds 1
ShadSeq ds 2
ShadScrn ds 1
ShadRepeat ds 1
ShadID ds 1
ShadSword ds 1
ShadLife ds 1
ENDIF

IF _TODO
 dum FCharVars
FCharImage ds 1
FCharX ds 2
FCharY ds 1
FCharFace ds 1
FCharIndex ds 1
FCharCU ds 1
FCharCD ds 1
FCharCL ds 1
FCharCR ds 1
FCharTable ds 1

 dend
ENDIF

\*-------------------------------
\*
\*  Misc. data
\*
\*-------------------------------
Fcheckmark = %01000000
Fthinmark = %00100000
Ffootmark = %00011111

floorheight = 15
angle = 7
VertDist = 11

UseFastlay = 0
UseLay = 1
UseLayrsave = 2

TypeKid = 0
TypeShad = 1
TypeGd = 2
TypeSword = 3
TypeReflect = 4
TypeComix = 5
TypeFF = $80
