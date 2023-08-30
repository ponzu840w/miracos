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
  JSR HEAD2FWK
  JSR RDSEC
  RTS

HEAD2FWK:
  ; AXで与えられた先頭クラスタ番号から、ファイル構造体を展開
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
CLUS_REOPEN:
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
  LDY #.SIZEOF(FCTRL)     ; Y=最後尾インデックス
@LOOP:
  LDA (ZR0),Y
  STA FWK,Y
  DEY
  BEQ @LOOP
  BPL @LOOP
@END:
  RTS

PUT_FWK:
  ; ワークエリアからFCTRLに書き込む
  ; input:A=FD
  JSR FD2FCTRL
  LDY #.SIZEOF(FCTRL)     ; Y=最後尾インデックス
@LOOP:
  LDA FWK,Y
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
  ; TODO:通常ドライブ以外なら以下は不要な処理
  ; FAT2を算出
  ; unsigned long fatlen=(dwk_p->DATSTART-dwk_p->FATSTART)/2;
  ; unsigned long fat2startsec=dwk_p->FATSTART+fatlen;
  ; dst=FATSTART2
  loadreg16 DWK_FATLEN
  JSR AX_DST
  ; *dst=DATSTART
  loadreg16 (DWK+DINFO::DATSTART)
  JSR L_LD_AXS
  ; *dst=*dst-FATSTART
  loadreg16 (DWK+DINFO::FATSTART)
  JSR L_SB_AXS
  ; *dst=*dst/2
  JSR L_DIV2
  ; DWK_FATSTART2=DWK_FATLEN
  loadreg16 DWK_FATSTART2
  JSR AX_DST
  loadreg16 DWK_FATLEN
  JSR L_LD_AXS
  ; *dst=*dst+FATSTART
  loadreg16 (DWK+DINFO::FATSTART)
  JSR L_ADD_AXS
  RTS

RDSEC:
  ; セクタバッファにFWK_REAL_SECを読みだす
  ;loadmem16 ZP_SDSEEK_VEC16,SECBF512         ; SECBFに縛るのは面白くない
  ;loadAY16 SECBF512                          ; 分割するとき、どうせ下位はゼロなのだからloadAYはナンセンス
  LDA #>SECBF512
RDSEC_A_DST:                                  ; Aが読み取り先ページを示す
  ;storeAY16 ZP_SDSEEK_VEC16                  ; ナンセンス
  STA ZP_SDSEEK_VEC16+1
  STZ ZP_SDSEEK_VEC16
  loadmem16 ZP_SDCMDPRM_VEC16,(FWK_REAL_SEC)  ; NOTE:FWK_REAL_SECを読んで監視するBP
  JSR SD::RDSEC
  SEC                                         ; C=1 ERR
  BNE @ERR
@SKP_E:
  DEC ZP_SDSEEK_VEC16+1
  CLC                                         ; C=0 OK
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
  ; TODO C=1ならセクタリードに失敗しているので、ここでエラー処理するのが望ましい
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

CUR_CLUS_2_LOGICAL_FAT:
  ; ---------------------------------------------------------------
  ;   現在クラスタ番号{N}->FAT論理セクタ
  LDA FWK+FCTRL::CUR_CLUS       ; 現在クラスタ番号{N}->FAT論理セクタ
  ASL                           ; x4/512 : /128 : >>7 最下位バイトからはMSBしか採れない
  ; 0
  LDA FWK+FCTRL::CUR_CLUS+1
  ROL
  STA FWK_REAL_SEC
  ; 1
  LDA FWK+FCTRL::CUR_CLUS+2
  ROL
  STA FWK_REAL_SEC+1
  ; 2
  LDA FWK+FCTRL::CUR_CLUS+3
  ROL
  STA FWK_REAL_SEC+2
  ; 3
  STZ FWK_REAL_SEC+3
  ROL FWK_REAL_SEC+3
  RTS

OPEN_FAT:
  ; ---------------------------------------------------------------
  ;   FATエントリを展開
  JSR RDSEC                       ; FATロード
  ; 参照ベクタをZP_LSRC0_VEC16に作成
  LDA #>SECBF512                  ; ソース上位をSECBFに
  STA ZP_LSRC0_VEC16+1
  LDA FWK+FCTRL::CUR_CLUS         ; 現在クラスタ最下位バイト
  ASL                             ; <<2
  ASL
  BCC @SKP_INCPAGE                ; C=0 上部 $03
  INC ZP_LSRC0_VEC16+1            ; C=1 下部 $04
