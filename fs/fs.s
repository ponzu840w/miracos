; -------------------------------------------------------------------
;               MIRACOS BCOS ファイルシステムモジュール
; -------------------------------------------------------------------
; SDカードのFAT32ファイルシステムをサポートする
; 1バイトのファイル記述子をオープンすることでファイルにアクセス可能
; -------------------------------------------------------------------
.INCLUDE "FXT65.inc"
.INCLUDE "errorcode.inc"

; 命名規則
; BYT  8bit
; SHORT 16bit
; LONG  32bit

; -------------------------------------------------------------------
;                           定数定義
; -------------------------------------------------------------------
FCTRL_ALLOC_SIZE = 4  ; 静的に確保するFCTRLの数
NONSTD_FD        = 8  ; 0～7を一応標準ファイルに予約

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

;TEST:
;  ; にっちもさっちも
;  loadAY16 PATH_YRYR  ; ファイルパスを指定
;  JSR FUNC_FS_OPEN    ; ファイルをオープンする
;  STA FD0
;  loadAY16 PATH_CCP   ; ファイルパスを指定
;  JSR FUNC_FS_OPEN    ; ファイルをオープンする
;  STA FD1
;@LOOP:
;  loadmem16 ZR0,$2000 ; 書き込み先
;  JSR FUNC_CON_IN_CHR ; 文字入力を待機
;  AND #$0F            ; 一桁抽出
;  PHA
;  LDY #0              ; $03文字
;  LDX FD0
;  JSR FUNC_FS_READ_BYTS
;  loadmem16 ZR0,$2100 ; 書き込み先
;  PLA
;  LDY #0              ; $03文字
;  LDX FD1
;  JSR FUNC_FS_READ_BYTS
;  BRK
;  NOP
;  BRA @LOOP
;
; テスト用変数
;FD0:  .RES 1
;FD1:  .RES 1
;
;PATH_CCP:       .ASCIIZ "A:/MIRACOS/CCP.COM"
;PATH_YRYR:      .ASCIIZ "A:/YRYR.TXT"

; -------------------------------------------------------------------
; BCOS 18                 ファイル読み取り
; -------------------------------------------------------------------
; input :ZR1=fd, AY=len, ZR0=bfptr
; output:AY=actual_len、C=EOF
; -------------------------------------------------------------------
FUNC_FS_READ_BYTS:
  STA ZR2
  STY ZR2+1                       ; ZR2=len
  LDA ZR1
  PHA                             ; fd退避
  LDA ZR0
  LDY ZR0+1
  PHA
  PHY                             ; 書き込み先を退避
  STZ ZR3
  STZ ZR3+1                       ; ZR3を実際に読み取ったバイト数のカウンタとして初期化
  LDA ZR1                         ; FDをAに
  JSR LOAD_FWK                    ; FDからFCTRL構造体をロード
  loadreg16 FWK_REAL_SEC          ; リアルセクタ
  JSR AX_DST                      ; 書き込み先に
  loadreg16 FWK+FCTRL::CUR_CLUS   ; 現在クラスタのポインタ
  JSR CLUS2SEC_AXS                ; ソースにしてクラスタセクタ変換
  LDY FWK+FCTRL::CUR_SEC          ; 現在セクタ
  JSR L_ADD_BYT                   ; リアルセクタに現在セクタを加算
  JSR RDSEC                       ; セクタ読み取り、SDSEEKは起点
  ; シークポインタの初期位置を計算
  LDA FWK+FCTRL::SEEK_PTR+1       ; 第1バイト
  LSR                             ; bit 0 をキャリーに
  BCC @SKP_INCPAGE                ; C=0 上部
  INC ZP_SDSEEK_VEC16+1           ; C=1 下部
@SKP_INCPAGE:
  LDA FWK+FCTRL::SEEK_PTR         ; 第0バイト
  CLC
  ADC ZP_SDSEEK_VEC16
  STA ZP_SDSEEK_VEC16             ; 下位バイトを加算
  PLA
  STA ZR0+1
  PLA
  STA ZR0                         ; 書き込み先を復帰
  loadreg16 FWK+FCTRL::SIZ        ; サイズ
  JSR AX_SRC                      ; 比較もとに
  loadreg16 FWK+FCTRL::SEEK_PTR   ; シークポインタ
  JSR AX_DST                      ; 書き込み先に
  JSR L_CMP                       ; SIZとSEEK_PTRを比較
  SEC                             ; C=最終バイトフラグ
  BEQ @END                        ; （始まる前から）最終バイト読み取り完了につき終了
  ; 一文字づつ読み取り
