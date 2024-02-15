; -------------------------------------------------------------------
;                             RXSREC.COM
; -------------------------------------------------------------------
; Sレコードをバイナリファイルに変換して保存する。
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.INCLUDE "../zr.inc"          ; ZPレジスタZR0..ZR5

; -------------------------------------------------------------------
;                             定数宣言
; -------------------------------------------------------------------
.PROC CONDEV
  ; ZP_CON_DEV_CFGでのコンソールデバイス
  UART_IN   = %00000001
  UART_OUT  = %00000010
  PS2       = %00000100
  GCON      = %00001000
.ENDPROC
EOT = $04 ; EOFでもある

BUFFER_SIZE = 256
FNAME_SIZE  = 64

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
BUFFER:             .RES BUFFER_SIZE
FNAME_OUT:          .RES FNAME_SIZE

; -------------------------------------------------------------------
;                             ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
  FD_SAV:           .RES 1    ; ファイル記述子
  ZP_CONCFG_ADDR16: .RES 2    ; 取得した設定値のアドレス
  ZP_CONDEV_SAV:    .RES 1    ; コンソールデバイス設定の控え
  ZP_CKSM:        .RES 1
  ZP_REC_BYTCNT:    .RES 1    ; レコードのデータ量は何バイトあるべきか
  ZP_BUF_INDEX:     .RES 1    ; 書き込みバッファの現在インデックス
  ZP_TOTAL_BYTCNT:  .RES 5    ; 十進10桁あれば4バイト値MAXも表現可能
  ZP_TOTAL_BYTCNT_F:.RES 1    ; 表示時の0以外初登場のフラグ
  ZP_STACK_BASE:    .RES 1    ; 帰るべきところ

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ---------------------------------------------------------------
  ;   スタックのセーブ
  TSX
  STX ZP_STACK_BASE
  ; ---------------------------------------------------------------
  ;   コマンドライン引数処理
  storeAY16 ZR0               ; ZR0=arg
  LDA (ZR0)                   ; if(!CMDARG[0])
  BEQ SHOW_USAGE              ;     SHOW_USAGE();
  LDY #$FF                    ; *
  loadmem16 ZR1,FNAME_OUT     ; |
@LOOP:                        ; |
  INY                         ; | strcpy(FNAME_OUT, CMDARG);
  LDA (ZR0),Y                 ; |
  STA (ZR1),Y                 ; |
  BNE @LOOP                   ; |
  ; ---------------------------------------------------------------
  ;   ファイルオープン前のメッセージ
  loadAY16 STR_OPENING
  syscall CON_OUT_STR
  ; ---------------------------------------------------------------
  ;   ファイルオープン
  loadAY16 FNAME_OUT
  LDX #1
  STX ZR0
  syscall FS_OPEN                 ; ファイルをオープン
  STA FD_SAV                      ; ファイル記述子をセーブ
  loadAY16 FNAME_OUT
  BCC @SKP_MAKE
  LDX #0
  STX ZR0                         ; ファイルアトリビュート
  syscall FS_MAKE                 ; 無ければ作成
  BCS MAKE_FAIL
  STA FD_SAV                      ; ファイル記述子をセーブ
@SKP_MAKE:
  ; ---------------------------------------------------------------
  ;   コンソールデバイス制御を取得
  LDY #BCOS::BHY_GET_ADDR_condevcfg   ; コンソールデバイス設定のアドレスを要求
  syscall GET_ADDR                    ; アドレス要求
  storeAY16 ZP_CONCFG_ADDR16          ; アドレス保存
  LDA (ZP_CONCFG_ADDR16)
  STA ZP_CONDEV_SAV                   ; 初期設定を控える
  ; ---------------------------------------------------------------
  ;   コンソールデバイスの設定
  ;       割り込み不能期間が長く取りこぼしの原因となるPS/2を排除
  LDA #CONDEV::UART_IN|CONDEV::UART_OUT|CONDEV::GCON
  AND ZP_CONDEV_SAV
  STA (ZP_CONCFG_ADDR16)
  ; ---------------------------------------------------------------
  ;   受信バイト数カウンタ初期化
  STZ ZP_TOTAL_BYTCNT
  STZ ZP_TOTAL_BYTCNT+1
  STZ ZP_TOTAL_BYTCNT+2
  STZ ZP_TOTAL_BYTCNT+3
  STZ ZP_TOTAL_BYTCNT+4
  ; ---------------------------------------------------------------
  ;   受信
  ; ---------------------------------------------------------------
  ;   プロンプトメッセージ
  loadAY16 STR_COMEON
  syscall CON_OUT_STR
  BRA LOAD

