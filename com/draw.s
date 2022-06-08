; -------------------------------------------------------------------
;                            DRAWコマンド
; -------------------------------------------------------------------
; 行志向インタプリタの指令で画面にいろいろ描き出す
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.PROC LG
  .INCLUDE "../lib/linegetter.s"
.ENDPROC
LINE_BUFFER = LG::LINEBUFFER

LF=10

; -------------------------------------------------------------------
;                             ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_ARG_IDX:     .RES 1  ; 引数用インデックス

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO
  ONECHR:         .RES 1

; -------------------------------------------------------------------
;                              実行領域
; -------------------------------------------------------------------
.SEGMENT "STARTUP"
START:
  ; コンソール入力を仮に前提とする
  JSR LG::INIT                    ; コンソール入力として初期化
LOOP:
  JSR LG::GETLINE                 ; 行を取得
  ; ---------------------------------------------------------------
  ; --  コマンドライン解析
  LDA COMMAND_BUF                 ; バッファ先頭を取得
  BEQ LOOP                        ; バッファ長さ0ならとりやめ
  JSR PRT_LF                      ; コマンド入力後の改行は、無入力ではやらない
  ; ---------------------------------------------------------------
  ; --  コマンド名と引数の分離
  LDX #$FF
@CMDNAME_LOOP:
  INX
  LDA LINE_BUFFER,X
  BEQ @CMDNAME_0END               ; 引数がなかった
  CMP #' '                        ; 空白か？
  BNE @CMDNAME_LOOP
  STZ LINE_BUFFER,X               ; 空白をヌルに
  BRA @PUSH_ARG
@CMDNAME_0END:
  STZ LINE_BUFFER+1,X             ; ダブル0で引数がないことを示す
@PUSH_ARG:                        ; COMMAND_BUF+X+1=引数先頭を渡したい
  TXA
  SEC
  ADC #<LINE_BUFFER
  PHA                             ; 下位をプッシュ
  LDA #0
  ADC #>LINE_BUFFER
  PHA                             ; 上位をプッシュ
@SEARCH_ICOM:
  LDX #0                          ; 内部コマンド番号初期化
  loadmem16 ZR0,LINE_BUFFER       ; 入力されたコマンドをZR0に
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
  JMP ICOM_NOTFOUND               ; このジャンプはおそらく呼ばれえない
EXEC_ICOM:                        ; Xで渡された内部コマンド番号を実行する
  TXA                             ; Xを作業のためAに
  ASL                             ; Xをx2
  TAX                             ; Xを戻す
  PLY                             ; 引数をAYに渡す
  PLA
  JMP (ICOMVECS,X)
  BRA LOOP

NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  syscall CON_OUT_CHR
  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

; -------------------------------------------------------------------
;                          コマンドテーブル
; -------------------------------------------------------------------
CMD_NAME_TABLE:     .ASCIIZ "dot"        ; 0
                    .ASCIIZ "fill"       ; 1
                    .BYT $0

CMD_VECTOR_TABLE:   .WORD CMD_DOT
                    .WORD CMD_FILL

