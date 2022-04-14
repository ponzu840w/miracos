;DEBUGBUILD:
; https://github.com/gfoot/sdcard6502/blob/master/src/1_readwritebyte.s
.INCLUDE "../../sd-monitor/FXT65.inc"
;.SCOPE SD
; .INCLUDE "sd.s"
;.ENDSCOPE

; 命名規則
; BYT  8bit
; SHORT 16bit
; LONG  32bit

IPL_RESET:
  ; VIAのリセット
  LDA #$FF  ; 全GPIOを出力に
  STA VIA::DDRA
  STA VIA::DDRB
  LDA #%01111111
  STA VIA::IER
  STA VIA::IFR

  ;print STR_START
  JSR SD::INIT
  JSR DRV_INIT

BOOT:
  ; ルートディレクトリを開く
  loadreg16 DRV::BPB_ROOTCLUS
  JSR FILE_OPEN
  ; BOOT.INIを探す
  ;print STR_SCFILE
  ;print STR_BOOTFILE
  loadreg16 STR_BOOTFILE
  JSR M_SFN_DOT2RAW_AXS
  JSR ETM_DIR_OPEN_BYNAME
  ; BOOT.INIを読む
  ;print STR_BTMOD
  JSR FILE_RDWORD           ; HEX1バイト:起動挙動 00=SDブート,01=モニタ
  JSR BLDPRTBYT             ; 文字列出力先の指定とかもできるかも？
  BEQ @SKPCTRL
  ; セクタを閉じる
  JSR FILE_THROWSEC
  ;JMP MON::CTRL
@SKPCTRL:
  JSR FILE_RDWORD           ; 改行と何か一つ読み飛ばす
  ; ブートローダ開始位置を決定する
  ;print STR_BTLOAD
  JSR FILE_RDWORD
  JSR BLDPRTBYT
  STA BOOT_LOAD_POINT+1
  JSR FILE_RDWORD
  JSR BLDPRTBYT
  STA BOOT_LOAD_POINT
  JSR FILE_RDWORD
  ; プログラムエントリポイントを決定する
  ;print STR_BTJUMP
  JSR FILE_RDWORD
  JSR BLDPRTBYT
  STA BOOT_ENTRY_POINT+1
  JSR FILE_RDWORD
  JSR BLDPRTBYT
  STA BOOT_ENTRY_POINT
  JSR FILE_RDWORD
  ;JSR MON::PRT_LF
  ; ブートローダバイナリのSFNを取得する
  loadmem16 ZP_SDSEEK_VEC16,DOT_SFN
  LDY #0
@SFNLOOP:
  PHY
  JSR FILE_RDWORD
  PLY
  STA (ZP_SDSEEK_VEC16),Y
  INY
  CPY #13
  BEQ @EXTL
  TXA
  STA (ZP_SDSEEK_VEC16),Y
  INY
  BRA @SFNLOOP
@EXTL:
  ; セクタを閉じる
  JSR FILE_THROWSEC
  ; ルートディレクトリを開く
  loadreg16 DRV::BPB_ROOTCLUS
  JSR FILE_OPEN
  ; ブートローダバイナリを探す
  ;print STR_SCFILE
  JSR M_SFN_DOT2RAW_WS
  JSR M_SFN_RAW2DOT_WS     ; ムダだが、きれいになる
  ;JSR MON::PRT_STR
  loadreg16 RAW_SFN
  JSR ETM_DIR_OPEN_BYNAME
  ; 配置
  LDA BOOT_LOAD_POINT
  LDX BOOT_LOAD_POINT+1
  JSR FILE_DLFULL
  ; 実行
  ;print STR_JUMPING
  JMP (BOOT_LOAD_POINT)

ETM_DIR_OPEN_BYNAME:
  ; 例外処理でモニタに落ちるシリーズ
  JSR DIR_OPEN_BYNAME
  CMP #$FF                  ; 見つからなかったらモニタへ
  BNE @SKP_HATENA
  ;JMP MON::HATENA
@SKP_HATENA:
  JSR SD::OK
  RTS

