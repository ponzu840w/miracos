; -------------------------------------------------------------------
;             MIRACOS BCOS FATファイルシステムモジュール
; -------------------------------------------------------------------
; SDカードのFAT32ファイルシステムをサポートする
; 1バイトのファイル記述子をオープンすることでファイルにアクセス可能
; 特殊ファイルの扱いをfs.sと分離
; fs.sに直接インクルードされ、fs.sに直接アクセスできる。
; -------------------------------------------------------------------
;.INCLUDE "FXT65.inc"
;.INCLUDE "errorcode.inc"

INTOPEN_DRV:
  ; input:A=DRV
  CMP DWK_CUR_DRV       ; カレントドライブと比較
  BEQ @SKP_LOAD         ; 変わらないならスキップ
  STA DWK_CUR_DRV       ; カレントドライブ更新
  JSR LOAD_DWK
@SKP_LOAD:
  RTS

INTOPEN_FILE:
  ; 内部的ファイルオープン（バッファに展開する）
  LDA FINFO_WK+FINFO::DRV_NUM
  JSR INTOPEN_DRV                   ; ドライブ番号が違ったら更新
  loadmem16 ZR0,FINFO_WK+FINFO::HEAD
  LDA (ZR0)
  LDY #1                            ; クラスタ番号がゼロなら特別処理
  ORA (ZR0),Y
  INY
  ORA (ZR0),Y
  INY
  ORA (ZR0),Y
  BNE @OTHERS                       ; クラスタ番号がゼロ
  LDA FINFO_WK+FINFO::ATTR          ; 属性を取得
  CMP #DIRATTR_DIRECTORY            ; ディレクトリ（..）か？
  BNE @OTHERS
  loadreg16 DWK+DINFO::BPB_ROOTCLUS ; ..がルートを示すので特別にルートをロード
  BRA OPENCLUS
@OTHERS:
  loadreg16 FINFO_WK+FINFO::HEAD
  BRA OPENCLUS

INTOPEN_ROOT:
  ; ルートディレクトリを開く
  loadreg16 DWK+DINFO::BPB_ROOTCLUS
OPENCLUS:
  JSR CLUS2FWK
  JSR RDSEC
  RTS

CLUS2FWK:
  ; AXで与えられたクラスタ番号から、ファイル構造体を展開
  ; サイズに触れないため、ディレクトリにも使える
  ; --- ファイル構造体の展開
  ; 先頭クラスタ番号
  JSR AX_SRC
  loadreg16 FWK+FCTRL::HEAD
  JSR AX_DST
  JSR L_LD
FILE_REOPEN:
  ; ここから呼ぶと現在のファイルを開きなおす
  ; 現在クラスタ番号に先頭クラスタ番号をコピー
  loadreg16 FWK+FCTRL::CUR_CLUS
  JSR AX_DST
  loadreg16 FWK+FCTRL::HEAD
  JSR L_LD_AXS
  ; 現在クラスタ内セクタ番号をゼロに
  STZ FWK+FCTRL::CUR_SEC
  ; リアルセクタ番号を展開
  ;loadmem8l ZP_LDST0_VEC16,FWK_REAL_SEC
  loadreg16 (FWK_REAL_SEC)
  JSR AX_DST
  JSR CLUS2SEC_IMP
  loadreg16 (FWK_REAL_SEC)
  RTS

LOAD_FWK:
  ; FCTRL内容をワークエリアにロード
  ; input:A=FD
  JSR FD2FCTRL
  STA ZR0
  STX ZR0+1               ; ZR0:FCTRL先頭ポインタ（ソース）
  loadmem16 ZR1,FWK       ; ZR1:ワークエリア先頭ポインタ（ディスティネーション）
  LDY #.SIZEOF(FCTRL)     ; Y=最後尾インデックス
@LOOP:
  LDA (ZR0),Y
  STA (ZR1),Y
  DEY
  BEQ @LOOP
  BPL @LOOP
@END:
  RTS

PUT_FWK:
  ; ワークエリアからFCTRLに書き込む
  ; input:A=FD
  JSR FD2FCTRL
  STA ZR0
  STX ZR0+1               ; ZR0:FCTRL先頭ポインタ（ディスティネーション）
  loadmem16 ZR1,FWK       ; ZR1:ワークエリア先頭ポインタ（ソース）
  LDY #.SIZEOF(FCTRL)     ; Y=最後尾インデックス
@LOOP:
  LDA (ZR1),Y
  STA (ZR0),Y
  DEY
  BEQ @LOOP
  BPL @LOOP
@END:
  RTS

