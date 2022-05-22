; -------------------------------------------------------------------
; テキストベースゲーム
; -------------------------------------------------------------------
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                             定数宣言
; -------------------------------------------------------------------
MAP_OFST = 10

; -------------------------------------------------------------------
;                            ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
ZX:       .RES 1  ; スペクトラム？
ZY:       .RES 1
HOME_X:   .RES 1
HOME_Y:   .RES 1
INPUT_X:  .RES 1
INPUT_Y:  .RES 1
HKL_X:    .RES 1
HKL_Y:    .RES 1
TIMES:    .RES 1

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
.BSS

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; 変数初期化
  STZ HOME_X
  STZ HOME_Y
  LDA #4
  STA HKL_X
  STA HKL_Y
  LDA #1
  STA TIMES
  ; イントロ
  loadAY16 STR_INTRO
  syscall CON_OUT_STR
  JSR PRT_MAP                 ; イントロ専用マップ
  ; 区切り線
  loadAY16 STR_DOUBLE_LINE
  syscall CON_OUT_STR
@NEXT:
  ; 入力
  JSR INPUT
  JSR PRT_MAP
  ; 正解判定
  LDA HOME_X
  CMP HKL_X
  BNE @NE
  LDA HOME_Y
  CMP HKL_Y
  BNE @NE
  ; 正解
  loadAY16 STR_YOUFOUNDHIMIN
  syscall CON_OUT_STR
  LDA TIMES
  JSR PRT_NUM
  loadAY16 STR_GUESSES
  syscall CON_OUT_STR
@NE:
  ; 不正解
  loadAY16 STR_GO
  syscall CON_OUT_STR         ; "Go "まで表示
  ; North/South
  LDA HOME_Y
  CMP HKL_Y                   ; INPUT-HKL
  BEQ @SKP_ADVY
  ; Yが不正解
  BCC @GO_NORTH               ; ボロー発生つまりHKLのほうがNにいる
@GO_SOUTH:
  loadAY16 STR_SOUTH
  BRA @PRT_N_S
@GO_NORTH:
  loadAY16 STR_NORTH
@PRT_N_S:
  syscall CON_OUT_STR         ; "North"か"South"を出力
@SKP_ADVY:
  ; West/East
  LDA HOME_X
  CMP HKL_X                   ; INPUT-HKL
  BEQ @SKP_ADVX
  ; Xが不正解
  BCC @GO_EAST               ; ボロー発生つまりHKLのほうがNにいる
@GO_WEST:
  loadAY16 STR_WEST
  BRA @PRT_W_E
@GO_EAST:
  loadAY16 STR_EAST
@PRT_W_E:
  syscall CON_OUT_STR         ; "North"か"South"を出力
@SKP_ADVX:
  JSR PRT_LF
  ; 更新
  INC TIMES
  ; 区切り線
  loadAY16 STR_SINGLE_LINE
  syscall CON_OUT_STR
  BRA @NEXT
  RTS

CONTINUE:

STR_INTRO:
.BYT $A
.BYT "========THE HURKLE GAME========="
.BYT "   A HURKLE is hiding on",$A
.BYT "  a 10x10 grid.",$A
.BYT "   Gridpoint is (0,0)...(9,9)",$A
;.BYT "   Homebase is (0,0).",$A
.BYT "   Try to guess the HURKLE's",$A
.BYT "  gridpoint.",$A
.BYT "   You can only try 5 times!",$A,$0

STR_GO:
.BYT "Go ",$0
STR_NORTH:
.BYT "North",$0
STR_SOUTH:
.BYT "South",$0
STR_WEST:
.BYT "West",$0
STR_EAST:
.BYT "East",$0

STR_YOUFOUNDHIMIN:
.BYT "You found him in ",$0
STR_GUESSES:
.BYT " guesses.",$A,$0

; -------------------------------------------------------------------
;                              入力
; -------------------------------------------------------------------
INPUT:
  loadAY16 STR_INPUT
  syscall CON_OUT_STR       ; 入力プロンプト
  JSR INPUT_NUM             ; 数字のみ受け付け
  BCS LF_INPUT
  STA INPUT_X
  LDA #','
  JSR PRT_CHR
  JSR INPUT_NUM             ; 数字のみ受け付け
  BCS LF_INPUT
  STA INPUT_Y
  LDA #')'
  JSR PRT_CHR
  JSR PRT_LF
  ; 入力を現在地に
  LDA INPUT_X
  STA HOME_X
  LDA INPUT_Y
  STA HOME_Y
  RTS