;  BRA .A
;
;  ; 任意クラスタ読み取り
;.LOOP
;  print STR_RS
;
;  JSR MON::INPUT_BYT
;  STA SECVEC32+3
;  JSR MON::INPUT_BYT
;  STA SECVEC32+2
;  JSR MON::INPUT_BYT
;  STA SECVEC32+1
;  JSR MON::INPUT_BYT
;  STA SECVEC32
;.B
;  JSR CLUS2SEC
;  loadmem16 ZP_SDCMDPRM_VEC16,SECVEC32
;  loadmem16 ZP_SDSEEK_VEC16,SECBF512
;  JSR SD_RDSEC
;.A
;  JSR .SHOWSEC
;  BRA .LOOP
;
;.SHOWSEC
;  loadmem16 ZP_GP0_VEC16,SECBF512
;  JSR DUMPPAGE
;  INC ZP_GP0_VEC16+1
;  JSR DUMPPAGE
;  RTS

DRV_INIT:
  ; MBRを読む
  loadmem16 ZP_SDCMDPRM_VEC16,BTS_CMDPRM_ZERO
  loadmem16 ZP_SDSEEK_VEC16,SECBF512
  JSR SD::RDSEC
  ;INC ZP_SDSEEK_VEC16+1    ; 後半にこそある。しかしこれも一般的サブルーチンによるべきか？
  LDY #(OFS_MBR_PARTBL-256+OFS_PT_SYSTEMID)
  LDA (ZP_SDSEEK_VEC16),Y ; システム標識
  CMP #SYSTEMID_FAT32
  BEQ @FAT32
  CMP #SYSTEMID_FAT32NOCHS
  BEQ @FAT32
  BRK
@FAT32:
  ; ソースを上位のみ設定
  LDA #(>SECBF512)+1
  STA ZP_LSRC0_VEC16+1
  ; DRV::PT_LBAOFS取得
  loadreg16 (DRV::PT_LBAOFS)
  JSR AX_DST
  LDA #(OFS_MBR_PARTBL-256+OFS_PT_LBAOFS)
  JSR L_LD_AS
  ; BPBを読む
  loadmem16 ZP_SDCMDPRM_VEC16,(DRV::PT_LBAOFS)
  DEC ZP_SDSEEK_VEC16+1
  JSR SD::RDSEC
  DEC ZP_SDSEEK_VEC16+1
  ; DRV::SEVPERCLUS取得
  LDY #(OFS_BPB_SECPERCLUS)
  LDA (ZP_SDSEEK_VEC16),Y       ; 1クラスタのセクタ数
  STA DRV::BPB_SECPERCLUS
  ; --- DRV::FATSTART作成
  ; PT_LBAOFSを下地としてロード
  loadreg16 (DRV::FATSTART)
  JSR AX_DST
  loadreg16 (DRV::PT_LBAOFS)
  JSR L_LD_AXS
  ; 予約領域の大きさのあと（NumFATsとルートディレクトリの大きさで、不要）をゼロにして、
  ; 予約領域の大きさを32bitの値にする
  LDA #0
  LDY #(OFS_BPB_RSVDSECCNT+2)
  STA (ZP_SDSEEK_VEC16),Y
  INY
  STA (ZP_SDSEEK_VEC16),Y
  ; 予約領域を加算
  loadreg16 (SECBF512+OFS_BPB_RSVDSECCNT)
  JSR L_ADD_AXS
  ; --- DRV::DATSTART作成
  ; FATの大きさをロード
  loadreg16 (DRV::DATSTART)
  JSR AX_DST
  loadreg16 (SECBF512+OFS_BPB_FATSZ32)
  JSR L_LD_AXS
  JSR L_X2                    ; 二倍にする
  ; FATSTARTを加算
  loadreg16 (DRV::FATSTART)
  JSR L_ADD_AXS
  ; --- ルートディレクトリクラスタ番号取得（どうせDAT先頭だけど…
  loadreg16 (DRV::BPB_ROOTCLUS)
  JSR AX_DST
  loadreg16 (SECBF512+OFS_BPB_ROOTCLUS)
  JSR L_LD_AXS
  RTS

MESSAGES:
.IFDEF DEBUGBUILD
  STR_CMD:     .BYTE $A,"CMD$",$0
.ENDIF
STR_IPLV:    .BYTE "IPL V.00",$0
STR_START:   .BYTE $A,"IPL V.00",$A,$0
STR_SDINIT:  .BYTE "SD:Init...",$0   ; この後に!?
STR_OLDSD:   .BYTE "SD:Old",$A,$0
STR_NEWSD:   .BYTE "SD:>HC",$A,$0
STR_SCFILE:  .BYTE "SearchFile:",$0  ; この後に!?
STR_BTMOD:   .BYTE "Mode:",$0
STR_BTLOAD:  .BYTE $A,"Load:",$0
STR_BTJUMP:  .BYTE $A,"Jump:",$0
STR_JUMPING: .BYTE $A,"Jumping...",$A,$A,$0
;STR_RS:
;  .ASCIIZ $A,"Read sector addr : $"
;STR_S:
;  .ASCIIZ "."
STR_BOOTFILE:
  .BYT "BOOT.INI"

