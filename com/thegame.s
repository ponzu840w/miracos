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
MAP_OFST = 8

; -------------------------------------------------------------------
;                            ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
ZX: .RES 1  ; スペクトラム？
ZY: .RES 1
HOME_X: .RES 1
HOME_Y: .RES 1
INPUT_X: .RES 1
INPUT_Y: .RES 1

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
.BSS

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  STZ HOME_X
  STZ HOME_Y
  loadAY16 STR_INTRO
  syscall CON_OUT_STR
  JSR PRT_MAP
  JSR INPUT
  RTS

STR_INTRO:
.BYT $A
.BYT "========THE HURKLE GAME=========",$A
.BYT "   A HURKLE is hiding on",$A
.BYT "  a 10x10 grid.",$A
.BYT "   Gridpoint is (0,0)...(9,9)",$A
;.BYT "   Homebase is (0,0).",$A
.BYT "   Try to guess the HURKLE's",$A
.BYT "  gridpoint.",$A
.BYT "   You can only try 5 times!",$A,$0

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

