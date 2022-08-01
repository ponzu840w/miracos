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
ZP_PADSTAT:          .RES 2
ZP_ATTR:          .RES 2

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ポートの設定
  LDA VIA::PAD_DDR         ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  ; 双方上げる
  LDA VIA::PAD_REG
  ORA #VIA::PAD_CLK|VIA::PAD_PTS
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
  ; 状態表示
  LDA ZP_PADSTAT
  STA ZP_ATTR

LOW:
  LDY #0
@ATTRLOOP:
  ASL ZP_ATTR                   ; C=ビット情報
  BCC @ATTR_CHR
  LDA #'-'                      ; そのビットが立っていないときはハイフンを表示
  BRA @SKP_ATTR_CHR
@ATTR_CHR:
  LDA STR_ATTR,Y                ; 属性文字を表示
@SKP_ATTR_CHR:
  PHY
  syscall CON_OUT_CHR           ; 属性文字/-を表示
  PLY
  INY
  CPY #8
  BNE @ATTRLOOP
  JSR PRT_S                     ; 区切りスペース

  LDA ZP_PADSTAT+1
  STA ZP_ATTR
HIGH:
  LDY #0
@ATTRLOOP:
  ASL ZP_ATTR                   ; C=ビット情報
  BCC @ATTR_CHR
  LDA #'-'                      ; そのビットが立っていないときはハイフンを表示
  BRA @SKP_ATTR_CHR
@ATTR_CHR:
  LDA STR_ATTRH,Y                ; 属性文字を表示
@SKP_ATTR_CHR:
  PHY
  syscall CON_OUT_CHR           ; 属性文字/-を表示
  PLY
  INY
  CPY #8
  BNE @ATTRLOOP

  JSR PRT_LF
  JMP START

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

STR_ATTR: .BYT  "BY#$",UE,SHITA,LEFT,RIGHT
STR_ATTRH:.BYT  "AXLR****"

