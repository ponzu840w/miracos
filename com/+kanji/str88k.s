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
ZP_FD_SAV:        .RES 1
ZP_FINFO_SAV:     .RES 2

.macro init_str88k
  ; ---------------------------------------------------------------
  ;   カーネルアドレス奪取
  LDY #BCOS::BHY_GET_ADDR_font2048    ; FONT
  syscall GET_ADDR
  STY STR88K_PUTC_ASCII+1
  ; ---------------------------------------------------------------
  ;   字形ファイルオープン
  loadAY16 STR_FONTPATH
  syscall FS_FIND_FST                 ; 検索
  BCS NOTFOUND                        ; 見つからなかったらあきらめる
  storeAY16 ZP_FINFO_SAV              ; FINFOを格納
  STZ ZR0
  syscall FS_OPEN                     ; ファイルをオープン
  BCS NOTFOUND                        ; オープンできなかったらあきらめる
  STA ZP_FD_SAV                       ; ファイル記述子をセーブ
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
  LDA ZP_FD_SAV
  syscall FS_CLOSE
  BCC @SKP_ERR
  JMP STR88K_BCOS_ERROR
@SKP_ERR:
.endmac

.macro str88k_setcolor col,bkcol
  LDA #col
  STA ZP_STR88_COLOR
  LDA #bkcol
  STA ZP_STR88_BKCOL
.endmac

.SEGMENT "LIB"

; EUC-JPコードをフォントファイルオフセットに変換
; input:  AX=EUC-JPコード（単バイトの場合はAのみ）
; output: ZR1,2=ファイルオフセット
EUCJ_DECODE:
  @OFST=ZR1 ;,ZR2
  @TMP=ZR3
  STZ @OFST+2
  STZ @OFST+3
  STZ @TMP
  TAY
  TXA
  ; 下位バイト
  SEC
  SBC #$A0
  ASL
  ASL
  ROL @TMP
  ASL
  ROL @TMP
  STA @OFST
  ; 上位バイト
  TYA
  SEC
  SBC #$A1
  ; --- 8(9区)以上なら4引く
  CMP #8
  BCC @SKP_M4
  ;SEC ;BCC直後なのでC=1
  SBC #4
@SKP_M4:
  ; --- 10(14区)以上なら2引く
  CMP #10
  BCC @SKP_M2
  ;SEC ;BCC直後なのでC=1
  SBC #2
@SKP_M2:
  STA @OFST+1
  ASL
  ;CLC ; MSBはゼロなのでC=0
  ADC @OFST+1
  STA @OFST+1
  LDA @TMP
  ;CLC ; ハミ出すはずはないのでC=0
  ADC @OFST+1
  STA @OFST+1
  RTS
;x3+(0~2)
;x2+self+(0~2)

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

; カーネルエラーのとき
STR88K_BCOS_ERROR:
  LDA #$A
  syscall CON_OUT_CHR
  syscall ERR_GET
  syscall ERR_MES
  RTS

; EUC-JPコードを印字する
; input: AX=EUC-JPコード（単バイトの場合はAのみ）
STR88K_PUTC:
  TAY         ; Yを使うわけではない
  BPL STR88K_PUTC_ASCII
  ; ---------------------------------------------------------------
  ;   外部フォント参照ベクタ作成
@KANJI:
  ; EUC-JPを字形ファイルオフセットへとデコード
  JSR EUCJ_DECODE
  ; 字形をバッファに読み出し
  ; シーク
  LDA ZP_GLYPH_FD
  LDY #BCOS::SEEK_SET
  syscall FS_SEEK
  BCS STR88K_BCOS_ERROR
  ; 実際の読み出し
  LDA ZP_GLYPH_FD
  STA ZR1                       ; FD
  loadmem16 ZR0, ZP_GLYPH_BUF   ; 字形バッファを保存先に
  loadAY16 8                    ; 8バイト（一時分）
  syscall FS_READ_BYTS          ; 読み出し
  BCS STR88K_BCOS_ERROR
  ; ポインタを字形バッファに設定
  loadAY16 ZP_GLYPH_BUF
  storeAY16 ZP_FONT_VEC16
  BRA STR88K_PUTC_OUTPUT
  ; ---------------------------------------------------------------
  ;   内部フォント参照ベクタ作成
STR88K_PUTC_ASCII:
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
STR88K_PUTC_OUTPUT:
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
