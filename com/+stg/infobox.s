INFO_TOP_MARGIN = 2
INFO_RL_MARGIN = 2

; -------------------------------------------------------------------
;                              スコア描画
; -------------------------------------------------------------------
.macro draw_score
  ; [0]000
  LDA ZP_SCORE+1
  LSR
  LSR
  LSR
  LSR
  CLC
  ADC #'0'
  STA SCORE_STR
  ; 0[0]00
  LDA ZP_SCORE+1
  AND #$0F
  CLC
  ADC #'0'
  STA SCORE_STR+1
  ; 00[0]0
  LDA ZP_SCORE
  LSR
  LSR
  LSR
  LSR
  CLC
  ADC #'0'
  STA SCORE_STR+2
  ; 000[0]
  LDA ZP_SCORE
  AND #$0F
  CLC
  ADC #'0'
  STA SCORE_STR+3
  STZ SCORE_STR+4
  str88_puts 1+(4*6),2,SCORE_STR
.endmac

; -------------------------------------------------------------------
;                              残機描画
; -------------------------------------------------------------------
; 塗りつぶしてから、左から一機一機描いていく
; NOTE:増減のたびにやるのは非効率ではある
.macro draw_zanki
  ; エリアを黒で塗りつぶす
  ; 座標設定
  LDX #128-(4*ZANKI_MAX)-(INFO_RL_MARGIN/2)
  LDY #INFO_TOP_MARGIN
  ; 色設定
  LDA #BGC
  STX CRTC2::PTRX
  STY CRTC2::PTRY
  LDX #ZANKI_MAX
@FILL_LOOP:
  STA CRTC2::WDAT
  .REPEAT 32-1
  LDY CRTC2::REPT
  .ENDREP
  DEX
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
  STA ZP_INFOBOX_WORK
  BBS0 ZP_INFOBOX_WORK,@ZANKI
  JMP @SCORE
@ZANKI:
  draw_zanki
@SCORE:
  BBR1 ZP_INFOBOX_WORK,@END
  draw_score
@END:
  RTS

