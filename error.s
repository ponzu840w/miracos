.INCLUDE "errorcode.inc"
; -------------------------------------------------------------------
;                         エラーを報告
; -------------------------------------------------------------------
; input   : A=EC
; エラーコードを受け取り、保存する。
; ジャンプしてくればすぐに戻れる
; デバッグ時にはここでトラップできる
; -------------------------------------------------------------------
REPORT:
  STA LAST_ERROR
  SEC
  RTS

; -------------------------------------------------------------------
;                         エラーを取得
; -------------------------------------------------------------------
; -------------------------------------------------------------------
FUNC_ERR_GET:
  LDA LAST_ERROR
  RTS

; -------------------------------------------------------------------
;                          エラーを表示
; -------------------------------------------------------------------
; input   : A=EC
; エラーコードに対応するメッセージを表示する
; -------------------------------------------------------------------
FUNC_ERR_MES:
  ASL
  TAX
  PHX
  loadAY16 STR_ERROR
  JSR FUNC_CON_OUT_STR
  PLX
  LDA ERROR_MES_TABLE,X
  LDY ERROR_MES_TABLE+1,X
  JSR FUNC_CON_OUT_STR
  LDA #$A
  JSR FUNC_CON_OUT_CHR
  RTS

ERROR_MES_TABLE:
  .WORD EM_DRV_NOT_FOUND
  .WORD EM_ILLEGAL_PATH
  .WORD EM_FILE_NOT_FOUND
  .WORD EM_NOT_DIR

ERROR_MES:
EM_DRV_NOT_FOUND:             .BYT "Drive Not Found.",$0
EM_ILLEGAL_PATH:              .BYT "Illegal Path.",$0
EM_FILE_NOT_FOUND:            .BYT "File Not Found.",$0
EM_NOT_DIR:                   .BYT "Not Directory.",$0
EM_FAILED_CLOSE:              .BYT "Failed to CLOSE.",$0
EM_FAILED_OPEN:               .BYT "Failed to OPEN.",$0

STR_ERROR:                    .BYT "[BCOSERR] ",$0