; ---------------------------------------------------------------
;   FDを閉じ、スタックを戻して親プロセスに戻る
EXIT:
  LDA FD_SAV
  syscall FS_CLOSE
  LDX ZP_STACK_BASE
  TXS
  RTS

; ---------------------------------------------------------------
;   1文字入力するが、Ctrl-Dなら強制終了する
INPUT_WITH_TRAP:
  syscall CON_IN_CHR_RPD
  CMP #EOT
  BEQ EXIT
  RTS

; ---------------------------------------------------------------
;   使用法表示
SHOW_USAGE:
  loadAY16 STR_SHOWUSAGE
  syscall CON_OUT_STR
  RTS

; ---------------------------------------------------------------
;   ファイル作成失敗
MAKE_FAIL:
; ---------------------------------------------------------------
;   BCOSエラーの取得と表示
BCOS_ERROR:
  LDA #$A
  syscall CON_OUT_CHR
  syscall ERR_GET
  syscall ERR_MES
  RTS

LOAD_SKIPLAST2:
  JMP LOAD_SKIPLAST

LOAD:
  STZ ZP_BUF_INDEX
  ; ---------------------------------------------------------------
  ;   Sレコード種類判別
LOAD_CHECKTYPE:
  JSR INPUT_WITH_TRAP
  CMP #'S'
  BNE LOAD_CHECKTYPE  ; 最初の文字がSじゃないというのはありえないが
  JSR INPUT_WITH_TRAP
  CMP #'9'
  BEQ LOAD_SKIPLAST2  ; 最終レコード
  CMP #'1'
  BNE LOAD_CHECKTYPE  ; S1以外のレコードはどうでもいい
  ; ---------------------------------------------------------------
  ;   S1レコード --- レコード長 ---
  STZ ZP_CKSM
  JSR INPUT_BYT
  SEC                   ; アドレス部の2バイトを減算
  SBC #$2               ;
  STA ZP_REC_BYTCNT     ; BYTCNT <- データ部+CSUMのバイト数
  DEC
  JSR ADD_TO_TOTAL      ; TOTAL += データ部のバイト数（十進で）
  ; ---------------------------------------------------------------
  ;   S1レコード --- アドレス部 ---（完全無視）
  JSR INPUT_BYT
  JSR INPUT_BYT
  ; ---------------------------------------------------------------
  ;   S1レコード --- データ部 ---
LOAD_STORE_DATA:
  JSR INPUT_BYT
  DEC ZP_REC_BYTCNT
  BEQ EVAL_CHECKSUM  ; 全バイト読んだ
  LDY ZP_BUF_INDEX
  STA BUFFER,Y          ; Zero Page Indirect
  INY
  STY ZP_BUF_INDEX
  .IF BUFFER_SIZE <> 256
    CPY #BUFFER_SIZE
  .ENDIF
  BNE LOAD_STORE_DATA
  .IF BUFFER_SIZE <> 256
    STZ ZP_BUF_INDEX
  .ENDIF
  ; ---------------------------------------------------------------
  ;   バッファ満杯時のファイル書き込み
  LDA #'~'              ; 書き込みメッセージ
  syscall CON_OUT_CHR
  LDA FD_SAV
  STA ZR1
  loadmem16 ZR0,BUFFER
  loadAY16 BUFFER_SIZE
  syscall FS_WRITE
  BCS SHOW_ERROR_AND_EXIT
  BRA LOAD_STORE_DATA
  ; ---------------------------------------------------------------
  ;   S1レコード終了時のチェックサム評価
EVAL_CHECKSUM:
  INC ZP_CKSM         ; チェックサムが256でOK
  BNE BROKEN_RECORD
  JMP LOAD_CHECKTYPE
  ; ---------------------------------------------------------------
  ;   S9レコード --- 価値がないので読み飛ばす ---
LOAD_SKIPLAST:
  syscall CON_IN_CHR_RPD
  CMP #EOT
  BNE LOAD_SKIPLAST
  ; ---------------------------------------------------------------
  ;   データ終了時のバッファ書き込み
FLASH_AND_EXIT:
  LDA #'~'              ; 書き込みメッセージ
  syscall CON_OUT_CHR
  LDA ZP_BUF_INDEX
  BEQ @SKP_FLASH        ; バッファが空ならフラッシュ動作不要
  ; バッファのフラッシュ動作
  LDA FD_SAV
  STA ZR1
  loadmem16 ZR0,BUFFER
  LDY #0
  LDA ZP_BUF_INDEX
  syscall FS_WRITE
  BCS SHOW_ERROR_AND_EXIT
@SKP_FLASH:

; ---------------------------------------------------------------
;   転送が完全に完了
COMPLETE:
  JSR PRT_LF
  JSR PRT_TOTAL_BYTCNT
  loadAY16 STR_COMPLETE
  syscall CON_OUT_STR
  JMP EXIT

; ---------------------------------------------------------------
;   BCOSエラーを表示してから丁寧にプロセスをたたむ
SHOW_ERROR_AND_EXIT:
  JSR BCOS_ERROR
  JMP EXIT

; ---------------------------------------------------------------
;   壊れたレコードに対する終了処理
BROKEN_RECORD:
  loadAY16 STR_BROKEN
  syscall CON_OUT_STR
  JMP EXIT

; Aレジスタに2桁のhexを値として取り込み
INPUT_BYT:
  JSR INPUT_WITH_TRAP
  CMP #$0A      ; 改行だったらCTRLに戻る
  BEQ BROKEN_RECORD
  JSR CHR2NIB
  ASL
  ASL
  ASL
  ASL
  STA ZR0       ; LOADしか使わないだろうから大丈夫だろう
  JSR INPUT_WITH_TRAP
  JSR CHR2NIB
  ORA ZR0
  STA ZR0
  CLC           ; * チェックサム加算
  ADC ZP_CKSM   ; |
  STA ZP_CKSM   ; |
  LDA ZR0
  RTS

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
  BRA PRT_C_CALL

PRT_BYT_S:
  JSR PRT_BYT
PRT_S:
  ; スペース
  LDA #' '
  BRA PRT_C_CALL

; *
; --- Aレジスタの一文字をNibbleとして値にする ---
; *
CHR2NIB:
  syscall UPPER_CHR
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

; 二進化十進数5バイトを表示
PRT_TOTAL_BYTCNT:
  STZ ZP_TOTAL_BYTCNT_F
  LDA ZP_TOTAL_BYTCNT+4
  JSR PRT_BYT_SKP0
  LDA ZP_TOTAL_BYTCNT+3
  JSR PRT_BYT_SKP0
  LDA ZP_TOTAL_BYTCNT+2
  JSR PRT_BYT_SKP0
  LDA ZP_TOTAL_BYTCNT+1
  JSR PRT_BYT_SKP0
  LDA ZP_TOTAL_BYTCNT
  JSR PRT_BYT_SKP0
  RTS

PRT_BYT_SKP0:
  JSR BYT2ASC
  PHY
  JSR @PRT_C_CALL
  PLA
@PRT_C_CALL:
  BBS0 ZP_TOTAL_BYTCNT_F,PRT_C_CALL
  CMP #'0'
  BEQ @_RTS
  syscall CON_OUT_CHR
  SMB0 ZP_TOTAL_BYTCNT_F
@_RTS:
  RTS

; Aを二進化十進数にしてZR0に格納する
DECIMAL:
  STZ ZR0
  STZ ZR0+1
@LOOP100:
  SEC
  SBC #100
  INC ZR0+1
  BCS @LOOP100
  DEC ZR0+1
  ADC #100
@LOOP10:
  SEC
  SBC #10
  INC ZR0
  BCS @LOOP10
  DEC ZR0
  ADC #10
  CLC
  ASL ZR0
  ASL ZR0
  ASL ZR0
  ASL ZR0
  ORA ZR0
  STA ZR0
  RTS

ADD_TO_TOTAL:
  ; 総バイト数に加算
  JSR DECIMAL
  SED
  CLC
  LDA ZR0
  ADC ZP_TOTAL_BYTCNT
  STA ZP_TOTAL_BYTCNT
  LDA ZR0+1
  ADC ZP_TOTAL_BYTCNT+1
  STA ZP_TOTAL_BYTCNT+1
  LDA #0
  ADC ZP_TOTAL_BYTCNT+2
  STA ZP_TOTAL_BYTCNT+2
  LDA #0
  ADC ZP_TOTAL_BYTCNT+3
  STA ZP_TOTAL_BYTCNT+3
  LDA #0
  ADC ZP_TOTAL_BYTCNT+4
  STA ZP_TOTAL_BYTCNT+4
  CLD
  RTS

STR_SHOWUSAGE:
  .BYT "Usage: RXSREC <OUTFILE>",$A,$0

STR_BROKEN:
  .BYT "Broken record.",$A,$0

STR_COMPLETE:
  .BYT " bytes completed!",$A,$0

STR_OPENING:
  .BYT "Wait... ",$A,$0

STR_COMEON:
  .BYT "Send S-Records. Abort with Ctrl-D",$A,$0