LOAD_DWK:
  ; ドライブ情報をワークエリアに展開する
  ; 複数ドライブが実装されるまでは徒労もいいところ
  ; input A=ドライブ番号
  STA FWK+FCTRL::DRV_NUM  ; ファイルワークエリアのドライブ番号をセット
  ASL                     ; ベクタテーブルなので二倍にする
  TAY
  LDA DRV_TABLE,Y
  LDX DRV_TABLE+1,Y       ;NOTE:ベクタ位置を示すBP
  STA ZR0
  STX ZR0+1
  ; コピーループ
  LDY #0
@LOOP:
  LDA (ZR0),Y
  STA DWK,Y
  INY
  CPY #.SIZEOF(DINFO)      ; DINFOのサイズ分コピーしたら終了
  BNE @LOOP                ; ロード結果を示すBP
  RTS

RDSEC:
  ;loadmem16 ZP_SDSEEK_VEC16,SECBF512         ; SECBFに縛るのは面白くない
  ;loadAY16 SECBF512                          ; 分割するとき、どうせ下位はゼロなのだからloadAYはナンセンス
  LDA #>SECBF512
RDSEC_A_DST:                                  ; Aが読み取り先ページを示す
  ;storeAY16 ZP_SDSEEK_VEC16                  ; ナンセンス
  STA ZP_SDSEEK_VEC16+1
  STZ ZP_SDSEEK_VEC16
  loadmem16 ZP_SDCMDPRM_VEC16,(FWK_REAL_SEC)  ; NOTE:FWK_REAL_SECを読んで監視するBP
  JSR SD::RDSEC
  SEC
  BNE @ERR
@SKP_E:
  DEC ZP_SDSEEK_VEC16+1
  CLC
@ERR:
  RTS

CLUS2SEC_AXS: ; ソースを指定
  JSR AX_SRC
CLUS2SEC_IMP: ; S,Dが適切に設定されている
  JSR L_LD    ; そのままコピーする
CLUS2SEC:
  ; クラスタ番号をセクタ番号に変換する
  ; SECPERCLUSは2の累乗であることが保証されている
  ; 2を減算
  LDA #$2
  JSR L_SB_BYT
  ; *SECPERCLUS
  LDA DWK+DINFO::BPB_SECPERCLUS
@LOOP:
  TAX
  JSR L_X2
  TXA
  LSR
  CMP #1
  BNE @LOOP
  ; DATSTARTを加算
  loadreg16 (DWK+DINFO::DATSTART)
  JSR L_ADD_AXS
  RTS

DIR_NEXTENT:
  ; 次の有効な（LFNでない）エントリを拾ってくる
  ; ZP_SDSEEK_VEC16が32bitにアライメントされる
  ; Aには属性が入って帰る
  ; もう何もなければ$FFを返す
  ; 次のエントリ
@LOOP:
  LDA ZP_SDSEEK_VEC16+1
  CMP #(>SECBF512)+1
  BNE @SKP_NEXTSEC            ; 上位桁が後半でないならセクタ読み切りの心配なし
  LDA ZP_SDSEEK_VEC16
  CMP #256-32
  BNE @SKP_NEXTSEC            ; 下位桁が最終エントリならこのセクタは読み切った
  JSR NEXTSEC                 ; 次のセクタに進む
  JSR RDSEC                   ; セクタを読み出す
  BRA @ENT
@SKP_NEXTSEC:
  ; シーク
  LDA ZP_SDSEEK_VEC16
  LDX ZP_SDSEEK_VEC16+1
  LDY #32
  JSR S_ADD_BYT
  STA ZP_SDSEEK_VEC16
  STX ZP_SDSEEK_VEC16+1
@ENT:
DIR_NEXTENT_ENT:              ; エントリポイント
  JSR DIR_GETENT
  CMP #0
  BNE @SKP_NULL               ; 0ならもうない
  LDA #$FF                    ; EC:NotFound
  RTS
@SKP_NULL:
  CMP #$E5                    ; 消去されたエントリ
  BEQ DIR_NEXTENT
  CMP #DIRATTR_LONGNAME
  BNE @EXT
  BRA DIR_NEXTENT
@EXT:
  LDA FINFO_WK+FINFO::ATTR
  RTS

DIR_GETENT:
  ; エントリを拾ってくる
  ; ZP_SDSEEK_VEC16がディレクトリエントリ先頭にある
  ; 属性
  ; LFNだったらサボる
  LDA FWK+FCTRL::DRV_NUM        ; FWKのドライブ番号を引っ張る
  STA FINFO_WK+FINFO::DRV_NUM   ; DRV_NUM登録
  LDX #4