@SKP_INCPAGE:
  STA ZP_LSRC0_VEC16
  RTS

NEXTSEC:
  ; ファイル構造体を更新し、次のセクタを開く
  ;  output: C=1:EOC 単にエラーとするか新規クラスタを割り当てるかはあなた次第
  ;               状態:CUR_SECは更新されている
  ;                    REAL_SECとセクタバッファ、参照ベクタLSRC0はEOCを示すFAT領域を開いている
  loadreg16 (FWK_REAL_SEC)
  JSR AX_DST                    ; リアルセクタをDSTに
  ; クラスタ内セクタ番号の更新
  INC FWK+FCTRL::CUR_SEC
  LDA FWK+FCTRL::CUR_SEC
  CMP DWK+DINFO::BPB_SECPERCLUS ; クラスタ内最終セクタか
  BNE @SKP_NEXTCLUS             ; まだならFATチェーン読み取りキャンセル
  ; 次のクラスタの先頭セクタを開く
  JSR CUR_CLUS_2_LOGICAL_FAT    ; 現在クラスタ番号{N}->FAT論理セクタ
  ; ---------------------------------------------------------------
  ;   FAT論理セクタ->FAT実セクタ
  loadreg16 (DWK+DINFO::FATSTART) ; FATSTART加算
  JSR L_ADD_AXS
  pushmem16 ZP_SDSEEK_VEC16       ; 書き込み先ポインタ退避 高速読み取り時に必要
  ; ---------------------------------------------------------------
  ;   FATエントリを展開
  JSR OPEN_FAT

  ; 現在クラスタにFATからコピー
  ;  NOTE:開いたけどそこまでタイミングクリティカルじゃない？
  LDY #3
  LDA (ZP_LSRC0_VEC16),Y
  STA FWK+FCTRL::CUR_CLUS,Y
  DEY
  CMP #$0F
  BEQ @MIGHT_EOC                  ; EOCかもしれない
@NOT_EOC:
  ; FWK現在クラスタ更新
  LDA (ZP_LSRC0_VEC16),Y
  STA FWK+FCTRL::CUR_CLUS,Y
  DEY
  LDA (ZP_LSRC0_VEC16),Y
  STA FWK+FCTRL::CUR_CLUS,Y
  DEY
  LDA (ZP_LSRC0_VEC16),Y
  STA FWK+FCTRL::CUR_CLUS,Y
  JSR CLUS_REOPEN                 ; 更新された現在クラスタをもとにFWK再展開
  pullmem16 ZP_SDSEEK_VEC16       ; 書き込み先ポインタ復帰
  CLC
  RTS
@SKP_NEXTCLUS:
  ; リアルセクタ番号を更新
  ;loadreg16 (FWK_REAL_SEC) ; DST設定済み
  ;JSR AX_DST
  LDA #1
  JSR L_ADD_BYT
  CLC
  RTS

@MIGHT_EOC:
  ; 上位バイトを見たところEOCの可能性あり
  LDA (ZP_LSRC0_VEC16),Y    ; $0F[??]_????
  DEY
  AND (ZP_LSRC0_VEC16),Y    ; $0F??_[??]??
  DEY
  INC                       ; $FF++==0
  BNE @NOT_EOC1             ; 中位2バイトをみたらEOCじゃなかった
  LDA (ZP_LSRC0_VEC16),Y    ; $0F??_??[??]
  ORA #%111
  INC                       ; $FF++==0
  BNE @NOT_EOC1             ; 最下位バイトを見たらEOCじゃなかった（そんなことある？）
  ; EOC確定
  PLA                       ; 控えてあったZP_SDSEEK_VEC16の破棄
  PLA
  SEC
  RTS
@NOT_EOC1:
  LDY #2
  BRA @NOT_EOC

INTOPEN_FILE_SIZ:
  ; FINFO構造体に展開されたサイズをFCTRL構造体にコピー
  ; NOTE: FD_OPENでしか呼ばれないので開いてもいいかも
  loadreg16 FWK+FCTRL::SIZ        ; デスティネーションをサイズに
  JSR AX_DST
  loadreg16 FINFO_WK+FINFO::SIZ   ; ソースをFINFOのサイズにしてロード
  JSR L_LD_AXS
  RTS

