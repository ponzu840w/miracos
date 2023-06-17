; -------------------------------------------------------------------
;                            TYPEコマンド
; -------------------------------------------------------------------
; テキストファイルを打ち出す
; -------------------------------------------------------------------
.INCLUDE "../generic.mac"     ; 汎用マクロ
.PROC BCOS
  .INCLUDE "../syscall.inc"   ; システムコール番号定義
.ENDPROC
.INCLUDE "../syscall.mac"     ; 簡単システムコールマクロ
.INCLUDE "../FXT65.inc"       ; ハードウェア定義
.INCLUDE "../fs/structfs.s"   ; ファイルシステム関連構造体定義
.INCLUDE "../zr.inc"          ; ZPレジスタZR0..ZR5

FILE_BUF_SIZE = 512

; -------------------------------------------------------------------
;                             ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
  FD_SAV:         .RES 1    ; ファイル記述子
  FINFO_SAV:      .RES 2    ; FINFO
  FILE_BUF_PTR:   .RES 2    ; ファイルバッファ上のどこかを指すポインタ

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ---------------------------------------------------------------
  ;   初期化
  ; ---------------------------------------------------------------
  ;   バッファ終端設定
  STZ FILE_BUF+FILE_BUF_SIZE
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

  ; ---------------------------------------------------------------
  ;   メインループ
  ; ---------------------------------------------------------------
LOOP:
  ; ---------------------------------------------------------------
  ;   バッファへのデータロード
  LDA FD_SAV
  STA ZR1                         ; ZR1 = FD
  loadmem16 ZR0,FILE_BUF          ; ZR0 = 書き込み先
  loadAY16 FILE_BUF_SIZE          ; AY  = 読み取り長さ
  syscall FS_READ_BYTS            ; 以上設定で読み取り
  ; ---------------------------------------------------------------
  ;   ロード結果への対応
  BCS @CLOSE                      ; 初手EOF -> 終了
  CLC                             ; *
  ADC #<FILE_BUF                  ; | *FILE_BUF_PTR = &FILE_BUF + len;
  STA FILE_BUF_PTR                ; |
  TYA                             ; |
  ADC #>FILE_BUF                  ; |
  STA FILE_BUF_PTR+1              ; |
  LDA #0
  STA (FILE_BUF_PTR)              ; 終端
  ; ---------------------------------------------------------------
  ;   バッファ内容の出力
  loadAY16 FILE_BUF
  syscall CON_OUT_STR
  BRA LOOP

  ; ---------------------------------------------------------------
  ;   終了処理
  ; ---------------------------------------------------------------
@CLOSE:
  ; ファイルクローズ
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  RTS

; ファイルがないとき
NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
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
FILE_BUF:

