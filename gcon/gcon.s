; 2色モードChDzによるコンソールモジュール
.INCLUDE "FXT65.inc"

PATH_FONT_DEFAULT:  .ASCIIZ "A:/MCOS/DAT/MIRAFONT.FNT"

INIT:
  ; コンソール画面の初期化
  ; フォントロードで使うのでファイルシステムモジュールが起動していること
  loadAY16 PATH_FONT_DEFAULT
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

PUTC:
  ; コンソールに一文字表示する
  ; --- テキスト書き込みベクタ作成
  CMP #$A
  BNE @SKP_LF           ; 改行なら改行する
  JSR SCROLL_DOWN
  STZ CURSOR_X
  RTS
@SKP_LF:
  CMP #$8
  BNE @SKP_BS           ; バックスペースなら1文字消す
  DEC CURSOR_X          ; カーソルを戻す
  LDA #' '              ; 一つ戻ってスペースを書き込む
  JSR PUTC
  DEC CURSOR_X          ; 再びカーソルを戻す
  RTS
@SKP_BS:
  PHA
  LDA CURSOR_Y
  CMP #24
  BNE @SKP_OVER
  JSR SCROLL_DOWN
  STZ CURSOR_X
  DEC CURSOR_Y
@SKP_OVER:
  STZ ZP_FONT_SR
  STZ ZP_TRAM_VEC16
  LDA CURSOR_Y
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  ADC #>TXTVRAM768
  STA ZP_TRAM_VEC16+1
  LDA CURSOR_X
  ORA ZP_FONT_SR
  TAY
  ; --- 書き込み
  PLA
SKP_EXT_PUTC:
  CMP #$A
  BNE SKP_NL
  LDA #0
  STA CURSOR_X
  BEQ EDIT_NL
SKP_NL:
  STA (ZP_TRAM_VEC16),Y
  JSR GCHR::DRAW_LINE_RAW
  ; --- カーソル更新
  LDA CURSOR_X
  CLC
  ADC #1
  AND #%00011111
  STA CURSOR_X
  BNE SKP_INC_EDY
EDIT_NL:
  INC CURSOR_Y
SKP_INC_EDY:
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
  ;JSR GCHR::DRAW_ALLLINE
  JSR GCHR::ENTER_TXTMODE             ; CHDZがすぐ狂うので初期化処理まで含める
  RTS