@LOOP:
  LDA #$FF                        ; 全ビットを見る
  BIT ZR2+1                       ; 上位桁がゼロか  -len
  BNE @NZ
  BIT ZR2                         ; 下位桁がゼロか
  BNE @NZ                         ; まだ残ってるなら読み取りを実行、そうでなければ要求完了
  CLC                             ; 最終バイトフラグを折る
@END:
  PLA                             ; 終了処理、現在ファイル記述子復帰
  PHP
  JSR PUT_FWK
  LDA ZR3                         ; 実際に読み込んだバイト数をロード
  LDY ZR3+1
  PLP
  RTS
@NZ:                              ; どちらかがゼロではない
  LDA (ZP_SDSEEK_VEC16)           ; データを1バイト取得
  STA (ZR0)                       ; データを書き込み
  JSR L_CMP                       ; SIZとSEEK_PTRを比較
  SEC                             ; C=最終バイトフラグ
  BEQ @END                        ; 最終バイト読み取り完了につき終了
  INC ZP_SDSEEK_VEC16             ; 下位をインクリメント
  BNE @SKP_INCH
  INC ZP_SDSEEK_VEC16+1           ; 上位をインクリメント
  LDA ZP_SDSEEK_VEC16+1
  CMP #(>SECBF512)+2              ; 読み切ったらEQ
  BNE @SKP_INCH                   ; NOTE:次のセクタに行くときのBP
  JSR NEXTSEC                     ; 次のセクタに移行
  JSR RDSEC                       ; ロード NOTE:Aに示されるエラーコードを見る
@SKP_INCH:
  INC ZR0                         ; ZR0下位をインクリメント -書き込み先
  BNE @SKP_INCH0
  INC ZR0+1                       ; ZR0上位をインクリメント
@SKP_INCH0:
  INC ZR3                         ; ZR3下位をインクリメント -読み取りバイト数
  BNE @SKP_INCH3
  INC ZR3+1                       ; ZR3上位をインクリメント
@SKP_INCH3:
  DEC ZR2                         ; ZR2下位をデクリメント   -len
  LDA ZR2
  CMP #$FF
  BNE @SKP_DECH2
  DEC ZR2+1                       ; ZR2上位をデクリメント
@SKP_DECH2:
  LDA #1
  JSR L_ADD_BYT                   ; SEEK_PTRをインクリメント
  BRA @LOOP

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
  loadreg16 FINFO_WK+FINFO::DIR_CLUS
  JSR CLUS2FWK                        ; FINFOの親ディレクトリの現在クラスタをFWKに展開、ただしSEC=0
  LDA FINFO_WK+FINFO::DIR_SEC         ; クラスタ内セクタ番号を取得
  STA FWK+FCTRL::CUR_SEC              ; 現在セクタ反映
  JSR FLASH_REALSEC
  JSR RDSEC                           ; セクタ読み取り
  LDA FINFO_WK+FINFO::DIR_ENT
  ASL                                 ; 左に転がしてSDSEEK下位を復元、C=後半フラグ
  STA ZP_SDSEEK_VEC16
  LDA #>SECBF512                      ; 前半のSDSEEK
  ADC #0                              ; C=1つまり後半であれば+1する
  STA ZP_SDSEEK_VEC16+1               ; SDSEEK上位を復元
  JSR DIR_NEXTMATCH_NEXT_ZR2
  CMP #$FF                            ; もう無いか？
  CLC
  BNE @SUCS
  SEC
@SUCS:
  loadAY16 FINFO_WK
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
  SEC
  SBC #NONSTD_FD            ; 標準ファイル分を減算
  BVS @SKP_CLOSESTDF
  RTS
@SKP_CLOSESTDF:
  ASL                       ; テーブル参照の為x2
  INC                       ; 上位を見るために+1
  TAX
  LDA #0
  STA FD_TABLE,X
  RTS

