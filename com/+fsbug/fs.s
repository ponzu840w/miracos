; -------------------------------------------------------------------
;               MIRACOS BCOS ファイルシステムモジュール
; -------------------------------------------------------------------
; SDカードのFAT32ファイルシステムをサポートする
; 1バイトのファイル記述子をオープンすることでファイルにアクセス可能
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../errorcode.inc"

.INCLUDE "lib_fs.s"
;.PROC FAT
  .INCLUDE "fat.s"
;.ENDPROC

; 命名規則
; BYT  8bit
; SHORT 16bit
; LONG  32bit

; -------------------------------------------------------------------
;                           定数定義
; -------------------------------------------------------------------
FCTRL_ALLOC_SIZE = 4  ; 静的に確保するFCTRLの数

; -------------------------------------------------------------------
;                           初期化処理
; -------------------------------------------------------------------
INIT:
  LDA #$FF
  STA FINFO_WK+FINFO::SIG ; FINFO_WKのシグネチャ設定
  STA DWK_CUR_DRV         ; カレントドライブをめちゃくちゃにする
  JSR SD::INIT            ; カードの初期化
  ;JSR DRV_INIT           ; ドライブの初期化はIPLがやったのでひとまずパス
  ; ドライブテーブルの初期化
  loadmem16 DRV_TABLE,DRV0
  ; ファイル記述子テーブルの初期化 上位バイトを0にしてテーブルを開放する
  LDA #0
  TAX
@FDT_LOOP:
  STA FD_TABLE+1,X
  INX
  CPX #(FCTRL_ALLOC_SIZE*2)-1
  BNE @FDT_LOOP
  RTS

; -------------------------------------------------------------------
; BCOS 15                 ファイル読み取り
; -------------------------------------------------------------------
; input :ZR1=fd, AY=len, ZR0=bfptr
; output:AY=actual_len、C=EOF
; -------------------------------------------------------------------
FUNC_FS_READ_BYTS:
  ; ---------------------------------------------------------------
  ;   サブルーチンローカル変数の定義
  @ZR2_LENGTH         = ZR2       ; 読みたいバイト長=>読まれたバイト長
  @ZR34_TMP32         = ZR3       ; 32bit計算用、読まれたバイト長が求まった時点で破棄
  @ZR3_BFPTR          = ZR3       ; 書き込み先のアドレス
  @ZR4_ITR            = ZR4       ; イテレータ
  @ZR5L_RWFLAG        = ZR5       ; bit0 0=R 1=W
  ; ---------------------------------------------------------------
  ;   引数の格納
  RMB0 @ZR5L_RWFLAG               ; READにセット
@WRITE_ENTRY:
  storeAY16 @ZR2_LENGTH
  LDA ZR1
  PHA                             ; fdをプッシュ
  pushmem16 ZR0                   ; 書き込み先アドレス退避
  ; ---------------------------------------------------------------
  ;   特殊ファイル判定
  LDA ZR1
  JSR LOAD_FWK_MAKEREALSEC        ; AのfdからFCTRL構造体をロード、リアルセクタ作成
  JMP FAT_READ
WRITE_ENTRY=@WRITE_ENTRY

; -------------------------------------------------------------------
; BCOS 9                   ファイル検索                エラーハンドル
; -------------------------------------------------------------------
; input :AY=PATH
; output:AY=FINFO
; パス文字列から新たなFINFO構造体を得る
; 初回（FST）
; -------------------------------------------------------------------
FUNC_FS_FIND_FST:
  JSR FUNC_FS_FPATH         ; 何はともあれフルパス取得
FIND_FST_RAWPATH:           ; FPATHを多重に呼ぶと狂うので"とりあえず"スキップ
@PATH:
  JSR PATH2FINFO            ; パスからFINFOを開く
  BCC @SKP_PATHERR          ; エラーハンドル
  RTS
@SKP_PATHERR:
  loadAY16 FINFO_WK
  CLC
  RTS

