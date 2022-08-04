; -------------------------------------------------------------------
;                           RDSFCコマンド
; -------------------------------------------------------------------
; パッド状態表示テスト
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
ZP_PADSTAT:               .RES 2
ZP_PRE_PADSTAT:           .RES 2
ZP_SHIFTER:               .RES 1
  ; キャラクタ表示モジュール
ZP_TXTVRAM768_16:         .RES 2  ; カーネルのワークエリアを借用するためのアドレス
ZP_FONT2048_16:           .RES 2  ; カーネルのワークエリアを借用するためのアドレス
ZP_TRAM_VEC16:            .RES 2  ; TRAM操作用ベクタ
ZP_FONT_VEC16:            .RES 2  ; フォント読み取りベクタ
ZP_FONT_SR:               .RES 1  ; FONT_OFST
ZP_DRAWTMP_X:             .RES 1  ; 描画用
ZP_DRAWTMP_Y:             .RES 1  ; 描画用

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; 初期化
  STZ ZP_PRE_PADSTAT+1                ; 変化前の状態をありえない値にして、初回強制上書き
  ; アドレス類を取得
  LDY #BCOS::BHY_GET_ADDR_txtvram768  ; TRAM
  syscall GET_ADDR
  storeAY16 ZP_TXTVRAM768_16
  LDY #BCOS::BHY_GET_ADDR_font2048    ; FONT
  syscall GET_ADDR
  storeAY16 ZP_FONT2048_16
  ; ボタン値位置参考を表示
  JSR PRT_LF
  LDX #1
  LDY #22
  loadmem16 ZR0,STR_BUTTON_NAMES
  JSR XY_PRT_STR
  JSR DRAW_LINE
  ; ポートの設定
  LDA VIA::PAD_DDR         ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
READ:
  LDA #BCOS::BHA_CON_RAWIN_NoWaitNoEcho  ; キー入力チェック
  syscall CON_RAWIN
  BEQ @SKP_RTS
  RTS
@SKP_RTS:
  ; P/S下げる
  LDA VIA::PAD_REG
  ORA #VIA::PAD_PTS
  STA VIA::PAD_REG
  ; P/S下げる
  LDA VIA::PAD_REG
  AND #<~VIA::PAD_PTS
  STA VIA::PAD_REG
  ; 読み取りループ
  LDX #16
LOOP:
  LDA VIA::PAD_REG        ; データ読み取り
  ; クロック下げる
  AND #<~VIA::PAD_CLK
  STA VIA::PAD_REG
  ; 16bit値として格納
  ROR
  ROL ZP_PADSTAT+1
  ROL ZP_PADSTAT
  ; クロック上げる
  LDA VIA::PAD_REG        ; データ読み取り
  ORA #VIA::PAD_CLK
  STA VIA::PAD_REG
  DEX
  BNE LOOP
  ; 変化はあったか
  LDA ZP_PADSTAT
  CMP ZP_PRE_PADSTAT
  BNE PRINT
  LDA ZP_PRE_PADSTAT+1
  CMP ZP_PADSTAT+1
  BEQ READ

; 状態表示
PRINT:
  mem2mem16 ZP_PRE_PADSTAT,ZP_PADSTAT ; 表示するときすなわち状態変化があったとき、前回状態更新
  ; 下位8bit、上位4bitに分けて文字列を生成
  ; 下位8bit
  LDA ZP_PADSTAT
  STA ZP_SHIFTER
LOW:
  LDY #0
@ATTRLOOP:
  ASL ZP_SHIFTER           ; C=ビット情報
  BCC @ATTR_CHR
  LDA #'-'                 ; そのビットが立っていないときはハイフンを表示
  BRA @SKP_ATTR_CHR
@ATTR_CHR:
  LDA STR_BUTTON_NAMES,Y   ; 属性文字を表示
@SKP_ATTR_CHR:
  STA STR_WORK,Y           ; 属性文字/-を格納
  INY
  CPY #8
  BNE @ATTRLOOP
  ; 上位4bit
  LDA ZP_PADSTAT+1
  STA ZP_SHIFTER
HIGH:
  LDY #0
@ATTRLOOP:
  ASL ZP_SHIFTER                ; C=ビット情報
  BCC @ATTR_CHR
  LDA #'-'                      ; そのビットが立っていないときはハイフンを表示
  BRA @SKP_ATTR_CHR