; -------------------------------------------------------------------
; BCOS 10                   パス分類
; -------------------------------------------------------------------
; あらゆる種類のパスを解析する
; ディスクアクセスはしない
; input : AY=パス先頭
; output: A=分析結果
;           bit3:/で終わる
;           bit2:ルートディレクトリを指す
;           bit1:ルートから始まる（相対パスでない
;           bit0:ドライブ文字を含む
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
@LOOP:            ; 最後の文字を調べるループ
  INY
  LDA (ZR0),Y
  BNE @LOOP       ; 以下、(ZR0),Yはヌル
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
  pushAY16
  JSR FUNC_FS_PURSE             ; ディレクトリである必要性をチェック
  BBS2 ZR1,@OK                  ; ルートディレクトリを指すならディレクトリチェック不要
  pullAY16
  pushAY16
  JSR FIND_FST_RAWPATH          ; 検索、成功したらC=0
  BCC @SKPERR
  RTS
@SKPERR:                        ; どうやら存在するらしい
  LDA FINFO_WK+FINFO::ATTR      ; 属性値を取得
  AND #DIRATTR_DIRECTORY        ; ディレクトリかをチェック
  BEQ @NOTDIR
@OK:
  loadmem16 ZR1,CUR_DIR         ; カレントディレクトリを対象に
  pullAY16                      ; フルパスをプルしてソースに
  JSR M_CP_AYS                  ; カレントディレクトリを更新
  CLC
  RTS
@NOTDIR:                        ; ERR:ディレクトリ以外に移動しようとした
  pullAY16
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
; BCOS 5                  ファイルオープン
; -------------------------------------------------------------------
; ドライブパスまたはFINFOポインタからファイル記述子をオープンして返す
; input:AY=ptr
; output:A=FD, X=ERR
; -------------------------------------------------------------------
FUNC_FS_OPEN:
  STA ZR2
  STY ZR2+1
  LDA (ZR2)                 ; 先頭バイトを取得
  CMP #$FF                  ; FINFOシグネチャ
  BEQ @FINFO
@PATH:
  JSR PATH2FINFO_ZR2        ; パスからFINFOを開く
  BCC @SKP_PATHERR          ; エラーハンドル
  RTS
@SKP_PATHERR:
@FINFO:
  JSR FD_OPEN
  BEQ X0RTS                 ; エラーハンドル
  LDX #2                    ; EC2:OPENERR
  RTS

FD_OPEN:
  ; FINFOからファイル記述子をオープン
  ; output A=FD, X=EC
  LDA DIRATTR_DIRECTORY
  BIT FINFO_WK+FINFO::ATTR  ; ディレクトリなら非ゼロ
  BEQ @SKP_DIRERR
  LDX #1                    ; EC1:DIR
  RTS
@SKP_DIRERR:                ; 以下、ディレクトリではない
  JSR INTOPEN_FILE          ; FINFOからファイルを開く
  JSR FINFO2SIZ             ; サイズ情報も展開
  JSR GET_NEXTFD            ; ファイル記述子を取得
  PHA
  JSR FCTRL_ALLOC           ; ファイル記述子に実際の構造体を割り当て
  PLA
  PHA
  JSR PUT_FWK               ; ワークエリアの内容を書き込む
  PLA
X0RTS:
  LDX #0
  RTS

PATH2FINFO:
  ; フルパスからFINFOをゲットする
  ; input:AY=PATH
  ; output:AY=FINFO, ZR2=最終要素の先頭
  STA ZR2
  STY ZR2+1             ; パス先頭を格納
PATH2FINFO_ZR2:
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
  JSR PATH_SLASHNEXT_GETNULL    ; 次の（初回ならルート直下の）要素先頭、最終要素でC=1 NOTE:AYが次のよう先頭を指すBP
  storeAY16 ZR2
  BCS @LAST             ; パス要素がまだあるなら続行
  JSR @NEXT             ; 非最終要素
  BCC @LOOP             ; 見つからないエラーがなければ次の要素へ
  RTS                   ; 見つからなければC=1を保持して戻る
