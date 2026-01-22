; -------------------------------------------------------------------
;                           PIPOコマンド
; -------------------------------------------------------------------
; BEEPボードでピポ音を鳴らすテストプログラム
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.INCLUDE "../zr.inc"          ; ZPレジスタZR0..ZR5

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.macro sound d, length
  LDA #1
  STA BEEP::OUT_ENABLE
  LDA #<(d)
  STA BEEP::FRQ_LOW
  LDA #>(d)
  STA BEEP::FRQ_HIGH
  LDA length
  JSR WAIT
  LDA #0
  STA BEEP::OUT_ENABLE
  LDA 1
  JSR WAIT
.endmac
.macro wait length
  LDA #0
  STA BEEP::OUT_ENABLE
  LDA length
  JSR WAIT
.endmac
.CODE

INIT:
  ;sound 567, 99 ; ラ5
  ;sound 567, 99 ; ラ5
  ;sound 505, 50 ; シ5

  ;sound 567, 99 ; ラ5
  ;sound 567, 99 ; ラ5
  ;sound 505, 50 ; シ5

  ;sound 567, 99 ; ラ5
  ;sound 505, 99 ; シ5
  ;sound 476, 99 ; ド6
  ;sound 505, 99 ; シ5

  ;sound 567, 99 ; ラ5
  ;sound 505, 120 ; シ5
  ;sound 567, 120 ; ラ5
  ;sound 714, 50 ; ファ5

  LDA #1
  STA BEEP::OUT_ENABLE
  LDA #<249
  STA BEEP::FRQ_LOW
  STZ BEEP::FRQ_HIGH
  LDA #50
  JSR WAIT
  LDA #<499
  STA BEEP::FRQ_LOW
  LDA #>499
  STA BEEP::FRQ_HIGH
  LDA #50
  JSR WAIT

  LDA #0
  STA BEEP::OUT_ENABLE
  RTS

WAIT:
  PHA
  loadmem16 ZR0,WAIT_EXIT
  PLA
  syscall TIMEOUT
  WAIT_LOOP:
  BRA WAIT_LOOP
WAIT_EXIT:
  RTS

;.WORD 18180 ; 0 ラ0 A0
;.WORD 17160 ; 1 ラ#0 A#0
;.WORD 16197 ; 2 シ0 B0
;.WORD 15288 ; 3 ド1 C1
;.WORD 14429 ; 4 ド#1 C#1
;.WORD 13620 ; 5 レ1 D1
;.WORD 12855 ; 6 レ#1 D#1
;.WORD 12134 ; 7 ミ1 E1
;.WORD 11452 ; 8 ファ1 F1
;.WORD 10810 ; 9 ファ#1 F#1
;.WORD 10203 ; 10 ソ1 G1
;.WORD 9630 ; 11 ソ#1 G#1
;.WORD 9089 ; 12 ラ1 A1
;.WORD 8579 ; 13 ラ#1 A#1
;.WORD 8098 ; 14 シ1 B1
;.WORD 7643 ; 15 ド2 C2
;.WORD 7214 ; 16 ド#2 C#2
;.WORD 6809 ; 17 レ2 D2
;.WORD 6427 ; 18 レ#2 D#2
;.WORD 6066 ; 19 ミ2 E2
;.WORD 5725 ; 20 ファ2 F2
;.WORD 5404 ; 21 ファ#2 F#2
;.WORD 5101 ; 22 ソ2 G2
;.WORD 4814 ; 23 ソ#2 G#2
;.WORD 4544 ; 24 ラ2 A2
;.WORD 4289 ; 25 ラ#2 A#2
;.WORD 4048 ; 26 シ2 B2
;.WORD 3821 ; 27 ド3 C3
;.WORD 3606 ; 28 ド#3 C#3
;.WORD 3404 ; 29 レ3 D3
;.WORD 3213 ; 30 レ#3 D#3
;.WORD 3032 ; 31 ミ3 E3
;.WORD 2862 ; 32 ファ3 F3
;.WORD 2701 ; 33 ファ#3 F#3
;.WORD 2550 ; 34 ソ3 G3
;.WORD 2406 ; 35 ソ#3 G#3
;.WORD 2271 ; 36 ラ3 A3
;.WORD 2144 ; 37 ラ#3 A#3
;.WORD 2023 ; 38 シ3 B3
;.WORD 1910 ; 39 ド4 C4
;.WORD 1802 ; 40 ド#4 C#4
;.WORD 1701 ; 41 レ4 D4
;.WORD 1606 ; 42 レ#4 D#4
;.WORD 1515 ; 43 ミ4 E4
;.WORD 1430 ; 44 ファ4 F4
;.WORD 1350 ; 45 ファ#4 F#4
;.WORD 1274 ; 46 ソ4 G4
;.WORD 1202 ; 47 ソ#4 G#4
;.WORD 1135 ; 48 ラ4 A4
;.WORD 1071 ; 49 ラ#4 A#4
;.WORD 1011 ; 50 シ4 B4
;.WORD 954 ; 51 ド5 C5
;.WORD 900 ; 52 ド#5 C#5
;.WORD 850 ; 53 レ5 D5
;.WORD 802 ; 54 レ#5 D#5
;.WORD 757 ; 55 ミ5 E5
;.WORD 714 ; 56 ファ5 F5
;.WORD 674 ; 57 ファ#5 F#5
;.WORD 636 ; 58 ソ5 G5
;.WORD 600 ; 59 ソ#5 G#5
;.WORD 567 ; 60 ラ5 A5
;.WORD 535 ; 61 ラ#5 A#5
;.WORD 505 ; 62 シ5 B5
;.WORD 476 ; 63 ド6 C6
;.WORD 449 ; 64 ド#6 C#6
;.WORD 424 ; 65 レ6 D6
;.WORD 400 ; 66 レ#6 D#6
;.WORD 378 ; 67 ミ6 E6
;.WORD 356 ; 68 ファ6 F6
;.WORD 336 ; 69 ファ#6 F#6
;.WORD 317 ; 70 ソ6 G6
;.WORD 299 ; 71 ソ#6 G#6
;.WORD 283 ; 72 ラ6 A6
;.WORD 267 ; 73 ラ#6 A#6
;.WORD 252 ; 74 シ6 B6
;.WORD 237 ; 75 ド7 C7
;.WORD 224 ; 76 ド#7 C#7
;.WORD 211 ; 77 レ7 D7
;.WORD 199 ; 78 レ#7 D#7
;.WORD 188 ; 79 ミ7 E7
;.WORD 177 ; 80 ファ7 F7
;.WORD 167 ; 81 ファ#7 F#7
;.WORD 158 ; 82 ソ7 G7
;.WORD 149 ; 83 ソ#7 G#7
;.WORD 141 ; 84 ラ7 A7
;.WORD 133 ; 85 ラ#7 A#7
;.WORD 125 ; 86 シ7 B7
;.WORD 118 ; 87 ド8 C8
