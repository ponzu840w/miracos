; -------------------------------------------------------------------
;                           GREPコマンド
; -------------------------------------------------------------------
; テキストファイルを読み、パターンに一致した行のみを表示する
; -------------------------------------------------------------------
.INCLUDE "../generic.mac"     ; 汎用マクロ
.PROC BCOS
  .INCLUDE "../syscall.inc"   ; システムコール番号定義
.ENDPROC
.INCLUDE "../syscall.mac"     ; 簡単システムコールマクロ
.INCLUDE "../FXT65.inc"       ; ハードウェア定義
.INCLUDE "../fs/structfs.s"   ; ファイルシステム関連構造体定義
.INCLUDE "../zr.inc"          ; ZPレジスタZR0..ZR5

; -------------------------------------------------------------------
;                             ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO
  FILE_BUF_PTR:   .RES 2  ; ファイルバッファ上のどこかを指すポインタ
  LINE_BUF_PTR:   .RES 1

FILE_BUF_SIZE = 512

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ---------------------------------------------------------------
  ;   初期化
  ; ---------------------------------------------------------------
  STZ FILE_BUF+FILE_BUF_SIZE      ;   バッファ終端設定
  ; ---------------------------------------------------------------
  ;   コマンドライン引数処理
  storeAY16 ZR0                   ; ZR0=arg
  ; nullチェック
  TAX
  LDA (ZR0)
  BEQ NOTFOUND
  TXA
  ; ---------------------------------------------------------------
  ;   ファイルオープン
  syscall FS_FIND_FST             ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ

  loadmem16 LINE_BUF_PTR,LINE_BUF

  ; ---------------------------------------------------------------
  ;   バッファへのデータロード
LOAD_FILE:
  LDA FD_SAV
  STA ZR1                         ; ZR1 = FD
  loadmem16 ZR0,FILE_BUF          ; ZR0 = 書き込み先
  loadAY16 FILE_BUF_SIZE          ; AY  = 読み取り長さ
  syscall FS_READ_BYTS            ; 以上設定で読み取り
  ; ---------------------------------------------------------------
  ;   ロード結果への対応
  BCS CLOSE                       ; 初手EOF -> 終了
  CLC                             ; *
  ADC #<FILE_BUF                  ; | *FILE_BUF_PTR = &FILE_BUF + len;
  STA FILE_BUF_PTR                ; |
  TYA                             ; |
  ADC #>FILE_BUF                  ; |
  STA FILE_BUF_PTR+1              ; |
  LDA #0
  STA (FILE_BUF_PTR)              ; 終端
  ; ---------------------------------------------------------------
  ;   バッファ->行バッファ
  loadmem16 FILE_BUF_PTR,FILE_BUF
LOAD_LINE:
  LDA (FILE_BUF_PTR)              ; バッファから1文字取得
  BEQ LOAD_FILE                   ; それが終端ならファイルロード
  STA (LINE_BUF_PTR)              ; 行バッファに書き出し
  BEQ LOAD_FILE
  ; FILE_BUF_PTR++
  INC FILE_BUF_PTR
  BNE @SKP_INCFILEPTR
  INC FILE_BUF_PTR+1
@SKP_INCFILEPTR:
  ; LINE_BUF_PTR++
  INC LINE_BUF_PTR
  BNE @SKP_INCLINEPTR
  INC LINE_BUF_PTR+1
@SKP_INCLINEPTR:
  ; 改行までループ
  CMP #$A
  BNE LOAD_LINE
  ; ---------------------------------------------------------------
  ;   行バッファ終端設置
  LDA #0
  STA (LINE_BUF_PTR)
  ; ---------------------------------------------------------------
  ;   行バッファ内容の出力
  loadAY16 LINE_BUF
  syscall CON_OUT_STR
  loadmem16 LINE_BUF_PTR,LINE_BUF
  BRA LOAD_LINE

; ファイルがないとき
NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

  ; ---------------------------------------------------------------
  ;   終了処理
  ; ---------------------------------------------------------------
CLOSE:
  ; ファイルクローズ
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  RTS

; カーネルエラーのとき
BCOS_ERROR:
  LDA #$A
  syscall CON_OUT_CHR
  syscall ERR_GET
  syscall ERR_MES
  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

; -------------------------------------------------------------------
;                            バッファ領域
; -------------------------------------------------------------------
.BSS
FILE_BUF:       .RES FILE_BUF_SIZE+1
LINE_BUF:

