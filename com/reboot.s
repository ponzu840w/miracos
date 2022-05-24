; -------------------------------------------------------------------
;                         REBOOTコマンド
; -------------------------------------------------------------------
; ハードリセット！
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
  loadAY16 STR_HELLO
  syscall CON_OUT_STR
  JMP ($FFFC)
  RTS

STR_HELLO: .BYT "Rebooting...",$A,$0

