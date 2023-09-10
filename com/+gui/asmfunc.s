.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

.BSS

.DATA

;.CONSTRUCTOR INIT

.CODE

.INCLUDE "./+gui/chdz_basic.s"

; コンストラクタ
;.SEGMENT "ONCE"
;INIT:
;  RTS

; -------------------------------------------------------------------
; PAD()関数
; ゲームパッドのボタン押下状況を取得する
; 引数: ボタン番号（ビット位置）
; 押されている=1, 押されていない=0を返す
; -------------------------------------------------------------------
PADSTAT:  .RES 2
.PROC _pad
  TAX
  ; P/S下げる
  LDA VIA::PAD_REG
  ORA #VIA::PAD_PTS
  STA VIA::PAD_REG
  ; P/S下げる
  LDA VIA::PAD_REG
  AND #<~VIA::PAD_PTS
  STA VIA::PAD_REG
  ; 読み取りループ
  INX
@LOOP:
  LDA VIA::PAD_REG        ; データ読み取り
  ; クロック下げる
  AND #<~VIA::PAD_CLK
  STA VIA::PAD_REG
  ROR                     ; 値をCに出す
  ; クロック上げる
  LDA VIA::PAD_REG        ; データ読み取り
  ORA #VIA::PAD_CLK
  STA VIA::PAD_REG
  DEX
  BNE @LOOP
  ; CをAに反映する C=0で押下
  TXA
  BCS @SKP_INX
  INC
@SKP_INX:
.ENDPROC

