.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fscons.inc"
.INCLUDE "../zr.inc"
.INCLUDE "./+fsbug/structfs.s"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; OS側変数領域
.BSS
  .INCLUDE "./+fsbug/varfs.s"
  .INCLUDE "./+fsbug/varfs2.s"
BASE: .RES 2

.ZEROPAGE
  .INCLUDE "./+fsbug/zpfs.s"
SETTING: .RES 1
ZP_CONCFG_ADDR16:         .RES 2  ; 取得した設定値のアドレス

.DATA
  _sector_buffer_512:
SECBF512:       .RES 512  ; SDカード用セクタバッファ

.IMPORT popa, popax
.IMPORTZP sreg

.EXPORT _read_sec,_dump
.EXPORT _sector_buffer_512
.EXPORTZP _sdcmdprm,_sdseek

.CODE

.PROC INIT
  syscall GET_ADDR                    ; アドレス要求
  storeAY16 ZP_CONCFG_ADDR16          ; アドレス保存
  RTS
.ENDPROC

.PROC ERR
  .INCLUDE "../errorcode.inc"
REPORT:
  BRK
  NOP
  RTS
.ENDPROC
; -------------------------------------------------------------------
; BCOS 15                大文字小文字変換
; -------------------------------------------------------------------
; input   : A = chr
; -------------------------------------------------------------------
FUNC_UPPER_CHR:
  CMP #'a'
  BMI FUNC15_RTS
  CMP #'z'+1
  BPL FUNC15_RTS
  SEC
  SBC #'a'-'A'
FUNC15_RTS:
  RTS

; -------------------------------------------------------------------
; BCOS 16                大文字小文字変換（文字列）
; -------------------------------------------------------------------
; input   : AY = buf
; -------------------------------------------------------------------
; TODO: もはや""を考慮する必要はない
FUNC_UPPER_STR:
  storeAY16 ZR0
  LDY #$FF
@LOOP:
  INY
  LDA (ZR0),Y
  BEQ FUNC15_RTS
  JSR FUNC_UPPER_CHR
  STA (ZR0),Y
  CMP #'"' ;"
  BNE @LOOP
  ; "
@SKIPLOOP:
  INY
  LDA (ZR0),Y
  CMP #'"' ;"
  BEQ @LOOP
  BRA @SKIPLOOP

  .INCLUDE "./+fsbug/fsmac.mac"
  .PROC SPI
    .INCLUDE "./+fsbug/spi.s"
  .ENDPROC
  .PROC SD
    .INCLUDE "./+fsbug/sd.s"
  .ENDPROC
  .PROC FS
    .INCLUDE "./+fsbug/fs.s"
  .ENDPROC

.PROC _read_sec
  LDA #$81
  STA SDCMD_CRC
  JSR SD::RDSEC
  RTS
.ENDPROC

; void dump(boolean wide, unsigned int from, unsigned int to, unsigned int base);

; -------------------------------------------------------------------
;                       dコマンド メモリダンプ
; -------------------------------------------------------------------
;   第1引数から第2引数までをダンプ表示
;   第2引数がなければ第1引数から256バイト
; -------------------------------------------------------------------
.PROC _dump
  ZR2_TO=ZR2
  ZR4_FROM=ZR4
  ZR5_OFST=ZR5
  ; ---------------------------------------------------------------
  ;   引数格納
  storeAX16 ZR5_OFST
  JSR popax
  storeAX16 ZR2_TO
  JSR popax
  storeAX16 ZR4_FROM
  JSR popa  ; WIDE
  CMP #0

  BNE @SKP_INITWIDE
  SMB0 SETTING
  ;LDA #%00000011 ; only UART
  ;STA ZP_CON_DEV_CFG
  ;STA (ZP_CONCFG_ADDR16)
  BRA DUMP1
@SKP_INITWIDE:
  RMB0 SETTING
DUMP1:
  ; ---------------------------------------------------------------
  ;   ループ
@LINE:
  ; アドレス表示部すっ飛ばすか否かの判断
  BBS0 SETTING,@PRT_ADDR ; ワイドモード:アドレス毎行表示
  DEC ZR3
  BNE @DATA
@SET_ZR3:
  LDA #4
  STA ZR3
  ; ---------------------------------------------------------------
  ;   アドレス表示部
  ;"<1234>--------------------------"
  JSR PRT_LF            ; 視認性向上のための空行は行の下にした方がよさそうだが、
@PRT_ADDR:              ;   最大の情報を表示しつつ作業用コマンドラインを出すにはこうする。

  ;JSR PRT_ZR4_ZDDR      ; <1234>_:mコマンドと共用
; d,mで共用のアドレス表示部
;PRT_ZR4_ZDDR:
  JSR PRT_LF
  LDA #'<'              ; アドレス左修飾
  JSR FUNC_CON_OUT_CHR
  LDA ZR5_OFST+1        ; アドレス上位
  JSR PRT_BYT
  LDA ZR5_OFST
  JSR PRT_BYT
  LDA #'>'              ; アドレス右修飾
  JSR FUNC_CON_OUT_CHR
  JSR PRT_S
  ;RTS

  BBS0 SETTING,@DATA_NOLF    ; ワイドモード:ハイフンスキップ
  LDA #'-'
  LDX #32-(4+2+1)       ; 画面幅からこれまで表示したものを減算
  JSR PRT_FEW_CHARS     ; 画面右までハイフン
  ; ---------------------------------------------------------------
  ;   データ表示部
@DATA:
  JSR PRT_LF
@DATA_NOLF:
  ;loadmem16 DUMP_SUB_FUNCPTR,DUMP_SUB_DATA
  pushmem16 ZR4_FROM
  pushmem16 ZR5_OFST
  LDA #<(DUMP_SUB_DATA-(DUMP_SUB_BRA+2))
  JSR DUMP_SUB
  BEQ @SKP_PADDING
  ; 一部のみ表示したときの空白
@PADDING_LOOP:
  DEX
  BEQ @SKP_PADDING
  PHX
  JSR PRT_S
  JSR PRT_S
  JSR PRT_S
  PLX
  BRA @PADDING_LOOP
@SKP_PADDING:
  ; ---------------------------------------------------------------
  ;   ASCII表示部
  ;loadmem16 DUMP_SUB_FUNCPTR,DUMP_SUB_ASCII
  pullmem16 ZR5_OFST
  pullmem16 ZR4_FROM
  LDA #<(DUMP_SUB_ASCII-(DUMP_SUB_BRA+2))
  JSR DUMP_SUB
  BEQ @LINE
@END:
  JSR PRT_LF
  RTS

; ポインタ切り替えでHEXかASCIIを表示する
DUMP_SUB:
  STA DUMP_SUB_BRA+1
  BBS0 SETTING,@SKP8  ; ワイドモード:1行16バイト
  LDX #8              ; X=行ダウンカウンタ
  BRA DATALOOP
@SKP8:
  LDX #16
DATALOOP:
  LDA (ZR4_FROM)     ; バイト取得
  PHX
  ;JMP (DUMP_SUB_FUNCPTR)
DUMP_SUB_BRA:
  .BYTE $80 ; BRA
  .BYTE $00
DUMP_SUB_RETURN:
  PLX
  ; 終了チェック
  LDA ZR4_FROM+1
  CMP ZR2_TO+1
  BNE @SKP_ENDCHECK_LOW
  LDA ZR4_FROM
  CMP ZR2_TO
  BEQ @END_DATALOOP
@SKP_ENDCHECK_LOW:
  inc16 ZR4_FROM   ; アドレスインクリメント
  inc16 ZR5_OFST
  DEX
  BNE DATALOOP
@END_DATALOOP:      ; 到達時点でX=0なら8バイト表示した、それ以外ならのこったバイト数+1
  CPX #0            ; 終了z、途中Z
  RTS

DUMP_SUB_DATA:
  JSR PRT_BYT_S
  BRA DUMP_SUB_RETURN
DUMP_SUB_ASCII:
@ASCIILOOP:
  CMP #$20
  BCS @SKP_20   ; 20以上
  LDA #'.'
@SKP_20:
  CMP #$7F
  BCC @SKP_7F   ; 7F未満
  LDA #'.'
@SKP_7F:
  JSR FUNC_CON_OUT_CHR
  BRA DUMP_SUB_RETURN
.ENDPROC

FUNC_CON_OUT_CHR:
  syscall CON_OUT_CHR
  RTS

FUNC_CON_OUT_STR:
  syscall CON_OUT_STR
  RTS

; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
; どうする？ライブラリ？システムコール？
; -------------------------------------------------------------------
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
  BRA PRT_C_CALL

PRT_BYT_S:
  JSR PRT_BYT
PRT_S:
  ; スペース
  LDA #' '
  BRA PRT_C_CALL

PRT_FEW_CHARS:
  ; Xレジスタで文字数を指定
  PHA
  PHX
  JSR FUNC_CON_OUT_CHR
  PLX
  PLA
  DEX
  BNE PRT_FEW_CHARS
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

NIB2ASC:
  ; #$0?をアスキー一文字にする
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

