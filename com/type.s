; -------------------------------------------------------------------
; テキストファイルを打ち出す
; -------------------------------------------------------------------
; TCのテスト
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

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  STZ TEXT+256                    ; 終端
  ;pushAY16                       ; デバッグ情報
  ;loadAY16 STR_FILE
  ;syscall CON_OUT_STR
  ;pullAY16
  ;pushAY16
  ;syscall CON_OUT_STR
  ;JSR PRT_LF
  ;pullAY16
  ; nullチェック
  storeAY16 ZR0
  TAX
  LDA (ZR0)
  BEQ NOTFOUND
  TXA
  ; オープン
  syscall FS_FIND_FST             ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
  ;JSR PRT_BYT
  ;JSR PRT_LF
LOOP:
  ; ロード
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,TEXT              ; 書き込み先
  loadAY16 256
  syscall FS_READ_BYTS            ; ロード
  BCS @CLOSE
  TAX                             ; 読み取ったバイト数
  CPY #1                          ; 256バイト読んだか？
  BEQ @SKP_EOF
  LDA #0
  STZ TEXT,X
@SKP_EOF:
  ; 出力
  loadAY16 TEXT
  syscall CON_OUT_STR
  BRA LOOP
  ; 最終バイトがあるとき
  ; クローズ
@CLOSE:
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  ;loadAY16 STR_EOF               ; debug EOF表示
  ;syscall CON_OUT_STR
  RTS

NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  JMP LOOP

;PRT_BYT:
;  JSR BYT2ASC
;  PHY
;  JSR PRT_C_CALL
;  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL
;
;PRT_S:
;  ; スペース
;  LDA #' '
;  JMP PRT_C_CALL
;
;BYT2ASC:
;  ; Aで与えられたバイト値をASCII値AYにする
;  ; Aから先に表示すると良い
;  PHA           ; 下位のために保存
;  AND #$0F
;  JSR NIB2ASC
;  TAY
;  PLA
;  LSR           ; 右シフトx4で上位を下位に持ってくる
;  LSR
;  LSR
;  LSR
;  JSR NIB2ASC
;  RTS
;
;NIB2ASC:
;  ; #$0?をアスキー一文字にする
;  ORA #$30
;  CMP #$3A
;  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
;  ADC #$06
;@SKP_ADC:
;  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0
;STR_FILE:
;  .BYT "File:",$0
;STR_EOF:
;  .BYT "[EOF]",$0

; -------------------------------------------------------------------
;                             データ領域
; -------------------------------------------------------------------
.BSS
TEXT:

