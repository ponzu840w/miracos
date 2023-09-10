.IMPORT popa, popax
.IMPORTZP sreg

.EXPORT _disp
.EXPORT _gcls
.EXPORT _gput
.EXPORT _rect
.EXPORT _box
.EXPORT _plot
.EXPORT _gcls
.EXPORT _col
.EXPORT _gr

.ZEROPAGE

ZP_GR:        .RES 1
ZP_COLOR:     .RES 1
ZP_BAKCOL:    .RES 1
ZP_FD:        .RES 1  ; ファイル記述子
ZP_TXTPTR:    .RES 2
ZX1:          .RES 1
ZY1:          .RES 1
ZX2:          .RES 1
ZY2:          .RES 1
ZDX:          .RES 1
ZDY:          .RES 1
ZP_FONT_VEC16:  .RES 2
ZP_FONT_SR:   .RES 2

.CODE

CHDZ_BASIC_INIT:
  ; カーネルアドレス奪取
  LDY #BCOS::BHY_GET_ADDR_font2048    ; FONT
  syscall GET_ADDR
  STY DRAW_TXT_LOOP+1
  RTS

; -------------------------------------------------------------------
; DISP ステートメント
; 用法: disp(unsigned char display_number);
; 表示画面を変更する
; -------------------------------------------------------------------
.PROC _disp
  STA CRTC2::DISP
  RTS
.ENDPROC

; -------------------------------------------------------------------
; GR ステートメント
; 用法: gr(unsigned char display_number);
; グラフィック書き込み画面を選択する
; GR 0は可能だが推奨されない
; -------------------------------------------------------------------
_gr:
  AND #%00000011
  ORA #CRTC2::WF
  STA ZP_GR
  RTS

; -------------------------------------------------------------------
; 画面上2座標の引数指定を取得、X1Y1をCRTCに設定
; NOTE:タートル機能をつけるなら、ここでX2Y2を記憶すればいい
; -------------------------------------------------------------------
GET_SCREEN_XYXY:
  ; 終点座標を取得
  STA ZY2
  JSR popa
  STA ZX2
  ; 始点座標を取得
  JSR popa
  STA ZY1
  JSR popa
  STA ZX1
  ; X1<X2
@X_DIFF:
  LDX ZX2
  TXA                 ; X=X2
  SEC
  SBC ZX1          ; X2-X1
  STA ZDX          ; 差を格納
  BCS @SKP_XSWP
  ; X2<X1であるときのスワップ
  LDA ZX1
  STX ZX1
  STA ZX2
  TAX
  BRA @X_DIFF
@SKP_XSWP:
  ; Y1<Y2
@Y_DIFF:
  LDY ZY2
  TYA                 ; Y=Y2
  SEC
  SBC ZY1          ; Y2-Y1
  STA ZDY          ; 差を格納
  BCS RET
  ; Y2<Y1であるときのスワップ
  LDA ZY1
  STY ZY1
  STA ZY2
  TAY
  BRA @Y_DIFF

SET_PTR_X1Y1:
  ; 大抵の場合、X1Y1をセットする
  LDX ZX1
  STX CRTC2::PTRX
  LDX ZY1
  STX CRTC2::PTRY
  RTS

; -------------------------------------------------------------------
; COL ステートメント
; 用法: COL [aexpr][,aexpr]
; 前景色と背景色を設定する
; -------------------------------------------------------------------
_col:
  STA ZP_BAKCOL
  JSR popa
  STA ZP_COLOR
RET:
  RTS

; -------------------------------------------------------------------
; GCLS ステートメント
; -------------------------------------------------------------------
.PROC _gcls
  JSR GRA_SETUP
  LDX #%10000000      ; chrboxoff
  STX CRTC2::CHRW
  STZ CRTC2::PTRX     ; 原点セット
  STZ CRTC2::PTRY
  LDA ZP_BAKCOL
  LDY #192
@VLOOP:
  LDX #128
@HLOOP:
  STA CRTC2::WDAT
  DEX
  BNE @HLOOP
  DEY
  BNE @VLOOP
  BRA END_PLOT
.ENDPROC

; -------------------------------------------------------------------
; BOX ステートメント
; -------------------------------------------------------------------
.PROC _box
  JSR GET_SCREEN_XYXY ; 2点座標を取得
  JSR GRA_SETUP       ; グラフィクス画面への書き込みを設定
  LDA #255            ; 次CHR送りをしない
  STA CRTC2::CHRH
  JSR SET_PTR_X1Y1
  ; 色設定
  LDA ZP_COLOR
  ; 上部横線
  JSR @YOKO
  ; 右縦線
  STZ CRTC2::CHRW     ; キャラクタボックス有効、幅1
  LDX ZX2          ; chrboxカウンタ更新のためにXを再設定せざるを得ない
  STX CRTC2::PTRX
  LDX ZDY
  JSR BOX_LOOP
  ; 左縦線
  JSR SET_PTR_X1Y1    ; 座標再設定
  LDX ZDY
  JSR BOX_LOOP
  ; 下部横線
  JSR @YOKO
  BRA END_PLOT
@YOKO:
  LDX #%10000000      ; chrboxoff
  STX CRTC2::CHRW
  LDX ZDX
  INX
