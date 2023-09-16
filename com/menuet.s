; -------------------------------------------------------------------
;                           menuetコマンド
; -------------------------------------------------------------------
; menuet G-Dur を鳴らす
; 将来プログラムとデータの分離する事･･･
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../zr.inc"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

.macro bp
  JSR VB_OFF
  BRK
  NOP
.endmac


; -------------------------------------------------------------------
;                           実行用ライブラリ
; -------------------------------------------------------------------
.INCLUDE "./+menuet/ymzq.s"
.PROC IMF
.INCLUDE "./+menuet/imf.s"
.ENDPROC

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ; VBLANK
  ZP_VB_STUB:         .RES 2        ; 割り込み終了処理

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------

.CODE
INIT:
  ; ---------------------------------------------------------------
  ;   YMZ
  init_ymzq
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの登録
  SEI
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB

  LDX #0
  loadAY16 NOTES_MAIN
  JSR PLAY

  LDX #1
  loadAY16 NOTES_SUB
  JSR PLAY
  CLI

  ; 画像表示
  loadAY16 PATH_PICT
  JSR IMF::PRINT_IMF
MAIN:
  LDA ZP_CH_ENABLE
  AND #%1
  BNE MAIN
  RTS

PATH_PICT:
  .BYTE "/DOC/MENUET.IM4",$0

; -------------------------------------------------------------------
;                          垂直同期割り込み
; -------------------------------------------------------------------
VBLANK:
TICK:
  ;LDA #'S'
  ;syscall CON_OUT_CHR
  ;LDA #1
  ;LDX #2
  ;LDY #3
  ;JMP BRK_VB
  tick_ymzq
  JMP (ZP_VB_STUB)            ; 片付けはBCOSにやらせる

NOTES_MAIN:     ; 主旋律
.BYTE 128+1,12
.BYTE 128+2,1   ; ピアノ

NOTE1:
.REPEAT 2
.BYTE 51,2
.BYTE 44,1
.BYTE 46,1
.BYTE 48,1
.BYTE 49,1
.BYTE 51,2
.BYTE 44,2
.BYTE 44,2
.BYTE 53,2
.BYTE 49,1
.BYTE 51,1
.BYTE 53,1
.BYTE 55,1
.BYTE 56,2
.BYTE 44,2
.BYTE 44,2
.BYTE 49,2
.BYTE 51,1
.BYTE 49,1
.BYTE 48,1
.BYTE 46,1
.BYTE 48,2
.BYTE 49,1
.BYTE 48,1
.BYTE 46,1
.BYTE 44,1
.BYTE 43,2
.BYTE 44,1
.BYTE 46,1
.BYTE 48,1
.BYTE 44,1
.BYTE 46,6

.BYTE 51,2
.BYTE 44,1
.BYTE 46,1
.BYTE 48,1
.BYTE 49,1
.BYTE 51,2
.BYTE 44,2
.BYTE 44,2
.BYTE 53,2
.BYTE 49,1
.BYTE 51,1
.BYTE 53,1
.BYTE 55,1
.BYTE 56,2
.BYTE 44,2
.BYTE 44,2
.BYTE 49,2
.BYTE 51,1
.BYTE 49,1
.BYTE 48,1
.BYTE 46,1
.BYTE 48,2
.BYTE 49,1
.BYTE 48,1
.BYTE 46,1
.BYTE 44,1
.BYTE 46,2
.BYTE 48,1
.BYTE 46,1
.BYTE 44,1
.BYTE 43,1
.BYTE 44,6
.ENDREPEAT

.REPEAT 2
.BYTE 60,2
.BYTE 56,1
.BYTE 58,1
.BYTE 60,1
.BYTE 56,1
.BYTE 58,2
.BYTE 51,1
.BYTE 53,1
.BYTE 55,1
.BYTE 51,1
.BYTE 56,2
.BYTE 53,1
.BYTE 55,1
.BYTE 56,1
.BYTE 51,1
.BYTE 50,2
.BYTE 48,1
.BYTE 50,1
.BYTE 46,2
.BYTE 46,1
.BYTE 48,1
.BYTE 50,1
.BYTE 51,1
.BYTE 53,1
.BYTE 55,1
.BYTE 56,2
.BYTE 55,2
.BYTE 53,2
.BYTE 55,2
.BYTE 46,2
.BYTE 50,2
.BYTE 51,6

