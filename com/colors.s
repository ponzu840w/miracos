; -------------------------------------------------------------------
;                            COLORS.COM
; -------------------------------------------------------------------
; 色一覧
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                               定数
; -------------------------------------------------------------------
BOX_WIDTH   = (256/2)/4
BOX_HEIGHT  = 192/4

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_COLOR:                 .RES 1
  ZP_CANVAS_Y:              .RES 1
  ZP_X:                     .RES 1
  ZP_Y:                     .RES 1
  ZP_CNT_X:                 .RES 1
  ZP_CNT_Y:                 .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
  ; ---------------------------------------------------------------
  ;   CRTC
  LDA #%00000001            ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ有効
  STA CRTC::CFG
  LDA #%01010101            ; フレームバッファ1
  STA CRTC::RF              ; FB1を表示
  STA CRTC::WF              ; FB1を書き込み先に
  ; ---------------------------------------------------------------
  ;   画面の初期化
  LDA #$00
  JSR FILL
  ; ---------------------------------------------------------------
  ;   描画
  STZ ZP_COLOR
  STZ ZP_X
  STZ ZP_Y
  LDA #4
  STA ZP_CNT_X
  STA ZP_CNT_Y
LOOP:
  LDX ZP_X
  LDY ZP_Y
  LDA ZP_COLOR
  JSR DRAW_BOX
  ; 位置を進める
  LDA #BOX_WIDTH
  CLC
  ADC ZP_X
  STA ZP_X
  DEC ZP_CNT_X
  BNE @SKP_INC_Y
  ; Y進め
  LDA #4
  STA ZP_CNT_X
  LDA #BOX_HEIGHT
  CLC
  ADC ZP_Y
  STA ZP_Y
  DEC ZP_CNT_Y
  BEQ END
@SKP_INC_Y:
  ;; ---------------------------------------------------------------
  ;;   キー入力待機
  ;LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho
  ;syscall CON_RAWIN
  ; 色を進める
  LDA #$11
  CLC
  ADC ZP_COLOR
  STA ZP_COLOR
  ;CMP #$FF
  BRA LOOP
END:
  ; ---------------------------------------------------------------
  ;   キー入力待機
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho
  syscall CON_RAWIN
  RTS

; 指定色で正方形領域を塗りつぶす
; X,Yがそのまま座標
DRAW_BOX:
  PHA
  TYA
  CLC
  ADC #BOX_HEIGHT
  STA ZP_CANVAS_Y
  PLA
DRAW_SQ_LOOP:
  STX CRTC::VMAH
  STY CRTC::VMAV
  .REPEAT BOX_WIDTH
  STA CRTC::WDBF
  .ENDREPEAT
  INY
  CPY ZP_CANVAS_Y
  BNE DRAW_SQ_LOOP
  RTS

; 画面全体をAの値で埋め尽くす
FILL:
  LDY #$00
  STY CRTC::VMAV
  STY CRTC::VMAH
  LDY #$C0
FILL_LOOP_V:
  LDX #$80
FILL_LOOP_H:
  STA CRTC::WDBF
  DEX
  BNE FILL_LOOP_H
  DEY
  BNE FILL_LOOP_V
  RTS

