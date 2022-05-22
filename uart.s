; BCOSに含まれるUART部分
; 受信部分はinterrupt.s

; 使える設定集
UARTCMD_WELLCOME = UART::CMD::RTS_ON|UART::CMD::DTR_ON
UARTCMD_BUSY = UART::CMD::DTR_ON
UARTCMD_DOWN = UART::CMD::RIRQ_OFF

; --- UART初期化 ---
INIT:
  LDA #$00                ; ステータスへの書き込みはソフトリセットを意味する
  STA UART::STATUS
  LDA #UARTCMD_WELLCOME   ; RTS_ON|DTR_ON
  STA UART::COMMAND
  LDA #%00011101          ; 1stopbit,word=8bit,rx-rate=tx-rate,xl/256
  STA UART::CONTROL       ; SBN/WL1/WL0/RSC/SBR3/SBR2/SBR1/SBR0
  RTS

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

