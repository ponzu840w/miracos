; --- 変数領域定義
.PROC DRV
  ; 各ドライブ用変数
  BPB_SECPERCLUS:   .RES 1  ; いらないのにデフォルト値が必須
  PT_LBAOFS:        .RES 4  ; セクタ番号
  FATSTART:         .RES 4  ; セクタ番号
  DATSTART:         .RES 4  ; セクタ番号
  BPB_ROOTCLUS:     .RES 4  ; クラスタ番号
  SEC_RESWORD:      .RES 1  ; 残りワード数  0ならCMD17データパケット途中ではない
.ENDPROC
.PROC DIR
  ; カレントディレクトリとその中のエントリ弄り用
  ; ファイルとしての実態こそがだいじ
  CUR_DIR:          .RES 4  ; クラスタ番号
  ENT_NUM:          .RES 1  ; 検索など何らかで選択されたエントリ番号（返り値用
  ENT_ATTR:         .RES 1  ; エントリの属性
  ENT_HEAD:         .RES 4  ; エントリの最初のクラスタ番号
  ENT_NAME:         .RES 2  ; ポインタ
  ENT_SIZ:          .RES 4  ; ファイルサイズバイト
.ENDPROC
.PROC FILE
  ; ファイルを開くとき必要な情報
  HEAD_CLUS:        .RES 4  ; クラスタ番号
  CUR_CLUS:         .RES 4  ; クラスタ番号
  CUR_SEC:          .RES 1  ; クラスタ内セクタ番号
  SIZ:              .RES 4  ; バイト数
  REAL_SEC:         .RES 4  ; セクタ番号
  RES_SIZ:          .RES 4  ; バイト数
  ENDSEC_FLG:       .RES 1  ; 残るサイズが1セクタ未満になると立つフラグ
.ENDPROC
RAW_SFN:            .RES 11 ; 11文字
DOT_SFN:            .RES 13 ; .とEOTを含んで13文字
SDCMD_CRC:          .RES 1
SECVEC32:           .RES 4  ; 4バイト セクタアドレス指定汎用
BOOT_LOAD_POINT:    .RES 2
BOOT_ENTRY_POINT:   .RES 2

; プログラム例
  ; LDA A_+DRV::OFS_PT_LBAOFS ; 変数領域を指すラベルに、構造体内部オフセットを加算してアクセス
  ;
  ; LDY OFS_PT_LBAOFS
  ; LDA (DRVSEL),Y           ; ドライブセレクタ変数に応じたアクセス
                             ; 4バイト変数へのアクセスが面倒だが仕方あるまい
  ; 普通に面倒なので別ドライブを扱うときはZ_にコピーすること