@LAST:                  ; 最終要素 ; NOTE:ZR2を読むと、LASTが本当にLASTか見えるBP
  JSR @NEXT
  BCS @ERREND           ; 最終要素が見つからなかったらC=1を保持して戻る
  loadAY16 FINFO_WK     ; パス要素がもうないのでFINFOを返す
  CLC                   ; 成功コード
@ERREND:
  RTS
@NEXT:
  JSR DIR_NEXTMATCH     ; 現在ディレクトリ内のマッチするファイルを取得 NOTE:ヒットしたが開かれる前のFINFOを見るBP
  CMP #$FF              ; 見つからない場合
  BNE @SKP_E2
  LDA #ERR::FILE_NOT_FOUND
  JMP ERR::REPORT       ; ERR:指定されてファイルが見つからなかった
@SKP_E2:
  JSR INTOPEN_FILE      ; ファイル/ディレクトリを開く NOTE:開かれた内容を覗くBP
  CLC                   ; コールされた時の成功を知るC=0
  RTS

INTOPEN_DRV:
  ; input:A=DRV
  CMP DWK_CUR_DRV       ; カレントドライブと比較
  BEQ @SKP_LOAD         ; 変わらないならスキップ
  STA DWK_CUR_DRV       ; カレントドライブ更新
  JSR LOAD_DWK
@SKP_LOAD:
  RTS

INTOPEN_ROOT:
  ; ルートディレクトリを開く
  loadreg16 DWK+DINFO::BPB_ROOTCLUS
OPENCLUS:
  JSR CLUS2FWK
  JSR RDSEC
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

FCTRL_ALLOC:
  ; FDにFCTRL領域を割り当てる…インチキで
  ; input:A=FD
  SEC
  SBC #NONSTD_FD          ; 非標準番号
  TAX                     ; 下位作成のためXに移動
  ASL                     ; 非標準番号*2でテーブルの頭
  TAY                     ; Yに保存
  loadmem16 ZR0,FD_TABLE  ; 非標準FDテーブルへのポインタを作成
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
  CLC
  ADC #NONSTD_FD          ; 非標準ファイル
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

FD2FCTRL:
  ; ファイル記述子をFCTRL先頭AXに変換
  SEC
  SBC #NONSTD_FD          ; 非標準番号
  ASL                     ; x2
  TAY
  loadmem16 ZR0,FD_TABLE  ; 非標準FDテーブルへのポインタを作成
  INY
  LDA (ZR0),Y
  TAX
  DEY
  LDA (ZR0),Y
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
  loadmem16 ZP_SDSEEK_VEC16,SECBF512
  loadmem16 ZP_SDCMDPRM_VEC16,(FWK_REAL_SEC)  ; NOTE:FWK_REAL_SECを読んで監視するBP
  JSR SD::RDSEC
  SEC
  BNE @ERR
@SKP_E:
  DEC ZP_SDSEEK_VEC16+1
  CLC
@ERR:
  RTS

;DIR_OPEN_BYNAME:
;  ; カレントディレクトリ内の名前に一致したファイルを開く
;  ; AXで与えられた名前に合致するのを探す
;  ; アトリビュートを返すので、ファイルかどうかはそっちで確認してね
;  JSR DIR_GET_BYNAME
;  CMP #$FF                ; 見つからなかったら$FFを返して終わり
;  BEQ @EXT
;@DIR_OPEN:
;  loadreg16 DIR::ENT_HEAD
;  JSR FILE_OPEN
;  LDA DIR::ENT_ATTR
;@EXT:
;  RTS
;
;DIR_GET_BYNAME:
;  ; 名前に一致するエントリをゲットする
;  ; Aには属性が入って帰る
;  ; もう何もなければ$FFを返す
;  ; 要求された文字列
;  STA ZR0
;  STX ZR0+1
;  ; カレントディレクトリを開きなおす
;  JSR FILE_REOPEN
;  JSR DIR_RDSEC
;  ; エントリ番号の初期化
;  ;LDA #$FF
;  ;STA DIR::ENT_NUM
;  ;loadmem16 ZP_SDSEEK_VEC16,(SECBF512-32) ; シークポインタの初期化
;  JSR DIR_NEXTENT_ENT
;  BRA @LOOPENT
;@LOOP:
;  JSR DIR_NEXTENT
;  CMP #$FF
;  BNE @LOOPENT
;  RTS
;@LOOPENT:
;  ;LDA ZP_SDSEEK_VEC16
;  ;LDX ZP_SDSEEK_VEC16+1
;  ;JSR PRT_DOTSFN
;  LDA ZP_SDSEEK_VEC16
;  LDX ZP_SDSEEK_VEC16+1
;  LDY #11
;  JSR EQBYTS
;  BNE @LOOP
;  LDA DIR::ENT_ATTR
;  RTS

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

