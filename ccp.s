; -------------------------------------------------------------------
; CCP
; -------------------------------------------------------------------
; 中国共産党
; COSアプリケーションはCCPを食いつぶすことがあり、ウォームブートでカードからリロードされる
; つまり特権的地位を持つかもしれないCOSアプリケーションである
; -------------------------------------------------------------------
.INCLUDE "FXT65.inc"
.INCLUDE "generic.mac"
.PROC BCOS
  .INCLUDE "syscall.inc"  ; システムコール番号
.ENDPROC

.macro syscall func
  LDX #(BCOS::func)*2
  JSR BCOS::SYSCALL
.endmac

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
ZR0 = $0000
ZR1 = ZR0+2
.ZEROPAGE

.BSS
CUR_DIR:          .RES 64 ; カレントディレクトリのパスが入る。二行分でアボン
COMMAND_BUF:      .RES 64 ; コマンド入力バッファ

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
; -------------------------------------------------------------------
;                           シェルスタート
; -------------------------------------------------------------------
START:
  loadAY16 STR_INITMESSAGE
  syscall CON_OUT_STR             ; タイトル表示

; -------------------------------------------------------------------
;                           シェルループ
; -------------------------------------------------------------------
LOOP:
  LDA #'>'
  syscall CON_OUT_CHR             ; プロンプト表示
  LDA #64                         ; バッファ長さ指定
  STA ZR0
  loadAY16 COMMAND_BUF            ; バッファ指定
  syscall CON_IN_STR              ; バッファ行入力
  JSR PRT_LF
; コマンドライン解析
  LDX #0                          ; 内部コマンド番号初期化
  loadmem16 ZR0,COMMAND_BUF       ; 入力されたコマンドをZR0に
  loadmem16 ZR1,ICOMMANDS         ; 内部コマンド名称配列をZR1に
@NEXT_ICOM:
  JSR M_EQ                        ; 両ポインタは等しいか？
  BEQ EXEC_ICOM                   ; 等しければ実行する（Xが渡る
  INY                             ; 内部コマンド名称インデックスを次の先頭に
  CLC
  ADC ZR1                         ; 内部コマンド名称インデックスをポインタに反映
  TYA
  ADC ZR1+1
  INX                             ; 内部コマンド番号インデックスを増加
  BNE @NEXT_ICOM                  ; Xが一周しないうちは周回
  ; TODO:ここに内部コマンドが見つからないときのコード
EXEC_ICOM:                        ; Xで渡された内部コマンド番号を実行する
  TXA
  JSR BYT2ASC
  JSR PRT_HEX                     ; とりあえず内部コマンド番号を出力してみる
  JSR PRT_LF
  BRA LOOP

PRT_HEX:
  JSR BYT2ASC
  PHY
  JSR @call
  PLA
@call:
  syscall CON_OUT_CHR
  RTS

BYT2ASC:
  ; Aで与えられたバイト値をASCII値AYにする
  ; Aから先に表示すると良い
  PHA
  LSR
  LSR
  LSR
  LSR
  JSR PRHEXZ
  STA ZR0
  PLA
  AND #$0F
  JSR PRHEXZ
  LDY ZR0
  RTS

PRHEXZ:
  ORA #$30
  CMP #$3A
  BCC PRT_BYT1
  ADC #$06
PRT_BYT1:
  RTS

M_EQ_AY:
  ; AYとZR0が等しいかを返す
  ; YはAYの終端文字を指すインデックス
  STA ZR1
  STY ZR1+1
M_EQ:
  LDY #$FF                ; インデックスはゼロから
@LOOP:
  INY
  LDA (ZR0),Y
  BEQ @END                ; ヌル終端なら終端検査に入る
  CMP (ZR1),Y
  BEQ @LOOP               ; 一致すればもう一文字
@NOT:
  SEC
  RTS
@END:
  LDA (ZR1),Y
  BNE @EQ
@EQ:
  CLC
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  LDX #BCOS::CON_OUT_CHR*2
  JSR BCOS::SYSCALL
  RTS

; -------------------------------------------------------------------
;                             データ領域
; -------------------------------------------------------------------
STR_INITMESSAGE:  .BYT "MIRACOS 0.01 for FxT-65",$A,$A,$0 ; 起動時メッセージ
PATH_DEFAULT:     .BYT "A:/"

; -------------------------------------------------------------------
;                        内部コマンドテーブル
; -------------------------------------------------------------------
ICOMMANDS:        .ASCIIZ "EXIT"        ; 0
                  .ASCIIZ "CD"          ; 1
                  .ASCIIZ "REBOOT"      ; 2

