; -------------------------------------------------------------------
; DONKI                  Debug OperatioN KIt
; -------------------------------------------------------------------
; デバッガ
; ひとまず、BCOSの一部として常駐する
; -------------------------------------------------------------------
; TODO 専用コマンドライン
; TODO ソフトウェアブレーク処理ルーチン
LOOP:
  loadAY16 STR_NEWLINE
  JSR FUNC_CON_OUT_STR
  JSR FUNC_CON_IN_STR
  ; 復帰
  LDA ROM::SP_SAVE
  CLC
  ADC #3                  ; SPを割り込み前の状態に戻す
  TAX
  TXS                     ; SP復帰
  LDA ROM::A_SAVE
  LDX ROM::X_SAVE
  LDY ROM::Y_SAVE
  LDA FLAG_SAVE           ; フラグをロード
  PHA                     ; フラグをプッシュ
  PLP                     ; フラグをフラグとしてプル
  JMP (PC_SAVE)           ; 復帰ジャンプ
  JMP LOOP

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
  JMP LOOP

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

