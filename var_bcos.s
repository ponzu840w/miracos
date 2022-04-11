; bcosの変数定義
; ROMからのインポート
ZR0 = ROM::ZR0
ZR1 = ROM::ZR1
ZR2 = ROM::ZR2
ZR3 = ROM::ZR3
ZP_CONINBF_WR_P = ROM::ZP_INPUT_BF_WR_P
ZP_CONINBF_RD_P = ROM::ZP_INPUT_BF_RD_P
ZP_CONINBF_LEN  = ROM::ZP_INPUT_BF_LEN
CONINBF_BASE    = ROM::INPUT_BF_BASE

.ZEROPAGE
ZP_CONIN_DEV:  .RES 1  ; どの入力デバイスが有効かのフラグ。LSBからUART、PS2

.APPVAR

.STRUCT DRV               ; ドライブ情報構造体、IPLから引き継ぐ
  BPB_SECPERCLUS  .BYT    ; クラスタ当たりのセクタ数
  PT_LBAOFS       .DWORD  ; セクタ番号  LBAの位置
  FATSTART        .DWORD  ; セクタ番号  FAT領域の始まり
  DATSTART        .DWORD  ; セクタ番号  データ領域始点（大抵ルートディレクトリ）
  BPB_ROOTCLUS    .DWORD  ; クラスタ番号 ルートディレクトリの始点
.ENDSTRUCT

.STRUCT 