; -------------------------------------------------------------------
; BCOS 17                ファイル検索（次）              エラーハンドル
; -------------------------------------------------------------------
; input :AY=前のFINFO、ZR0=ファイル名
; output:AY=FINFO
; -------------------------------------------------------------------
FUNC_FS_FIND_NXT:
  storeAY16 ZR1                       ; ZR1=与えられたFINFO
  LDY #.SIZEOF(FINFO)-1
@DLFWK_LOOP:                          ; 与えられたFINFOをワークエリアにコピーするループ
  LDA (ZR1),Y
  STA FINFO_WK,Y
  DEY
  BPL @DLFWK_LOOP                     ; FINFOコピー終了
  JSR FINFO_WK_OPEN_DIRENT
  JSR RDSEC                           ; セクタ読み取り
  JSR FINFO_WK_SEEK_DIRENT
  JSR DIR_NEXTMATCH_NEXT_ZR2
  CMP #$FF                            ; もう無いか？
  CLC
  BNE @SUCS
  SEC
@SUCS:
  loadAY16 FINFO_WK
  RTS

FINFO_WK_OPEN_DIRENT:
  ; FINFOのもつ親ディレクトリのクラスタ番号・クラスタ内セクタ番号からFWK・REALSECを展開する
  loadreg16 FINFO_WK+FINFO::DIR_CLUS
  JSR HEAD2FWK                        ; FINFOの親ディレクトリの現在クラスタをFWKに展開、ただしSEC=0
                                      ;   先頭扱いでコールしているが先頭クラスタは覚えていない
  LDA FINFO_WK+FINFO::DIR_SEC         ; クラスタ内セクタ番号を取得
  STA FWK+FCTRL::CUR_SEC              ; 現在セクタ反映
  JSR FLASH_REALSEC
  RTS

FINFO_WK_SEEK_DIRENT:
  ; FINFOのもつ親ディレクトリのセクタ内エントリ番号からセクタバッファ内のポインタを作る
  LDA FINFO_WK+FINFO::DIR_ENT
SEEK_DIRENT:
  ASL                                 ; 左に転がしてSDSEEK下位を復元、C=後半フラグ
  STA ZP_SDSEEK_VEC16
  LDA #>SECBF512                      ; 前半のSDSEEK
  ADC #0                              ; C=1つまり後半であれば+1する
  STA ZP_SDSEEK_VEC16+1               ; SDSEEK上位を復元
  RTS

FLASH_REALSEC:
  ; リアルセクタ番号にクラスタ内セクタ番号を反映
  loadreg16 (FWK_REAL_SEC)
  JSR AX_DST
  LDA FWK+FCTRL::CUR_SEC              ; クラスタ内セクタ番号取得
  JSR L_ADD_BYT
  RTS

; -------------------------------------------------------------------
; BCOS 6                  ファイルクローズ
; -------------------------------------------------------------------
; ファイル記述子をクローズして開放する
; input:A=fd
; -------------------------------------------------------------------
FUNC_FS_CLOSE:
;  SEC
;  SBC #NONSTD_FD            ; 標準ファイル分を減算
;  BVC @SKP_CLOSESTDF
;  LDA #ERR::FAILED_CLOSE
;  JMP ERR::REPORT
;@SKP_CLOSESTDF:
  ASL                       ; テーブル参照の為x2
  INC                       ; 上位を見るために+1
  TAX
  LDA #0
  STA FD_TABLE,X
  CLC
  RTS

