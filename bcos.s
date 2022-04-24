; -------------------------------------------------------------------
;                           MIRACOS BCOS
; -------------------------------------------------------------------
; MIRACOSの本体
; CP/MでいうところのBIOSとBDOSを混然一体としたもの
; ファンクションコール・インタフェース（特に意味はない）
; -------------------------------------------------------------------
.INCLUDE "FXT65.inc"
.INCLUDE "generic.mac"
.INCLUDE "fscons.inc"

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

; -------------------------------------------------------------------
;                             変数宣言
; -------------------------------------------------------------------
; 変数領域宣言（ZP）
.ZEROPAGE
  .PROC ROMZ
    .INCLUDE "zpmon.s"  ; モニタ用領域は確保するが、それ以外は無視
  .ENDPROC
  .INCLUDE "gcon/zpgcon.s"
  .INCLUDE "fs/zpfs.s"
  .INCLUDE "zpbcos.s"

; 変数領域定義
.SEGMENT "MONVAR"
  .PROC ROM
    .INCLUDE "varmon.s"
  .ENDPROC
  .INCLUDE "fs/structfs.s"
  .INCLUDE "fs/varfs.s"
  .INCLUDE "varbcos.s"
  .INCLUDE "gcon/vargcon.s"

; OS側変数領域
.SEGMENT "COSVAR"
  .INCLUDE "fs/varfs2.s"

; ROMとの共通バッファ
.SEGMENT "ROMBF100"         ; $0200~
  CONINBF_BASE:   .RES 256  ; UART受信用リングバッファ
  SECBF512:       .RES 512  ; SDカード用セクタバッファ

; OS独自バッファ
.SEGMENT "COSBF100"
  TXTVRAM768:     .RES 768  ; テキストVRAM3ページ
  FONT2048:       .RES 2048 ; フォントグリフ8ページ

; ROMからのインポート
ZR0 = ROMZ::ZR0
ZR1 = ROMZ::ZR1
ZR2 = ROMZ::ZR2
ZR3 = ROMZ::ZR3
ZR4 = ROMZ::ZR4
ZR5 = ROMZ::ZR5
ZP_CONINBF_WR_P = ROMZ::ZP_INPUT_BF_WR_P
ZP_CONINBF_RD_P = ROMZ::ZP_INPUT_BF_RD_P
ZP_CONINBF_LEN  = ROMZ::ZP_INPUT_BF_LEN

.SCOPE
  .INCLUDE "ccp.s"
.ENDSCOPE

; -------------------------------------------------------------------
;                             BCOS本体
; -------------------------------------------------------------------

; -------------------------------------------------------------------
;                           下位モジュール
; -------------------------------------------------------------------
.SEGMENT "COSLIB"
  .INCLUDE "fs/fsmac.mac"
  .PROC ERR
    .INCLUDE "error.s"
  .ENDPROC
  .PROC BCOS_UART ; 単にUARTとするとアドレス宣言とかぶる
    .INCLUDE "uart.s"
  .ENDPROC
  .PROC SPI
    .INCLUDE "fs/spi.s"
  .ENDPROC
  .PROC SD
    .INCLUDE "fs/sd.s"
  .ENDPROC
  .PROC FS
    .INCLUDE "fs/fs.s"
  .ENDPROC
  .PROC GCHR
    .INCLUDE "gcon/gchr.s"
  .ENDPROC
  .PROC GCON
    .INCLUDE "gcon/gcon.s"
  .ENDPROC

; -------------------------------------------------------------------
;                       システムコールテーブル
; -------------------------------------------------------------------
; 別バイナリ（SYSCALL.BIN）で出力され、$0600にあとから配置される
; -------------------------------------------------------------------
.SEGMENT "SYSCALL"
; システムコール ジャンプテーブル $0600
  JMP FUNC_RESET
SYSCALL:
  JMP (SYSCALL_TABLE,X) ; 呼び出し規約：Xにコール番号*2を格納してJSR $0603
SYSCALL_TABLE:
  .WORD FUNC_RESET          ; 0 リセット、CCPロード部分に変更予定
  .WORD FUNC_CON_IN_CHR     ; 1 コンソール入力
  .WORD FUNC_CON_OUT_CHR    ; 2 コンソール出力
  .WORD FUNC_CON_RAWIN      ; 3 コンソール生入力
  .WORD FUNC_CON_OUT_STR    ; 4 コンソール文字列出力
  .WORD FS::FUNC_FS_OPEN    ; 5 ファイル記述子オープン
  .WORD FS::FUNC_FS_CLOSE   ; 6 ファイル記述子クローズ
  .WORD FUNC_CON_IN_STR     ; 7 バッファ行入力
  .WORD GCHR::FUNC_GCHR_COL ; 8 2色テキスト画面パレット操作
  .WORD FS::FUNC_FS_FIND_FST; 9 最初のエントリの検索
  .WORD FS::FUNC_FS_PURSE   ; 10 パス文字列の解析
  .WORD FS::FUNC_FS_CHDIR   ; 11 カレントディレクトリ変更
  .WORD FS::FUNC_FS_FPATH   ; 12 絶対パス取得
  .WORD ERR::FUNC_ERR_GET   ; 13 エラー番号取得
  .WORD ERR::FUNC_ERR_MES   ; 14 エラー表示

; -------------------------------------------------------------------
;                       システムコールの実ルーチン
; -------------------------------------------------------------------
; 下位モジュールにもFUNC_ルーチンはある
; -------------------------------------------------------------------

.SEGMENT "COSCODE"

; -------------------------------------------------------------------
; BCOS 0                        リセット
; -------------------------------------------------------------------
; BDOS 0
; 各種モジュールを初期化して、CCPをロードし、CCPに飛ぶ
; ホットスタートをするなら初期化処理はすっ飛ばすべきか？
; -------------------------------------------------------------------
FUNC_RESET:
  LDA #CONDEV::UART_IN|CONDEV::UART_OUT|CONDEV::GCON
  STA ZP_CON_DEV_CFG              ; 有効なコンソールデバイスの設定
  JSR FS::INIT                    ; ファイルシステムの初期化処理
  JSR GCON::INIT                  ; コンソール画面の初期化処理
  ; TODO: SYSCALL.BINを配置する
  ; TODO: CCP.COMを配置する
  JMP $5000                       ; TPAへ飛ぶ
  ;RTS

TEST:
  loadAY16 STR_TEST
  JSR FUNC_CON_OUT_STR
@LOOP:
  JSR FUNC_CON_IN_CHR
  BRA @LOOP

STR_TEST: .BYT "hello,BCOS.",$A,$0

; -------------------------------------------------------------------
; BCOS 1                  コンソール文字入力
; -------------------------------------------------------------------
; BDOS 1
; 一文字入力する。なければ入力を待つ。
; 何らかのキーで中断する？（CTRL+C？）
; 使う場面がわからない…（改行もエコーするよこれ）
; -------------------------------------------------------------------
FUNC_CON_IN_CHR:
  LDA #$2
  JSR FUNC_CON_RAWIN      ; 待機入力するがエコーしない
  JSR FUNC_CON_OUT_CHR    ; エコー
  RTS

; -------------------------------------------------------------------
; BCOS 2                  コンソール文字出力
; -------------------------------------------------------------------
; BDOS 2
; input:A=char
; コンソールから（CTRL+S）が押されると一時停止？
; -------------------------------------------------------------------
FUNC_CON_OUT_CHR:
  BBR1  ZP_CON_DEV_CFG,@SKP_UART    ; UART_OUTが無効ならスキップ
  JSR BCOS_UART::OUT_CHR
@SKP_UART:
  BBR3  ZP_CON_DEV_CFG,@SKP_GCON    ; GCONが無効ならスキップ
  PHA
  JSR GCON::PUTC
  PLA
@SKP_GCON:
  RTS

; -------------------------------------------------------------------
; BCOS 6                 コンソール文字生入力
; -------------------------------------------------------------------
; BDOS 3
; input:A=動作選択
;   A=$0:コンソール入力状況を返す
;   A=$1:コンソール入力があれば返すがエコーしない
;   A=$2:文字入力があるまで待機して返し、エコーしない
; output:A=獲得文字/$00（バッファなし）
; -------------------------------------------------------------------
FUNC_CON_RAWIN:
  BIT #$FF
  BNE @NOT_BUFLEN
  ; 入力状況を返すだけ
  LDA ZP_CONINBF_LEN
  RTS
@NOT_BUFLEN:            ; 待機するかしないか、エコーせずに返す
  ROR
  BCS @SKP_WAIT         ; FDでなければ（FFなら）待機はしない
@WAIT:
  LDA ZP_CONINBF_LEN
  BEQ @WAIT             ; バッファに何もないなら待つ
@SKP_WAIT:
C_RAWWAITIN:
  LDA ZP_CONINBF_LEN
  BEQ END               ; バッファに何もないなら0を返す
  LDX ZP_CONINBF_RD_P   ; インデックス
  LDA CONINBF_BASE,X    ; バッファから読む、ここからRTSまでA使わない
  INC ZP_CONINBF_RD_P   ; 読み取りポインタ増加
  DEC ZP_CONINBF_LEN    ; 残りバッファ減少
  LDX ZP_CONINBF_LEN
  CPX #$80              ; LEN - $80
  BNE END               ; バッファに余裕があれば毎度XON送ってた…？
  ; UARTが有効なら、RTS再開
  BBR0 ZP_CON_DEV_CFG,END
  PHA
  LDA #UART::XON
  JSR BCOS_UART::OUT_CHR
  PLA
END:
  RTS

; -------------------------------------------------------------------
; BCOS 4                 コンソール文字列出力
; -------------------------------------------------------------------
; input:AY=str
; コンソールから（CTRL+S）が押されると一時停止？
; -------------------------------------------------------------------
FUNC_CON_OUT_STR:
  STA ZR5
  STY ZR5+1                   ; ZR5を文字列インデックスに
  LDY #$FF
@LOOP:
  INY
  LDA (ZR5),Y                 ; 文字をロード
  BEQ END                     ; ヌルなら終わり
  PHY
  JSR FUNC_CON_OUT_CHR        ; 文字を表示（独自にした方が効率的かも）
  PLY
  BRA @LOOP                   ; ループ

; -------------------------------------------------------------------
; BCOS 7               コンソールバッファ行入力
; -------------------------------------------------------------------
; input   : AY   = buff
;           ZR0L = バッファ長さ（1～255）
; output  : A    = 実際に入力された字数
; TODO:バックスペースや矢印キーを用いた行編集機能
; -------------------------------------------------------------------
FUNC_CON_IN_STR:
  STA ZR1
  STY ZR1+1             ; ZR1をバッファインデックスに
  LDY #$FF
@NEXT:
  INY
  PHY
  LDA #$2
  JSR FUNC_CON_RAWIN    ; 入力待機するがエコーしない
  CMP #$A               ; 改行か？
  BEQ @END
  JSR FUNC_CON_OUT_CHR  ; エコー出力
  PLY
  STA (ZR1),Y           ; バッファに書き込み
  BRA @NEXT
@END:
  PLY
  LDA #0
  STA (ZR1),Y           ; 終端挿入
  DEY
  TYA                   ; 入力された字数を返す
  RTS

