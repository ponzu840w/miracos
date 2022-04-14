; BCOSに含まれるUART部分

; 通常より待ちの短い一文字送信。XOFF送信用。
; 時間計算をしているわけではないがとにかくこれで動く
.macro prt_xoff
  PHX
  LDX #$80
SHORTDELAY:
  NOP
  NOP
  DEX
  BNE SHORTDELAY
  PLX
  LDA #UART::XOFF
  STA UART::TX
.endmac

; *
; --- UART割り込み処理 ---
; *
IRQ:
  ; Aはすでにプッシュされている
  TXA
  PHA
; すなわち受信割り込み
  LDA UART::RX            ; UARTから読み取り
  LDX ZP_CONINBF_WR_P     ; バッファの書き込み位置インデックス
  STA CONINBF_BASE,X      ; バッファへ書き込み
  LDX ZP_CONINBF_LEN
  CPX #$BF                ; バッファが3/4超えたら停止を求める
  BCC SKIP_RTSOFF         ; A < M BLT
; バッファがきついのでXoff送信
  prt_xoff
SKIP_RTSOFF:
  CPX #$FF                ; バッファが完全に限界なら止める
  BNE SKIP_BRK
  BRK
SKIP_BRK:
; ポインタ増加
  INC ZP_CONINBF_WR_P
  INC ZP_CONINBF_LEN
EXIT_UART_IRQ:
  PLA
  TAX
  PLA
  CLI
  RTI

; print A reg to UART
OUT_CHR:
  STA UART::TX
@DELAY_6551:
  PHY
  PHX
@DELAY_LOOP:
  LDY #16
@MINIDLY:
  LDX #$68
@DELAY_1:
  DEX
  BNE @DELAY_1
  DEY
  BNE @MINIDLY
  PLX
  PLY
@DELAY_DONE:
  RTS

