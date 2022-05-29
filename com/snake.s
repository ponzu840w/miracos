; -------------------------------------------------------------------
;                           SNAKEゲーム
; -------------------------------------------------------------------
; 蛇のゲーム
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.INCLUDE "../zr.inc"

; -------------------------------------------------------------------
;                            定数定義
; -------------------------------------------------------------------
LEFT  =%0001
BUTTOM=%0010
TOP   =%0100
RIGHT =%1000
CHR_BLANK =' '
CHR_HEAD  ='@'
CHR_WALL  ='#'

; -------------------------------------------------------------------
;                             ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
ZP_TXTVRAM768_16:         .RES 2
ZP_FONT2048_16:           .RES 2
ZP_TRAM_VEC16:            .RES 2  ; TRAM操作用ベクタ
ZP_FONT_VEC16:            .RES 2  ; フォント読み取りベクタ
ZP_FONT_SR:               .RES 1  ; FONT_OFST
ZP_X:                     .RES 1
ZP_Y:                     .RES 1
ZP_CURSOR_X:              .RES 1
ZP_CURSOR_Y:              .RES 1
ZP_ITR:                   .RES 1
ZP_SNK_HEAD_X:            .RES 1
ZP_SNK_HEAD_Y:            .RES 1
ZP_SNK_TAIL_X:            .RES 1
ZP_SNK_TAIL_Y:            .RES 1
ZP_SNK_HEAD_PTR8:         .RES 1
ZP_SNK_TAIL_PTR8:         .RES 1
ZP_SNK_LENGTH:            .RES 1
ZP_SNK_DIREC:             .RES 1
ZP_INPUT:                 .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; アドレス類を取得
  LDY #BCOS::BHY_GET_ADDR_txtvram768  ; TRAM
  syscall GET_ADDR
  storeAY16 ZP_TXTVRAM768_16
  LDY #BCOS::BHY_GET_ADDR_font2048    ; FONT
  syscall GET_ADDR
  storeAY16 ZP_FONT2048_16
  ; 画面をいじってみる
  ; 初期化
  JSR CLEAR_TXTVRAM                   ; 画面クリア
  JSR DRAW_ALLLINE
  JSR DRAW_FRAME                      ; 枠の描画
  ; ゲーム情報の初期化
  ; 向きリングキューのポインタ初期化
  STZ ZP_SNK_TAIL_PTR8
  STZ ZP_SNK_HEAD_PTR8
  ; 向きリングキューの内容初期化
  LDA #RIGHT          ; 右を向いている
  STA ZP_SNK_DIREC
  STA SNAKE_DATA256
  ; 実座標データの初期化
  LDA #10             ; 10,10がちょうどよかろうか
  STA ZP_SNK_HEAD_X
  STA ZP_SNK_HEAD_Y
  STA ZP_SNK_TAIL_X
  STA ZP_SNK_TAIL_Y
@LOOP:
  ; wasd
  LDA #BCOS::BHA_CON_RAWIN_NoWaitNoEcho
  syscall CON_RAWIN
  BEQ @END_WASD
  STA ZP_INPUT
  LDA ZP_SNK_DIREC
  BIT #LEFT|RIGHT
  BEQ @V
@H:
@W:
  LDA ZP_INPUT
  CMP #'w'
  BNE @S
  LDA #TOP
  STA ZP_SNK_DIREC
@S:
  CMP #'s'
  BNE @END_WASD
  LDA #BUTTOM
  STA ZP_SNK_DIREC
@V:
@A:
  LDA ZP_INPUT
  CMP #'a'
  BNE @D
  LDA #LEFT
  STA ZP_SNK_DIREC
@D:
  CMP #'d'
  BNE @END_WASD
  LDA #RIGHT
  STA ZP_SNK_DIREC
@END_WASD:
  JSR MOVE_HEAD
  JSR MOVE_TAIL
  JSR WAIT
  BRA @LOOP
EXIT:
  ; 大政奉還コード
  RTS

; --- デバッグ用ウェイト
WAIT:
  LDY #$FF
WAIT_Y:
  LDX #$FF
WAIT_X:
  NOP
  NOP
  NOP
  NOP
  DEX
  BNE WAIT_X
  DEY
  BNE WAIT_Y
  RTS