@ATTR_CHR:
  LDA STR_BUTTON_NAMES+8,Y      ; 属性文字を表示
@SKP_ATTR_CHR:
  STA STR_WORK+8,Y
  INY
  CPY #4
  BNE @ATTRLOOP

  ; 格納された文字列の表示
  LDX #1
  LDY #23
  loadmem16 ZR0,STR_WORK
  JSR XY_PRT_STR
  JSR DRAW_LINE
  JMP READ

; -------------------------------------------------------------------
;                            文字列を表示
; -------------------------------------------------------------------
XY_PRT_STR:
  LDA (ZR0)
  BEQ @EXT
  JSR XY_PUT
  INX
  INC ZR0
  BNE @SKP_INCH
  INC ZR0+1
@SKP_INCH:
  BRA XY_PRT_STR
@EXT:
  RTS

; -------------------------------------------------------------------
;                         XY位置に書き込み
; -------------------------------------------------------------------
XY_PUT:
  PHX
  PHY
  ; --- 書き込み
  PHA
  JSR XY2TRAM_VEC
  PLA
  STA (ZP_TRAM_VEC16),Y
  PLY
  PLX
  RTS

; -------------------------------------------------------------------
;                    XY位置に書き込み、描画込み
; -------------------------------------------------------------------
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

; -------------------------------------------------------------------
;                 カーソル位置に書き込み、描画込み
; -------------------------------------------------------------------
XY2TRAM_VEC:
  STZ ZP_FONT_SR        ; シフタ初期化
  STZ ZP_TRAM_VEC16     ; TRAMポインタ初期化
  TYA
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  ADC ZP_TXTVRAM768_16+1
  STA ZP_TRAM_VEC16+1
  TXA
  ORA ZP_FONT_SR
  TAY
  RTS

; -------------------------------------------------------------------
;                     Yで指定された行を反映する
; -------------------------------------------------------------------
DRAW_LINE:
  JSR XY2TRAM_VEC
DRAW_LINE_RAW:
  ; 行を描画する
  ; TRAM_VEC16を上位だけ設定しておき、そのなかのインデックスもYで持っておく
  ; 連続実行すると次の行を描画できる
  TYA                       ; インデックスをAに
  AND #%11100000            ; 行として意味のある部分を抽出
  TAX                       ; しばらく使わないXに保存
  ; HVの初期化
  STZ ZP_DRAWTMP_X
  ; 0~2のページオフセットを取得
  LDA ZP_TRAM_VEC16+1
  SEC
  ;SBC #>TXTVRAM768
  SBC ZP_TXTVRAM768_16+1
  STA ZP_DRAWTMP_Y
  ; インデックスの垂直部分3bitを挿入
  TYA
  ASL
  ROL ZP_DRAWTMP_Y
  ASL
  ROL ZP_DRAWTMP_Y
  ASL
  ROL ZP_DRAWTMP_Y
  ; 8倍
  LDA ZP_DRAWTMP_Y
  ASL
  ASL
  ASL
  STA ZP_DRAWTMP_Y
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
  LDA ZP_DRAWTMP_X
  STA CRTC::VMAH
  ; 一文字表示ループ
  LDY #0
CHAR_LOOP:
  LDA ZP_DRAWTMP_Y
  STA CRTC::VMAV
  ; フォントデータ読み取り
  LDA (ZP_FONT_VEC16),Y
  STA CRTC::WDBF
  INC ZP_DRAWTMP_Y
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
  INC ZP_DRAWTMP_X
  LDA ZP_DRAWTMP_X
  AND #%00011111  ; 左端に戻るたびゼロ
  BNE SKP_EXT_DRAWLINE
  TXA
  TAY
  RTS
SKP_EXT_DRAWLINE:
  ; V
  SEC
  LDA ZP_DRAWTMP_Y
  SBC #8
  STA ZP_DRAWTMP_Y
  BRA DRAW_TXT_LOOP


; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

PRT_S:
  ; スペース
  LDA #' '
  ;JMP PRT_C_CALL
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

UE      = $C2
SHITA   = $C3
LEFT    = $C1
RIGHT   = $C0

STR_BUTTON_NAMES: .BYT  "BY#$",UE,SHITA,LEFT,RIGHT,"AXLR",0
STR_WORK: .BYT  "BY#$",UE,SHITA,LEFT,RIGHT,"AXLR",0

