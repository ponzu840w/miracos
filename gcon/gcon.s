; 2色モードChDzによるコンソールモジュール
.INCLUDE "FXT65.inc"

PATH_FONT_DEFAULT:  .ASCIIZ "A:/MCOS/DAT/MIRAFONT.FNT"

INIT:
  ; コンソール画面の初期化
  ; フォントロードで使うのでファイルシステムモジュールが起動していること
  loadAY16 PATH_FONT_DEFAULT
  STZ ZR0
  JSR FS::FUNC_FS_OPEN        ; フォントファイルをオープン NOTE:ロードできたかを見るBP
  STA ZR1
  PHA
  loadmem16 ZR0,FONT2048      ; 書き込み先
  loadAY16  2048              ; 長さ
  JSR FS::FUNC_FS_READ_BYTS   ; ロード NOTE:ロードできたかを見るBP
  JSR GCHR::INIT
  PLA                         ; FD復帰
  JSR FS::FUNC_FS_CLOSE       ; クローズ
  STZ CURSOR_X
  LDA #23                     ; 最下行
  STA CURSOR_Y
  RTS

;TEST:
;@LOOP:
;  JSR FUNC_CON_IN_CHR
;  ;JSR SCROLL_DOWN
;  BRA @LOOP

BACK_CURSOR:
  LDA CURSOR_X
  BNE @SKP
  DEC CURSOR_Y
@SKP:
  DEC
  AND #%00011111        ; 0-31にマスク
  STA CURSOR_X
  RTS

PUTC:
  LDX #(CRTC2::WF|0)        ; 第0フレーム
  STX CRTC2::CONF
  ; コンソールに一文字表示する
  ; ---------------------------------------------------------------
  ;   改行コードの場合
  CMP #$A
  BNE @SKP_LF           ; 改行なら改行する
@NL:
  STZ CURSOR_X
  INC CURSOR_Y
  LDA CURSOR_Y
  ;CMP #25
  ;BNE @SKP_SCROLL
  JSR SCROLL_DOWN
  DEC CURSOR_Y
@SKP_SCROLL:
  JSR DISABLE_BOX
  RTS
@SKP_LF:
  ; ---------------------------------------------------------------
  ;   列がオーバーしている場合
  PHA
  LDA CURSOR_X
  CMP #32
  BNE @SKP_OVER_COLUMN
  JSR @NL               ; 改行
@SKP_OVER_COLUMN:
  PLA
  ; ---------------------------------------------------------------
  ;   バックスペースの場合
  CMP #$8
  BNE @SKP_BS           ; バックスペースなら1文字消す
  JSR BACK_CURSOR       ; カーソルを戻す
  LDA #' '              ; 一つ戻ってスペースを書き込む
  JSR PUTC
  JSR BACK_CURSOR       ; カーソルを戻す
  JSR DISABLE_BOX
  RTS
@SKP_BS:
  PHA
  ; ---------------------------------------------------------------
  ;   行がオーバーしている場合
  LDA CURSOR_Y
  CMP #24
  BNE @SKP_OVER
  STZ CURSOR_X
  DEC CURSOR_Y
  JSR SCROLL_DOWN
@SKP_OVER:
  ; ---------------------------------------------------------------
  ;   テキスト書き込みベクタ作成
  STZ ZP_FONT_SR
  STZ ZP_TRAM_VEC16
  LDA CURSOR_Y
.REPEAT 3
  LSR
  ROR ZP_FONT_SR
.ENDREP
  ADC #>TXTVRAM768
  STA ZP_TRAM_VEC16+1
  LDA CURSOR_X
  ORA ZP_FONT_SR
  TAY
  ; ---------------------------------------------------------------
  ;   書き込み
  PLA
;SKP_EXT_PUTC:
;  CMP #$A
;  BNE SKP_NL
;  LDA #0
;  STA CURSOR_X
;  BEQ EDIT_NL
;SKP_NL:
  STA (ZP_TRAM_VEC16),Y
  JSR GCHR::DRAW_LINE_RAW
  ; ---------------------------------------------------------------
  ;   カーソル更新
  ;LDA CURSOR_X
  ;INC                   ; 右に
  ;AND #%00011111        ; 0-31にマスク
  ;STA CURSOR_X
  INC CURSOR_X
;  BNE SKP_INC_EDY
;EDIT_NL:                ; マスクした結果ゼロになったらば
;  INC CURSOR_Y          ; カーソル下降
;SKP_INC_EDY:
  JSR DISABLE_BOX
  RTS

SCROLL_DOWN:
  ; 1行スクロールする
  ; カメラが下がるイメージからの命名
  loadmem16 ZP_TRAM_VEC16,TXTVRAM768  ; 原点
  LDX #23
@LOOP:
  LDA #32                             ; 1行下を指す読み取りインデックス
  STA ZP_X
  STZ ZP_Y                            ; 書き込み先インデックス
@LINELOOP:
  LDY ZP_X
  LDA (ZP_TRAM_VEC16),Y
  LDY ZP_Y
  STA (ZP_TRAM_VEC16),Y
  INC ZP_Y
  INC ZP_X                            ; 先を行くこれを監視
  LDA ZP_X
  AND #31
  BNE @LINELOOP                       ; ひっくり返るまではループ
  LDA #32
  CLC
  ADC ZP_TRAM_VEC16                   ; 最後にページを一つ進める
  STA ZP_TRAM_VEC16
  LDA #0
  ADC ZP_TRAM_VEC16+1                 ; 最後にページを一つ進める
  STA ZP_TRAM_VEC16+1
  DEX
  BNE @LOOP
  LDY #0
  LDA #' '
@LASTLOOP:
  STA (ZP_TRAM_VEC16),Y
  INY
  CPY #32
  BNE @LASTLOOP
  JSR GCHR::DRAW_ALLLINE                ; 新生ChDzはそんなに狂わない、今こそアプリにモード権限を委譲
  ;JSR GCHR::ENTER_TXTMODE             ; CHDZがすぐ狂うので初期化処理まで含める
  RTS

DISABLE_BOX:
  LDA #(CRTC2::WF|1)        ; 第1フレーム
  STA CRTC2::CONF
  RTS

