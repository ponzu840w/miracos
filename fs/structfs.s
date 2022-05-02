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
  DIR_SEC           .RES 1  ; 親ディレクトリ現在クラスタ内セクタ
  DIR_ENT           .RES 1  ; セクタ内エントリ番号（SDSEEKの下位を右に1シフトしてMSBが後半フラグ
.ENDSTRUCT