; -------------------------------------------------------------------
; BCOS 10                   パス分類
; -------------------------------------------------------------------
; あらゆる種類のパスを解析する
; ディスクアクセスはしない
; input : AY=パス先頭
; output: A=分析結果
;           bit4:/を含む
;           bit3:/で終わる
;           bit2:ルートディレクトリを指す
;           bit1:ルートから始まる（相対パスでない
;           bit0:ドライブ文字を含む
; ZR0,1使用
; -------------------------------------------------------------------
FUNC_FS_PURSE:
  storeAY16 ZR0
  STZ ZR1         ; 記録保存用
  LDY #1
  LDA (ZR0),Y     ; :の有無を見る
  CMP #':'
  BNE @NODRIVE
  SMB0 ZR1        ; ドライブ文字があるフラグを立てる
  LDA #2          ; ポインタを進め、ドライブなしと同一条件にする
  CLC
  ADC ZR0
  STA ZR0
  LDA #0
  ADC ZR0+1
  STA ZR0+1
  LDA (ZR0)       ; 最初の文字を見る
  BEQ @ROOTEND    ; 何もないならルートを指している（ドライブ前提
@NODRIVE:
  LDA (ZR0)       ; 最初の文字を見る
  CMP #'/'
  BNE @NOTFULL    ; /でないなら相対パス（ドライブ指定なし前提
  SMB1 ZR1        ; ルートから始まるフラグを立てる
@NOTFULL:
  LDY #$FF
@LOOP:            ; 最後の文字を調べるループ;おまけに/の有無を調べる
  INY
  LDA (ZR0),Y
  BEQ @SKP_LOOP   ; 以下、(ZR0),Yはヌル
  CMP #'/'
  BNE @SKP_SET4
  SMB4 ZR1        ; /を含むフラグを立てる
@SKP_SET4:
  BRA @LOOP
@SKP_LOOP:
  DEY             ; 最後の文字を指す
  LDA (ZR0),Y     ; 最後の文字を読む
  CMP #'/'
  BNE @END        ; 最後が/でなければ終わり
  SMB3 ZR1        ; /で終わるフラグを立てる
  CPY #0          ; /で終わり、しかも一文字だけなら、それはルートを指している
  BNE @END
@ROOTEND:
  SMB2 ZR1        ; ルートディレクトリが指されているフラグを立てる
@END:
  LDA ZR1
  RTS

; -------------------------------------------------------------------
; BCOS 11              カレントディレクトリ変更        エラーハンドル
; -------------------------------------------------------------------
; input : AY=パス先頭
; -------------------------------------------------------------------
FUNC_FS_CHDIR:
  JSR FUNC_FS_FPATH             ; 何はともあれフルパス取得
  storeAY16 ZR3                 ; フルパスをZR3に格納
  JSR FUNC_FS_PURSE             ; ディレクトリである必要性をチェック
  BBS2 ZR1,@OK                  ; ルートディレクトリを指すならディレクトリチェック不要
  mem2AY16 ZR3
  JSR FIND_FST_RAWPATH          ; 検索、成功したらC=0
  BCC @SKPERR
  RTS
@SKPERR:                        ; どうやら存在するらしい
  LDA FINFO_WK+FINFO::ATTR      ; 属性値を取得
  AND #DIRATTR_DIRECTORY        ; ディレクトリかをチェック
  BEQ @NOTDIR
@OK:
  loadmem16 ZR1,CUR_DIR         ; カレントディレクトリを対象に
  mem2AY16 ZR3                  ; フルパスをソースに
  JSR M_CP_AYS                  ; カレントディレクトリを更新
  CLC
  RTS
@NOTDIR:                        ; ERR:ディレクトリ以外に移動しようとした
  LDA #ERR::NOT_DIR
  JMP ERR::REPORT

