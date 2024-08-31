# MIRACOS･･･Mirakurun Card Operating System

A CP/M-like OS and apps that powers the FxT-65, a simple 65C02 homebrew computer.

## Features

* 30+ System-calls with ABI
* SD card support
* FAT32 File System with file-descriptor interface
* Abstracted character input/output
  * UART input/output
  * PS/2 Keyboard input
  * Video console output
* Interrupt control
* Kernel built-in debugger
* Command-Line shell (CCP)
* Application cross development with CA65/CC65

Planned
* STDIO including files and consoles
* Child process call
* Pipe, Shell Scripts

## ライセンス
このリポジトリの一部にはponzu840w以外の著作物が含まれます。
### not-runtime/misaki_mincho.png
* [美咲フォント](https://littlelimit.net/misaki.htm)
* 作者：門真 なむ氏
> These fonts are free software.
>
> Unlimited permission is granted to use, copy, and distribute them, with or without modification, either commercially or noncommercially.
>
> THESE FONTS ARE PROVIDED "AS IS" WITHOUT WARRANTY.
>
> これらのフォントはフリー（自由な）ソフトウエアです。
>
> あらゆる改変の有無に関わらず、また商業的な利用であっても、自由にご利用、複製、再配布することができますが、全て無保証とさせていただきます。

### sweet16.s
* SWEET16のReplica1用移植（[github.com, sweet16](https://github.com/jefftranter/6502/tree/master/asm/sweet16)）
* 作者
  * オリジナル：STEVE WOZNIAK氏
  * Replica1移植版：Jeff Tranter氏
* FxT-65用に改変移植
> ```
> ; Sweet16 port to MIRACOS APP
> ;
> ; Based on Replica 1 port. See: https://github.com/jefftranter/6502/tree/master/asm/sweet16
> ;   Based on Atari port. See: http://atariwiki.strotmann.de/wiki/Wiki.jsp?page=Sweet16Mac65
> ;
> ; ***************************
> ; *                         *
> ; * APPLE II PSEUDO MACHINE *
> ; *        INTERPRETER      *
> ; *                         *
> ; * COPYRIGHT (C) 1977      *
> ; * APPLE COMPUTER INC.     *
> ; *                         *
> ; * STEVE WOZNIAK           *
> ; *                         *
> ; ***************************
> ; * TITLE: SWEET 16 INTERPRETER
> ```

## ps2/decode_ps2.s, encode_ps2.s
* PC（≒PS/2）キーボードをVIAでビットバンするドライバ（[sbc.rictor.org, PC Keyboard Device](http://sbc.rictor.org/io/pckb6522.html)）
* 作者：Daryl Rictor氏
* FxT-65用に改変移植
> ```
> ;****************************************************************************
> ; PC keyboard Interface for the 6502 Microprocessor utilizing a 6522 VIA
> ; (or suitable substitute)
> ;
> ; Designed and Written by Daryl Rictor (c) 2001   65c02@altavista.com
> ; Offered as freeware.  No warranty is given.  Use at your own risk.
> ;
> ; Software requires about 930 bytes of RAM or ROM for code storage and only 4 bytes
> ; in RAM for temporary storage.  Zero page locations can be used but are NOT required.
> ;
> ; Hardware utilizes any two bidirection IO bits from a 6522 VIA connected directly 
> ; to a 5-pin DIN socket (or 6 pin PS2 DIN).  In this example I'm using the 
> ; 6526 PB4 (Clk) & PB5 (Data) pins connected to a 5-pin DIN.  The code could be
> ; rewritten to support other IO arrangements as well.  
> ; ________________________________________________________________________________
> ;|                                                                                |
> ;|        6502 <-> PC Keyboard Interface Schematic  by Daryl Rictor (c) 2001      |
> ;|                                                     65c02@altavista.com        |
> ;|                                                                                |
> ;|                                                           __________           |
> ;|                      ____________________________________|          |          |
> ;|                     /        Keyboard Data            15 |PB5       |          |
> ;|                     |                                    |          |          |
> ;|                _____|_____                               |          |          |
> ;|               /     |     \                              |   6522   |          |
> ;|              /      o      \    +5vdc (300mA)            |   VIA    |          |
> ;|        /-------o    2    o--------------------o---->     |          |          |
> ;|        |   |    4       5    |                |          |          |          |
> ;|        |   |                 |          *C1 __|__        |          |          |
> ;|        |   |  o 1       3 o  |              _____        |          |          |
> ;|        |   |  |              |                |          |          |          |
> ;|        |    \ |             /               __|__        |          |          |
> ;|        |     \|     _      /                 ___         |          |          |
> ;|        |      |____| |____/                   -          |          |          |
> ;|        |      |                  *C1 0.1uF Bypass Cap    |          |          |
> ;|        |      |                                          |          |          |
> ;|        |      \__________________________________________|          |          |
> ;|        |                    Keyboard Clock            14 | PB4      |          |
> ;|      __|__                                               |__________|          |
> ;|       ___                                                                      |
> ;|        -                                                                       |
> ;|            Keyboard Socket (not the keyboard cable)                            |
> ;|       (As viewed facing the holes)                                             |
> ;|                                                                                |
> ;|________________________________________________________________________________|
> ```

## fs/lib_fs.s, com/grep.s
* 文字列パターンマッチルーチン（[6502.org, Pattern Matcher](http://www.6502.org/source/strings/patmatch.htm)）
* 作者：Paul Guertin氏

## com/vtl.s
* VTLインタプリタ（[github.com, 6502-Assembly](https://github.com/barrym95838/6502-Assembly/blob/main/VTLC02)）
* 作者：Michael T. Barry氏
* FxT-65用に改変移植
> ```
> ;-----------------------------------------------------;
> ;             VTL-2 for the 65C02 (VTLC02)            ;
> ;           Original Altair 680b version by           ;
> ;          Frank McCoy and Gary Shannon 1977          ;
> ;    2012: Adapted to the 6502 by Michael T. Barry    ;
> ;    2024: Port to MIRACOS(FxT-65) by @ponzu840w      ;
> ;-----------------------------------------------------;
> ;        Copyright (c) 2012, Michael T. Barry
> ;       Revision B (c) 2015, Michael T. Barry
> ;       Revision C (c) 2015, Michael T. Barry
> ;     Revision C02 (c) 2022, Michael T. Barry
> ;               All rights reserved.
> ;
> ; VTLC02 is a ligntweight "self-contained" IDE, and
> ;   features a command line, program editor and
> ;   language interpreter, all in 957 bytes of dense
> ;   65C02 machine code.  The "only" thing missing is a
> ;   secondary storage facility for your programs, but
> ;   this Kowalski version assumes that you will be
> ;   copying/pasting code from the simulator host.
> ;
> ; Redistribution and use in source and binary forms,
> ;   with or without modification, are permitted,
> ;   provided that the following conditions are met: 
> ;
> ; 1. Redistributions of source code must retain the
> ;    above copyright notice, this list of conditions
> ;    and the following disclaimer. 
> ; 2. Redistributions in binary form must reproduce the
> ;    above copyright notice, this list of conditions
> ;    and the following disclaimer in the documentation
> ;    and/or other materials provided with the
> ;    distribution. 
> ;
> ; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS
> ; AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
> ; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
> ; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
> ; FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
> ; SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
> ; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
> ; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
> ; NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
> ; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
> ; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
> ; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
> ; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
> ; IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
> ; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
> ;-----------------------------------------------------;
> ```

## com/othello.c
* C言語・stdioによるオセロ（[だえうホームページ, C言語でオセロゲームを作成](https://daeudaeu.com/othello/)）
* 作者：だえう氏
* CC65用に改変

## com/nvtl-c.c
* 偽VTL（[github.com, nlp](https://github.com/cherry-takuan/nlp/blob/master/nlp-16a/Software/Application/NiseVTL/main.c)）
* 作者：cherry-takuan氏
* [CC-BY-SA-4.0 license](https://creativecommons.org/licenses/by-sa/4.0/deed.ja)
* CC65用に改変

## その他すべて
* 作者：ponzu840w

|MIT License|
| :--- |
|Copyright (c) 2024, @ponzu840w. All rights reserved.<br><br> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:<br> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.<br><br> THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.|
