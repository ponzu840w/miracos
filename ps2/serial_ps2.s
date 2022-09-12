; -------------------------------------------------------------------
;               PS/2 キーボード シリアル信号ドライバ
; -------------------------------------------------------------------
; http://sbc.rictor.org/io/pckb6522.htmlの写経
; FXT65.incにアクセスできること
; -------------------------------------------------------------------
; アセンブル設定スイッチ
TRUE = 1
FALSE = 0
PS2DEBUG = FALSE

; -------------------------------------------------------------------
;                             定数
; -------------------------------------------------------------------
CPUCLK = 4                ; 一定時間の待機ルーチンに使うCPUクロック[MHz]
INIT_TIMEOUT_MAX = $FF    ; 初期化タイムアウト期間
; -------------------------------------------------------------------
; ->KB コマンド
; -------------------------------------------------------------------
KBCMD_ENABLE_SCAN   = $F4 ; キースキャンを開始する。res:ACK
KBCMD_RESEND_LAST   = $FE ; 再送要求。res:DATA
KBCMD_RESET         = $FF ; リセット。res:ACK
KBCMD_SETLED        = $ED ; LEDの状態を設定。res:ACK
  KBLED_CAPS          = %100
  KBLED_NUM           = %010
  KBLED_SCROLL        = %001

; -------------------------------------------------------------------
; <-KB レスポンス
; -------------------------------------------------------------------
KBRES_ACK           = $FA ; 通常応答
KBRES_BAT_COMPLET   = $AA ; BATが成功

; -------------------------------------------------------------------
; PS2KBドライバルーチン群
; -------------------------------------------------------------------
; INIT: ドライバソフトウェア及びキーボードデバイスの初期化
; SCAN: データの有無を取得  データなしでA=0、あるとA=非ゼロもしくはGET
; GET : A=スキャンコード
; -------------------------------------------------------------------
SCAN:
  ;LDX #(CPUCLK*$50) ; 実測で420usの受信待ち
  LDX #$FF
  ; クロックを入力にセット（とあるが両方入力にしている
  LDA VIA::PS2_DDR
  AND #<~(VIA::PS2_CLK|VIA::PS2_DAT)
  STA VIA::PS2_DDR
@LOOP: ;kbscan1
  LDA #VIA::PS2_CLK ; クロックの                          | 2
  BIT VIA::PS2_REG  ;     状態を取得                      | 4
  BEQ @READY        ; クロックの立下りつまりデータを検出  | 2
  DEX               ; タイマー減少                        | 2
  BNE @LOOP         ;                                     | 3 | sum=13  | 13*$FF=3315
                    ;                                     | 0.125us*3315=414us
  ; データが結局ない
  JSR DIS           ; 無効化
  LDA #0            ; データなしを示す0
  RTS
@READY: ;kbscan2
  ; データがある
  ;JSR DIS           ; 無効化
  ; 選べる終わり方の選択肢
  ;RTS               ; データの有無だけを返す
  ;JMP GET           ; 直接スキャンコードを取得
  PHX                ; 直接GETの途中に突入する
  PHY
  ; バイトとパリティのクリア
  STZ BYTSAV
  STZ PARITY
  TAY
  LDX #$08            ; ビットカウンタ
  JMP GET_STARTBIT

FLUSH:
  ; バッファをフラッシュするらしいが実際にはスキャン開始コマンド？
  LDA #KBCMD_ENABLE_SCAN
SEND:
  ; --- バイトデータを送信する
  STA BYTSAV        ; 送信するデータを保存
  PHX               ; レジスタ退避
  PHY
  STA LASTBYT       ; 失敗に備える
  ; クロックを下げ、データを上げる
  LDA VIA::PS2_REG
  AND #<~VIA::PS2_CLK
  ORA #VIA::PS2_DAT
  STA VIA::PS2_REG
  ; 両ピンを出力に設定
  LDA VIA::PS2_DDR
  ORA #VIA::PS2_CLK|VIA::PS2_DAT
  STA VIA::PS2_DDR
  ; CPUクロックに応じた遅延64us
  ; NOTE: 割り込み化できないか？
  ;       もともと割込みで呼ばれるんだから無茶を言うな
  LDA #(CPUCLK*$10)
@WAIT:
  DEC
  BNE @WAIT
  LDY #$00          ; パリティカウンタ
  LDX #$08          ; bit カウンタ
  ; 両ピンを下げる
  LDA VIA::PS2_REG
  AND #<~(VIA::PS2_CLK|VIA::PS2_DAT)
  STA VIA::PS2_REG
  ; クロックを入力に設定
  LDA VIA::PS2_DDR
  AND #<~VIA::PS2_CLK
  STA VIA::PS2_DDR
  JSR HL
SENDBIT:                ; シリアル送信
  ROR BYTSAV
  BCS MARK
  ; データビットを下げる
  LDA VIA::PS2_REG
  AND #<~VIA::PS2_DAT
  STA VIA::PS2_REG
  BRA NEXT
MARK:
  ; データビットを上げる
  LDA VIA::PS2_REG
  ORA #VIA::PS2_DAT
  STA VIA::PS2_REG
  INY                   ; パリティカウンタカウントアップ