INTOPEN_FILE_DIR_RSEC:
  JSR FINFO_WK_OPEN_DIRENT        ; FINFOの親をFWKに
  ; fwk::rsec<=realsec
  loadreg16 FWK+FCTRL::DIR_RSEC
  JSR AX_DST
  loadreg16 FWK_REAL_SEC
  JSR L_LD_AXS
  ; 最高位バイトの上位4bitが空なのでエントリ座標を仕込む
  LDA FINFO_WK+FINFO::DIR_ENT
  ORA FWK+FCTRL::DIR_RSEC+3
  STA FWK+FCTRL::DIR_RSEC+3
  RTS

INTOPEN_FILE_CLEAR_SEEK:
  STZ FWK+FCTRL::SEEK_PTR
  STZ FWK+FCTRL::SEEK_PTR+1
  STZ FWK+FCTRL::SEEK_PTR+2
  STZ FWK+FCTRL::SEEK_PTR+3
  RTS

INTOPEN_PDIR:
  ; 親ディレクトリを開く
  ;   セクタ
  loadreg16 FWK_REAL_SEC
  JSR AX_DST
  loadreg16 FWK+FCTRL::DIR_RSEC
  JSR L_LD_AXS
  LDA FWK+FCTRL::DIR_RSEC+3
  PHA
  AND #%00001111
  STA FWK_REAL_SEC+3
  JSR RDSEC                 ; セクタを開く
  ;   セクタ内シーク
  PLA
  AND #%11110000
  JSR SEEK_DIRENT
  ;   FINFOに格納
  JSR DIR_GETENT
  RTS

DIR_NEXTMATCH:
  ; 次のマッチするエントリを拾ってくる（FINFO_WKを構築する）
  ; ZP_SDSEEK_VEC16が32bitにアライメントされる
  ; Aには属性が入って帰る
  ; もう何もなければ$FFを返す
  ; input:AY=ファイル名
  STA ZR2                       ; ZR2=マッチパターン（ファイル名）
  STY ZR2+1
  JSR DIR_NEXTENT_ENT           ; 初回用エントリ
  BRA :+                        ; @FIRST
DIR_NEXTMATCH_NEXT_ZR2:         ; 今のポイントを無視して次を探すためのエントリポイント
@NEXT:
  JSR DIR_NEXTENT               ; 次のエントリを拾う
:
@FIRST:
  CMP #$FF                      ; もうエントリがない時のエラーハンドル
  BNE @SKP_END
  RTS
@SKP_END:
  PHA                           ; 属性値をプッシュ
  LDA ZR2
  LDY ZR2+1
  JSR PATTERNMATCH
  PLA                           ; 属性値をプル
  BCC @NEXT                     ; C=0つまりマッチしなかったら次を見る
  RTS

PATH2FINFO:
  ; フルパスからFINFOをゲットする
  ; A:/HOGE/FUGA のFUGAのFINFO
  ; input:AY=PATH
  ; output:AY=ZR2=最終要素の先頭
  ; ZR0,2使用
  STA ZR2
  STY ZR2+1             ; パス先頭を格納
PATH2FINFO_ZR2:
  JSR P2F_PATH2DIRINFO
  BCS @ERR
  JSR P2F_CHECKNEXT
  loadAY16 FINFO_WK
@ERR:
  RTS

P2F_PATH2DIRINFO:
  ; フルパスから最終要素直前のディレクトリのFINFOをゲットする
  ; A:/HOGE/FUGA のHOGEのFINFO
  ; input:ZR2=PATH
  ; output:AY=ZR2=最終要素の先頭
  ; ZR0,2使用
  LDY #1
  LDA (ZR2),Y           ; 二文字目
  CMP #':'              ; ドライブ文字があること判別
  BEQ @SKP_E1
  LDA #ERR::ILLEGAL_PATH
  JMP ERR::REPORT       ; ERR:ドライブ文字がないパスをぶち込まれても困る
