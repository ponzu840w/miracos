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

; YMZ294
YMZ_BASE = $E400
YMZ_ADDR = YMZ_BASE
YMZ_DATA = YMZ_BASE+1

; --- 定数定義 ---
; YMZ294内部アドレス
; 各チャンネル周波数
YMZ_INNADDR_FRQ = $00
; ノイズ音周波数
YMZ_INNADDR_NOISE_FRQ = $06
; ミキサ設定
YMZ_INNADDR_MIX = $07
; 各チャンネル音量
YMZ_INNADDR_VOL = $08
; エンベロープ周波数
YMZ_INNADDR_EVLP_FRQ = $0B
; エンベロープ形状
YMZ_INNADDR_EVLP_SHAPE = $0D

; -------------------------------------------------------------------
;                               変数領域
; -------------------------------------------------------------------
.BSS
  TMP_MIX:          .RES 1
  TMP_SHAPE:        .RES 1
  TMP_VOL:          .RES 1

; -------------------------------------------------------------------
;                               マクロ
; -------------------------------------------------------------------
.macro setSound frq,efrq,shape,mix,vol
  ; 音は出さない
  ; ミキシング設定
  LDA #YMZ_INNADDR_MIX
  LDX #%00111111
  JSR SET_YMZREG
  LDA mix
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
  LDA shape
  STA TMP_SHAPE
  ; 音量
  LDA vol
  STA TMP_VOL
.endmac
; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; 音を鳴らす
  JSR POYO
  ; キー待機
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
  syscall CON_RAWIN
  JSR SILENT
  RTS

SILENT:
  setSound 1,1,1,1,0
  JSR SOUND
  RTS

POYO:
  setSound 300,700,#$E,#$FE,#$0F
  JSR SOUND
  RTS

SOUND:
  LDA #YMZ_INNADDR_MIX
  LDX TMP_MIX
  JSR SET_YMZREG
  LDA #YMZ_INNADDR_EVLP_SHAPE
  LDX TMP_SHAPE
  JSR SET_YMZREG
  LDA #YMZ_INNADDR_VOL
  LDX TMP_VOL
  JSR SET_YMZREG
  RTS

; *
; --- 内部レジスタに値を格納する ---
; データをA、内部アドレスをXに格納しておくこと
; この通り呼ぶ意味はあまりない
; *
SET_YMZREG:
  STA YMZ_ADDR
  STX YMZ_DATA
  RTS

