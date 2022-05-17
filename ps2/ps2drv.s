; PS/2キーボードドライバテスト
; http://sbc.rictor.org/io/pckb6522.htmlの写経
; FXT65.incにアクセスできること
; アセンブル設定スイッチ
TRUE = 1
FALSE = 0
PS2DEBUG = TRUE

CPUCLK = 4

FLUSH:
  ; バッファフラッシュ
  LDA #$F4
SEND:
  ; --- バイトデータを送信する
  STA BYTSAV        ; 送信するデータを保存
  PHX               ; レジスタ退避
  PHY
  STA LASTBYT       ; 失敗に備える
  .IF !PS2DEBUG
    LDA #'S'
    JSR PRT_CHR
    LDA BYTSAV
    JSR PRT_BYT
    JSR PRT_S
  .ENDIF
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
  ; データを入力に、クロックを出力に
  STA VIA::PS2_DDR
  AND #<~(VIA::PS2_CLK|VIA::PS2_DAT)
  ORA #VIA::PS2_CLK
  STA VIA::PS2_DDR
  RTS

ERROR:
  LDA #$FE
  JSR SEND            ; 再送信
GET:
  PHX
  PHY
  .IFDEF DBG
    LDA #'G'
    JSR PRT_CHR
    JSR PRT_S
  .ENDIF
  ; バイトとパリティのクリア
  LDA #$00
  StA BYTSAV
  STA PARITY
  TAY
  LDX #$08            ; ビットカウンタ
  ; 両ピンを入力に
  LDA VIA::PS2_DDR
  AND #<~(VIA::PS2_CLK|VIA::PS2_DAT)
  STA VIA::PS2_DDR
@WCLKH: ; kbget1
  ; クロックが高い間待つ
  LDA #VIA::PS2_CLK
  BIT VIA::PS2_REG
  BNE @WCLKH
  ; スタートビットを取得
  LDA VIA::PS2_REG
  AND #VIA::PS2_DAT
  BNE @WCLKH          ; 1だとスタートビットとして不適格なのでやり直し
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

INIT:
  LDA #$02            ; NUMLOCKのみがオン
  STA SPECIAL
@RESET:
  LDA #$FF
  JSR SEND            ; $FF リセットコマンド
  JSR GET
  CMP #$FA
  BNE @RESET          ; ACKが来るまででリセット
  JSR GET
  CMP #$AA
  BNE @RESET          ; reset ok が来るまでリセット
SETLED:
  LDA #$ED            ; 変数に従いLEDをセット
  JSR SEND
  JSR GET
  CMP #$FA
  BNE SETLED          ; ack待機
  LDA SPECIAL
  AND #$07            ; bits 3-7 を0に
  JSR SEND
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