@SKP_E1:
  LDA (ZR2)             ; ドライブレターを取得
  SEC
  SBC #'A'              ; ドライブ番号に変換
  ;STA FINFO_WK+FINFO::DRV_NUM ; ドライブ番号を登録
  JSR INTOPEN_DRV       ; ドライブを開く
  JSR INTOPEN_ROOT      ; ルートディレクトリを開く
  ; ディレクトリをたどる旅
@LOOP:
  mem2AY16 ZR2
  JSR PATH_SLASHNEXT_GETNULL  ; 次の（初回ならルート直下の）要素先頭、最終要素でC=1 NOTE:AYが次のよう先頭を指すBP
  storeAY16 ZR2
  BCS @LAST             ; 最終要素であれば探索せずいったん帰って指示を仰ぐ
  JSR P2F_CHECKNEXT     ; 非最終要素なら探索
  BCC @LOOP             ; 見つからないエラーがなければ次の要素へ
  RTS                   ; 見つからなければC=1を保持して戻る
@LAST:
  CLC                   ; TODO:PATH_SLASHNEXTのキャリーエラーを逆転させればこれを省ける
  RTS

P2F_CHECKNEXT:
  ; PATH2FINFOにおいて、次の要素を開く
  ; input:AY=要素名
  ; output:<FINFOが開かれる>
  ; C=1 ERR
  JSR DIR_NEXTMATCH     ; 現在ディレクトリ内のマッチするファイルを取得 NOTE:ヒットしたが開かれる前のFINFOを見るBP
  CMP #$FF              ; 見つからない場合
  BNE @SKP_E2
  LDA #ERR::FILE_NOT_FOUND
  JMP ERR::REPORT       ; ERR:指定されたファイルが見つからなかった
@SKP_E2:
  JSR INTOPEN_FILE      ; ファイル/ディレクトリを開く NOTE:開かれた内容を覗くBP
  CLC                   ; コールされた時の成功を知るC=0
  RTS

PATH_SLASHNEXT_GETNULL:
  ; 下のサブルーチンの、その要素が/で終わるのかnullで終わるのか通知する版
  JSR PATH_SLASHNEXT
  BCC @SKP_FIRSTNULL        ; そもそもnullから開始される
  RTS
@SKP_FIRSTNULL:
  pushAY16
  JSR PATH_SLASHNEXT        ; 進んだ先の次を探知
  pullAY16
  RTS                       ; キャリー含め返す

PATH_SLASHNEXT:
  ; AYの次のスラッシュの次を得る、AYが進む
  ; そこがnullならC=1（失敗
  STA ZR0
  STY ZR0+1
  LDY #$FF
@LOOP:
  INY
  LDA (ZR0),Y
  BNE @SKP_ERR
@EXP:                   ; 例外終了
  SEC
  RTS
@SKP_ERR:
  CMP #'/'
  BNE @LOOP
  INY                   ; スラッシュの次を示す
  LDA (ZR0),Y           ; /の次がヌルならやはり例外終了
  BEQ @EXP
  LDA ZR0
  LDX ZR0+1
  JSR S_ADD_BYT         ; ZR0+Y
  PHX
  PLY
  CLC
  RTS

GET_EMPTY_CLUS:
  ; FAT2を探索して空クラスタを発見する
  @ZR2_SP=ZR2
  @ZR34_NEWCLUS=ZR3
  ; SPを控える
  TSX
  STX @ZR2_SP
  ; クラスタ番号カウンタをリセット
  LDA #2
  STA @ZR34_NEWCLUS
  STZ @ZR34_NEWCLUS+1
  STZ @ZR34_NEWCLUS+2
  STZ @ZR34_NEWCLUS+3
  ; FAT2の頭を開く
  mem2mem16 FWK_REAL_SEC,DWK_FATSTART2
  JSR RDSEC
  ; ZP_SDSEEK_VEC16は最初のクラスタを指している…
  ; 0,1番クラスタはスキップ
  LDY #2*4
@LOOP:
  JSR @SEARCH_PAGE
  INC ZP_SDSEEK_VEC16+1
  JSR @SEARCH_PAGE
@NEXT_SEC:
  ; 次セクタ
  loadreg16 (FWK_REAL_SEC)
  JSR AX_DST
  LDA #1
  JSR L_ADD_BYT ; use:ZR0
  LDY #0
  JSR RDSEC
  BRA @LOOP