.BYTE 51,2
.BYTE 44,1
.BYTE 43,1
.BYTE 44,2
.BYTE 53,2
.BYTE 44,1
.BYTE 43,1
.BYTE 44,2
.BYTE 51,2
.BYTE 49,2
.BYTE 49,2
.BYTE 48,2
.BYTE 46,1
.BYTE 44,1
.BYTE 43,1
.BYTE 44,1
.BYTE 46,2
.BYTE 39,1
.BYTE 41,1
.BYTE 43,1
.BYTE 44,1
.BYTE 46,1
.BYTE 48,1
.BYTE 49,2
.BYTE 48,2
.BYTE 46,2
.BYTE 48,1
.BYTE 51,1
.BYTE 44,2
.BYTE 43,2
.BYTE 44,6
.ENDREPEAT
.BYTE 128+6     ; stop

NOTES_SUB:      ; 主じゃない旋律
.BYTE 128+1,12
.BYTE 128+2,1   ; ピアノ

.REPEAT 2
.BYTE 36,4
.BYTE 34,2
.BYTE 36,6
.BYTE 37,6
.BYTE 36,6
.BYTE 34,6
.BYTE 32,6
.BYTE 39,2
.BYTE 36,2
.BYTE 32,2
.BYTE 39,2
.BYTE 27,1
.BYTE 37,1
.BYTE 36,1
.BYTE 34,1
.BYTE 36,4
.BYTE 34,2
.BYTE 32,2
.BYTE 36,2
.BYTE 32,2
.BYTE 37,6
.BYTE 36,2
.BYTE 37,1
.BYTE 36,1
.BYTE 34,1
.BYTE 32,1
.BYTE 34,4
.BYTE 31,2
.BYTE 32,4
.BYTE 36,2
.BYTE 37,2
.BYTE 39,2
.BYTE 27,2
.BYTE 32,4
.BYTE 20,2
.ENDREPEAT

.REPEAT 2
.BYTE 32,6
.BYTE 31,6
.BYTE 29,2
.BYTE 32,2
.BYTE 29,2
.BYTE 34,4
.BYTE 22,2
.BYTE 34,6
.BYTE 36,2
.BYTE 39,2
.BYTE 38,2
.BYTE 39,2
.BYTE 31,2
.BYTE 34,2
.BYTE 39,2
.BYTE 27,2
.BYTE 37,2
.BYTE 36,2
.BYTE 39,2
.BYTE 36,2
.BYTE 37,2
.BYTE 41,2
.BYTE 37,2
.BYTE 36,2
.BYTE 34,2
.BYTE 32,2
.BYTE 39,4
.BYTE 128,2
.BYTE 27,4
.BYTE 31,2
.BYTE 29,2
.BYTE 32,2
.BYTE 31,2
.BYTE 32,2
.BYTE 24,2
.BYTE 27,2
.BYTE 32,2
.BYTE 27,2
.BYTE 20,2
.ENDREPEAT

.BYTE 128+6     ; stop

;.BYTE 128+3
;.WORD .LOWORD(NOTES-*-1)

VB_OFF:
  PHA
  PHX
  PHY
  mem2AY16 ZP_VB_STUB
  syscall IRQ_SETHNDR_VB
  PLY
  PLX
  PLA
  BRK
  NOP
  RTS

; 16bit値を表示+改行
PRT_SHORT_LF:
  storeAY16 ZR2
  LDY #1
  LDA (ZR2),Y
  JSR PRT_BYT
  LDY #0
  LDA (ZR2),Y
  JSR PRT_BYT
  JMP PRT_LF

; 8bit値を表示
PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

; 改行
PRT_LF:
  LDA #$A
  JMP PRT_C_CALL

; スペース印字
PRT_S:
  LDA #' '
  JMP PRT_C_CALL

; Aで与えられたバイト値をASCII値AYにする
; Aから先に表示すると良い
BYT2ASC:
  PHA           ; 下位のために保存
  AND #$0F
  JSR NIB2ASC
  TAY
  PLA
  LSR           ; 右シフトx4で上位を下位に持ってくる
  LSR
  LSR
  LSR
  JSR NIB2ASC
  RTS

; #$0?をアスキー一文字にする
NIB2ASC:
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

