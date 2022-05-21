; BCOSに含まれるUART部分
; 受信が割り込みによる関係で、uart.macのほうに含まれている

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