@SEARCH_PAGE:
  ; ゼロ=空クラスタ検出
  LDA (ZP_SDSEEK_VEC16),Y
  INY
  ORA (ZP_SDSEEK_VEC16),Y
  INY
  ORA (ZP_SDSEEK_VEC16),Y
  INY
  ORA (ZP_SDSEEK_VEC16),Y
  BNE @NEXT_ENT                       ; 非ゼロなら次
  ; 空クラスタ検出
  ;   一段深いサブルーチンになっているのでスタック復帰
  LDX @ZR2_SP
  TXS
  RTS
@NEXT_ENT:
  ; 次エントリ
  PHY
  loadreg16 (@ZR34_NEWCLUS)
  JSR AX_DST
  LDA #1
  JSR L_ADD_BYT ; use:ZR0
  PLY
  INY
  BNE @SEARCH_PAGE
  ; ページを読み終わったら帰る
  RTS

WRITE_CLUS:
  ; FAT2の着目箇所にクラスタ番号を書き込み、FAT1にも同様に書き込む
  ; FAT2に書き込む
  JSR WRSEC
  BCS @ERR                    ; C=1 ERR
@SKP_FAT2ERR:
  ; FAT1に書き込む
  DEC ZP_SDSEEK_VEC16+1       ; * fat1=fat2-fatlen
  loadreg16 FWK_REAL_SEC      ; |
  JSR AX_DST                  ; |
  loadreg16 DWK_FATLEN        ; |
  JSR L_SB_AXS                ; |
  JSR WRSEC
@ERR:
  RTS

ALLOC_CLUS:
  ; 新規クラスタを割り当てる

DIR_WRENT:
  ; ディレクトリエントリを書き込む
  ; 要求: 該当セクタがバッファに展開されている、REALSECも正しい
  ;       ZP_SDSEEK_VEC16がエントリ先頭を指している
  JSR DIR_WRENT_DRY
  ; ライトバック
  JSR WRSEC
  SEC                                         ; C=1 ERR
  BNE @ERR
  CLC                                         ; C=0 OK
@ERR:
  RTS

DIR_WRENT_DRY:
  ; 名前
  mem2AX16 ZP_SDSEEK_VEC16
  JSR AX_DST
  loadreg16 FINFO_WK+FINFO::NAME
  JSR AX_SRC
  JSR M_SFN_DOT2RAW
  ; 属性
  LDA FINFO_WK+FINFO::ATTR
  LDY #OFS_DIR_ATTR
  STA (ZP_SDSEEK_VEC16),Y
  ; サポートしない情報 NTRes(1)CrtTimeTenth(1)CrtTime(2)CrtDate(2)LstAccDate(2)=8bytes
  LDA #0
@LOOP:
  INY
  STA (ZP_SDSEEK_VEC16),Y
  CPY #OFS_DIR_FSTCLUSHI-1
  BNE @LOOP
  ; 先頭クラスタ 上位
  INY
  LDA FINFO_WK+FINFO::HEAD+2
  STA (ZP_SDSEEK_VEC16),Y
  INY
  LDA FINFO_WK+FINFO::HEAD+3
  STA (ZP_SDSEEK_VEC16),Y
  ; 更新日時
  LDX #FINFO::WRTIME
@LOOP2:
  INY
  LDA FINFO_WK,X
  STA (ZP_SDSEEK_VEC16),Y
  INX
  CPY #OFS_DIR_FSTCLUSLO-1
  BNE @LOOP2
  ; 先頭クラスタ 下位
  INY
  LDA FINFO_WK+FINFO::HEAD
  STA (ZP_SDSEEK_VEC16),Y
  INY
  LDA FINFO_WK+FINFO::HEAD+1
  STA (ZP_SDSEEK_VEC16),Y
  ; サイズ
  LDX #FINFO::SIZ
@LOOP3:
  INY
  LDA FINFO_WK,X
  STA (ZP_SDSEEK_VEC16),Y
  INX
  CPY #OFS_DIR_FILESIZE+3
  BNE @LOOP3
  RTS

WRSEC:
  ; セクタバッファをFWK_REAL_SECに書き出す
  LDA #>SECBF512
  STA ZP_SDSEEK_VEC16+1
  STZ ZP_SDSEEK_VEC16
  loadmem16 ZP_SDCMDPRM_VEC16,(FWK_REAL_SEC)
  JSR SD::WRSEC
  SEC                                         ; C=1 ERR
  BNE @ERR
