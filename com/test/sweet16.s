; -------------------------------------------------------------------
; SWEET16
; -------------------------------------------------------------------
; SWEET16のテスト
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

.INCLUDE "../sweet16.s"

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_PTR: .RES 2

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  loadAY16 STR_HELLO
  syscall CON_OUT_STR
  loadAY16 $1234
  storeAY16 R0

  JSR SWEET16

  .SETCPU "sweet16"
  SET R1,$5678
  ST R2
  ADD R1
  ST R3
  LD R2
  SUB R1
  ST R4
  RTN
  .SETCPU "65C02"

  loadAY16 STR_TEST_ADD
  syscall CON_OUT_STR
  loadAY16 R3
  JSR PRT_REG
  JSR PRT_LF

  loadAY16 STR_TEST_SUB
  syscall CON_OUT_STR
  loadAY16 R4
  JSR PRT_REG
  JSR PRT_LF
  RTS

PRT_REG:
  storeAY16 ZP_PTR
  LDA #'$'
  syscall CON_OUT_CHR
  LDY #1
  LDA (ZP_PTR),Y
  JSR PRT_BYT
  LDA (ZP_PTR)
  JSR PRT_BYT
  RTS

PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

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

NIB2ASC:
  ; #$0?をアスキー一文字にする
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  BRA PRT_C_CALL

STR_HELLO:
  .BYTE "SWEET16 Virtual 16bit CPU TEST",$A,$0

STR_TEST_ADD:
  .BYTE "$1234 + $5678 = ",0

STR_TEST_SUB:
  .BYTE "$1234 - $5678 = ",0

