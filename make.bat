@echo off
set HH=%TIME:~0,2%
if %HH% leq 9 set HH=0%HH:~1,1%
echo EQUB $%DATE:~8,2%, $%DATE:~3,2%, $%DATE:~0,2%, $%HH%, $%TIME:~3,2%, "%USERNAME:~0,2%" > version.txt

rem SM: selfishly not sending compiler output to compile.txt so I can use VS.code console instead
rem KC: super hack balls just for me ;)
if "%USERNAME%"=="kconnell" (
bin\BeebAsm.exe -v -i pop-beeb.asm > compile.txt
) else (
bin\BeebAsm.exe -v -i pop-beeb.asm -di disc/template-side-a.ssd.bin -do pop-beeb-side-a.ssd 
)

if %ERRORLEVEL% neq 0 (
	echo Assemble failed!
	exit /b 1
)

rem Crunch files produced by Code build
bin\pucrunch.exe -d -c0 -l0x1000 "disc\PRIN2" disc\prin2.pu.bin
bin\pucrunch.exe -d -c0 -l0x1000 "disc\BANK1" disc\bank1.pu.bin

del pop-beeb.ssd
bin\BeebAsm.exe -v -i disc\pop-beeb-layout.asm -boot Prince -do pop-beeb.ssd