@SKP_E:
  DEC ZP_SDSEEK_VEC16+1
  CLC                                         ; C=0 OK
@ERR:
  RTS

FAT_READ:
; 32bit値をコピーする
.macro long_long_copy dst,src
  LDA src
  STA dst
  LDA src+1
  STA dst+1
  LDA src+2
  STA dst+2
  LDA src+3
  STA dst+3
.endmac
; 32bit値を減算する
.macro long_long_sub dst,left,right
  SEC
  LDA left
  SBC right
  STA dst
  LDA left+1
  SBC right+1
  STA dst+1
  LDA left+2
  SBC right+2
  STA dst+2
  LDA left+3
  SBC right+3
  STA dst+3
.endmac
; 32bit値と16bit値とを比較する
.macro long_short_cmp left,right
  .local @EXIT
  .local @LEFT_GREAT
  .local @EQUAL
  .local @LEFT_SMALL
  ; byte 3, 2 の比較
  LDA left+3
  ORA left+2
  BNE @LEFT_GREAT ; 左の上位半分がゼロでなかったら右は敵わない
  ; byte 1
  LDA left+1
  CMP right+1
  BNE @EXIT       ; 16bit中上位8bitが同じでなかったら比較結果が出ている
  ; byte 0
  LDA left
  CMP right
  BRA @EXIT
@LEFT_GREAT:
  LDA #2
  CMP #1          ; 2-1
@EXIT:
.endmac
; 32bit値に16bit値を加算する
.macro long_short_add dst,left,right
  CLC
  LDA left
  ADC right
  STA dst
  LDA left+1
  ADC right+1
  STA dst+1
  LDA left+2
  ADC #0
  STA dst+2
  LDA left+3
  ADC #0
  STA dst+3
.endmac
; エラー無視readsec
.macro rdsec_f
  .local @LOOP
@LOOP:
  JSR RDSEC ; ロード NOTE:Aに示されるエラーコードを見る…1ならたぶんCMD17失敗
  BCS @LOOP ; CMD17失敗をリトライで対応 TODO:大変アドホック！なんとかしろ
.endmac
  ; ---------------------------------------------------------------
  ;   サブルーチンローカル変数の定義
  @ZR2_LENGTH         = ZR2       ; 読みたいバイト長=>読まれたバイト長
  @ZR34_TMP32         = ZR3       ; 32bit計算用、読まれたバイト長が求まった時点で破棄
  @ZR3_BFPTR          = ZR3       ; 書き込み先のアドレス
  @ZR4_ITR            = ZR4       ; イテレータ
  @ZR5L_RWFLAG        = ZR5       ; bit0 0=R 1=W
  ; ---------------------------------------------------------------
  ;   引数の格納
  PHX                             ; fdをプッシュ
  pushmem16 ZR0                   ; 書き込み先アドレス退避
  ; ---------------------------------------------------------------
  ;   LENGTHの処理
  ;   READ:   ファイルの残りより多く要求されていた場合、ファイルの残りにする
  ;   WRITE:  ファイルの残りより多く書くつもりの場合、ファイルサイズを拡張する
  TXA
  JSR LOAD_FWK_MAKEREALSEC        ; AのfdからFCTRL構造体をロード、リアルセクタ作成
  LDA FWK+FCTRL::SIZ
  long_long_sub   @ZR34_TMP32, FWK+FCTRL::SIZ, FWK+FCTRL::SEEK_PTR   ; tmp=siz-seek
  long_short_cmp  @ZR34_TMP32, @ZR2_LENGTH                           ; tmp<=>length @ZR34_TMP32の破棄
  BEQ @SKP_PARTIAL_LENGTH
  BCS @SKP_PARTIAL_LENGTH         ; 要求lengthがファイルの残りより小さければそのままで問題なし
  ; siz-seek<length
  BBR0 @ZR5L_RWFLAG,@OVER_LEN_READ
  ; ---------------------------------------------------------------
  ;   WRITE:sizを更新
