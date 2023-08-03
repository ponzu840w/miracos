; VARMONが狭いので分割する必要がある
; ファイルパス編集解析用ワークエリア
PATH_WK:            .RES 64
; ふたつめのFATのセクタ番号
; 高速化のために保持 計算で求める
DWK_FATSTART2:      .RES 4
DWK_FATLEN:         .RES 4

FWK:                .TAG FCTRL  ; ファイルワークエリア
FWK_REAL_SEC:       .RES 4      ; 実際のセクタ
