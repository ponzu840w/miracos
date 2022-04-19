; モニタRAM領域（ゼロページ）
ZR0:               .RES 2  ; Apple][のA1Lをまねた汎用レジスタ
ZR1:               .RES 2
ZR2:               .RES 2
ZR3:               .RES 2
ZR4:               .RES 2
ZR5:               .RES 2
ADDR_INDEX_L:      .RES 1  ; 各所で使うので専用
ADDR_INDEX_H:      .RES 1
ZP_INPUT_BF_WR_P:  .RES 1
ZP_INPUT_BF_RD_P:  .RES 1
ZP_INPUT_BF_LEN:   .RES 1
ECHO_F:            .RES 1  ; エコーフラグ