; -------------------------------------------------------------------
; BCOS 12                 絶対パス取得                エラーレポート
; -------------------------------------------------------------------
; input : AY=相対/絶対パス先頭
; output: AY=絶対パス先頭
; FINFOを受け取ったら親ディレクトリを追いかけてフルパスを組み立てることも
;  検討したが面倒すぎて折れた
; -------------------------------------------------------------------
FUNC_FS_FPATH:
  storeAY16 ZR2                 ; 与えられたパスをZR2に
  loadmem16 ZR1,PATH_WK         ; PATH_WKにカレントディレクトリをコピー
  loadAY16 CUR_DIR
  JSR M_CP_AYS
  loadAY16 CUR_DIR
  JSR M_LEN                     ; Yにカレントディレクトリの長さを与える
  STY ZR3                       ; ZR3に保存
  LDA ZR2
  LDY ZR2+1
  JSR FUNC_FS_PURSE             ; パスを解析する
  ;BBR2 ZR1,@SKP_SETROOT         ; サブディレクトリやファイル（ルートディレクトリを指さない）なら分岐
  BBR0 ZR1,@NO_DRV              ; ドライブレターがないなら分岐
  ; ドライブが指定された（A:/MIRACOS/）
  loadmem16 ZR1,PATH_WK         ; PATH_WKに与えられたパスをそのままコピー
  mem2AY16 ZR2                  ; 与えられたパス
  JSR M_CP_AYS
  BRA @CLEAR_DOT                ; 最終工程だけは共有
@NO_DRV:                        ; 少なくともドライブレターを流用しなければならない
  BBS1 ZR1,@ZETTAI              ; 絶対パスなら分岐
@SOUTAI:                        ; 相対パスである
  LDA #'/'
  LDY ZR3                       ; カレントディレクトリの長さを取得
  STA PATH_WK,Y                 ; 最後に区切り文字を設定
  INY
  loadreg16 PATH_WK
  JSR S_ADD_BYT                 ; Yを加算してつぎ足すべき場所を産出
  STA ZR1
  STX ZR1+1
  BRA @CONCAT
@ZETTAI:                        ; 絶対パスである
  loadmem16 ZR1,PATH_WK+2       ; ワークエリアのA:より後が対象
@CONCAT:                        ; 接合
  mem2AY16 ZR2                  ; 与えられたパスがソース
  JSR M_CP_AYS                  ; 文字列コピーで接合
@CLEAR_DOT:                     ; .を削除する
  LDX #$FF
@CLEAR_DOT_LOOP:                ; .を削除するための探索ループ
  STY ZR0
  INX
  LDA PATH_WK,X
  BEQ @DEL_SLH
  CMP #'/'
  BNE @CLEAR_DOT_LOOP           ; /でないならパス
  TXA                           ; 前の/としてインデックスを保存
  TAY
  LDA PATH_WK+1,X               ; 一つ先読み
  CMP #'.'                      ; /.であるか
  BNE @CLEAR_DOT_LOOP
  LDA PATH_WK+2,X               ; さらに先読み
  CMP #'.'                      ; /..であるか
  BEQ @DELDOTS
@DELDOT:                        ; /.を削除
  LDA PATH_WK+2,X
  STA PATH_WK,X
  BEQ @CLEAR_DOT
  INX
  BRA @DELDOT
@DEL_SLH:                       ; 最終工程スラッシュ消し
  loadAY16 PATH_WK
  JSR M_LEN                     ; 最終結果の長さを取得
  LDA PATH_WK-1,Y
  CMP #'/'
  BNE @RET
  LDA #0
  STA PATH_WK-1,Y
@RET:
  loadAY16 PATH_WK
  JSR FUNC_UPPER_STR
  loadAY16 PATH_WK
  CLC                           ; キャリークリアで成功を示す
  RTS
@DELDOTS:                       ; ../を消すループ（飛び地）
  LDY ZR0
@DELDOTS_LOOP:
  LDA PATH_WK+3,X
  STA PATH_WK,Y
  BEQ @CLEAR_DOT                ; 文頭からやり直す
  INX
  INY
  BRA @DELDOTS_LOOP

; -------------------------------------------------------------------
;                            ファイル作成
; -------------------------------------------------------------------
; ドライブパスからファイルを作成してオープンする
; input:AY=path ptr
; output:A=FD, X=ERR
; -------------------------------------------------------------------
FUNC_FS_MAKEF:
  STA ZR2
  STY ZR2+1
  JSR FUNC_UPPER_STR        ; 大文字にしておく