; -------------------------------------------------------------------
;                           頭を動かす
; -------------------------------------------------------------------
MOVE_HEAD:
  ; 次の頭の座標を取得する
  LDA ZP_SNK_DIREC
  LDX ZP_SNK_HEAD_X
  LDY ZP_SNK_HEAD_Y
  JSR NEXT_XY
  ; そこを調べる
  JSR XY_GET
  CMP #CHR_WALL
  BEQ GAMEOVER
  CMP #CHR_HEAD
  BEQ GAMEOVER
  ; 大丈夫そうだ
  ; 頭の座標を更新
  LDA #CHR_HEAD
  STX ZP_SNK_HEAD_X
  STY ZP_SNK_HEAD_Y
  JSR XY_PUT_DRAW
  ; 向きリングキューの更新
  LDA ZP_SNK_DIREC        ; 使った向き
  LDX ZP_SNK_HEAD_PTR8    ; 更新すべき場所のポインタ
  STA SNAKE_DATA256,X     ; 向きを登録
  INC ZP_SNK_HEAD_PTR8    ; 進める
  RTS

GAMEOVER:
  BRK
  NOP
  RTS

; -------------------------------------------------------------------
;                           尾を動かす
; -------------------------------------------------------------------
MOVE_TAIL:
  ; 現在の尾を消す
  LDA #CHR_BLANK
  LDX ZP_SNK_TAIL_X
  LDY ZP_SNK_TAIL_Y
  JSR XY_PUT_DRAW
  ; 尾の座標を更新
  PHX
  LDX ZP_SNK_TAIL_PTR8
  LDA SNAKE_DATA256,X   ; 尾の持つ次の胴体へのDIRECを取得
  PLX
  JSR NEXT_XY           ; 次の尾となる胴体の座標を取得
  ; 次の尾の座標とする
  STX ZP_SNK_TAIL_X
  STY ZP_SNK_TAIL_Y
  ; 向きリングキューの尾ポインタを移動
  INC ZP_SNK_TAIL_PTR8
  RTS

; -------------------------------------------------------------------
;                 XY座標のDIREC方向に隣接するXY座標
; -------------------------------------------------------------------
NEXT_XY:
@RIGHT:
  CMP #RIGHT
  BNE @LEFT
  INX
  RTS
@LEFT:
  CMP #LEFT
  BNE @TOP
  DEX
  RTS
@TOP:
  CMP #TOP
  BNE @BUTTOM
  DEY
  RTS
@BUTTOM:
  INY
  RTS

; -------------------------------------------------------------------
;                           ワクを描画
; -------------------------------------------------------------------
DRAW_FRAME:
  ; 上
  LDY #0
  JSR DRAW_HLINE
  ; 下
  LDY #24-1-2
  JSR DRAW_HLINE
  ; 左右
  DEY
@LOOP_SIDE:
  LDX #0
  LDA #CHR_WALL
  JSR XY_PUT
  LDX #32-1
  LDA #CHR_WALL
  JSR XY_PUT
  DEY
  BNE @LOOP_SIDE
  JSR DRAW_ALLLINE
  RTS

DRAW_HLINE:
  LDX #0
  LDA #32
  STA ZP_ITR
@LOOP:
  LDA #CHR_WALL
  JSR XY_PUT
  INX
  DEC ZP_ITR
  BNE @LOOP
  ;JSR DRAW_LINE_RAW
  RTS

; -------------------------------------------------------------------
;                     カーソル位置から読み取り
; -------------------------------------------------------------------
XY_GET:
  PHX
  PHY
  ; --- 読み取り
  JSR XY2TRAM_VEC
  LDA (ZP_TRAM_VEC16),Y
  PLY
  PLX
  RTS

; -------------------------------------------------------------------
;                     カーソル位置に書き込み
; -------------------------------------------------------------------
; 呼び出し直後にJSR DRAW_LINE_RAWが使える
; -------------------------------------------------------------------
XY_PUT:
  PHX
  PHY
  ; --- 書き込み
  PHA
  JSR XY2TRAM_VEC
  PLA
  STA (ZP_TRAM_VEC16),Y
  ;JSR DRAW_LINE_RAW    ; 呼び出し側の任意
  PLY
  PLX
  RTS

XY_PUT_DRAW:
  PHX
  PHY
  ; --- 書き込み
  PHA
  JSR XY2TRAM_VEC
  PLA
  STA (ZP_TRAM_VEC16),Y
  JSR DRAW_LINE_RAW    ; 呼び出し側の任意
  PLY
  PLX
  RTS

XY2TRAM_VEC:
  STZ ZP_FONT_SR        ; シフタ初期化
  STZ ZP_TRAM_VEC16     ; TRAMポインタ初期化
  ;LDA ZP_CURSOR_Y
  TYA
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  ADC ZP_TXTVRAM768_16+1
  STA ZP_TRAM_VEC16+1
  ;LDA ZP_CURSOR_X
  TXA
  ORA ZP_FONT_SR
  TAY
  RTS