PATTERNMATCH:                   ; http://www.6502.org/source/strings/patmatch.htm by Paul Guertin
  LDY #0                        ; ZR2パターンのインデックス
  LDX #$FF                      ; FINFO::NAMEのインデックス
@NEXT:
  LDA (ZR2),Y                   ; 次のパターン文字を見る
  CMP #'*'                      ; スターか？
  BEQ @STAR
  INX
  CMP #'?'                      ; ハテナか
  BNE @REG                      ; スターでもはてなでもないので普通の文字
  LDA FINFO_WK+FINFO::NAME,X    ; ハテナなのでなんにでもマッチする（同じ文字をロードしておいて比較する）
  BEQ @FAIL                     ; 終了ならマッチしない
  CMP #'/'
  BEQ @FAIL
@REG:
  CMP FINFO_WK+FINFO::NAME,X    ; 文字が等しいか？
  BEQ @EQ
  CMP #'/'                      ; これらは終端か2
  BEQ @FOUND
  BRA @FAIL
@EQ:
  INY                           ; 合っている、続けよう
  CMP #0                        ; これらは終端か
  BNE @NEXT
@FOUND:
  RTS                           ; 成功したのでC=1を返す（SECしなくてよいのか）
@STAR:
  INY                           ; ZR2パターンの*をスキップ
  CMP (ZR2),Y                   ; 連続する*は一つの*に等しい
  BEQ @STAR                     ; のでスキップする
@STLOOP:
  PHY
  PHX
  JSR @NEXT
  PLX
  PLY
  BCS @FOUND                    ; マッチしたらC=1が帰る
  INX                           ; マッチしなかったら*を成長させる
  LDA FINFO_WK+FINFO::NAME,X    ; 終端か
  BEQ @FAIL
  CMP #'/'
  BNE @STLOOP
@FAIL:
  CLC                           ; マッチしなかったらC=0が帰る
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

L_LD_AXS:
  STX ZP_LSRC0_VEC16+1
L_LD_AS:
  STA ZP_LSRC0_VEC16
L_LD:
  ; 値の輸入
  ; DSTは設定済み
  LDY #0
@LOOP:
  LDA (ZP_LSRC0_VEC16),Y
  STA (ZP_LDST0_VEC16),Y
  INY
  CPY #4
  BNE @LOOP
  RTS

AX_SRC:
  ; AXからソース作成
  STA ZP_LSRC0_VEC16
  STX ZP_LSRC0_VEC16+1
  RTS

AX_DST:
  ; AXからデスティネーション作成
  STA ZP_LDST0_VEC16
  STX ZP_LDST0_VEC16+1
  RTS

L_X2_AXD:
  JSR AX_DST
L_X2:
  ; 32bit値を二倍にシフト
  LDY #0
  CLC
  PHP
@LOOP:
  PLP
  LDA (ZP_LDST0_VEC16),Y
  ROL
  STA (ZP_LDST0_VEC16),Y
  INY
  PHP
  CPY #4
  BNE @LOOP
  PLP
  RTS

L_ADD_AXS:
  JSR AX_SRC
L_ADD:
  ; 32bit値同士を加算
  CLC
  LDY #0
  PHP
@LOOP:
  PLP
  LDA (ZP_LSRC0_VEC16),Y
  ADC (ZP_LDST0_VEC16),Y
  PHP
  STA (ZP_LDST0_VEC16),Y
  INY
  CPY #4
  BNE @LOOP
  PLP
  RTS

L_ADD_BYT:
  ; 32bit値に8bit値（アキュムレータ）を加算
  CLC