@CLUSLOOP:                      ; ディレクトリの現在クラスタとクラスタ内セクタをコピー
  LDA FWK+FCTRL::CUR_CLUS,X
  STA FINFO_WK+FINFO::DIR_CLUS,X
  DEX
  BPL @CLUSLOOP
  ; セクタ内エントリ番号の登録
  LDA ZP_SDSEEK_VEC16+1         ; シーク位置の上位
  CMP #>SECBF512                ; バッファの上位と同じか
  CLC
  BEQ @SKP_8
  SEC
@SKP_8:                         ; シークがセクタ前半ならC=0、後半ならC=1
  LDA ZP_SDSEEK_VEC16           ; シーク位置の下位、32bitアライメント
  ROR ; 16                      ; キャリーを巻き込む
  STA FINFO_WK+FINFO::DIR_ENT   ; セクタ内エントリ番号を登録
  LDY #OFS_DIR_ATTR
  LDA (ZP_SDSEEK_VEC16),Y
  STA FINFO_WK+FINFO::ATTR      ; 一応LFNであったとしても属性は残しておく
  CMP #DIRATTR_LONGNAME         ; LFNならサボる
  BEQ @EXT
  ; 名前
  LDA (ZP_SDSEEK_VEC16)
  BEQ @EXT                      ; 0ならもうない
  CMP #$E5                      ; 消去されたエントリならサボる
  BEQ @EXT
  LDA ZP_SDSEEK_VEC16
  LDX ZP_SDSEEK_VEC16+1
  JSR AX_SRC
  loadreg16 FINFO_WK+FINFO::NAME
  JSR M_SFN_RAW2DOT_AXD
  ; サイズ
  loadreg16 FINFO_WK+FINFO::SIZ
  JSR AX_DST
  LDA ZP_SDSEEK_VEC16
  LDX ZP_SDSEEK_VEC16+1
  LDY #OFS_DIR_FILESIZE
  JSR S_ADD_BYT
  JSR L_LD_AXS
  ; 更新日時
  loadreg16 FINFO_WK+FINFO::WRTIME
  JSR AX_DST
  LDA ZP_SDSEEK_VEC16
  LDX ZP_SDSEEK_VEC16+1
  LDY #OFS_DIR_WRTTIME
  JSR S_ADD_BYT
  JSR L_LD_AXS
 ; クラスタ番号
  ; TODO 16bitコピーのサブルーチン化
  LDY #OFS_DIR_FSTCLUSLO
  LDA (ZP_SDSEEK_VEC16),Y      ; 低位
  STA FINFO_WK+FINFO::HEAD
  INY
  LDA (ZP_SDSEEK_VEC16),Y      ; 低位
  STA FINFO_WK+FINFO::HEAD+1
  LDY #OFS_DIR_FSTCLUSHI
  LDA (ZP_SDSEEK_VEC16),Y      ; 高位
  STA FINFO_WK+FINFO::HEAD+2
  INY
  LDA (ZP_SDSEEK_VEC16),Y      ; 高位
  STA FINFO_WK+FINFO::HEAD+3
  LDA #1                       ; 成功コード
@EXT:
  RTS

NEXTSEC:
  ; ファイル構造体を更新し、次のセクタを開く
  ; クラスタ内セクタ番号の更新
  LDA FWK+FCTRL::CUR_SEC
  CMP DWK+DINFO::BPB_SECPERCLUS ; クラスタ内最終セクタか
  BNE @SKP_NEXTCLUS             ; まだならFATチェーン読み取りキャンセル
  BRK                           ; TODO:FATを読む
@SKP_NEXTCLUS:
  INC FWK+FCTRL::CUR_SEC
  ; リアルセクタ番号を更新
  loadreg16 (FWK_REAL_SEC)
  JSR AX_DST
  LDA #1
  JSR L_ADD_BYT
  RTS

FINFO2SIZ:
  ; FINFO構造体に展開されたサイズをFCTRL構造体にコピー
  loadreg16 FWK+FCTRL::SIZ        ; デスティネーションをサイズに
  JSR AX_DST
  loadreg16 FINFO_WK+FINFO::SIZ   ; ソースをFINFOのサイズにしてロード
  JSR L_LD_AXS
  loadreg16 FWK+FCTRL::SEEK_PTR   ; デスティネーションをシークポインタに
  JSR AX_DST
  loadreg16 SD::BTS_CMDPRM_ZERO   ; ソースを$00000000にしてロード
  JSR L_LD_AXS
  RTS

