IRQ_BCOS:
; --- BCOS独自の割り込みハンドラ ---
; SEIだけされてここに飛んだ
; --- 外部割込み判別 ---
  PHA ; まだXY使用禁止
  ; UART判定
  LDA UART::STATUS
  BIT #%00001000
  BEQ @SKP_UART       ; bit3の論理積がゼロ、つまりフルじゃない
  JMP BCOS_UART::IRQ
@SKP_UART:
  ; VIA判定
  LDA VIA::IFR        ; 割り込みフラグレジスタ読み取り
  LSR                 ; C = bit 0 CA2
  BCC @SKP_CA2
  ; 垂直同期割り込み処理
@CA2_END:
  LDA VIA::IFR
  AND #%00000001      ; 割り込みフラグを折る
  STA VIA::IFR
  PLA
  CLI
  RTI
@SKP_CA2:

IRQ_DEBUG:
  PLA
  JMP DONKI::ENT_DONKI

