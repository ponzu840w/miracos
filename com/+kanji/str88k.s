; -------------------------------------------------------------------
;                       STR88K ライブラリ
; -------------------------------------------------------------------
;   8x8サイズの文字および文字列の印字を扱うライブラリ
;   K(ANJI)対応（ディスクフォント）
;   init_str88k
;   str88_puts  wx,wy,ptr
; -------------------------------------------------------------------

.ZEROPAGE
ZP_FONT_VEC16:    .RES 2
ZP_FONT_SR:       .RES 1
ZP_STR88_COLOR:   .RES 1
ZP_STR88_BKCOL:   .RES 1
ZP_STR88_STRPTR:  .RES 2
ZP_GLYPH_BUF:     .RES 8
ZP_GLYPH_FD:      .RES 1
ZP_GLYPH_FINFO:   .RES 2

.macro init_str88k
  ; ---------------------------------------------------------------
  ;   カーネルアドレス奪取
  LDY #BCOS::BHY_GET_ADDR_font2048    ; FONT
  syscall GET_ADDR
  STY DRAW_TXT_LOOP+1
  ; ---------------------------------------------------------------
  ;   字形ファイルオープン
  loadAY16 STR_FONTPATH
  syscall FS_FIND_FST             ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  STZ ZR0
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
.endmac

.macro str88k_puts wx,wy,ptr
  LDA #wx
  STA CRTC2::PTRX
  LDA #wy
  STA CRTC2::PTRY
  loadmem16 ZP_STR88_STRPTR,ptr
  JSR STR88K_PUTS
.endmac

.macro str88k_close
  .local @SKP_ERR
  ; ファイルクローズ
  LDA FD_SAV
  syscall FS_CLOSE
  BCC @SKP_ERR
  JMP STR88K_BCOS_ERROR
  @SKP_ERR
.endmac

.macro str88k_setcolor col,bkcol
  LDA #col
  STA ZP_STR88_COLOR
  LDA #bkcol
  STA ZP_STR88_BKCOL
.endmac

.SEGMENT "LIB"

; カーネルエラーのとき
STR88K_BCOS_ERROR:
  LDA #$A
  syscall CON_OUT_CHR
  syscall ERR_GET
  syscall ERR_MES
  RTS

; Shift-JISコードをフォントファイルオフセットに変換
; input: AX=Shift-JISコード（単バイトの場合はAのみ）
SJIS_DECODE:
  @SJIS=ZR0
  @OFST=ZR1 ;,ZR2
  @TMP=ZR3
  STZ @OFST
  STZ @OFST+3
  STZ @TMP
  STA @SJIS+1
  STX @SJIS
  ;storeAX16 @SJIS
  ; ---------------------------------------------------------------
  ;   上位バイトを線形化
@HIGH:
  LDA @SJIS+1
  CMP #$89        ; 漢字か？
  BCS @KANJI1
@ALPHABET:        ; 漢字以前なら$85~$88を$85に圧縮
  TAY
  DEC
  AND #%11111110
  TAX
  TYA
  CPX #$86        ; $87 or $88のときのみ EQUAL
  BNE @HIGH_END
  LDA #($85-$81)
  BRA @HIGH_END2
@KANJI1:
  ;SEC ;BCSでジャンプしてきたからC=1
  SBC #3
  ; ---------------------------------------------------------------
  ;   線形化された上位バイトをシフト加算
  ;   x8(bytes) x192(char blocks) -> x2^9 x2^10
@HIGH_END:
  ; -$81減算
  SEC
  SBC #$81
@HIGH_END2:
  ; x2^9
  ASL
  TAX             ; X=2^9 B1
  STA @OFST+1
  LDA #0
  ROL
  STA @OFST+2
  TAY             ; Y=2^9 B2
  ; + x2^10
  TXA
  ASL
  ROL @OFST+2
  ; CLC
  ADC @OFST+1
  STA @OFST+1
  TYA
  ADC @OFST+2
  STA @OFST+2
@LOW:
  ; ---------------------------------------------------------------
  ;   下位バイトを加算 -$40 x8
  LDA @SJIS
  SEC
  SBC #$40
  ASL
  ROL @TMP
  ASL
  ROL @TMP
  ASL
  ROL @TMP
  ; CLC
  ADC @OFST
  STA @OFST
  LDA @TMP
  ADC @OFST+1
  STA @OFST+1
@END:
  RTS

STR88K_PUTS:
  LDY #0
@LOOP:
  LDA (ZP_STR88_STRPTR),Y
  BEQ @RET
  BPL @SKP_KANJI
  INY
  PHA
  TAX
  LDA (ZP_STR88_STRPTR),Y
  TAX
  PLA
@SKP_KANJI:
  PHY
  JSR STR88K_PUTC
  PLY
  INY
  BRA @LOOP
@RET:
  RTS

; Shift-JISコードを印字する
; input: AX=Shift-JISコード（単バイトの場合はAのみ）
STR88K_PUTC:
  TAY         ; Yを使うわけではない
  BPL @ASCII
  ; ---------------------------------------------------------------
  ;   外部フォント参照ベクタ作成
@KANJI:
  ; Shift-JISを字形ファイルオフセットへとデコード
  JSR SJIS_DECODE
  ; 字形をバッファに読み出し
  ; シーク
  LDA ZP_GLYPH_FD
  LDY #BCOS::SEEK_SET
  syscall FS_SEEK
  ; 実際の読み出し
  LDA ZP_GLYPH_FD
  STA ZR1                       ; FD
  loadmem16 ZR0, ZP_GLYPH_BUF   ; 字形バッファを保存先に
  loadAY16 8                    ; 8バイト（一時分）
  syscall FS_READ_BYTS          ; 読み出し
  ; ポインタを字形バッファに設定
  loadAY16 ZP_GLYPH_BUF
  storeAY16 ZP_FONT_VEC16
  BRA @OUTPUT
  ; ---------------------------------------------------------------
  ;   内部フォント参照ベクタ作成
@ASCII:
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
@OUTPUT:
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
  LDA ZP_STR88_COLOR
  BCS @COL
  LDA ZP_STR88_BKCOL
@COL:
  RTS
