; -------------------------------------------------------------------
; DONKI                  Debug OperatioN KIt
; -------------------------------------------------------------------
; デバッガ
; ひとまず、BCOSの一部として常駐する
; -------------------------------------------------------------------
; TODO 専用コマンドライン
; TODO ソフトウェアブレーク処理ルーチン

; コマンドラインを要素に分解する
.macro purse_args
  ; ゼロチェック
  BEQ LOOP
  ; 第1引数の検索
  STZ ZR0                 ; 引数の数
  LDX #1
  JSR CMD_ARGS_SPLIT
  BEQ @END_PURSE
  ; 第1引数存在
  INC ZR0
  PHY
  JSR ARG2NUM
  mem2mem16 ZR1,ZR2
  PLX
  ; 第2引数の検索
  JSR CMD_ARGS_SPLIT
  BEQ @END_PURSE
  ; 第2引数存在
  INC ZR0
  JSR ARG2NUM
@END_PURSE:
.endmac

ENT_DONKI:
SAV_STAT:
; 状態を保存
; 割り込み直後のスタック状態を想定
  SEI
  STA ROM::A_SAVE   ; レジスタ保存
  STX ROM::X_SAVE
  STY ROM::Y_SAVE
  LDX #12-1
@STOREZRLOOP:       ; ゼロページレジスタを退避
  LDA ZR0,X
  STA ROM::ZR0_SAVE,X
  DEX
  BPL @STOREZRLOOP
  TSX
  STX ROM::SP_SAVE  ; save targets stack poi
  ; --- FLAG、PC保存 ---
  ; SP+1=FLAG、+2=PCL、+3=PCH
  LDY #0
@STACK_SAVE_LOOP:
  INX
  LDA $0100,X
  STA FLAG_SAVE,Y
  INY
  CPY #3
  BNE @STACK_SAVE_LOOP
  ; --- プログラムカウンタを減算 ---
  LDA #$1
  CMP PC_SAVE   ; PCLと#$1の比較
  BCC SKIPHDEC
  BEQ SKIPHDEC
  DEC PC_SAVE+1 ; PCH--
SKIPHDEC:
  DEC PC_SAVE   ; PCL--
  ; --- 垂直同期ユーザベクタをデフォルトに変更 ---
  mem2mem16 VB_HNDR_SAVE,VBLANK_USER_VEC16  ; ユーザベクタを退避
  loadAY16 IRQ::VBLANK_STUB
  storeAY16 VBLANK_USER_VEC16               ; スタブに差し替え
PRT_STAT:  ; print contents of stack
  ; --- レジスタ情報を表示 ---
  ; 表示中にさらにBRKされると分かりづらいので改行
  loadAY16 STR_NEWLINE
  JSR FUNC_CON_OUT_STR
  ; A
  JSR PRT_S
  LDA #'a'
  JSR FUNC_CON_OUT_CHR
  LDA ROM::A_SAVE       ; Acc reg
  JSR PRT_BYT_S
  ; X
  LDA #'x'
  JSR FUNC_CON_OUT_CHR
  LDA ROM::X_SAVE       ; X reg
  JSR PRT_BYT_S
  ; Y
  LDA #'y'
  JSR FUNC_CON_OUT_CHR
  LDA ROM::Y_SAVE       ; Y reg
  JSR PRT_BYT_S
  ; Flag
  LDA #'f'
  JSR FUNC_CON_OUT_CHR
  LDA FLAG_SAVE
  JSR PRT_BYT_S
  ; PC
  LDA #'p'
  JSR FUNC_CON_OUT_CHR
  LDA PC_SAVE+1
  JSR PRT_BYT
  LDA PC_SAVE
  JSR PRT_BYT_S
  ; SP
  LDA #'s'
  JSR FUNC_CON_OUT_CHR
  LDA ROM::SP_SAVE      ; stack pointer
  JSR PRT_BYT
  CLI
  ;JMP LOOP

LOOP:
  loadAY16 STR_NEWLINE
  JSR FUNC_CON_OUT_STR
  loadAY16 COMMAND_BUF
  JSR FUNC_CON_IN_STR       ; コマンド行を取得
  purse_args
  ; コマンド処理
  LDA COMMAND_BUF
  CMP #'D'
  BNE @SKP_D
  ; [DEBUG] 引数表示
  JSR PRT_LF
  LDA ZR0
  JSR PRT_BYT_S
  LDA ZR1+1
  JSR PRT_BYT
  LDA ZR1
  JSR PRT_BYT_S
  LDA ZR2+1
  JSR PRT_BYT
  LDA ZR2
  JSR PRT_BYT_S
  ;JMP DUMPPAGE
@SKP_D:
  ; 復帰
  mem2mem16 VBLANK_USER_VEC16,VB_HNDR_SAVE  ; 垂直同期ユーザベクタを復帰
  SEC
  LDA ROM::SP_SAVE
  ADC #3                  ; SPを割り込み前の状態に戻す
  TAX
  TXS                     ; SP復帰
  LDA ROM::A_SAVE
  LDX ROM::X_SAVE
  LDY ROM::Y_SAVE
  LDA FLAG_SAVE           ; フラグをロード
  PHA                     ; フラグをプッシュ
  PLP                     ; フラグをフラグとしてプル
  CLC
  JMP (PC_SAVE)           ; 復帰ジャンプ
  JMP LOOP

