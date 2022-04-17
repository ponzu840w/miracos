; ------------------
; --- 構造体定義 ---
; ------------------
.STRUCT DINFO
  ; 各ドライブ用変数
  BPB_SECPERCLUS    .RES 1
  PT_LBAOFS         .RES 4  ; セクタ番号
  FATSTART          .RES 4  ; セクタ番号
  DATSTART          .RES 4  ; セクタ番号
  BPB_ROOTCLUS      .RES 4  ; クラスタ番号
.ENDSTRUCT

.STRUCT FCTRL
  ; 内部的FCB
  DRV_NUM           .RES 1  ; ドライブ番号
  HEAD              .RES 4  ; 先頭クラスタ
  CUR_CLUS          .RES 4  ; 現在クラスタ
  CUR_SEC           .RES 1  ; クラスタ内セクタ
  SIZ               .RES 4  ; サイズ
  SEEK_PTR          .RES 4  ; シーケンシャルアクセス用ポインタ
.ENDSTRUCT

.STRUCT FINFO
  ; FIB、ファイル詳細情報を取得し、検索などに利用
  SIG               .RES 1  ; $FFシグネチャ、フルパス指定と区別
  NAME              .RES 13 ; 8.3ヌル終端
  ATTR              .RES 1  ; 属性
  WRTIME            .RES 2  ; 最終更新時刻
  WRDATE            .RES 2  ; 最終更新日時
  HEAD              .RES 4  ; 先頭クラスタ番号
  SIZ               .RES 4  ; ファイルサイズ
  ; 次を検索するためのデータ
  DRV_NUM           .RES 1  ; ドライブ番号
  DIR_CLUS          .RES 4  ; 親ディレクトリ現在クラスタ
  DIR_SEC           .RES 4  ; 親ディレクトリ現在セクタ
  DIR_ENT           .RES 1  ; セクタ内エントリ番号（0~15）
.ENDSTRUCT

; --------------------
; --- 変数領域定義 ---
; --------------------

DRV0:               .TAG DINFO  ; ROMからの引継ぎ

RAW_SFN:            .RES 11     ; 11文字
DOT_SFN:            .RES 13     ; .とEOTを含んで13文字
SDCMD_CRC:          .RES 1
SECVEC32:           .RES 4      ; 4バイト セクタアドレス指定汎用

; ファイル記述子テーブル
; 0=標準入力、1=標準出力、2=エラー出力を除いた3から
; ゼロページにあるはずないので、上位バイトが0なら未使用
;FD_TABLE:           .REPEAT FCTRL_ALLOC_SIZE
FD_TABLE:           .REPEAT 4
                      .RES 2
                    .ENDREP

; ドライブテーブル
; ドライブ番号0、A:のみ
DRV_TABLE:          .RES 2

; FCTRL置き場の静的確保
;FCTRL_RES:          .REPEAT FCTRL_ALLOC_SIZE
FCTRL_RES:          .REPEAT 4
                      .TAG FCTRL
                    .ENDREP

; FINFOのデフォルトワークエリア
FINFO_WK:           .TAG FINFO

DWK:                .TAG DINFO  ; ドライブワークエリア
DWK_CUR_DRV:        .RES 1      ; カレントドライブ（無駄リロード阻止用）

FWK:                .TAG FCTRL  ; ファイルワークエリア
FWK_REAL_SEC:       .RES 4      ; 実際のセクタ

