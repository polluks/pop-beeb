@echo off
..\bin\pucrunch.exe -d -c0 -l0x3a00 john.Splash.mode2.bin splash.pu.bin
..\bin\pucrunch.exe -d -c0 -l0x3a00 john.Credits.mode2.bin credits.pu.bin
..\bin\pucrunch.exe -d -c0 -l0x3a00 john.Epilog.mode2.bin epilog.pu.bin
..\bin\pucrunch.exe -d -c0 -l0x3a00 john.Prolog.mode2.bin prolog.pu.bin
..\bin\pucrunch.exe -d -c0 -l0x3a00 john.Sumup.mode2.bin sumup.pu.bin

..\bin\pucrunch.exe -d -c0 -l0x5800 john.Byline.mode2.bin byline.pu.bin
..\bin\pucrunch.exe -d -c0 -l0x5800 john.Title.mode2.bin title.pu.bin
..\bin\pucrunch.exe -d -c0 -l0x5800 john.Presents.mode2.bin presents.pu.bin