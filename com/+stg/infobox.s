INFO_TOP_MARGIN = 2
INFO_RL_MARGIN = 2

; -------------------------------------------------------------------
;                              残機描画
; -------------------------------------------------------------------
.macro draw_zanki
  ; エリアを黒で塗りつぶす
  LDX #128-(4*ZANKI_MAX)-(INFO_RL_MARGIN/2)
  LDY #INFO_TOP_MARGIN
  LDA #BGC
@FILL_LOOP:
  STX CRTC::VMAH
  STY CRTC::VMAV
  .REPEAT ZANKI_MAX*4
  STA CRTC::WDBF
  .ENDREP
  INY
  CPY #INFO_TOP_MARGIN+8
  BNE @FILL_LOOP
  ; 残機画像
  loadmem16 ZP_CHAR_PTR,CHAR_DAT_ZIKI
  LDA #256-INFO_TOP_MARGIN-8
  STA ZP_CANVAS_X
  LDA #INFO_TOP_MARGIN
  STA ZP_CANVAS_Y
  JSR DRAW_CHAR8
.endmac

; -------------------------------------------------------------------
;                          INFOBOXティック
; -------------------------------------------------------------------
.macro tick_infobox
  ; セカンダリから処理
  LDA ZP_INFO_FLAG_S
  JSR DRAW_INFO_LIST
  ; プライマリも処理
  LDA ZP_INFO_FLAG_P
  JSR DRAW_INFO_LIST
  ; プライマリをセカンダリに移管
  LDA ZP_INFO_FLAG_P
  STA ZP_INFO_FLAG_S
  ; プライマリを初期化
  STZ ZP_INFO_FLAG_P
.endmac

; -------------------------------------------------------------------
;                         フラグに従って描画
; -------------------------------------------------------------------
DRAW_INFO_LIST:
  STA ZR0
  BBR0 ZR0,@SKP_ZANKI
  draw_zanki
@SKP_ZANKI:
  RTS