LF_INPUT:
  JSR PRT_LF
  BRA INPUT

; -------------------------------------------------------------------
;                         10進一桁の入力
; -------------------------------------------------------------------
INPUT_NUM:
  LDA #$1                   ; エコーなし入力
  syscall CON_RAWIN
  CMP #$1B                  ; ESC
  BNE @SKP_ESC
  SEC
  RTS
@SKP_ESC:
  CMP #'0'
  BCC INPUT_NUM             ; A<'0'
  CMP #'9'+1
  BCS INPUT_NUM             ; A>='9'+1
  PHA
  syscall CON_OUT_CHR
  PLA
  AND #$0F                  ; 内部表現に
  CLC
  RTS

STR_INPUT:
.BYT "What is your guess? (",$0

; -------------------------------------------------------------------
;                          グリッドの表示
; -------------------------------------------------------------------
PRT_MAP:
  ; N
  JSR PRT_MAP_OFST
  loadAY16 STR_N
  syscall CON_OUT_STR
  ; グリッドYループ
  LDA #9
  STA ZY
@GY_LOOP:
  JSR PRT_MAP_OFST        ; オフセット表示
  LDA ZY                  ; Yの値を取得
  CMP #4                  ; 中心であるところの4か
  BNE @SKP_W
  loadAY16 STR_W
  syscall CON_OUT_STR
  LDA ZY                  ; Yの値を取得
@SKP_W:
  JSR PRT_NUM             ; Yの値を10進表示
  ; グリッドXループ
  LDX #0                  ; X初期化
@GX_LOOP:
  CPX HOME_X              ; 座標Xチェック
  BNE @SKP_HIT
  LDA ZY
  CMP HOME_Y              ; 座標Yチェック
  BNE @SKP_HIT
  ; 現在座標である
  LDA #'*'
  BRA @SKP_PLUS
@SKP_HIT:
  LDA #'+'                ; グリッド文字
@SKP_PLUS:
  PHX
  JSR PRT_CHR             ; グリッド文字を出力
  PLX
  INX
  CPX #$A
  BNE @GX_LOOP
  LDA ZY                  ; Yの値を取得
  CMP #4                  ; 中心であるところの4か
  BNE @SKP_E
  loadAY16 STR_E
  syscall CON_OUT_STR
@SKP_E:
  JSR PRT_LF              ; 改行
  DEC ZY
  BPL @GY_LOOP
  JSR PRT_S               ; 空白を表示
  ; 目盛りXループ
  JSR PRT_MAP_OFST        ; オフセット表示
  LDA #0
@MX_LOOP:
  PHA
  JSR PRT_NUM
  PLA
  INC
  CMP #$A
  BNE @MX_LOOP
  JSR PRT_LF
  ; S
  JSR PRT_MAP_OFST
  loadAY16 STR_S
  syscall CON_OUT_STR
  RTS

STR_N:
.BYT "    (N)",$A,$0
STR_S:
.BYT "    (S)",$A,$0
STR_W:
.BYT $8,$8,$8,"(W)",$0
STR_E:
.BYT "(E)",$0

STR_SINGLE_LINE:
.BYT "--------------------------------",$0
STR_DOUBLE_LINE:
.BYT "================================",$0

; -------------------------------------------------------------------
;                     グリッド左オフセットの表示
; -------------------------------------------------------------------
PRT_MAP_OFST:
  loadAY16 STR_OFST
  syscall CON_OUT_STR
  RTS

STR_OFST:
.REPEAT MAP_OFST
  .BYT " "
.ENDREPEAT
.BYT $0

; -------------------------------------------------------------------
;                             10進1桁表示
; -------------------------------------------------------------------
PRT_NUM:
  AND #$0F
  ORA #$30
PRT_CHR:
  syscall CON_OUT_CHR
  RTS

; -------------------------------------------------------------------
;                              改行表示
; -------------------------------------------------------------------
PRT_LF:
  LDA #$A
  BRA PRT_CHR

; -------------------------------------------------------------------
;                              空白表示
; -------------------------------------------------------------------
PRT_S:
  LDA #' '
  BRA PRT_CHR

; -------------------------------------------------------------------
;                             データ領域
; -------------------------------------------------------------------
.DATA

