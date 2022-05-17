; -------------------------------------------------------------------
; PS2TESTコマンド
; -------------------------------------------------------------------
; ps2drvのテストプログラム
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

.CODE
  JMP TEST

.PROC PS2
    .INCLUDE "../ps2/ps2drv.s"
  .SEGMENT "BSS"
    .INCLUDE "../ps2/varps2.s"
.ENDPROC

.CODE
TEST:
  ; テストアプリケーション
  JSR PS2::INIT
LOOP:
  JSR PRT_LF      ; 改行
  JSR PS2::GET
  JSR PRT_BYT
  BRA LOOP
;  JSR PS2::INIT    ; キーボード、LED、フラグの初期化
;@LF:
;  JSR PRT_LF      ; 改行
;@IN:
;  JSR PS2::IN     ; キー押下を待って、でコードされたアスキーをAに格納
;  CMP #$0A        ; LFなら改行
;  BEQ @LF
;  CMP #$1B        ; ESC
;  BEQ @ESC
;  CMP #$20        ; Control
;  BCC @HEX
;  CMP #$80        ; 拡張キー
;  BCS @HEX
;  JSR PRT_CHR     ; 普通の文字を表示
;  BRA @IN
;@ESC:
;  RTS
;@HEX:
;  PHA
;  LDA #'<'
;  JSR PRT_CHR
;  PLA
;  JSR PRT_BYT
;  LDA #'>'
;  JSR PRT_CHR
;  BRA @IN

PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

PRT_S:
  ; スペース
  LDA #' '
  JMP PRT_C_CALL

BYT2ASC:
  ; Aで与えられたバイト値をASCII値AYにする
  ; Aから先に表示すると良い
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

NIB2ASC:
  ; #$0?をアスキー一文字にする
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

