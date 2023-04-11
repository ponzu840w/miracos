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

.macro bp
  JSR VB_OFF
  BRK
  NOP
.endmac


; -------------------------------------------------------------------
;                           実行用ライブラリ
; -------------------------------------------------------------------
.INCLUDE "./+bell/ymzq.s"

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
  loadAY16 TEST_NOTE1
  JSR PLAY

  LDX #1
  loadAY16 TEST_NOTE2
  JSR PLAY
  CLI

MAIN:
  BRA MAIN

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

NOISE_NOTES:
.BYTE 128+1,2
.BYTE 128+2,0   ; ノイズ
.BYTE 128+5     ; ノイズ有効化
.BYTE 50,1
.BYTE 128,2
.BYTE 128+2,0   ; ノイズ
.BYTE 128+4     ; ノイズ有効化
.BYTE 50,4
.BYTE 128,4
.BYTE 128+3     ; bra
.WORD .LOWORD(NOISE_NOTES-*-1)

NOTES:
.BYTE 128+1,10
.BYTE 128+2,2   ; ビブラート

NOTE1:
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

.BYTE 128+1,10
.BYTE 128+2,1   ; ピアノ

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

.BYTE 128+2,2   ; ビブラート

NOTE2:
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

.BYTE 128+2,1   ; ピアノ
.BYTE 128+1,10

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

.BYTE 128+3
.WORD .LOWORD(NOTES-*-1)

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