BOX_LOOP:
  ; 直前にゼロフラグが設定されるのが前提
  BEQ @RTS
@DX_LOOP:
  STA CRTC2::WDAT
  DEX
  BNE @DX_LOOP
@RTS:
  RTS
.ENDPROC

; -------------------------------------------------------------------
; PLOT ステートメント
; 用法: plot(unsigned char x, unsigned char y)
; 指定されたX,Y座標に前景色で点を打つ
; -------------------------------------------------------------------
_plot:
  ;JSR GET_SCREEN_XY
  PHA
  JSR popa
  TAX
  PLY
  JSR GRA_SETUP       ; グラフィクス画面への書き込みを設定
  STX CRTC2::PTRX     ; 水平座標設定
  STY CRTC2::PTRY     ; 垂直座標設定
  LDA ZP_COLOR
  STA CRTC2::WDAT     ; データ書き込み
END_PLOT:             ; 汎用的お片付け
  LDA #7
  STA CRTC2::CHRH     ; 高さ8
  LDA #CRTC2::WF      ; テキスト画面への書き込みを設定
  STA CRTC2::CONF
  STZ CRTC2::CHRW     ; キャラクタボックス有効、幅1
  RTS

; -------------------------------------------------------------------
; RECT ステートメント
; -------------------------------------------------------------------
.PROC _rect
  JSR GET_SCREEN_XYXY ; 2点座標を取得
  JSR GRA_SETUP       ; グラフィクス画面への書き込みを設定
  JSR SET_PTR_X1Y1
  LDX ZDX          ; Xの幅をchrboxに
  STX CRTC2::CHRW
  LDY ZDY          ; Yの幅をchrboxに
  STY CRTC2::CHRH
  ; 色設定
  LDA ZP_COLOR
  INY                 ; DY=0でも1行
@VLOOP:
  LDX ZDX
  INX                 ; DX=0でも1回
@HLOOP:
  STA CRTC2::WDAT
  DEX
  BNE @HLOOP
  DEY
  BNE @VLOOP
  BRA END_PLOT
.ENDPROC

; -------------------------------------------------------------------
; GPUT ステートメント
; 用法: gput(unsigned char x, unsigned char y, unsigned char* str);
; グラフィック画面に文字列を印字する
; PRINTに準ずる
; -------------------------------------------------------------------
.PROC _gput
  storeAX16 ZP_TXTPTR
  JSR popa
  STA CRTC2::PTRY     ; 垂直座標設定
  JSR popa
  STA CRTC2::PTRX     ; 水平座標設定
  ;JSR CHRGET          ; 歩を進める
  JSR GRA_SETUP       ; グラフィクス画面への書き込みを設定
  LDA #7
  STA CRTC2::CHRH     ; 高さ8
  LDA #3
  STA CRTC2::CHRW     ; キャラクタボックス有効、幅1
  LDY #0
@LOOP:
  LDA (ZP_TXTPTR),Y
  BEQ END_PLOT
  PHY
  JSR GR_OUT_CHR
  PLY
  INY
  BRA @LOOP
.ENDPROC

; -------------------------------------------------------------------
; グラフィックス画面への書き込みを設定
; -------------------------------------------------------------------
GRA_SETUP:
_gra_setup:
  LDA ZP_GR
  STA CRTC2::CONF
GRA_SETUP_RTS:
  RTS

; グラフィック画面に文字を表示する
GR_OUT_CHR:
  ; ---------------------------------------------------------------
  ;   例外処理
  CMP #$A
  BEQ GRA_SETUP_RTS
  ; ---------------------------------------------------------------
  ;   フォント参照ベクタ作成
DRAW_TXT_LOOP:
  LDX #0                    ; #0はスタブ、initで書き換わる
  STX ZP_FONT_VEC16+1
  STZ ZP_FONT_SR            ; フォントあぶれ初期化
.REPEAT 3
  ASL                       ; 8倍してあぶれた分を格納
  ROL ZP_FONT_SR
.ENDREP
  STA ZP_FONT_VEC16         ; 8倍した結果をフォント参照下位に
  LDA ZP_FONT_SR            ; 桁あぶれを
  ADC ZP_FONT_VEC16+1       ;   加算、キャリーは最後のROLにより0
  STA ZP_FONT_VEC16+1
  ; ---------------------------------------------------------------
  ;   CRTCにデータを出力
  LDY #0                    ; フォント参照インデックス
@VLOOP:
  LDA (ZP_FONT_VEC16),Y     ; フォントデータ取得
  STA ZP_FONT_SR
  LDX #4                    ; 水平方向ループカウンタ
@HLOOP:
  JSR @COL_OR_BACK
  AND #%11110000
  STA ZR0                   ; ZR0:色データバイト
  JSR @COL_OR_BACK
  AND #%00001111
  ORA ZR0
  STA CRTC2::WDAT           ; 色データ書き込み
  DEX
  BNE @HLOOP
  INY
  CPY #8
  BNE @VLOOP
  RTS

@COL_OR_BACK:
  ASL ZP_FONT_SR
  LDA ZP_COLOR
  BCS @COL
  LDA ZP_BAKCOL
@COL:
  RTS

