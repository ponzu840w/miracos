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
  .WORD EM_FAILED_CLOSE
  .WORD EM_FAILED_OPEN
  .WORD EM_FILE_EXISTS
  .WORD EM_BROKEN_FD
  .WORD EM_DIR_NOT_EMPTY
  .WORD EM_ILLEGAL_ATTR
  .WORD EM_ILLEGAL_ARG

ERROR_MES:
EM_DRV_NOT_FOUND:             .BYT "Drive Not Found.",$0
EM_ILLEGAL_PATH:              .BYT "Illegal Path.",$0
EM_FILE_NOT_FOUND:            .BYT "File Not Found.",$0
EM_NOT_DIR:                   .BYT "Not Dir.",$0
EM_FAILED_CLOSE:              .BYT "Failed to CLOSE.",$0
EM_FAILED_OPEN:               .BYT "Failed to OPEN.",$0
EM_FILE_EXISTS:               .BYT "File Exists.",$0
EM_BROKEN_FD:                 .BYT "Broken FD.",$0
EM_DIR_NOT_EMPTY:             .BYT "Dir not empty.",$0
EM_ILLEGAL_ATTR:              .BYT "Illegal Attr.",$0
EM_ILLEGAL_ARG:               .BYT "Illegal Arg.",$0

STR_ERROR:                    .BYT "[BCOSERR] ",$0

