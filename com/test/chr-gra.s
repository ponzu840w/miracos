; -------------------------------------------------------------------
; -------------------------------------------------------------------
; SNAKEゲームのおこぼれ
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
  LDA #10
  STA ZP_CURSOR_X
  STA ZP_CURSOR_Y                     ; カーソルの初期化
  ; 本処理
  LDA #'@'
  JSR CURSOR_PUT
@LOOP:
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho
  syscall CON_RAWIN                   ; 入力待機
  PHA
  LDA #' '
  JSR CURSOR_PUT
  PLA
  ; wasd
@W:
  CMP #'w'
  BNE @S
  DEC ZP_CURSOR_Y
@S:
  CMP #'s'
  BNE @A
  INC ZP_CURSOR_Y
@A:
  CMP #'a'
  BNE @D
  DEC ZP_CURSOR_X
@D:
  CMP #'d'
  BNE @END_WASD
  INC ZP_CURSOR_X
@END_WASD:
  LDA #'@'
  JSR CURSOR_PUT
  BRA @LOOP
EXIT:
  ; 大政奉還コード
  RTS

CURSOR_GET:
  ; --- 読み取り
  JSR CUR2TRAM_VEC
  LDA (ZP_TRAM_VEC16),Y
  RTS

CURSOR_PUT:
  ; --- 書き込み
  PHA
  JSR CUR2TRAM_VEC
  PLA
  STA (ZP_TRAM_VEC16),Y
  JSR DRAW_LINE_RAW
  RTS

CUR2TRAM_VEC:
  STZ ZP_FONT_SR        ; シフタ初期化
  STZ ZP_TRAM_VEC16     ; TRAMポインタ初期化
  LDA ZP_CURSOR_Y
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  ADC ZP_TXTVRAM768_16+1
  STA ZP_TRAM_VEC16+1
  LDA ZP_CURSOR_X
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

