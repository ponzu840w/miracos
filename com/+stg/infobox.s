INFO_TOP_MARGIN = 2
INFO_RL_MARGIN = 2

; -------------------------------------------------------------------
;                              残機描画
; -------------------------------------------------------------------
; 塗りつぶしてから、左から一機一機描いていく
; NOTE:増減のたびにやるのは非効率ではある
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
  loadmem16 ZP_CHAR_PTR,CHAR_DAT_ZIKI ; 画像指定
  LDA ZP_ZANKI                        ; 残機数取得
  STA ZR1+1                           ; ZR1H=カウントダウン用
  INC ZR1+1
  LDA #256-INFO_TOP_MARGIN-8          ; 一匹目のX座標
  STA ZR1                             ; X座標保存
@ZANKI_LOOP:
  ; X座標指定
  STA ZP_CANVAS_X
  ; 脱出条件確認
  DEC ZR1+1
  BEQ @EXT_LOOP
  ; Y座標指定
  LDA #INFO_TOP_MARGIN
  STA ZP_CANVAS_Y
  JSR DRAW_CHAR8
  ; X座標更新
  LDA ZR1
  SEC
  SBC #8
  STA ZR1
  BRA @ZANKI_LOOP
@EXT_LOOP:
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
  BBS0 ZR0,@NOTSKP_ZANKI
  RTS
@NOTSKP_ZANKI:
  draw_zanki
  RTS

