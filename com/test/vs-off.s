; -------------------------------------------------------------------
; VS-OFFコマンド
; -------------------------------------------------------------------
; 垂直同期割り込みを無効化する
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  SEI
  LDA #%00000001                  ; bit 0はCA2
  STA VIA::IER
  CLI
  RTS

