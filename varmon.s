; モニタRAM領域
SP_SAVE:      .RES 1  ; BRK時の各レジスタのセーブ領域。
A_SAVE:       .RES 1
X_SAVE:       .RES 1
Y_SAVE:       .RES 1
ZR0_SAVE:     .RES 2
ZR1_SAVE:     .RES 2
ZR2_SAVE:     .RES 2
ZR3_SAVE:     .RES 2
ZR4_SAVE:     .RES 2
ZR5_SAVE:     .RES 2
LOAD_CKSM:    .RES 1
LOAD_BYTCNT:  .RES 1
IRQ_VEC16:    .RES 2  ; 割り込みベクタ

