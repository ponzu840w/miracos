; fsのゼロページワークエリア
ZP_SDCMDPRM_VEC16:    .RES 2      ; コマンド引数4バイトを指す。アドレスであることが多いか。
ZP_SDSEEK_VEC16:      .RES 2      ; カードレベルのポインタ
ZP_LSRC0_VEC16:       .RES 2      ; ソースとディスティネーション。32bit演算用
ZP_LDST0_VEC16:       .RES 2
ZP_SWORK0_VEC16:      .RES 2