; SDコマンド用固定引数
; 共通部分を重ねて圧縮している
BTS_CMD8PRM:   ; 00 00 01 AA
  .BYTE $AA,$01
BTS_CMDPRM_ZERO:  ; 00 00 00 00
  .BYTE $00
BTS_CMD41PRM:  ; 40 00 00 00
  .BYTE $00,$00,$00,$40

PRT_BYT_S:
  ;JSR MON::PRT_BYT
  ;JSR MON::PRT_S
  RTS

EQBYTS:
  ; Yで与えられた長さのバイト列が等しいかを返す
  ; ZR0とAX
  ; 文字列比較ではないのでNULLがあってもOK
  STA ZR1
  STX ZR1+1
@LOOP:
  DEY
  BMI @EQ               ; 初回で引っかかっても、長さ0の比較は問答無用で正しい
  LDA (ZR0),Y
  CMP (ZR1),Y
  BEQ @LOOP
@NOT:
  LDA #1
  RTS
@EQ:
  LDA #0
  RTS

DIR_OPEN_BYNAME:
  ; カレントディレクトリ内の名前に一致したファイルを開く
  ; AXで与えられた名前に合致するのを探す
  ; アトリビュートを返すので、ファイルかどうかはそっちで確認してね
  JSR DIR_GET_BYNAME
  CMP #$FF                ; 見つからなかったら$FFを返して終わり
  BEQ @EXT
@DIR_OPEN:
  loadreg16 DIR::ENT_HEAD
  JSR FILE_OPEN
  LDA DIR::ENT_ATTR
@EXT:
  RTS

DIR_GET_BYNAME:
  ; 名前に一致するエントリをゲットする
  ; Aには属性が入って帰る
  ; もう何もなければ$FFを返す
  ; 要求された文字列
  STA ZR0
  STX ZR0+1
  ; カレントディレクトリを開きなおす
  JSR FILE_REOPEN
  JSR DIR_RDSEC
  ; エントリ番号の初期化
  ;LDA #$FF
  ;STA DIR::ENT_NUM
  ;loadmem16 ZP_SDSEEK_VEC16,(SECBF512-32) ; シークポインタの初期化
  JSR DIR_NEXTENT_ENT
  BRA @LOOPENT
@LOOP:
  JSR DIR_NEXTENT
  CMP #$FF
  BNE @LOOPENT
  RTS
@LOOPENT:
  ;LDA ZP_SDSEEK_VEC16
  ;LDX ZP_SDSEEK_VEC16+1
  ;JSR PRT_DOTSFN
  LDA ZP_SDSEEK_VEC16
  LDX ZP_SDSEEK_VEC16+1
  LDY #11
  JSR EQBYTS
  BNE @LOOP
  LDA DIR::ENT_ATTR
  RTS

DIR_NEXTENT:
  ; 次の有効な（LFNでない）エントリを拾ってくる
  ; ZP_SDSEEK_VEC16が32bitにアライメントされ、DIR::ENT_NUMと一致するとする
  ; Aには属性が入って帰る
  ; もう何もなければ$FFを返す
  ; エントリ番号更新
@LOOP:
  LDA DIR::ENT_NUM
  INC
  STA DIR::ENT_NUM
  AND #%00001111
  BNE @SKP_NEXTSEC            ; セクタを読み切った
  JSR FILE_NEXTSEC            ; 次のセクタに進む
  JSR DIR_RDSEC               ; セクタを読み出す
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
DIR_NEXTENT_ENT:
  JSR DIR_GETENT
  ;LDA (DIR::ENT_NAME)     ; 名前先頭
  LDA (ZP_SDSEEK_VEC16)
  BNE @SKP_NULL               ; 0ならもうない
  LDA #$FF
  RTS
@SKP_NULL:
  CMP #$E5                    ; 消去されたエントリ
  BEQ DIR_NEXTENT
  LDA DIR::ENT_ATTR
  CMP #DIRATTR_LONGNAME
  BNE @EXT
  BRA DIR_NEXTENT
@EXT:
  LDA DIR::ENT_ATTR
  RTS

