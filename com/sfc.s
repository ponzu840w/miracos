; -------------------------------------------------------------------
;                           RDSFCコマンド
; -------------------------------------------------------------------
; パッド状態表示テスト
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.INCLUDE "../zr.inc"

; -------------------------------------------------------------------
;                             ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
ZP_PADSTAT:          .RES 2

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ポートの設定
  LDA VIA::PAD_DDR         ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  ; 双方上げる
  LDA VIA::PAD_REG
  ORA #VIA::PAD_CLK|VIA::PAD_PTS
  STA VIA::PAD_REG
  ; P/S下げる
  LDA VIA::PAD_REG
  AND #<~VIA::PAD_PTS
  STA VIA::PAD_REG
  ; 読み取りループ
  LDX #16
LOOP:
  LDA VIA::PAD_REG        ; データ読み取り
  ; クロック下げる
  AND #<~VIA::PAD_CLK
  STA VIA::PAD_REG
  ; 16bit値として格納
  ROR
  ROL ZP_PADSTAT+1
  ROL ZP_PADSTAT
  ; クロック上げる
  LDA VIA::PAD_REG        ; データ読み取り
  ORA #VIA::PAD_CLK
  STA VIA::PAD_REG
  DEX
  BNE LOOP
  ; 状態表示
  LDX #8
  LDA ZP_PADSTAT
  PHA
LOOP2:
  PLA
  ROL
  PHA
  LDA #'0'
  BCC NOTSET              ; キャリーに含んだデータによって'1'にINCする否か分岐
SET:
  INC
NOTSET:
  PHX
  syscall CON_OUT_CHR
  PLX
  DEX
  BNE LOOP2
  PLA
  JSR PRT_LF
  BRA START
  RTS

; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

PRT_S:
  ; スペース
  LDA #' '
  ;JMP PRT_C_CALL
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

STR_ATTR: .BYT  "advshr"