@PATH:
  JSR P2F_PATH2DIRINFO      ; パスからディレクトリのFINFOを開く
  BCC @SKP_DIRPATHERR       ; エラーハンドル
  RTS
@SKP_DIRPATHERR:
  ; ディレクトリは開けた状態
  JSR P2F_CHECKNEXT         ; 最終要素は開けるかな？
  BCC @EXIST
  ; ディレクトリは開けたが、最終要素が開けない
  ; = ファイル作成の季節
  ; FWK_REAL_SECとZP_SDSEEK_VEC16をスタックにプッシュ
  pushmem16 ZP_SDSEEK_VEC16
  pushmem16 FWK_REAL_SEC
  pushmem16 FWK_REAL_SEC+2
  ; FINFOに新規ファイル名を設定する
  loadmem16 ZR1,FINFO_WK+FINFO::NAME
  mem2mem16 ZR0,ZR2
  JSR M_CP
  ; FINFOをゼロリセットする
  LDA #0
  TAX
@FILLLOOP:
  STA FINFO_WK+FINFO::ATTR,X
  INX
  CPX FINFO::DRV_NUM-FINFO::ATTR
  BNE @FILLLOOP
  ; FINFOに割り当てクラスタを設定する
  JSR GET_EMPTY_CLUS        ; 新規クラスタを発見 ZR34に
  JSR WRITE_CLUS            ; FAT登録
  mem2mem16 FINFO_WK+FINFO::HEAD,ZR3
  mem2mem16 FINFO_WK+FINFO::HEAD+2,ZR4
  ; ディレクトリエントリの書き込み先をスタックから回復
  pullmem16 FWK_REAL_SEC+2
  pullmem16 FWK_REAL_SEC
  JSR RDSEC
  pullmem16 ZP_SDSEEK_VEC16
  JSR DIR_WRENT
  ; ファイルをオープンする
  BRA FINFO2FD
@EXIST:
  LDA #ERR::FILE_EXISTS     ; ERR:ファイルが既に存在していたらダメ
  BRA ERR_REPORT

; -------------------------------------------------------------------
; BCOS 5                  ファイルオープン
; -------------------------------------------------------------------
; ドライブパスまたはFINFOポインタからファイル記述子をオープンして返す
; input:AY=(path or FINFO)ptr
; output:A=FD, X=ERR
; -------------------------------------------------------------------
FUNC_FS_OPEN:
  STA ZR2
  STY ZR2+1
  LDA (ZR2)                 ; 先頭バイトを取得
  CMP #$FF                  ; FINFOシグネチャ
  BEQ FINFO2FD
@PATH:
  JSR PATH2FINFO_ZR2        ; パスからファイルのFINFOを開く
  BCC @SKP_PATHERR          ; エラーハンドル
  RTS
@SKP_PATHERR:
FINFO2FD:
  ; 開かれているFINFOからFDを作成して帰る
  JSR FD_OPEN
  BCC X0RTS                 ; エラーハンドル
  LDA #ERR::FAILED_OPEN
ERR_REPORT:
  JMP ERR::REPORT           ; ERR:ディレクトリとかでオープンできない

; -------------------------------------------------------------------
;                         リアルセクタ作成
; -------------------------------------------------------------------
; input   :A=fd
; output  :FWKがREAL_SECが展開された状態で作成される
; -------------------------------------------------------------------
LOAD_FWK_MAKEREALSEC:
  JSR LOAD_FWK                    ; AのFDからFCTRL構造体をロード
  loadreg16 FWK_REAL_SEC          ; FWKのリアルセクタのポインタを
  JSR AX_DST                      ;   書き込み先にして
  loadreg16 FWK+FCTRL::CUR_CLUS   ; 現在クラスタのポインタを
  JSR CLUS2SEC_AXS                ;   ソースにしてクラスタtoセクタ変換
  LDA FWK+FCTRL::CUR_SEC          ; 現在セクタ
  JSR L_ADD_BYT                   ; リアルセクタに現在セクタを加算
  RTS

