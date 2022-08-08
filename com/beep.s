; -------------------------------------------------------------------
;                           BEEPコマンド
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
  TMP_MIX:          .RES 1
  TMP_SHAPE:        .RES 1

; -------------------------------------------------------------------
;                               マクロ
; -------------------------------------------------------------------
.macro setSound frq,efeq,shape,mix
  ; 音は出さない
  ; ミキシング設定
  LDA #YMZ_INNADDR_MIX
  LDX #%00111111
  JSR SET_YMZREG
  LDA #mix
  STA TMP_MIX
  ; 音階上位
  LDA #YMZ_INNADDR_FRQ+1
  LDX #>(125000/frq)
  JSR SET_YMZREG
  ; 音階下位
  LDA #YMZ_INNADDR_FRQ
  LDX #<(125000/frq)
  JSR SET_YMZREG
  ; エンベ上位
  LDA #YMZ_INNADDR_EVLP_FRQ+1
  LDX #>(244000/efrq)
  JSR SET_YMZREG
  ; エンベ下位
  LDA #YMZ_INNADDR_EVLP_FRQ
  LDX #<(244000/efrq)
  JSR SET_YMZREG
  ; 形状
  LDA #shape
  STA TMP_SHAPE
.endmac
; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; 音を鳴らす
  ; キー待機
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
  syscall CON_RAWIN
  RTS

POYO:
  setSound 300,700,$E,$FE
  JSR SOUND
  RTS

SOUND:
  LDA #YMZ_INNADDR_MIX
  LDX TMP_MIX
  JSR SET_YMZREG
  LDA #YMZ_INNADDR_EVLP_SHAPE
  LDX TMP_SHAPE
  JSR SET_YMZREG
  RTS

