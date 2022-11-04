.ZEROPAGE
ZP_FONT_VEC16:    .RES 2
ZP_FONT_SR:       .RES 1
ZP_STR88_COLOR:   .RES 1
ZP_STR88_BKCOL:   .RES 1
ZP_STR88_STRPTR:  .RES 2

.macro init_str88
  ; カーネルアドレス奪取
  LDY #BCOS::BHY_GET_ADDR_font2048    ; FONT
  syscall GET_ADDR
  STY DRAW_TXT_LOOP+1
.endmac

.macro str88_puts wx,wy,ptr
  LDA #wx
  STA CRTC2::PTRX
  LDA #wy
  STA CRTC2::PTRY
  loadmem16 ZP_STR88_STRPTR,ptr
  JSR STR88_PUTS
.endmac

.SEGMENT "LIB"

STR88_PUTS:
  LDY #0
@LOOP:
  LDA (ZP_STR88_STRPTR),Y
  BEQ @RET
  PHY
  JSR DRAW_TXT_LOOP
  PLY
  INY
  BRA @LOOP
@RET:
  RTS

STR88_PUTC:
  STX CRTC2::PTRX
  STY CRTC2::PTRY
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
  LDA ZP_STR88_COLOR
  BCS @COL
  LDA ZP_STR88_BKCOL
@COL:
  RTS