; -------------------------------------------------------------------
;                       ファイル記述子操作関連
; -------------------------------------------------------------------
FD_OPEN:
  ; FINFOからファイル記述子をオープン
  ; output A=FD, X=EC
  LDA FINFO_WK+FINFO::ATTR      ; 属性値を取得
  AND #DIRATTR_DIRECTORY        ; ディレクトリかをチェック ディレクトリなら非ゼロ
  BEQ @SKP_DIRERR
  SEC                       ; ディレクトリを開こうとしたエラー
  RTS
@SKP_DIRERR:                ; 以下、ディレクトリではない
  JSR INTOPEN_FILE_DIR_RSEC ; 破壊的なので先にFINFOから親ディレクトリ情報をコピー
  JSR INTOPEN_FILE          ; FINFOからファイルを開く
  JSR INTOPEN_FILE_SIZ      ; サイズ情報も展開
  JSR INTOPEN_FILE_CLEAR_SEEK ; シーク位置をリセット
  JSR GET_NEXTFD            ; ファイル記述子を取得
  PHA
  JSR FCTRL_ALLOC           ; ファイル記述子に実際の構造体を割り当て
  PLA
  PHA
  JSR PUT_FWK               ; ワークエリアの内容を書き込む
  PLA
X0RTS:
  CLC
  RTS

FCTRL_ALLOC:
  ; FDにFCTRL領域を割り当てる…インチキで
  ; input:A=FD
  ;SEC
  ;SBC #NONSTD_FD          ; 非標準番号
  TAX                     ; 下位作成のためXに移動
  ASL                     ; *2でテーブルの頭
  TAY                     ; Yに保存
  loadmem16 ZR0,FD_TABLE  ; FDテーブルへのポインタを作成
  LDA #<FCTRL_RES         ; オフセット下位をロード
@OFST_LOOP:
  CPX #0
  BEQ @OFST_DONE          ; オフセット完成
  CLC
  ADC #.SIZEOF(FCTRL)     ; 構造体サイズを加算
  DEX
  BRA @OFST_LOOP
@OFST_DONE:               ; 下位が完成
  STA (ZR0),Y             ; テーブルに保存
  INY
  LDA #>FCTRL_RES
  STA (ZR0),Y             ; 上位をテーブルに保存
  RTS

GET_NEXTFD:
  ; 次に空いたFDを取得
  loadmem16 ZR0,FD_TABLE  ; テーブル読み取り
  LDY #1
@TLOOP:
  LDA (ZR0),Y             ;NOTE:間接参照する利益がないのでは？
  BEQ @ZERO
  INY
  INY
  BRA @TLOOP
@ZERO:
  DEY                     ; 下位桁に合わせる
  TYA
;  CLC
;  ADC #NONSTD_FD          ; 非標準ファイル
  RTS

FD2FCTRL:
  ; ファイル記述子をFCTRL先頭AXに変換
  ;SEC
  ;SBC #NONSTD_FD          ; 非標準番号
  ASL                     ; x2
  TAY
  loadmem16 ZR0,FD_TABLE  ; FDテーブルへのポインタを作成
  INY
  LDA (ZR0),Y
  TAX
  DEY
  LDA (ZR0),Y
  RTS

; -------------------------------------------------------------------
;                         ファイル書き込み
; -------------------------------------------------------------------
; input :ZR1=fd, AY=len, ZR0=bfptr
; output:AY=actual_len、C=EOF
; -------------------------------------------------------------------
FUNC_FS_WRITE:
  ; ---------------------------------------------------------------
  ;   サブルーチンローカル変数の定義
  @ZR5L_RWFLAG        = ZR5       ; bit0 0=R 1=W
  SMB0 @ZR5L_RWFLAG
  ; ---------------------------------------------------------------
  ;   READを流用
  JMP WRITE_ENTRY