DIR_GETENT:
  ; エントリを拾ってくる
  ; LFNだったらサボる
  ; 属性
  LDY #OFS_DIR_ATTR
  LDA (ZP_SDSEEK_VEC16),Y
  STA DIR::ENT_ATTR
  CMP #DIRATTR_LONGNAME
  BEQ @EXT
  ; 名前
  LDA ZP_SDSEEK_VEC16
  STA DIR::ENT_NAME
  LDA ZP_SDSEEK_VEC16+1
  STA DIR::ENT_NAME+1
  ; サイズ
  loadreg16 (DIR::ENT_SIZ)
  JSR AX_DST
  LDA ZP_SDSEEK_VEC16
  LDX ZP_SDSEEK_VEC16+1
  LDY #OFS_DIR_FILESIZE
  JSR S_ADD_BYT
  JSR L_LD_AXS
  ; クラスタ番号
  ; TODO 16bitコピーのサブルーチン化
  LDY #OFS_DIR_FSTCLUSLO
  LDA (ZP_SDSEEK_VEC16),Y      ; 低位
  STA DIR::ENT_HEAD
  INY
  LDA (ZP_SDSEEK_VEC16),Y      ; 低位
  STA DIR::ENT_HEAD+1
  LDY #OFS_DIR_FSTCLUSHI
  LDA (ZP_SDSEEK_VEC16),Y      ; 高位
  STA DIR::ENT_HEAD+2
  INY
  LDA (ZP_SDSEEK_VEC16),Y      ; 高位
  STA DIR::ENT_HEAD+3
@EXT:
  RTS

DIR_RDSEC:
  ; ディレクトリ操作用のバッファ位置は固定
  loadmem16 ZP_SDSEEK_VEC16,SECBF512
  loadmem16 ZP_SDCMDPRM_VEC16,(FILE::REAL_SEC)
  JSR SD::RDSEC
  DEC ZP_SDSEEK_VEC16+1
  RTS

FILE_OPEN:
  ; AXで与えられたクラスタ番号から、ファイル構造体を展開
  ; サイズに触れないため、ディレクトリにも使える
  ; --- ファイル構造体の展開
  ; 先頭クラスタ番号
  JSR AX_SRC
  loadreg16 FILE::HEAD_CLUS
  JSR AX_DST
  JSR L_LD
FILE_REOPEN:
  ; ここから呼ぶと現在のファイルを開きなおす
  STZ DRV::SEC_RESWORD
  ; 現在クラスタ番号に先頭クラスタ番号をコピー
  loadreg16 (FILE::CUR_CLUS)
  JSR AX_DST
  loadreg16 (FILE::HEAD_CLUS)
  JSR L_LD_AXS
  ; 現在クラスタ内セクタ番号をゼロに
  STZ FILE::CUR_SEC
  ; リアルセクタ番号を展開
  loadmem8l ZP_LDST0_VEC16,FILE::REAL_SEC
  JSR CLUS2SEC_IMP
  RTS

FILE_NEXTSEC:
  ; ファイル構造体を更新し、次のセクタを開く
  ; クラスタ内セクタ番号の更新
  LDA FILE::CUR_SEC
  CMP DRV::BPB_SECPERCLUS
  BNE @SKP_NEXTCLUS
  BRK                       ; TODO:FATを読む
@SKP_NEXTCLUS:
  INC FILE::CUR_SEC
  ; リアルセクタ番号を更新
  loadreg16 (FILE::REAL_SEC)
  JSR AX_DST
  LDA #1
  JSR L_ADD_BYT
  ; 残りバイト数を減算
  loadmem8l ZP_LDST0_VEC16,FILE::RES_SIZ+1
  LDA #1
  PHA
  JSR L_SB_BYT
  PLA
  JSR L_SB_BYT
CK_ENDSEC_FLG:
  ; 残るバイト数を評価
  ; ゼロ    0  （次のデータを要求してはいけない）
  ; 512以下 1
  ; 512以上 2
  LDA FILE::RES_SIZ+1
  AND #%11111110
  ORA FILE::RES_SIZ+2
  ORA FILE::RES_SIZ+3
  BNE @SKP_SETF
  ; 512以下である
  ORA FILE::RES_SIZ+1
  ORA FILE::RES_SIZ
  BEQ @ZERO   ; 完全なるゼロ
  LDA #$1
  BRA @SKP_RSTF
@SKP_SETF:
  ; 512以上である
  LDA #$2
@SKP_RSTF:
@ZERO:
  STA FILE::ENDSEC_FLG
  RTS

FILE_RDWORD:
  ; ファイルからデータを2バイト読み出してAXに
  ; TODO ファイル終端の検出
  LDA DRV::SEC_RESWORD
  BNE @SKP_RDCMD          ; CMD17が終わっているので新たにコマンドを送る
  loadmem16 ZP_SDCMDPRM_VEC16,FILE::REAL_SEC
  JSR SD::RDINIT
@SKP_RDCMD:
  JSR SPI::RDBYT
  PHA
  JSR SPI::RDBYT
  TAX
  PLA
  DEC DRV::SEC_RESWORD
  BNE @SKP_ENDSEC
  ; セクタが終わったので次のセクタを開く
  PHA
  PHX
  JSR FILE_NEXTSEC
  PLX
  PLA
@SKP_ENDSEC:
  RTS

FILE_THROWSEC:
  ; RDBYTを抜ける
  JSR SPI::RDBYT
  JSR SPI::RDBYT
  DEC DRV::SEC_RESWORD
  BNE FILE_THROWSEC
  ; コマンド終了
  cs0high
  RTS

FILE_SETSIZ:
  ; DIR構造体に展開されたサイズをFILE構造体にコピー
  loadreg16 FILE::SIZ
  JSR AX_DST
  loadreg16 DIR::ENT_SIZ
  JSR L_LD_AXS
  loadreg16 FILE::RES_SIZ
  JSR AX_DST
  loadreg16 DIR::ENT_SIZ
  JSR L_LD_AXS
  JSR L_LD
  RTS

FILE_DLFULL:
  ; バイナリファイルをAXからだだっと展開する
  ; 速さが命
  STA ZP_SDSEEK_VEC16
  STX ZP_SDSEEK_VEC16+1
  ; サイズをロード
  JSR FILE_SETSIZ
@CK:
  JSR CK_ENDSEC_FLG
  CMP #1
  BEQ @ENDSEC           ; $1であれば最終セクタ
@LOOP:
  loadmem16 ZP_SDCMDPRM_VEC16,FILE::REAL_SEC
  JSR SD::RDSEC
  INC ZP_SDSEEK_VEC16+1
  JSR FILE_NEXTSEC
  CMP #2
  BEQ @LOOP              ; $2ならループ
@ENDSEC:
  CMP #0
  BEQ @END               ; $0なら終わり
  ; 最終セクタ
  LDA #$80
  STA DRV::SEC_RESWORD
  loadmem16 ZP_SDCMDPRM_VEC16,FILE::REAL_SEC
  JSR SD::RDINIT
  LDA FILE::RES_SIZ+1
  BIT #%00000001
  BEQ @SKP_PG
  ; ページ丸ごと
  STZ DRV::SEC_RESWORD
  JSR SD::RDPAGE
  INC ZP_SDSEEK_VEC16+1
  ; 1ページ分減算
  loadmem8l ZP_LDST0_VEC16,FILE::RES_SIZ+1
  LDA #$1
  JSR L_SB_BYT
  ;BRA @CK
@SKP_PG:
  LDY #0
@RDLOOP:
  CPY FILE::RES_SIZ
  BEQ @SKP_PBYT
  spi_rdbyt
  STA (ZP_SDSEEK_VEC16),Y
  INY
  BRA @RDLOOP
@SKP_PBYT:
  ; 残るセクタ分を処分
  STY ZR0
  LDA #0
  SEC
  SBC ZR0
  LSR
  ADC DRV::SEC_RESWORD
  STA DRV::SEC_RESWORD
  JSR FILE_THROWSEC
@END:
  RTS

;CLUS2SEC_AXD:
  ; 作業するDSTをAX指定
  ;JSR AX_DST
CLUS2SEC_AXS:
  JSR AX_SRC
CLUS2SEC_IMP:
  JSR L_LD
CLUS2SEC:
  ; クラスタ番号をセクタ番号に変換する
  ; SECPERCLUSは2の累乗であることが保証されている
  ; 2を減算
  LDA #$2
  JSR L_SB_BYT
  ; *SECPERCLUS
  LDA DRV::BPB_SECPERCLUS
@LOOP:
  TAX
  JSR L_X2
  TXA
  LSR
  CMP #1
  BNE @LOOP
  ; DATSTARTを加算
  loadreg16 (DRV::DATSTART)
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

