; -------------------------------------------------------------------
; CCP
; -------------------------------------------------------------------
; 中国共産党
; COSアプリケーションはCCPを食いつぶすことがあり、ウォームブートでカードからリロードされる
; つまり特権的地位を持つかもしれないCOSアプリケーションである
; -------------------------------------------------------------------
.INCLUDE "FXT65.inc"
;.INCLUDE "generic.mac"
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
  LDA COMMAND_BUF                 ; バッファ先頭を取得
  BEQ LOOP                        ; バッファ長さ0ならとりやめ
  LDX #0                          ; 内部コマンド番号初期化
  loadmem16 ZR0,COMMAND_BUF       ; 入力されたコマンドをZR0に
  loadmem16 ZR1,ICOMNAMES         ; 内部コマンド名称配列をZR1に
@NEXT_ICOM:
  JSR M_EQ                        ; 両ポインタは等しいか？
  BEQ EXEC_ICOM                   ; 等しければ実行する（Xが渡る
  JSR M_LEN_ZR1
  CPY #0
  BEQ ICOM_NOTFOUND
  INY                             ; 内部コマンド名称インデックスを次の先頭に
  TYA
  CLC
  ADC ZR1                         ; 内部コマンド名称インデックスをポインタに反映
  STA ZR1
  LDA #0
  ADC ZR1+1
  STA ZR1+1
  INX                             ; 内部コマンド番号インデックスを増加
  BNE @NEXT_ICOM                  ; Xが一周しないうちは周回
  ; TODO:ここに内部コマンドが見つからないときのコード
  JMP ICOM_NOTFOUND
EXEC_ICOM:                        ; Xで渡された内部コマンド番号を実行する
  TXA
  ASL
  TAX
  JMP (ICOMVECS,X)
  JSR PRT_LF
  BRA LOOP

; -------------------------------------------------------------------
;                          内部コマンド
; -------------------------------------------------------------------

; -------------------------------------------------------------------
;                          見つからない
; -------------------------------------------------------------------
ICOM_NOTFOUND:
ICOM_CD:
ICOM_REBOOT:
  loadAY16 STR_COMNOTFOUND
  syscall CON_OUT_STR
  JMP LOOP

; -------------------------------------------------------------------
;                        ROMモニタに落ちる
; -------------------------------------------------------------------
ICOM_EXIT:
  loadAY16 STR_GOODBYE
  syscall CON_OUT_STR
  BRK
  NOP
  JMP LOOP

; -------------------------------------------------------------------
;                        画面の色を変える
; -------------------------------------------------------------------
ICOM_COLOR:
  loadAY16 STR_ICOM_COLOR_START
  syscall CON_OUT_STR                 ; 説明文
@LOOP:
  LDA #2
  syscall CON_RAWIN                   ; コマンド入力
@J:
  CMP #'j'
  BNE @K
  LDA #0
  JSR @GET
  DEY
  LDA #2
  JSR @PUT
  BRA @LOOP
@K:
  CMP #'k'
  BNE @H
  LDA #0
  JSR @GET
  INY
  LDA #2
  JSR @PUT
  BRA @LOOP
@H:
  CMP #'h'
  BNE @L
  LDA #1
  JSR @GET
  DEY
  LDA #3
  JSR @PUT
  BRA @LOOP
@L:
  CMP #'l'
  BNE @ENT
  LDA #1
  JSR @GET
  INY
  LDA #3
  JSR @PUT
@ENT:
  CMP #$A
  BNE @LOOP
  JSR PRT_LF
  JMP LOOP
@GET:
  syscall GCHR_COL
  TAY
  RTS
@PUT:
  syscall GCHR_COL
  RTS

; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
; どうする？ライブラリ？システムコール？
; -------------------------------------------------------------------
PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR @CALL
  PLA
@CALL:
  syscall CON_OUT_CHR
  RTS

BYT2ASC:
  ; Aで与えられたバイト値をASCII値AYにする
  ; Aから先に表示すると良い
  PHA           ; 下位のために保存
  AND #$0F
  JSR NIB2ASC
  TAY
  PLA
  LSR           ; 右シフトx4で上位を下位に持ってくる
  LSR
  LSR
  LSR
  JSR NIB2ASC
  RTS

NIB2ASC:
  ; #$0?をアスキー一文字にする
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

M_EQ_AY:
  ; AYとZR0が等しいかを返す
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

M_LEN:
  ; 文字列の長さを取得する
  ; input:AY
  ; output:Y
  STA ZR1
  STY ZR1+1
M_LEN_ZR1:  ; ZR1入力
  LDY #$FF
@LOOP:
  INY
  LDA (ZR1),Y
  BNE @LOOP
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
STR_COMNOTFOUND:  .BYT "Unknown Command.",$A,$0
STR_ICOM_COLOR_START:  .BYT "Console Color Setting.",$A,"j,k  : Character",$A,"h,l  : Background",$A,"ENTER: Complete",$0
STR_GOODBYE:  .BYT "Good Bye.",$A,$0
PATH_DEFAULT:     .BYT "A:/"

; -------------------------------------------------------------------
;                        内部コマンドテーブル
; -------------------------------------------------------------------
ICOMNAMES:        .ASCIIZ "EXIT"        ; 0
                  .ASCIIZ "CD"          ; 1
                  .ASCIIZ "REBOOT"      ; 2
                  .ASCIIZ "COLOR"       ; 3
                  .BYT $0

ICOMVECS:         .WORD ICOM_EXIT
                  .WORD ICOM_CD
                  .WORD ICOM_REBOOT
                  .WORD ICOM_COLOR