@OVER_LEN_WRITE:
  ; ディレクトリを開く
  JSR INTOPEN_PDIR
  ; FINFO newsiz=seek+len
  loadreg16 FINFO_WK+FINFO::SIZ   ; * siz=seek+len
  JSR AX_DST                      ; |
  loadreg16 FWK+FCTRL::SEEK_PTR   ; |
  JSR L_LD_AXS                    ; |
  STZ ZR3                         ; |
  STZ ZR3+1                       ; |
  loadreg16 @ZR2_LENGTH           ; |
  JSR L_ADD_AXS                   ; |
  ; FINFOをディスクに書き込み
  JSR DIR_WRENT
  ; FINFO->FWK
  JSR INTOPEN_FILE
  JSR INTOPEN_FILE_SIZ
  BRA @SKP_PARTIAL_LENGTH
  ; ---------------------------------------------------------------
  ;   READ:lengthをファイルの残りに変更
@OVER_LEN_READ:
  mem2mem16 @ZR2_LENGTH,@ZR34_TMP32
@SKP_PARTIAL_LENGTH:
  ; lengthが0になったら強制終了
  LDA @ZR2_LENGTH
  ORA @ZR2_LENGTH+1
  BNE @SKP_EOF
  ; length=0
  PLX                             ; ユーザバッファアドレス回収
  PLX
  PLX                             ; fd回収
  SEC
  RTS
@SKP_EOF:
  pullmem16 @ZR3_BFPTR            ; 書き込み先アドレスをスタックから復帰
  ; ---------------------------------------------------------------
  ;   モード分岐
  BBS0 @ZR5L_RWFLAG,@READ_BY_BYT  ; WRITEならバイトモード強制
  ; SEEKはセクタアライメントされているか？
  LDA FWK+FCTRL::SEEK_PTR
  BNE @NOT_SECALIGN
  LDA FWK+FCTRL::SEEK_PTR+1
  LSR
  BCS @NOT_SECALIGN
  ; SEEKがセクタアライン
  ; LENGTHはセクタアライメントされているか？
  LDA @ZR2_LENGTH                 ; 下位
  BNE @NOT_SECALIGN
  LDA @ZR2_LENGTH+1               ; 上位
  LSR                             ; C=bit0
  BCS @NOT_SECALIGN               ; ページ境界だがセクタ境界でない残念な場合
  ; LENGTHもセクタアライン、A=読み取りセクタ数
  JMP @READ_BY_SEC
@NOT_SECALIGN:
  ; SEEKがセクタアライメントされていなかった
  ; ---------------------------------------------------------------
  ;   バイト単位リード -- 実はREADと共用で、データの移動方向とクラスタ追加の可否だけが違う
@READ_BY_BYT:
  ; 読み取り長さの上位をイテレータに
  LDA @ZR2_LENGTH+1
  STA @ZR4_ITR
  rdsec_f
  ; SDSEEKの初期位置をシークポインタから計算
  JSR FCTRL2SEEK
  ; 1文字ずつ、固定バッファロード->指定バッファに移送
  LDX @ZR2_LENGTH                 ; ページ端数部分を初回ループカウンタに
  BEQ @SKP_INC_ITR                ; 下位がゼロでないとき、
  INC @ZR4_ITR                    ; DECでゼロ検知したいので1つ足す
@SKP_INC_ITR:
  LDY #0                          ; BFPTRインデックス
@LOOP_BYT:
  BBS0 @ZR5L_RWFLAG,@WRITE_BYTE   ; RW分岐
  ; --- R ---
@READ_BYTE:
  LDA (ZP_SDSEEK_VEC16)           ; 固定バッファからデータをロード
  STA (@ZR3_BFPTR),Y              ; 指定バッファにデータをストア
  BRA @SKP_WRITE_BYTE
  ; --- W ---
@WRITE_BYTE:
  LDA (@ZR3_BFPTR),Y              ; 指定バッファからデータをロード
  STA (ZP_SDSEEK_VEC16)           ; 固定バッファにデータをストア
  ; --- 共通 ---
@SKP_WRITE_BYTE:
  ; BFPTRの更新
  INY                             ; Yインクリメント
  BNE @SKP_BF_NEXT_PAGE           ; Yが0に戻った=BFPTRのページ跨ぎ発生
  ; BFPTRのページを進める
  INC @ZR3_BFPTR+1                ; 書き込み先の上位インクリメント
  ; - BFPTRのページ進め終了
@SKP_BF_NEXT_PAGE:                ; <-BFPTRページ跨ぎがない
  ; SDSEEKの更新
  INC ZP_SDSEEK_VEC16             ; 下位インクリメント
  BNE @SKP_SDSEEK_NEXT_PAGE       ; 下位のインクリメントがゼロに=SDSEEKのページ跨ぎ
  ; SDSEEKのページを進める
  LDA ZP_SDSEEK_VEC16+1           ; 上位
  CMP #>SECBF512
  BEQ @INC_SDSEEK_PAGE            ; 固定バッファの前半分だったら上位インクリメント
  ; SDSEEKのページを巻き戻し、次のセクタをロード
  PHX
  PHY
  BBR0 @ZR5L_RWFLAG,@SKP_WRSEC    ; RW分岐
  JSR WRSEC
@SKP_WRSEC:
  JSR NEXTSEC                     ; 次のセクタに移行
;  BCC @SKP_EOC
;  JMP RW_EOC
;@SKP_EOC:
  rdsec_f
  PLY
  PLX
  BRA @SKP_INC_SDSEEK
@INC_SDSEEK_PAGE:                 ; <-ページ巻き戻しが不要
  INC ZP_SDSEEK_VEC16+1           ; 上位インクリメント
@SKP_INC_SDSEEK:                  ; <-ページ巻き戻し終了（特別やることがないので実際には直接LOOP_BYTへ）
@SKP_SDSEEK_NEXT_PAGE:            ; <-SDSEEKページ跨ぎなし（特別やることがないので実際には直接LOOP_BYTへ）
  ; 残りチェック
  DEX
  BNE @LOOP_BYT                   ; まだ文字があるので次へ
  ; 残りページ数チェック
  DEC @ZR4_ITR                    ; 読み取り長さ上位イテレータ
  BNE @LOOP_BYT                   ; イテレータが1以上ならまだやることがある
  ; おわり
  BBR0 @ZR5L_RWFLAG,@END
  JSR WRSEC
  BRA @END
  ; ---------------------------------------------------------------
  ;   セクタ単位リード
@READ_BY_SEC:
  ; 残りセクタ数をイテレータに
  STA @ZR4_ITR
  ; rdsec
  mem2mem16 ZP_SDSEEK_VEC16  ,  @ZR3_BFPTR      ; 書き込み先をBFPTRに（初回のみ）
  loadmem16 ZP_SDCMDPRM_VEC16,  FWK_REAL_SEC    ; リアルセクタをコマンドパラメータに
@LOOP_SEC:
  JSR SD::RDSEC                   ; 実際にロード
  JSR NEXTSEC                     ; 次弾装填
  INC ZP_SDSEEK_VEC16+1           ; 書き込み先ページの更新
  DEC @ZR4_ITR                    ; 残りセクタ数を減算
  BNE @LOOP_SEC                   ; 残りセクタが0でなければ次を読む
  ; エラー処理省略
  ; ---------------------------------------------------------------
  ;   終了処理
@END:
  ; fctrl::seekを進める
  long_short_add FWK+FCTRL::SEEK_PTR, FWK+FCTRL::SEEK_PTR, @ZR2_LENGTH ; seek=seek+length
  ; FWKを反映
  PLA                             ; fd
  JSR PUT_FWK
@SKP_SEC:
  ; 実際に読み込んだバイト長をAYで帰す
  mem2AY16 @ZR2_LENGTH
  CLC
  ; debug for com/test/fsread.s
  ;mem2mem16 ZR0,ZP_SDSEEK_VEC16
  ;loadAY16 FWK                    ; 実験用にFCTRLを開放
  RTS

FCTRL2SEEK:
  ; SDSEEKの初期位置をシークポインタから計算
  LDA FWK+FCTRL::SEEK_PTR+1       ; 第1バイト
  LSR                             ; bit 0 をキャリーに
  BCC @SKP_INCPAGE                ; C=0 上部 $03 ？ 逆では
  INC ZP_SDSEEK_VEC16+1           ; C=1 下部 $04
@SKP_INCPAGE:
  LDA FWK+FCTRL::SEEK_PTR         ; 第0バイト
  STA ZP_SDSEEK_VEC16
  RTS

