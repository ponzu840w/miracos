; SDカードドライバのSPI部分
; しかし半二重である
.INCLUDE "../FXT65.inc"

SETIN:
  ; --- SPIシフトレジスタを入力（MISO）モードにする
  LDA VIA::ACR      ; シフトレジスタ設定の変更
  AND #%11100011    ; bit 2-4がシフトレジスタの設定なのでそれをマスク
  ORA #%00001000    ; PHI2制御下インプット
  STA VIA::ACR
  LDA VIA::PORTB
  ORA #(VIA::SPI_INOUT) ; INOUT=1で入力モード
  STA VIA::PORTB
  RTS

SETOUT:
  ; --- SPIシフトレジスタを出力（MOSI）モードにする
  LDA VIA::ACR      ; シフトレジスタ設定の変更
  AND #%11100011    ; bit 2-4がシフトレジスタの設定なのでそれをマスク
  ORA #%00011000    ; PHI2制御下出力
  STA VIA::ACR
  LDA VIA::PORTB
  AND #<~(VIA::SPI_INOUT)
  STA VIA::PORTB
  RTS

WRBYT:
  ; --- Aを送信
  STA VIA::SR
@WAIT:
  LDA VIA::IFR
  AND #%00000100      ; シフトレジスタ割り込みを確認
  BEQ @WAIT
  RTS

RDBYT:
  ; --- AにSPIで受信したデータを格納
  spi_rdbyt
  RTS

DUMMYCLK:
  ; --- X回のダミークロックを送信する
  JSR SETOUT
@LOOP:
  LDA #$FF
  JSR WRBYT
  DEX
  BNE @LOOP
  RTS

