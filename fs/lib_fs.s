; fs.sのルーチンのうち、汎用性が高そうなものが押し込まれる
; とはいえ再利用を考えているわけでない
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
  JSR FUNC_UPPER_CHR
  CMP FINFO_WK+FINFO::NAME,X    ; 文字が等しいか2
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

L_DIV2:
  ; 32bitを1/2にシフト
  ; 今のところFAT2を求めるときにだけ使用
  LDY #3
  CLC
  PHP
@LOOP:
  PLP
  LDA (ZP_LDST0_VEC16),Y
  ROR
  STA (ZP_LDST0_VEC16),Y
  DEY
  PHP
  CPY #$FF
  BNE @LOOP
  PLP
  RTS

L_ADD_AXS:
  JSR AX_SRC
L_ADD:
  ; 32bit値同士を加算
  ; use:ZR0
  CLC
  LDY #0
  PHP
@LOOP:
  PLP
  LDA (ZP_LDST0_VEC16),Y
  ADC (ZP_LSRC0_VEC16),Y
  PHP
  STA (ZP_LDST0_VEC16),Y
  INY
  CPY #4
  BNE @LOOP
  PLP
  RTS

L_SB_AXS:
  JSR AX_SRC
L_SB:
  ; 32bit値同士を減算
  ; dst=dst-src
  SEC
  LDY #0
  PHP
@LOOP:
  PLP
  LDA (ZP_LDST0_VEC16),Y
  SBC (ZP_LSRC0_VEC16),Y
  PHP
  STA (ZP_LDST0_VEC16),Y
  INY
  CPY #$4
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
  ; use:ZR0
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

M_SFN_DOT2RAW:
  ; ドット入り形式のSFNを生形式に変換する
  ; TODO:fat.s DIR_WRENTでしか使わないため最適化
@ZR0L_SRC=ZR0
@ZR0H_DST=ZR0+1
  ; スペースで埋める
  LDA #' '
  LDY #10
@FILL_LOOP:
  STA (ZP_LDST0_VEC16),Y
  DEY
  BNE @FILL_LOOP
  STA (ZP_LDST0_VEC16),Y
  ; メインループ
  STZ @ZR0L_SRC
  STZ @ZR0H_DST
@LOOP:
  ; 読み取り
  LDY @ZR0L_SRC
  LDA (ZP_LSRC0_VEC16),Y
  BEQ @EXT
  INC @ZR0L_SRC ; 次のCMPに影響を与えない
  CMP #'.'
  BNE @SKP_DOT
  ; .処理
  LDA #8
  STA @ZR0H_DST
  BRA @LOOP
@SKP_DOT:
  ; 格納
  LDY @ZR0H_DST
  STA (ZP_LDST0_VEC16),Y
  INC @ZR0H_DST
  BRA @LOOP
@EXT:
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
M_CP:
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

