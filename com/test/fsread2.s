; -------------------------------------------------------------------
;                           FSREAD2コマンド
; -------------------------------------------------------------------
; 新しいリードファンクションのテスト用
; 実装されたら動かなくなるかも
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../zr.inc"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                             定数定義
; -------------------------------------------------------------------
BFPTR   = BUFFER

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO
  FCTRL_SAV:      .RES 2
  ACTLEN:         .RES 2
  REQLEN:         .RES 2
  SDSEEK:         .RES 2
  BFPTR_NEW:          .RES 2

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  pushAY16
  ; 挨拶
  loadAY16 STR_HELLO
  syscall CON_OUT_STR
  pullAY16
  ; nullチェック
  storeAY16 ZR0
  TAX
  LDA (ZR0)
  BEQ @TEST_TXT ; コマンドライン引数がないならデフォルトのパス
  TXA
  BRA @ARG
@TEST_TXT:
  loadAY16 PATH_DATA
@ARG:
  ; ファイル検索
  syscall FS_FIND_FST             ; 検索
  ;BCS NOTFOUND                    ; 見つからなかったらあきらめる
  BCC @SKP_NOTFOUND
  JMP NOTFOUND
@SKP_NOTFOUND:
  storeAY16 FINFO_SAV             ; FINFOを格納
  ; ファイルオープン
  syscall FS_OPEN                 ; ファイルをオープン
  ;BCS NOTFOUND                    ; オープンできなかったらあきらめる
  BCC @SKP_NOTFOUND2
  JMP NOTFOUND
@SKP_NOTFOUND2:
  STA FD_SAV                      ; ファイル記述子をセーブ
  ; ファイル記述子の報告
  loadAY16 STR_GOT_FD
  syscall CON_OUT_STR
  LDA FD_SAV
  JSR PRT_BYT
  JSR PRT_LF
  ; 要求LENGTHの入力
  ; LENGTH?プロンプト
@INPUT_LENGTH:
  loadAY16 STR_LENGTH
  syscall CON_OUT_STR
  ; 文字列入力
  LDA #8                          ; 入力バッファ長さは8
  STA ZR0
  loadAY16 INSTR_BF               ; 入力バッファのポインタ
  syscall CON_IN_STR
  ; 文字列の変換
  loadAY16 INSTR_BF               ; 入力バッファのポインタ
  JSR STR2NUM
  BCS @INPUT_LENGTH               ; 失敗したらリトライ
  mem2mem16 REQLEN,ZR1
  JSR PRT_LF
  ; コール
  LDA FD_SAV
  STA ZR1
  loadmem16 ZR0,BFPTR
  mem2AY16 REQLEN
  syscall FS_READ_BYTS            ; コール
  BCC @SKP_EOF
  JMP @EOF
@SKP_EOF:
  storeAY16 FCTRL_SAV             ; FCTRLを取得
  mem2mem16 ACTLEN,ZR2            ; 16bit値を保存
  mem2mem16 SDSEEK,ZR0
  mem2mem16 BFPTR_NEW,ZR3
  ; FCTRL表示
  ; FCTRL_SIZラベル
  loadAY16 STR_FCTRL_SIZ
  syscall CON_OUT_STR
  ; FCTRL_SIZ
  LDA #FCTRL::SIZ
  ADC FCTRL_SAV
  LDY FCTRL_SAV+1
  JSR PRT_LONG_LF
  ; FCTRL_SEEKラベル
  loadAY16 STR_FCTRL_SEEK
  syscall CON_OUT_STR
  ; FCTRL_SEEK
  LDA #FCTRL::SEEK_PTR
  ADC FCTRL_SAV
  LDY FCTRL_SAV+1
  JSR PRT_LONG_LF
  ; ACTLENラベル
  loadAY16 STR_ACTLEN
  syscall CON_OUT_STR
  ; ACTLEN
  loadAY16 ACTLEN
  JSR PRT_SHORT_LF
  ; SDSEEKラベル
  loadAY16 STR_SDSEEK
  syscall CON_OUT_STR
  ; SDSEEK
  loadAY16 SDSEEK
  JSR PRT_SHORT_LF
  ; BFPTRラベル
  loadAY16 STR_BFPTR
  syscall CON_OUT_STR
  ; BFPTR
  loadAY16 BFPTR_NEW
  JSR PRT_SHORT_LF
  ; 受信文字列
  loadAY16 BUFFER
  syscall CON_OUT_STR
  ; bra
  JMP @INPUT_LENGTH
@EOF:
  ; ファイルクローズ
  LDA FD_SAV
  syscall FS_CLOSE
  RTS

; ファイルが見つからないとか開けないとか
NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

; カーネルエラーの表示
BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  RTS

; ASCII文字列をHEXと信じて変換
STR2NUM:
  @STR_PTR=ZR0
  @NUMBER16=ZR1
  storeAY16 @STR_PTR
  STZ ZR1
  STZ ZR1+1
  ; 最後尾まで探索、余計な文字があったらエラー
  LDY #$FF
@FIND_EOS_LOOP:
  INY
  LDA (@STR_PTR),Y
  BNE @FIND_EOS_LOOP
@END_OF_STR:
  ; Y=\0
  LDX #0
@BYT_LOOP:
  ; 下位nibble
  DEY
  CPY #$FF
  BEQ @END
  LDA (@STR_PTR),Y
  JSR CHR2NIB
  BCS @ERR
  STA ZR1,X
  ; 上位nibble
  DEY
  CPY #$FF
  BEQ @END
  LDA (@STR_PTR),Y
  JSR CHR2NIB
  BCS @ERR
  ASL
  ASL
  ASL
  ASL
  ORA ZR1,X
  STA ZR1,X
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

; 16bit値を表示+改行
PRT_SHORT_LF:
  storeAY16 ZR2
  LDY #1
  LDA (ZR2),Y
  JSR PRT_BYT
  LDY #0
  LDA (ZR2),Y
  JSR PRT_BYT
  JMP PRT_LF

; 32bit値を表示+改行
PRT_LONG_LF:
  JSR PRT_LONG
  JMP PRT_LF

; 32bit値を表示
PRT_LONG:
  storeAY16 ZR2
  LDY #3
@LOOP:
  LDA (ZR2),Y
  PHY
  JSR PRT_BYT
  PLY
  DEY
  BPL @LOOP
  RTS

; 8bit値を表示
PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

; 改行
PRT_LF:
  LDA #$A
  JMP PRT_C_CALL

; スペース印字
PRT_S:
  LDA #' '
  JMP PRT_C_CALL

; Aで与えられたバイト値をASCII値AYにする
; Aから先に表示すると良い
BYT2ASC:
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

; #$0?をアスキー一文字にする
NIB2ASC:
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0
STR_FILE:
  .BYT "File:",$0
STR_EOF:
  .BYT "[EOF]",$0

PATH_DATA:
  .ASCIIZ "A:/TEST.TXT"

STR_HELLO:      .BYT "New FS_READ syscall dev tool",$A,$0
STR_LENGTH:     .BYT "Length?   : $",$0
STR_GOT_FD:     .BYT "File Dscr.:       $",$0
STR_FCTRL_SIZ:  .BYT "FCTRL_SIZE: $",$0
STR_FCTRL_SEEK: .BYT "FCTRL_SEEK: $",$0
STR_ACTLEN:     .BYT "ACTLEN    :     $",$0
STR_SDSEEK:     .BYT "SDSEEK    : $",$0
STR_BFPTR:      .BYT "BFPTR     : $",$0

INSTR_BF: .RES 8
.DATA
AAA:
.res 200
BUFFER:

