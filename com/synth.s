; -------------------------------------------------------------------
;                           SYNTHコマンド
; -------------------------------------------------------------------
; YMZ
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
;                               変数領域
; -------------------------------------------------------------------
.BSS
  VOL_A:            .RES 1
  VOL_B:            .RES 1
  VOL_C:            .RES 1
  FRQ_A:            .RES 2
  FRQ_B:            .RES 2
  FRQ_C:            .RES 2
  CURRENT_CH:       .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; 起動メッセージ
  loadAY16 STR_HELLO
  syscall CON_OUT_STR
  ; 音を鳴らす
  JSR POYO
  ; キー待機
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
  syscall CON_RAWIN
  JSR SILENT
  RTS

PRT_PROMPT:
  ; プロンプトを表示
  RTS

; *
; --- 内部レジスタに値を格納する ---
; データをA、内部アドレスをXに格納しておくこと
; この通り呼ぶ意味はあまりない
; *
SET_YMZREG:
  STA YMZ::ADDR
  STX YMZ::DATA
  RTS

STR_HELLO: .BYT "PSG:Programmable Sound Generator",$A,"YMZ294 Sound Playground.",$A,$0