@C:
  PHP
  LDY #0
@LOOP:
  PLP
  ADC (ZP_LDST0_VEC16),Y
  PHP
  STA (ZP_LDST0_VEC16),Y
  LDA #0
  INY
  CPY #4
  BNE @LOOP
  PLP
  RTS

L_CMP:
  ; 32bit値同士が等しいか否かをゼロフラグで返す
  LDY #0
@LOOP:
  LDA (ZP_LSRC0_VEC16),Y
  CMP (ZP_LDST0_VEC16),Y
  BNE @NOTEQ                  ; 違ってたら抜ける…フラグをそのまま
  INY
  CPY #4
  BNE @LOOP                   ; 全部見たなら抜ける…フラグをそのまま
@NOTEQ:
  RTS

S_ADD_BYT:
  ; AXにYを加算
  STA ZR0
  STX ZR0+1
  TYA
  CLC
  ADC ZR0
  STA ZR0
  LDA #0
  ADC ZR0+1
  STA ZR0+1
  LDA ZR0
  LDX ZR0+1
  RTS

L_SB_BYT:
  ; 32bit値から8bit値（アキュムレータ）を減算
  SEC
@C:
  STA ZR0
  PHP
  LDY #0
@LOOP:
  PLP
  LDA (ZP_LDST0_VEC16),Y
  SBC ZR0
  PHP
  STA (ZP_LDST0_VEC16),Y
  STZ ZR0
  INY
  CPY #4
  BNE @LOOP
  PLP
  RTS

BLDBYT:
  ; 文字列AXをAにする
  ;JSR MON::NIB_DECODE
  ASL
  ASL
  ASL
  ASL
  STA ZR0
  TXA
  ;JSR MON::NIB_DECODE
  ORA ZR0
  RTS

BLDPRTBYT:
  JSR BLDBYT
  PHA
  ;JSR MON::PRT_BYT
  PLA
  RTS

M_SFN_DOT2RAW_WS:
  ; 専用ワークエリアを使う
  ; 文字列操作系はSRC固定のほうが多そう？
  loadreg16 DOT_SFN
M_SFN_DOT2RAW_AXS:
  JSR AX_SRC
  loadreg16 RAW_SFN
M_SFN_DOT2RAW_AXD:
  JSR AX_DST
M_SFN_DOT2RAW:
  ; ドット入り形式のSFNを生形式に変換する
  STZ ZR0   ; SRC
  STZ ZR0+1 ; DST
@NAMELOOP:
  ; 固定8ループ DST
  LDY ZR0
  LDA (ZP_LSRC0_VEC16),Y
  CMP #'.'
  BEQ @SPACE
  ; 次のソース
  INC ZR0
  BRA @STORE
  ; スペースをロード
@SPACE:
  LDA #' '
@STORE:
  LDY ZR0+1
  STA (ZP_LDST0_VEC16),Y
  INC ZR0+1
  CPY #7
  BNE @CKEXEND
@NAMEEND:
  ; 拡張子
  INC ZR0     ; ソースを一つ進める
@CKEXEND:
  CPY #12
  BNE @NAMELOOP
  ; 結果のポインタを返す
  LDA ZP_LDST0_VEC16
  LDX ZP_LDST0_VEC16+1
  RTS

M_SFN_RAW2DOT_WS:
  ; 専用ワークエリアを使う
  loadreg16 RAW_SFN
M_SFN_RAW2DOT_AXS:
  JSR AX_SRC
  loadreg16 DOT_SFN
M_SFN_RAW2DOT_AXD:
  JSR AX_DST
M_SFN_RAW2DOT:
  ; 生形式のSFNをドット入り形式に変換する
  LDY #0
@NAMELOOP:
  LDA (ZP_LSRC0_VEC16),Y
  CMP #' '
  BEQ @NAMEEND
  STA (ZP_LDST0_VEC16),Y
  INY
  CPY #8
  BNE @NAMELOOP
@NAMEEND:
  ; 最終文字がスペースかどうかで拡張子の有無を判別
  STY ZR0 ; DSTのインデックス
  LDY #8
  LDA (ZP_LSRC0_VEC16),Y
  STY ZR0+1 ;SRCのインデックス
  LDY ZR0
  CMP #' '
  BEQ @NOEX
  ; 拡張子あり