CLEAR_TXTVRAM:
  mem2mem16 ZR0,ZP_TXTVRAM768_16
  LDA #' '
  LDY #0
  LDX #3
CLEAR_TXTVRAM_LOOP:
  STA (ZR0),Y
  INY
  BNE CLEAR_TXTVRAM_LOOP
  INC ZR0+1
  DEX
  BNE CLEAR_TXTVRAM_LOOP
  RTS

DRAW_ALLLINE:
  ; TRAMから全行を反映する
  mem2mem16 ZP_TRAM_VEC16,ZP_TXTVRAM768_16
  LDY #0
  LDX #6
DRAW_ALLLINE_LOOP:
  PHX
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  PLX
  DEX
  BNE DRAW_ALLLINE_LOOP
  RTS

DRAW_LINE:
  ; Yで指定された行を描画する
  TYA                       ; 行数をAに
  STZ ZP_Y                  ; シフト先をクリア
  ASL                       ; 行数を右にシフト
  ROR ZP_Y                  ; おこぼれをインデックスとするx3
  ASL
  ROR ZP_Y
  ASL
  ROR ZP_Y                  ; A:ページ数0~2 ZP_Y:ページ内インデックス行頭
  CLC
  ;ADC #>TXTVRAM768          ; TXTVRAM上位に加算
  ADC ZP_TXTVRAM768_16+1    ; TXTVRAM上位に加算
  STA ZP_TRAM_VEC16+1       ; ページ数登録
  LDY ZP_Y                  ; インデックスをYにロード
DRAW_LINE_RAW:
  ; 行を描画する
  ; TRAM_VEC16を上位だけ設定しておき、そのなかのインデックスもYで持っておく
  ; 連続実行すると次の行を描画できる
  TYA                       ; インデックスをAに
  AND #%11100000            ; 行として意味のある部分を抽出
  TAX                       ; しばらく使わないXに保存
  ; HVの初期化
  STZ ZP_X
  ; 0~2のページオフセットを取得
  LDA ZP_TRAM_VEC16+1
  SEC
  ;SBC #>TXTVRAM768
  SBC ZP_TXTVRAM768_16+1
  STA ZP_Y
  ; インデックスの垂直部分3bitを挿入
  TYA
  ASL
  ROL ZP_Y
  ASL
  ROL ZP_Y
  ASL
  ROL ZP_Y
  ; 8倍
  LDA ZP_Y
  ASL
  ASL
  ASL
  STA ZP_Y
  ; --- フォント参照ベクタ作成
DRAW_TXT_LOOP:
  ;LDA #>FONT2048
  LDA ZP_FONT2048_16+1
  STA ZP_FONT_VEC16+1
  ; フォントあぶれ初期化
  LDY #0
  STY ZP_FONT_SR
  ; アスキーコード読み取り
  TXA                       ; 保存していたページ内行を復帰してインデックスに
  TAY
  LDA (ZP_TRAM_VEC16),Y
  ASL                       ; 8倍してあぶれた分をアドレス上位に加算
  ROL ZP_FONT_SR
  ASL
  ROL ZP_FONT_SR
  ASL
  ROL ZP_FONT_SR
  STA ZP_FONT_VEC16
  LDA ZP_FONT_SR
  ADC ZP_FONT_VEC16+1       ; キャリーは最後のROLにより0
  STA ZP_FONT_VEC16+1
  ; --- フォント書き込み
  ; カーソルセット
  LDA ZP_X
  STA CRTC::VMAH
  ; 一文字表示ループ
  LDY #0
CHAR_LOOP:
  LDA ZP_Y
  STA CRTC::VMAV
  ; フォントデータ読み取り
  LDA (ZP_FONT_VEC16),Y
  STA CRTC::WDBF
  INC ZP_Y
  INY
  CPY #8
  BNE CHAR_LOOP
  ; --- 次の文字へアドレス類を更新
  ; テキストVRAM読み取りベクタ
  INX
  BNE SKP_TXTNP
  INC ZP_TRAM_VEC16+1
SKP_TXTNP:
  ; H
  INC ZP_X
  LDA ZP_X
  AND #%00011111  ; 左端に戻るたびゼロ
  BNE SKP_EXT_DRAWLINE
  TXA
  TAY
  RTS
SKP_EXT_DRAWLINE:
  ; V
  SEC
  LDA ZP_Y
  SBC #8
  STA ZP_Y
  BRA DRAW_TXT_LOOP

SNAKE_DATA256:

