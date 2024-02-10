; -------------------------------------------------------------------
; ファイルを16進でダンプする
; -------------------------------------------------------------------
; 全てが雑
; TODO:ダンプ位置指定 幅設定 CPUアドレスとファイルアドレスの分離
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
;                             ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_SEEK:        .RES 2  ; ファイル内アドレス （TODO:32bitに拡張）
  SETTING:        .RES 1
  CMD_ARG_NUM:    .RES 2
  CMD_ARG_1:      .RES 2
  CMD_ARG_2:      .RES 2
  ZP_LINE:        .RES 1

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
  STZ ZR0
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
LOOP:
  STZ ZP_SEEK
  STZ ZP_SEEK+1
  ; ロード
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,TEXT              ; 書き込み先
  loadAY16 256
  syscall FS_READ_BYTS            ; ロード
  BCS @CLOSE
  TAX                             ; 読み取ったバイト数
  ; 出力
  loadAY16 TEXT
  JSR DUMP
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

; -------------------------------------------------------------------
;                    Dコマンド ワイドメモリダンプ
; -------------------------------------------------------------------
;   UART前提：画面サイズにとらわれず1行16バイト表示する
; -------------------------------------------------------------------
WDUMP:
  SMB0 SETTING
  BRA DUMP1

; -------------------------------------------------------------------
;                       dコマンド メモリダンプ
; -------------------------------------------------------------------
;   第1引数から第2引数までをダンプ表示
;   第2引数がなければ第1引数から256バイト
; -------------------------------------------------------------------
DUMP:
  RMB0 SETTING
DUMP1:
  ;DUMP_SUB_FUNCPTR=ZR3 ; データ表示/アスキー表示関数ポインタ
  ; ---------------------------------------------------------------
  ;   引数の数に応じた処理
  ;LDA CMD_ARG_NUM
  ;BEQ @END              ; 引数ゼロなら何もしない
  ;CMP #2
  ;BEQ @SET_ZR3          ; 2でないなら、ARG1+63をARG2にする
  ;LDA CMD_ARG_1
  ;CLC
  ;;ADC #63
  ;ADC #128-1
  ;STA CMD_ARG_2
  ;LDA CMD_ARG_1+1
  ;ADC #0
  ;STA CMD_ARG_2+1
  loadmem16 CMD_ARG_1,TEXT
  loadmem16 CMD_ARG_2,TEXT+127
  BRA @SET_ZR3
  ; ---------------------------------------------------------------
  ;   ループ
@LINE:
  ; アドレス表示部すっ飛ばすか否かの判断
  BBS0 SETTING,@PRT_ADDR ; ワイドモード:アドレス毎行表示
  DEC ZP_LINE
  BNE @DATA
@SET_ZR3:
  LDA #4
  STA ZP_LINE
  ; ---------------------------------------------------------------
  ;   アドレス表示部
  ;"<1234>--------------------------"
  JSR PRT_LF            ; 視認性向上のための空行は行の下にした方がよさそうだが、
@PRT_ADDR:
  JSR PRT_LF            ;   最大の情報を表示しつつ作業用コマンドラインを出すにはこうする。
  LDA #'<'              ; アドレス左修飾
  syscall CON_OUT_CHR
  LDA CMD_ARG_1+1       ; アドレス上位
  JSR PRT_BYT
  LDA CMD_ARG_1         ; アドレス下位
  JSR PRT_BYT
  LDA #'>'              ; アドレス右修飾
  syscall CON_OUT_CHR
  BBS0 SETTING,@DATA_NOLF    ; ワイドモード:ハイフンスキップ
  LDA #'-'
  LDX #32-(4+2)         ; 画面幅からこれまで表示したものを減算
  JSR PRT_FEW_CHARS     ; 画面右までハイフン
  ; ---------------------------------------------------------------
  ;   データ表示部
@DATA:
  JSR PRT_LF
@DATA_NOLF:
  ;loadmem16 DUMP_SUB_FUNCPTR,DUMP_SUB_DATA
  pushmem16 CMD_ARG_1
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
  pullmem16 CMD_ARG_1
  LDA #<(DUMP_SUB_ASCII-(DUMP_SUB_BRA+2))
  JSR DUMP_SUB
  BEQ @LINE
@END:
  JMP LOOP

; ポインタ切り替えでHEXかASCIIを表示する
DUMP_SUB:
  STA DUMP_SUB_BRA+1
  BBS0 SETTING,@SKP8  ; ワイドモード:1行16バイト
  LDX #8              ; X=行ダウンカウンタ
  BRA DATALOOP
@SKP8:
  LDX #16
DATALOOP:
  LDA (CMD_ARG_1)     ; バイト取得
  PHX
  ;JMP (DUMP_SUB_FUNCPTR)
DUMP_SUB_BRA:
  .BYTE $80 ; BRA
  .BYTE $00
DUMP_SUB_RETURN:
  PLX
  ; 終了チェック
  LDA CMD_ARG_1+1
  CMP CMD_ARG_2+1
  BNE @SKP_ENDCHECK_LOW
  LDA CMD_ARG_1
  CMP CMD_ARG_2
  BEQ @END_DATALOOP
@SKP_ENDCHECK_LOW:
  inc16 CMD_ARG_1   ; アドレスインクリメント
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
  syscall CON_OUT_CHR
  BRA DUMP_SUB_RETURN
PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
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
  BRA PRT_C_CALL

PRT_FEW_CHARS:
  ; Xレジスタで文字数を指定
  PHA
  PHX
  syscall CON_OUT_CHR
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

