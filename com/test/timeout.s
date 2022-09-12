; -------------------------------------------------------------------
;                           TIMEOUT.COM
; -------------------------------------------------------------------
; タイムアウトのテスト
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
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_CNT:   .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ZR0のコマンドライン引数をHEXとしてタイムアウト時間に解釈
  JSR STR2NUM
  PHA
  ; 挨拶
  loadAY16 STR_HELLO
  syscall CON_OUT_STR
  ;LDA #$FF                        ; 256ms
  loadmem16 ZR0,EXIT
  PLA
  syscall TIMEOUT                 ; タイムアウト設定
  ; 数値表示
  STZ ZP_CNT
LOOP:
  LDA ZP_CNT
  JSR PRT_NUM
  JSR PRT_S
  INC ZP_CNT
  BRA LOOP

EXIT:                             ; タイムアウトした
  loadAY16 STR_TIMEOUT
  syscall CON_OUT_STR
  loadAY16 STR_GOODBYE
  syscall CON_OUT_STR
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

; -------------------------------------------------------------------
;                             10進1桁表示
; -------------------------------------------------------------------
PRT_NUM:
  AND #$0F
  ORA #$30
PRT_CHR:
  syscall CON_OUT_CHR
  RTS

; -------------------------------------------------------------------
;                              空白表示
; -------------------------------------------------------------------
PRT_S:
  LDA #' '
  BRA PRT_CHR

STR_HELLO:
  .BYT "Timeout syscall test program.",$A,$0
STR_TIMEOUT:
  .BYT "Timeout.",$A,$0
STR_GOODBYE:
  .BYT "Good Bye!",$A,$0

