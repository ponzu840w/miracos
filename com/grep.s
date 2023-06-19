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
  LINE_BUF_PTR:   .RES 2

FILE_BUF_SIZE = 512

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ---------------------------------------------------------------
  ;   初期化
  ; ---------------------------------------------------------------
  storeAY16 ZR0                   ; ZR0=arg
  STZ FILE_BUF+FILE_BUF_SIZE      ; バッファ終端設定
  loadmem16 LINE_BUF_PTR,LINE_BUF ; 行バッファポインタ初期化

  ; ---------------------------------------------------------------
  ;   コマンドライン引数処理
  ; ---------------------------------------------------------------
  ;   PATTERN文字列の取得
  LDA #'*'
  STA PATTERN                     ; 1文字目は*
  LDY #255
@LOOP:
  INY
  LDA (ZR0),Y
  BEQ @NOTFOUND1                  ; ヌル文字があったら、ファイル指定がない
  CMP #'\'
  BNE @SKP_BSL                    ; \エスケープ
  INY
  LDA (ZR0),Y
  STA PATTERN+1,Y
  BRA @LOOP
@SKP_BSL:
  STA PATTERN+1,Y
  CMP #' '
  BNE @LOOP
  LDA #'*'
  STA PATTERN+1,Y
  LDA #0
  STA PATTERN+2,Y
  ; debug
  PHY
  loadAY16 PATTERN
  syscall CON_OUT_STR
  PLY
  ; ---------------------------------------------------------------
  ;   ファイルパス文字列の取得
  ; ZR0 <- path*
  ; 次にスペース以外が出るまで進める
@SPNEXT:
  INY
  LDA (ZR0),Y
  CMP #' '
  BEQ @SPNEXT
  ; ZR0に反映する
  TYA
  CLC
  ADC ZR0
  STA ZR0
  LDA #0
  ADC ZR0+1
  STA ZR0+1
  ; nullチェック
  LDA (ZR0)
@NOTFOUND1:
  BEQ NOTFOUND
  mem2AY16 ZR0
  ; ---------------------------------------------------------------
  ;   ファイルオープン
  syscall FS_FIND_FST             ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ

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
  JSR INC_FILE_BUF_PTR            ; ファイルバッファポインタを進める
  JSR INC_LINE_BUF_PTR            ; 行バッファポインタを進める
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

PATTERNMATCH:                   ; http://www.6502.org/source/strings/patmatch.htm by Paul Guertin
  LDX #0                        ; PATTERNのインデックス
  loadmem16 LINE_BUF_PTR,LINE_BUF
@NEXT:
  LDA PATTERN,X                 ; 次のパターン文字を見る
  CMP #'*'                      ; スターか？
  BEQ @STAR
  JSR INC_LINE_BUF_PTR
  CMP #'?'                      ; ハテナか
  BNE @REG                      ; スターでもはてなでもないので普通の文字
  LDA (LINE_BUF_PTR)            ; ハテナなのでなんにでもマッチする（同じ文字をロードしておいて比較する）
  BEQ @FAIL                     ; 終了ならマッチしない
@REG:
  CMP (LINE_BUF_PTR)            ; 文字が等しいか？
  BEQ @EQ
  syscall UPPER_CHR             ; 大文字ではどうか
  CMP (LINE_BUF_PTR)            ; 文字が等しいか2
  BNE @FAIL
@EQ:
  INX                           ; 合っている、続けよう
  CMP #0                        ; これらは終端か
  BNE @NEXT
@FOUND:
  RTS                           ; 成功したのでC=1を返す（SECしなくてよいのか）
@STAR:
  INX                           ; ZR2パターンの*をスキップ
  CMP PATTERN,X                 ; 連続する*は一つの*に等しい
  BEQ @STAR                     ; のでスキップする
@STLOOP:
  PHX
  JSR @NEXT
  PLX
  BCS @FOUND                    ; マッチしたらC=1が帰る
  JSR INC_LINE_BUF_PTR          ; マッチしなかったら*を成長させる
  LDA (LINE_BUF_PTR)            ; 終端か
  BNE @STLOOP
@FAIL:
  CLC                           ; マッチしなかったらC=0が帰る
  RTS

; LINE_BUF_PTR++
INC_FILE_BUF_PTR:
  INC FILE_BUF_PTR
  BNE @SKP_INCFILEPTR
  INC FILE_BUF_PTR+1
@SKP_INCFILEPTR:
  RTS

; FILE_BUF_PTR++
INC_LINE_BUF_PTR:
  INC LINE_BUF_PTR
  BNE @SKP_INCLINEPTR
  INC LINE_BUF_PTR+1
@SKP_INCLINEPTR:
  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

; -------------------------------------------------------------------
;                            変数領域
; -------------------------------------------------------------------
.BSS
PATTERN:        .RES 256
FILE_BUF:       .RES FILE_BUF_SIZE+1
LINE_BUF:

