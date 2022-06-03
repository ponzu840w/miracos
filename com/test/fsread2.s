; -------------------------------------------------------------------
;                           FSREAD2コマンド
; -------------------------------------------------------------------
; 新しいリードファンクションのテスト用
; 実装されたら動かなくなるかも
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../zr.inc"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                             定数定義
; -------------------------------------------------------------------
LENGTH  = 1
BFPTR   = BUFFER

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO
  FCTRL_SAV:      .RES 2

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; 挨拶
  loadAY16 STR_HELLO
  syscall CON_OUT_STR
  ; ファイル検索
  loadAY16 PATH_DATA
  syscall FS_FIND_FST             ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  ; ファイルオープン
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
  ; ファイル記述子の報告
  loadAY16 STR_GOT_FD
  syscall CON_OUT_STR
  LDA FD_SAV
  JSR PRT_BYT
  JSR PRT_LF
  ; コール
  LDA FD_SAV
  STA ZR1
  loadmem16 ZR0,BUFFER
  loadAY16 1
  syscall FS_READ_BYTS2
  storeAY16 FCTRL_SAV
  ; FCTRL表示
  ; FCTRL_SIZラベル
  loadAY16 STR_FCTRL_SIZ
  syscall CON_OUT_STR
  ; FCTRL_SIZ
  LDA #FCTRL::SIZ
  ADC FCTRL_SAV
  LDY FCTRL_SAV+1
  JSR PRT_LONG_LF
  ; FCTRL_SEEKラベル
  loadAY16 STR_FCTRL_SEEK
  syscall CON_OUT_STR
  ; FCTRL_SEEK
  LDA #FCTRL::SEEK_PTR
  ADC FCTRL_SAV
  LDY FCTRL_SAV+1
  JSR PRT_LONG_LF
  RTS

NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  RTS

PRT_LONG_LF:
  JSR PRT_LONG
  JMP PRT_LF

PRT_LONG:
  storeAY16 ZR2
  LDY #3
@LOOP:
  LDA (ZR2),Y
  PHY
  JSR PRT_BYT
  PLY
  DEY
  BPL @LOOP
  RTS

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

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0
STR_FILE:
  .BYT "File:",$0
STR_EOF:
  .BYT "[EOF]",$0

PATH_DATA:
  .ASCIIZ "A:/TEST.TXT"

STR_HELLO:      .BYT "New FS_READ syscall dev tool",$A,$0
STR_GOT_FD:     .BYT "File Descriptor:",$0
STR_FCTRL_SIZ:  .BYT "FCTRL_SIZE:",$0
STR_FCTRL_SEEK:  .BYT "FCTRL_SEEK:",$0


BUFFER:

