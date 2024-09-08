; -------------------------------------------------------------------
;                           MIRACOS BCOS
; -------------------------------------------------------------------
; MIRACOSの本体 --- Basic Card Operationg System
; CP/MでいうところのBIOSとBDOSを混然一体としたもの
; ファンクションコール・インタフェース（特に意味はない）
; -------------------------------------------------------------------
; アセンブル設定スイッチ
TRUE = 1
FALSE = 0
.IFDEF SRECBUILD
.ELSE
  SRECBUILD = FALSE  ; TRUEで、テスト用のUARTによるロードに適した形にする
.ENDIF

.IF SRECBUILD
  .OUT "SREC TEST BUILD"
.ELSE
  .OUT "SD RELEASE BUILD"
.ENDIF

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
TIMEOUT_T1H = %01000000

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
  .INCLUDE "ps2/zpps2.s"

; 変数領域定義
.SEGMENT "MONVAR"
  .PROC ROM
    .INCLUDE "varmon.s"
  .ENDPROC
  .INCLUDE "fs/structfs.s"
  .INCLUDE "fs/varfs.s"
  .INCLUDE "varbcos.s"
  .INCLUDE "gcon/vargcon.s"
  .INCLUDE "donki/vardonki.s"
  .INCLUDE "ps2/varps2.s"

; OS側変数領域
.SEGMENT "COSVAR"
  .INCLUDE "fs/varfs2.s"
  .INCLUDE "varbcos2.s"

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
  .PROC SPI
    .INCLUDE "fs/spi.s"
  .ENDPROC
  .PROC SD
    .INCLUDE "fs/sd.s"
  .ENDPROC
  .PROC FS
    .INCLUDE "fs/fs.s"
  .ENDPROC
  .PROC BCOS_UART ; 単にUARTとするとアドレス宣言とかぶる
    .INCLUDE "uart.s"
  .ENDPROC
  .PROC PS2
    .INCLUDE "ps2/serial_ps2.s"
    .INCLUDE "ps2/decode_ps2.s"
  .ENDPROC
  .PROC IRQ
    .INCLUDE "interrupt.s"
  .ENDPROC
  .PROC GCHR
    .INCLUDE "gcon/gchr.s"
  .ENDPROC
  .PROC GCON
    .INCLUDE "gcon/gcon.s"
  .ENDPROC
BCOS_ENT_DONKI:
  .PROC DONKI
    .INCLUDE "donki/donki.s"
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
  .WORD FUNC_RESET                ; 0 リセット、CCPロード部分に変更予定
  .WORD FUNC_CON_IN_CHR           ; 1 コンソール入力
  .WORD FUNC_CON_OUT_CHR          ; 2 コンソール出力
  .WORD FUNC_CON_RAWIN            ; 3 コンソール生入力
  .WORD FUNC_CON_OUT_STR          ; 4 コンソール文字列出力
  .WORD FS::FUNC_FS_OPEN          ; 5 ファイル記述子オープン
  .WORD FS::FUNC_FS_CLOSE         ; 6 ファイル記述子クローズ
  .WORD FUNC_CON_IN_STR           ; 7 バッファ行入力
  .WORD GCHR::FUNC_GCHR_COL       ; 8 2色テキスト画面パレット操作
  .WORD FS::FUNC_FS_FIND_FST      ; 9 最初のエントリの検索
  .WORD FS::FUNC_FS_PURSE         ; 10 パス文字列の解析
  .WORD FS::FUNC_FS_CHDIR         ; 11 カレントディレクトリ変更
  .WORD FS::FUNC_FS_FPATH         ; 12 絶対パス取得
  .WORD ERR::FUNC_ERR_GET         ; 13 エラー番号取得
  .WORD ERR::FUNC_ERR_MES         ; 14 エラー表示
  .WORD FUNC_UPPER_CHR            ; 15 小文字を大文字に
  .WORD FUNC_UPPER_STR            ; 16 文字列の小文字を大文字に
  .WORD FS::FUNC_FS_FIND_NXT      ; 17 次のエントリの検索
  .WORD FS::FUNC_FS_READ_BYTS     ; 18 バイト数指定ファイル読み取り
  .WORD IRQ::FUNC_IRQ_SETHNDR_VB  ; 19 垂直同期割り込みハンドラ登録
  .WORD FUNC_GET_ADDR             ; 20 カーネル管理のアドレスを取得
  .WORD FUNC_CON_INTERRUPT_CHR    ; 21 コンソール入力キューに割り込む
  .WORD FUNC_TIMEOUT              ; 22 タイムアウトを設定
  .WORD GCHR::FUNC_CRTC_SETBASE   ; 23 CRTC基底状態を設定
  .WORD GCHR::FUNC_CRTC_RETBASE   ; 24 CRTC基底状態に回帰
  .WORD IRQ::FUNC_IRQ_SETHNDR_C   ; 25 CTRL+Cハンドラを設定
  .WORD FUNC_CON_IN_CHR_RPD       ; 26 無駄のないコンソール入力
  .WORD FS::FUNC_FS_WRITE         ; 27 ファイル書き込み
  .WORD FS::FUNC_FS_MAKE          ; 28 ファイル/ディレクトリ作成
  .WORD FS::FUNC_FS_DELETE        ; 29 ファイル/ディレクトリ削除
  .WORD FS::FUNC_FS_SEEK          ; 30 ファイルシーク

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
  SEI                             ; --- 割込みに関連する初期化
  JSR BCOS_UART::INIT             ; UARTの初期化処理
  ; コンソール入力バッファの初期化
  STZ ZP_CONINBF_RD_P
  STZ ZP_CONINBF_WR_P
  STZ ZP_CONINBF_LEN
  ; 割り込みベクタ変更
  loadAY16 IRQ::IRQ_BCOS
  storeAY16 ROM::IRQ_VEC16
  ; 垂直同期割り込みを設定する
  loadAY16 IRQ::VBLANK_STUB
  storeAY16 VBLANK_USER_VEC16     ; 垂直同期ユーザベクタ変更
  ; CTRL+C処理ベクタを設定する
  LDY #0                          ; ゼロページを指定するとリセットされる
  JSR IRQ::FUNC_IRQ_SETHNDR_C
  LDA VIA::PCR                    ; ポート制御端子の設定
  AND #%11110001                  ; 321がCA2
  ORA #%00000010                  ; 001＝独立した負の割り込みエッジ入力
  STA VIA::PCR
  LDA #(VIA::IER_SET|VIA::IFR_CA2) ; CA2割込みを有効に
  STA VIA::IER
  CLI                             ; --- 割込みに関連する初期化終わり
  ; --- PS/2キーボードの初期化処理  タイムアウト付き
  ; タイムアウト設定
  loadmem16 ZR0,@INIT_PS2_END
  LDA #PS2::INIT_TIMEOUT_MAX
  JSR FUNC_TIMEOUT
  JSR PS2::INIT                   ; PS/2キーボードの初期化処理
  ; 成功！
  ; タイムアウトオフ
  LDA #0
  JSR FUNC_TIMEOUT
  ; PS/2KBデバイス有効化
  SMB2 ZP_CON_DEV_CFG
@INIT_PS2_END:
  ; --- PS/2キーボードの初期化処理  ここまで
  .IF SRECBUILD                  ; 分離部分の配置は、UARTロードの時は不要
    BRA @JUMP_CCP
  .ELSE
    NOP
    NOP
  .ENDIF
  ; SYSCALL.SYSを配置する
  loadAY16 PATH_SYSCALL
  STZ ZR0
  JSR FS::FUNC_FS_OPEN            ; フォントファイルをオープン
  STA ZR1
  PHA
  loadmem16 ZR0,$0600             ; 書き込み先
  loadAY16  256                   ; 長さ
  JSR FS::FUNC_FS_READ_BYTS       ; ロード
  PLA
  JSR FS::FUNC_FS_CLOSE           ; クローズ
  ; CCP.SYSを配置する
  loadAY16 PATH_CCP
  STZ ZR0
  JSR FS::FUNC_FS_OPEN            ; CCPをオープン
  STA ZR1
  PHA
  loadmem16 ZR0,$5000             ; 書き込み先
  loadAY16  1024                  ; 長さ決め打ち、長い分には害はないはず
  JSR FS::FUNC_FS_READ_BYTS       ; ロード
  PLA
  JSR FS::FUNC_FS_CLOSE           ; クローズ
@JUMP_CCP:
  JMP $5000                       ; CCP（仮）へ飛ぶ

  PATH_SYSCALL:         .ASCIIZ "A:/MCOS/SYSCALL.SYS"
  PATH_CCP:             .ASCIIZ "A:/MCOS/CCP.SYS"

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
  BCC @WAIT             ; A=2なら待機する
  LDA ZP_CONINBF_LEN
  BEQ END               ; バッファに何もないなら0を返す
@WAIT:
  ; 乱数の更新
  INC ZP_RND16
  BNE @SKP_RNDH
  INC ZP_RND16+1
@SKP_RNDH:
  LDA ZP_CONINBF_LEN
  BEQ @WAIT             ; バッファに何もないなら待つ
@SKP_WAIT:
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
FUNC_CON_IN_CHR_RPD = @SKP_RNDH
END:
  RTS

; -------------------------------------------------------------------
; BCOS 21               コンソール文字入力割込み
; -------------------------------------------------------------------
; input:A=エンキューする文字
; -------------------------------------------------------------------
FUNC_CON_INTERRUPT_CHR:
  JMP IRQ::TRAP

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
  CPY #$FF
  BNE @LOOP                   ; #$FFに到達しないまではそのままループ
  INC ZR5+1                   ; 次のページへ
  BRA @LOOP                   ; ループ

; -------------------------------------------------------------------
; BCOS 7               コンソールバッファ行入力
; -------------------------------------------------------------------
; input   : AY   = buff
;           ZR0L = バッファ長さ（1～255）
; output  : A    = 実際に入力された字数
; TODO:矢印キーを用いた行編集機能
; -------------------------------------------------------------------
FUNC_CON_IN_STR:
  storeAY16 ZR1         ; ZR1をバッファインデックスに
  LDY #$FF
@NEXT:
  INY
  PHY
  LDA #$2
  JSR FUNC_CON_RAWIN    ; 入力待機するがエコーしない
  PLY
  CMP #$A               ; 改行か？
  BEQ @END              ; 改行なら行入力終了
  CMP #$8               ; ^H(BS)か？
  BNE @WRITE            ; なら直下のバックスペース処理
  DEY                   ; 後退（先行INY打消し
  CPY #$FF                ; Y=0ならそれ以上後退できない
  BEQ @NEXT             ; ので無視
  DEY                   ; 後退（本質
  BRA @ECHO             ; バッファには書き込まず、エコーのみ
@WRITE:
  STA (ZR1),Y           ; バッファに書き込み
@ECHO:
  PHY
  JSR FUNC_CON_OUT_CHR  ; エコー出力
  PLY
  BRA @NEXT
@END:
  LDA #0
  STA (ZR1),Y           ; 終端挿入
  ;DEY
  TYA                   ; 入力された字数を返す
  RTS

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

; -------------------------------------------------------------------
; BCOS 20                    アドレス取得
; -------------------------------------------------------------------
; input     : Y   = 0*2 : ZP_RND16            16bit乱数
;                 = 1*2 : TXTVRAM768          テキストVRAM
;                 = 2*2 : FONT2048            フォントグリフエリア
;                 = 3*3 : ZP_CON_DEV_CFG      コンソールデバイス設定
; output    : AY = ptr
; -------------------------------------------------------------------
FUNC_GET_ADDR:
  LDX OPEN_ADDR_TABLE,Y
  LDA OPEN_ADDR_TABLE+1,Y
  TAY
  TXA
  RTS

OPEN_ADDR_TABLE:
  .WORD ZP_RND16          ; 0
  .WORD TXTVRAM768        ; 1
  .WORD FONT2048          ; 2
  .WORD ZP_CON_DEV_CFG    ; 3

; -------------------------------------------------------------------
; BCOS 22                 タイムアウト設定
; -------------------------------------------------------------------
; input     : A   = タイムアウト期間（ミリ秒）
;           : ZR0 = 脱出先アドレス
; output    : A   = 可否？
; -------------------------------------------------------------------
FUNC_TIMEOUT:
  ; ゼロチェック
  TAX
  BNE @SKP_OFF
  ; ゼロ時間が指定されたので起動したタイマーを無効化
  LDA #VIA::IFR_T1               ; T1割込みを無効に
  BRA @SET_IER
@SKP_OFF:
  ; スタックポインタを保存
  TSX
  INX ; システムコールでのフレームを破棄
  INX
  STX TIMEOUT_STACKPTR
  ; 引数を変数領域に格納
  STA TIMEOUT_MS_CNT
  mem2mem16 TIMEOUT_EXIT_VEC16,ZR0
  ; タイマーを起動
  ; IER=割込み有効レジスタ
  LDA #(VIA::IER_SET|VIA::IFR_T1)   ; T1割込みを有効に
@SET_IER:
  STA VIA::IER
  ; ACR=補助制御レジスタ
  LDA VIA::ACR
  AND #%00111111                    ; 76=00でT1時限割込み
  STA VIA::ACR
  ; T1タイマー
  LDA #TIMEOUT_T1H                  ; フルの1/4で、8MHz時1ms
  STA VIA::T1CH
  STZ VIA::T1CL
  RTS

