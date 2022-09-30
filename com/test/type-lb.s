; -------------------------------------------------------------------
;                            TYPE-LB.COM
; -------------------------------------------------------------------
; LFのたびに表示を止めるTYPE
; 行志向のスクリプト処理の布石
; バッファリングバージョン
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

LF=10

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
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
LOOP:
  ; ロード
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,ONECHR            ; 書き込み先
  loadAY16 1                      ; 1文字だけ！
  syscall FS_READ_BYTS            ; ロード
  BCS @CLOSE                      ; 最終バイトなら表示しない
  LDA ONECHR
  CMP #LF
  BNE @SKP_WAIT                   ; 非改行なら待機しない
  ; 改行文字
@RAWIN:
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho
  syscall CON_RAWIN
  CMP #LF
  BNE @RAWIN
@SKP_WAIT:
  ; 出力
  LDA ONECHR
  syscall CON_OUT_CHR
  ; 最終バイトがあるとき
  ; クローズ
@CLOSE:
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
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

PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

