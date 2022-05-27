; -------------------------------------------------------------------
; VBLKTESTコマンド
; -------------------------------------------------------------------
; 垂直同期割り込みをコマンドルーチンにもお届け
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
;                             変数領域
; -------------------------------------------------------------------
.BSS
VB_STUB:          .RES 2  ; 割り込み終了処理
COUNTER:          .RES 1  ; カウンタ

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ;割り込みハンドラの登録
  SEI
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 VB_STUB
  CLI
LOOP:
  LDA COUNTER
  BNE LOOP                ; 非ゼロならスキップ
  ; カウンタがゼロ
  LDA #'!'
  syscall CON_OUT_CHR
  LDA #60
  STA COUNTER
  BRA LOOP
  RTS

; 垂直同期割り込み処理
VBLANK:
  LDA COUNTER
  BEQ @EXT                ; ゼロならスルー
  ; カウンタがゼロでない
  DEC COUNTER
@EXT:
  JMP (VB_STUB)           ; 片付けはBCOSにやらせる

