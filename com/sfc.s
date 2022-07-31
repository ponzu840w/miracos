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
ZP_ATTR:          .RES 1

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
  ; 双方下げる
  LDA VIA::PAD_REG
  AND #<~(VIA::PAD_CLK|VIA::PAD_PTS)
  STA VIA::PAD_REG
  ; 双方上げる
  LDA VIA::PAD_REG
  ORA #VIA::PAD_CLK|VIA::PAD_PTS
  STA VIA::PAD_REG
  ; 双方下げる
  LDA VIA::PAD_REG
  AND #<~(VIA::PAD_CLK|VIA::PAD_PTS)
  STA VIA::PAD_REG
  ; B読み取り
  LDA VIA::PAD_REG
  BIT #VIA::PAD_DAT
  BEQ TMP
  LDA #'b'
  BRA TMP2
TMP:
  LDA #'B'
TMP2:
  syscall CON_OUT_CHR
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

