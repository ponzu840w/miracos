; --------------------
; --- 変数領域定義 ---
; --------------------

; $0514
DRV0:               .TAG DINFO  ; ROMからの引継ぎ

RAW_SFN:            .RES 11     ; 11文字
DOT_SFN:            .RES 13     ; .とEOTを含んで13文字
SDCMD_CRC:          .RES 1
SECVEC32:           .RES 4      ; 4バイト セクタアドレス指定汎用

; ファイル記述子テーブル
; 0=標準入力、1=標準出力、2=エラー出力を除いた3から
; ゼロページにあるはずないので、上位バイトが0なら未使用
;FD_TABLE:           .REPEAT FCTRL_ALLOC_SIZE
; $0542
FD_TABLE:           .REPEAT 4
                      .RES 2
                    .ENDREP

; ドライブテーブル
; ドライブ番号0、A:のみ
; $054A
DRV_TABLE:          .RES 2

; FCTRL置き場の静的確保
;FCTRL_RES:          .REPEAT FCTRL_ALLOC_SIZE
; $054C
FCTRL_RES:          .REPEAT 4
                      .TAG FCTRL
                    .ENDREP

; FINFOのデフォルトワークエリア
; $0594
FINFO_WK:           .TAG FINFO

; $05B6
DWK:                .TAG DINFO  ; ドライブワークエリア
DWK_CUR_DRV:        .RES 1      ; カレントドライブ（無駄リロード阻止用）

; $05C8
FWK:                .TAG FCTRL  ; ファイルワークエリア
; $05DA
FWK_REAL_SEC:       .RES 4      ; 実際のセクタ