NEXT:
  JSR HL
  DEX
  BNE SENDBIT           ; シリアル送信バイトループ
  TYA                   ; パリティカウントを処理
  AND #01
  BNE PCLR              ; 偶数奇数で分岐
  ; 偶数なら1送信
  LDA VIA::PS2_REG
  ORA #VIA::PS2_DAT
  STA VIA::PS2_REG
  BRA BACK
PCLR:
  ; 奇数なら0送信
  LDA VIA::PS2_REG
  ORA #<~VIA::PS2_DAT
  STA VIA::PS2_REG
BACK:
  JSR HL
  ; 両ピンを入力にセット
  LDA VIA::PS2_DDR
  AND #<~(VIA::PS2_CLK|VIA::PS2_DAT)
  STA VIA::PS2_DDR
  ; レジスタ復帰
  PLY
  PLX
  JSR HL                ; キーボードからのACKを待機
  BNE INIT              ; 0以外であるはずがない…もしそうなら初期化してまえ
@WAIT2:
  LDA VIA::PS2_REG
  AND #VIA::PS2_CLK
  BEQ @WAIT2
DIS:
  ; 送信の無効化
  ; クロックを下げる
  LDA VIA::PS2_REG
  AND #<~VIA::PS2_CLK
  STA VIA::PS2_REG
  ; データを入力に、クロックを出力に
  LDA VIA::PS2_DDR
  AND #<~(VIA::PS2_CLK|VIA::PS2_DAT)
  ORA #VIA::PS2_CLK
  STA VIA::PS2_DDR
  RTS

ERROR:
  LDA #KBCMD_RESEND_LAST
  JSR SEND            ; 再送信要求
GET:
  PHX
  PHY
  ; バイトとパリティのクリア
  LDA #$00
  STZ BYTSAV
  STZ PARITY
  TAY
  LDX #$08            ; ビットカウンタ
  ; 両ピンを入力に
  LDA VIA::PS2_DDR
  AND #<~(VIA::PS2_CLK|VIA::PS2_DAT)
  STA VIA::PS2_DDR
WCLKH: ; kbget1
  ; クロックが高い間待つ
  LDA #VIA::PS2_CLK
  BIT VIA::PS2_REG
  BNE WCLKH
  ; スタートビットを取得
GET_STARTBIT:
  LDA VIA::PS2_REG
  AND #VIA::PS2_DAT
  BNE WCLKH          ; 1だとスタートビットとして不適格なのでやり直し
@NEXTBIT:  ; kbget2
  JSR HL              ; 次の立下りを待つ
  CLC
  BEQ @SKPSET
  ;LSR                ; 獲得したデータビットをキャリーに格納
  SEC
@SKPSET:
  ROR BYTSAV          ; 変数に保存
  BPL @SKPINP
  INY                 ; パリティ増加
@SKPINP: ; kbget3
  DEX                 ; バイトカウンタ減少
  BNE @NEXTBIT        ; バイト内ループ
  ; バイト終わり
  JSR HL              ; パリティビットを取得
  BEQ @SKPINP2        ; パリティビットが0なら何もしない
  INC PARITY          ; 1なら増加
@SKPINP2:
  TYA                 ; パリティカウントを取得
  PLY
  PLX
  EOR PARITY          ; パリティビットと比較
  AND #$01            ; LSBのみ見る
  BEQ ERROR           ; パリティエラー
  JSR HL              ; ストップビットを待機
  BEQ ERROR           ; ストップビットエラー
  LDA BYTSAV
  BEQ GET             ; 受信バイトが0なら何も受信してないのでもう一度
  JSR DIS
  LDA BYTSAV
  RTS

; -------------------------------------------------------------------
; INIT:キーボードの初期化
; -------------------------------------------------------------------
INIT:
  ; スペシャルキー状態初期化
  LDA #KBLED_NUM      ; NUMLOCKのみがオン
  STA ZP_DECODE_STATE
@RESET:
  ; リセットと自己診断
  LDA #KBCMD_RESET
  JSR SEND            ; $FF リセットコマンド
  JSR GET
  CMP #KBRES_ACK
  BNE @RESET          ; ACKが来るまででリセット
  JSR GET
  CMP #KBRES_BAT_COMPLET
  BNE @RESET          ; BATが成功するまでリセット
  ; LED状態更新
SETLED:
  LDA #KBCMD_SETLED   ; 変数に従いLEDをセット
  JSR SEND
  JSR GET
  CMP #KBRES_ACK
  BNE SETLED          ; ack待機
  LDA ZP_DECODE_STATE         ; スペシャルの下位3bitがLED状態に対応
  AND #%00000111      ; bits 3-7 を0に 不要説あり
  JSR SEND
  JSR GET             ; ackか何かが返る
  ;CMP #KBRES_ACK
  ;BNE SETLED          ; ack待機
  RTS

HL:
  ; 次の立下りでのデータを返す
  LDA #VIA::PS2_CLK
  BIT VIA::PS2_REG
  BEQ HL              ; クロックがLの期間待つ
@H:
  BIT VIA::PS2_REG
  BNE @H              ; クロックがHの期間待つ
  LDA VIA::PS2_REG
  AND #VIA::PS2_DAT   ; データラインの状態を返す
  RTS