@EX:
  LDA #'.'
  STA (ZP_LDST0_VEC16),Y
  INY
  STY ZR0
@EXTLOOP:
  LDY ZR0+1
  LDA (ZP_LSRC0_VEC16),Y
  INY
  CPY #12
  BEQ @NOEX
  STY ZR0+1
  LDY ZR0
  STA (ZP_LDST0_VEC16),Y
  INY
  STY ZR0
  BRA @EXTLOOP
  ; 終端
@NOEX:
  LDY ZR0
  LDA #0
  STA (ZP_LDST0_VEC16),Y
  ; 結果のポインタを返す
  LDA ZP_LDST0_VEC16
  LDX ZP_LDST0_VEC16+1
  RTS

M_CP_AYS:
  ; 文字列をコピーする
  STA ZR0
  STY ZR0+1
  LDY #$FF
@LOOP:
  INY
  LDA (ZR0),Y
  STA (ZR1),Y
  BEQ M_LEN_RTS
  BRA @LOOP

M_LEN:
  ; 文字列の長さを取得する
  ; input:AY
  ; output:Y
  STA ZR1
  STY ZR1+1
M_LEN_ZR1:  ; ZR1入力
  LDY #$FF
@LOOP:
  INY
  LDA (ZR1),Y
  BNE @LOOP
M_LEN_RTS:
  RTS


CUR_DIR:
.ASCIIZ "A:"
.RES 61     ; カレントディレクトリのパスが入る。二行分でアボン

;DRV_INIT:
;  ; MBRを読む
;  loadmem16 ZP_SDCMDPRM_VEC16,SD::BTS_CMDPRM_ZERO
;  loadmem16 ZP_SDSEEK_VEC16,SECBF512
;  JSR SD::RDSEC
;  ;INC ZP_SDSEEK_VEC16+1    ; 後半にこそある。しかしこれも一般的サブルーチンによるべきか？
;  LDY #(OFS_MBR_PARTBL-256+OFS_PT_SYSTEMID)
;  LDA (ZP_SDSEEK_VEC16),Y ; システム標識
;  CMP #SYSTEMID_FAT32
;  BEQ @FAT32
;  CMP #SYSTEMID_FAT32NOCHS
;  BEQ @FAT32
;BRK
;@FAT32:
;  ; ソースを上位のみ設定
;  LDA #(>SECBF512)+1
;  STA ZP_LSRC0_VEC16+1
;  ; DWK+DINFO::PT_LBAOFS取得
;  loadreg16 (DWK+DINFO::PT_LBAOFS)
;  JSR AX_DST
;  LDA #(OFS_MBR_PARTBL-256+OFS_PT_LBAOFS)
;  JSR L_LD_AS
;  ; BPBを読む
;  loadmem16 ZP_SDCMDPRM_VEC16,(DWK+DINFO::PT_LBAOFS)
;  DEC ZP_SDSEEK_VEC16+1
;  JSR SD::RDSEC
;  DEC ZP_SDSEEK_VEC16+1
;  ; DWK+DINFO::SEVPERCLUS取得
;  LDY #(OFS_BPB_SECPERCLUS)
;  LDA (ZP_SDSEEK_VEC16),Y       ; 1クラスタのセクタ数
;  STA DWK+DINFO::BPB_SECPERCLUS
;  ; --- DWK+DINFO::FATSTART作成
;  ; PT_LBAOFSを下地としてロード
;  loadreg16 (DWK+DINFO::FATSTART)
;  JSR AX_DST
;  loadreg16 (DWK+DINFO::PT_LBAOFS)
;  JSR L_LD_AXS
;  ; 予約領域の大きさのあと（NumFATsとルートディレクトリの大きさで、不要）をゼロにして、
;  ; 予約領域の大きさを32bitの値にする
;  LDA #0
;  LDY #(OFS_BPB_RSVDSECCNT+2)
;  STA (ZP_SDSEEK_VEC16),Y
;  INY
;  STA (ZP_SDSEEK_VEC16),Y
;  ; 予約領域を加算
;  loadreg16 (SECBF512+OFS_BPB_RSVDSECCNT)
;  JSR L_ADD_AXS
;  ; --- DWK+DINFO::DATSTART作成
;  ; FATの大きさをロード
;  loadreg16 (DWK+DINFO::DATSTART)
;  JSR AX_DST
;  loadreg16 (SECBF512+OFS_BPB_FATSZ32)
;  JSR L_LD_AXS
;  JSR L_X2                    ; 二倍にする
;  ; FATSTARTを加算
;  loadreg16 (DWK+DINFO::FATSTART)
;  JSR L_ADD_AXS
;  ; --- ルートディレクトリクラスタ番号取得（どうせDAT先頭だけど…
;  loadreg16 (DWK+DINFO::BPB_ROOTCLUS)
;  JSR AX_DST
;  loadreg16 (SECBF512+OFS_BPB_ROOTCLUS)
;  JSR L_LD_AXS
;  RTS

