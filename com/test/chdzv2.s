; -------------------------------------------------------------------
;                           ChDzVer2テスト
; -------------------------------------------------------------------
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

; ChDz
.PROC CRTC2
  CONF = CRTCBASE     ; コンフィグ
                          ;   MD0 MD1 MD2 MD3 - - WCMD WCUE
                          ;   MD    : 色モード選択（各内部行）
                          ;   WCMD  : 書き込み色モード 0:16色 1:2色
                          ;   WCUE  : 書き込みカウントアップ有効化
  WF = %00000000
  TT = %00010000
  T0 = %00100000
  T1 = %00110000
  REPT = CRTCBASE+$1  ; 連続書き込み

  PTRX = CRTCBASE+$2  ; VRAM書き込みアドレス下位
                          ;   - 6 5 4 3 2 1 0

  PTRY = CRTCBASE+$3  ; VRAM書き込みアドレス上位
                      ;   7 6 5 4 3 2 1 0

  WDAT = CRTCBASE+$4  ; 書き込みデータ

  DISP = CRTCBASE+$5  ; 出力フレーム選択
                      ;   (0) 1 0 | (1) 1 0 | (2) 1 0 | (3) 1 0

  CHRW = CRTCBASE+$6  ; 
                      ; 

  CHRH = CRTCBASE+$7  ; 
                      ; 
.ENDPROC

; -------------------------------------------------------------------
;                            ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
ZP_RND:         .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
  ; 設定
  LDA #0
  STA CRTC2::DISP
  LDA #(CRTC2::WF|%0000)
  STA CRTC2::CONF
  LDA #(CRTC2::TT|%0)
  STA CRTC2::CONF
  LDA #(CRTC2::T0|$0)
  STA CRTC2::CONF
  LDA #(CRTC2::T1|$3)
  STA CRTC2::CONF
  JSR CLS
  ; 矩形を描く
  LDA #8
  STA CRTC2::CHRW
  LDA #8
  STA CRTC2::CHRH
  LDA #50
  STA CRTC2::PTRX
  STA CRTC2::PTRY
  LDA #$88
  STA CRTC2::WDAT
  LDX #64
@LX1:
  LDA CRTC2::REPT
  DEX
  BNE @LX1
  JSR WAIT
  ; 二色モード
  LDA #(CRTC2::TT|1)
  STA CRTC2::CONF
  LDA #0
  STA CRTC2::CHRW
  LDA #7
  STA CRTC2::CHRH
  LDA #3
  STA CRTC2::PTRX
  LDA #100
  STA CRTC2::PTRY
@aaa:
  LDX #8
@TTLOOP:
  STX CRTC2::WDAT
  DEX
  BNE @TTLOOP
  JSR WAIT
  BRA @aaa
  JSR WAIT
  RTS

CLS:
  ; 画面を青でクリア
  LDA #(%10000000|0)  ; キャラクタボックス無効
  STA CRTC2::CHRW
  STZ CRTC2::CHRH
  STZ CRTC2::PTRX
  STZ CRTC2::PTRY
  LDA #$44
  STA CRTC2::WDAT
  LDY #192
@LY:
  LDX #(128/8)
@LX:
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  DEX
  BNE @LX
  DEY
  BNE @LY
  RTS

WAIT:
@INLOOP:
  INC ZP_RND
  LDA #$1                   ; エコーなし入力
  syscall CON_RAWIN
  BEQ @INLOOP
  RTS