;DUMPPAGE:
;  @
;  ; モニタにあってもいいので追加したコマンド
;  ; 指定アドレスから256バイトを吐き出す
;  JSR STR2NUM
;  LDY #16
;@LOOP:
;  ; アドレス表示部
;  JSR PRT_LF
;  LDA ZR1
;  PHA
;  JSR PRT_BYT
;  LDA ADDR_INDEX_L
;  PHA
;  JSR PRT_BYT
;  LDA #':'
;  JSR PRT_CHAR_UART
;  JSR PRT_S
;  LDX #16
;@BYTLOOP:
;  ; データ表示部
;  LDA (ADDR_INDEX_L)
;  JSR PRT_BYT_S
;  INC ADDR_INDEX_L
;  BNE @SKP_H
;  INC ADDR_INDEX_H
;@SKP_H:
;  DEX
;  BNE @BYTLOOP
;  LDX #16
;  PLA
;  STA ADDR_INDEX_L
;  PLA
;  STA ADDR_INDEX_H
;  ; テキスト表示部
;@ASCIILOOP:
;  LDA (ADDR_INDEX_L)
;  CMP #$20
;  BCS @SKP_20   ; 20以上
;  LDA #'.'
;@SKP_20:
;  CMP #$7F
;  BCC @SKP_7F   ; 7F未満
;  LDA #'.'
;@SKP_7F:
;  JSR PRT_CHAR_UART
;  INC ADDR_INDEX_L
;  BNE @SKP_H2
;  INC ADDR_INDEX_H
;@SKP_H2:
;  DEX
;  BNE @ASCIILOOP
;  DEY
;  BEQ @END
;  BRA @LOOP
;@END:
;  JMP LOOP

STR_NEWLINE: .BYT $A,"+",$0

; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
; どうする？ライブラリ？システムコール？
; -------------------------------------------------------------------
BCOS_ERROR:
  JSR PRT_LF
  JSR ERR::FUNC_ERR_GET
  JSR ERR::FUNC_ERR_MES
  JMP LOOP

PRT_BIN:
  LDX #8
@LOOP:
  ASL
  PHA
  LDA #'0'    ; キャリーが立ってなければ'0'
  BCC @SKP_ADD1
  INC         ; キャリーが立ってたら'1'
@SKP_ADD1:
  PHX
  JSR FUNC_CON_OUT_CHR
  PLX
  PLA
  DEX
  BNE @LOOP
  RTS

PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  JSR FUNC_CON_OUT_CHR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

PRT_BYT_S:
  JSR PRT_BYT
PRT_S:
  ; スペース
  LDA #' '
  JMP PRT_C_CALL

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

; コマンドバッファの引数の先頭Xと終端Yを取得
; スペースで区切ることが出来る
; 何もなければゼロフラグが立つ
CMD_ARGS_SPLIT:
  ; 先頭取得
@START_LOOP:
  LDA COMMAND_BUF,X
  BEQ @END
  CMP #' '
  BNE @SKP_START_LOOP ; ' '以外を発見して脱出
  INX
  BRA @START_LOOP
@SKP_START_LOOP:
  ; Xに先頭インデックスが取得された
  TXA
  TAY
  ; 終端取得
@END_LOOP:
  LDA COMMAND_BUF,Y
  BEQ @SKP_END_LOOP   ; 終端を発見して脱出
  CMP #' '
  BEQ @SKP_END_LOOP   ; ' 'を発見して脱出
  INY
  BRA @END_LOOP
@SKP_END_LOOP:
  ; Yに終端インデックスが取得された
  LDA #1
@END:
  RTS

; -------------------------------------------------------------------
;                    ASCII文字列をHEXと信じて変換
; -------------------------------------------------------------------
;   input:  X = 左インデックス
;           Y = 右インデックス
;   output: ZR2 = 値
; -------------------------------------------------------------------
ARG2NUM:
  @NUMBER16=ZR2
  @START=ZR0+1
  ; X=start
  ; Y=\0
  STX @START
  LDX #0
  STZ @NUMBER16
  STZ @NUMBER16+1
@BYT_LOOP:
  ; 下位nibble
  CPY @START
  BEQ @END
  DEY
  LDA COMMAND_BUF,Y
  JSR CHR2NIB
  BCS @ERR
  STA @NUMBER16,X
  ; 上位nibble
  CPY @START
  BEQ @END
  DEY
  LDA COMMAND_BUF,Y
  JSR CHR2NIB
  BCS @ERR
  ASL
  ASL
  ASL
  ASL
  ORA @NUMBER16,X
  STA @NUMBER16,X
  INX
  BRA @BYT_LOOP
@END:
  CLC
  RTS
@ERR:
  SEC
  RTS

; *
; --- Aレジスタの一文字をNibbleとして値にする ---
; *
CHR2NIB:
  CMP #'0'
  BMI @ERR
  CMP #'9'+1
  BPL @ABCDEF
  SEC
  SBC #'0'
  CLC
  RTS
@ABCDEF:
  CMP #'A'
  BMI @ERR
  CMP #'F'+1
  BPL @ERR
  SEC
  SBC #'A'-$0A
  CLC
  RTS
@ERR:
  SEC
  RTS

