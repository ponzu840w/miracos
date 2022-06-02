; -------------------------------------------------------------------
;                           COLORコマンド
; -------------------------------------------------------------------
; GCHRの色を変更する
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
  loadAY16 STR_COLOR_START
  syscall CON_OUT_STR                 ; 説明文
@LOOP:
  LDA #2
  syscall CON_RAWIN                   ; コマンド入力
@J:
  CMP #'j'
  BNE @K
  LDA #0
  JSR @GET
  DEY
  LDA #2
  JSR @PUT
  BRA @LOOP
@K:
  CMP #'k'
  BNE @H
  LDA #0
  JSR @GET
  INY
  LDA #2
  JSR @PUT
  BRA @LOOP
@H:
  CMP #'h'
  BNE @L
  LDA #1
  JSR @GET
  DEY
  LDA #3
  JSR @PUT
  BRA @LOOP
@L:
  CMP #'l'
  BNE @ENT
  LDA #1
  JSR @GET
  INY
  LDA #3
  JSR @PUT
@ENT:
  CMP #$A
  BNE @LOOP
  ;JSR PRT_LF
  LDA #$A
  syscall CON_OUT_CHR
  RTS
@GET:
  syscall GCHR_COL
  TAY
  RTS
@PUT:
  syscall GCHR_COL
  RTS

STR_COLOR_START:  .BYT "Console Color Setting.",$A,"j,k  : Character",$A,"h,l  : Background",$A,"ENTER: Complete",$0

