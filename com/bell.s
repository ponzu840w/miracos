; -------------------------------------------------------------------
;                           Bellコマンド
; -------------------------------------------------------------------
; ジングルベルを鳴らす
; シンプルBGMの礎となる
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

; -------------------------------------------------------------------
;                           実行用ライブラリ
; -------------------------------------------------------------------
.INCLUDE "./+bell/ymzq/ymzq.s"

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

.macro bp
  JSR VB_OFF
  BRK
  NOP
.endmac

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
  loadAY16 NOTES
  JSR PLAY
  CLI

MAIN:
  BRA MAIN

; -------------------------------------------------------------------
;                          垂直同期割り込み
; -------------------------------------------------------------------
VBLANK:
TICK:
  LDA #'S'
  syscall CON_OUT_CHR
  ;LDA #1
  ;LDX #2
  ;LDY #3
  ;JMP BRK_VB
  tick_ymzq
  JMP (ZP_VB_STUB)            ; 片付けはBCOSにやらせる

NOTES:
  .BYTE 40,3
  .BYTE 41,6
  .BYTE 42,3
  .BYTE 43,6
  .BYTE 44,6
  .BYTE 45,6
  .BYTE 46,6
  .BYTE 47,6
  .BYTE 48,6

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