;STR_LEN:
;  ; 文字列の長さを取得する
;  ; input:AY
;  ; output:X
;  STA ZR0
;  STY ZR0+1
;STR_LEN_ZR0:  ; ZR0入力
;  LDY #$FF
;@LOOP:
;  INY
;  LDA (ZR0),Y
;  BNE @LOOP
;  RTS
;
;EQBYTS:
;  ; Xで与えられた長さのバイト列が等しいかを返す
;  ; ZR0とAY
;  ; 文字列比較ではないのでNULLがあってもOK
;  STA ZR1
;  STY ZR1+1
;  TXA
;  TAY
;@LOOP:
;  DEY
;  BMI @EQ               ; 初回で引っかかっても、長さ0の比較は問答無用で正しい
;  LDA (ZR0),Y
;  CMP (ZR1),Y
;  BEQ @LOOP
;@NOT:
;  SEC
;  RTS
;@EQ:
;  CLC
;  RTS

;FILE_DLFULL:
;  ; バイナリファイルをAXからだだっと展開する
;  ; 速さが命
;  STA ZP_SDSEEK_VEC16
;  STX ZP_SDSEEK_VEC16+1
;  ; サイズをロード
;  JSR FILE_SETSIZ
;@CK:
;  JSR CK_ENDSEC_FLG
;  CMP #1
;  BEQ @ENDSEC           ; $1であれば最終セクタ
;@LOOP:
;  loadmem16 ZP_SDCMDPRM_VEC16,FWK+FCTRL::REAL_SEC
;  JSR SD::RDSEC
;  INC ZP_SDSEEK_VEC16+1
;  JSR FILE_NEXTSEC
;  CMP #2
;  BEQ @LOOP              ; $2ならループ
;@ENDSEC:
;  CMP #0
;  BEQ @END               ; $0なら終わり
;  ; 最終セクタ
;  LDA #$80
;  STA DWK+DINFO::SEC_RESWORD
;  loadmem16 ZP_SDCMDPRM_VEC16,FWK+FCTRL::REAL_SEC
;  JSR SD::RDINIT
;  LDA FWK+FCTRL::RES_SIZ+1
;  BIT #%00000001
;  BEQ @SKP_PG
;  ; ページ丸ごと
;  STZ DWK+DINFO::SEC_RESWORD
;  JSR SD::RDPAGE
;  INC ZP_SDSEEK_VEC16+1
;  ; 1ページ分減算
;  loadmem8l ZP_LDST0_VEC16,FWK+FCTRL::RES_SIZ+1
;  LDA #$1
;  JSR L_SB_BYT
;  ;BRA @CK
;@SKP_PG:
;  LDY #0
;@RDLOOP:
;  CPY FWK+FCTRL::RES_SIZ
;  BEQ @SKP_PBYT
;  spi_rdbyt
;  STA (ZP_SDSEEK_VEC16),Y
;  INY
;  BRA @RDLOOP
;@SKP_PBYT:
;  ; 残るセクタ分を処分
;  STY ZR0
;  LDA #0
;  SEC
;  SBC ZR0
;  LSR
;  ADC DWK+DINFO::SEC_RESWORD
;  STA DWK+DINFO::SEC_RESWORD
;  JSR FILE_THROWSEC
;@END:
;  RTS

