; -------------------------------------------------------------------
;                           bcosfunc.s
; -------------------------------------------------------------------
; BCOS関数へのラッパ関数群
; -------------------------------------------------------------------
.proc BCOS                  ; Basic Card Operating System（カーネル）
.include "../syscall.inc"   ; システムコール番号を定義するインクルードファイル
  ; --- 一部抜粋 ---
  ;; コール場所
  ;SYSCALL             = $0603
  ;; システムコールテーブル
  ;RESET               = 0
  ;CON_IN_CHR          = 1
  ;CON_OUT_CHR         = 2
  ;CON_RAWIN           = 3
  ;CON_OUT_STR         = 4
  ;FS_OPEN             = 5
  ;FS_CLOSE            = 6
  ;CON_IN_STR          = 7
  ; --- 抜粋ここまで ---
.include "../syscall.mac"   ; 普段使ってるマクロ
.include "../generic.mac"
.include "../zr.inc"
.endproc

.IMPORT popa, popax
.IMPORTZP sreg


; Cから呼び出せる関数名を宣言
.export _coutc
.export _couts
.export _cins
.export _fs_find_fst
.export _fs_find_nxt
.export _fs_delete
.export _err_print
.export _fs_open
.export _fs_close
.export _fs_read
.export _fs_write
.export _fs_makef

.CODE

; -------------------------------------------------------------------
;                              coutc
; -------------------------------------------------------------------
.proc _coutc                      ; 引数: A=char
  syscall CON_OUT_CHR
  rts
.endproc

; -------------------------------------------------------------------
;                              couts
; -------------------------------------------------------------------
.proc _couts: near                ; C関数引数:  AX=文字列先頭アドレス
                                  ;                 これがnearらしい
  PHX                             ; 「TXY」
  PLY                             ; Xはコールで使うし、AYで渡したい
  ;syscall CON_OUT_STR            ; 普段使っているマクロではこう表記
  ; --- マクロの中身 ---          ; システムコール引数: AY=文字列先頭アドレス
  LDX #(BCOS::CON_OUT_STR)*2      ; Xにコール番号の二倍を格納
  JSR BCOS::SYSCALL               ; コール
  ; --- マクロここまで ---
  rts                             ; 復帰
.endproc

; -------------------------------------------------------------------
;                              cins
; -------------------------------------------------------------------
.proc _cins: near                  ; 引数: A=格納先アドレス
  PHX
  PLY
  syscall CON_IN_STR
  rts
.endproc

; -------------------------------------------------------------------
;                            fs_find_fst
; パス文字列から新たなFINFO構造体を得る
; -------------------------------------------------------------------
.proc _fs_find_fst: near          ; 引数: AX=パス文字列
  PHX
  PLY
  syscall FS_FIND_FST
  PHY
  PLX
  BCC @FOUND
  LDA #$0
  TAX
@FOUND:
  RTS
.endproc

; -------------------------------------------------------------------
;                            fs_find_nxt
; -------------------------------------------------------------------
; void* fs_find_nxt(void* finfo, char* name)
.proc _fs_find_nxt: near          ; 引数: AX=ファイル名, スタック=FINFO
  STA $0
  STX $0+1
  JSR popax
  PHX
  PLY
  syscall FS_FIND_NXT             ; 引数: AY=FINFO構造体 ZR0=ファイル名
  PHY
  PLX
  BCC @FOUND
  LDA #$0
  TAX
@FOUND:
  RTS
.endproc

; -------------------------------------------------------------------
;                            fs_delete
; -------------------------------------------------------------------
; unsigned int fs_delete(void* finfo / path)
.proc _fs_delete: near          ; 引数: AX=FINFOかPATH
  PHX
  PLY
  syscall FS_DELETE             ; 引数: AY=FINFOかPATH
  LDA #$0
  BCC @NOERROR
  INC
@NOERROR:
  RTS                           ; 戻り値: OK=0 ERROR=1
.endproc

; -------------------------------------------------------------------
;                            err_print
; -------------------------------------------------------------------
; void err_print()
.proc _err_print
  syscall ERR_GET
  syscall ERR_MES
  RTS
.endproc

; -------------------------------------------------------------------
;                              fs_open
; -------------------------------------------------------------------
; unsigned char fs_open(void* finfo / path)
.PROC _fs_open                    ; 引数: AX=FINFOかPATH
  PHX
  PLY
  syscall FS_OPEN                 ; 引数: AY=FINFOかPATH
  BCC @END
  LDA #$FF                        ; エラーコード255
@END:
  RTS
.ENDPROC

; -------------------------------------------------------------------
;                              fs_close
; -------------------------------------------------------------------
; void fs_close(unsigned char fd)
.PROC _fs_close
  syscall FS_CLOSE
  RTS
.ENDPROC

; -------------------------------------------------------------------
;                              fs_read
; -------------------------------------------------------------------
; unsigned int fs_read(unsigned char fd, unsigned char *buf, unsigned int count);
.PROC _fs_read
  pushAX16
  JSR popax
  storeAX16 BCOS::ZR0
  JSR popa
  STA BCOS::ZR1
  pullAY16
  syscall FS_READ_BYTS
  BCC @END
  LDA #$FF                          ; エラーコード65535
  TAY
@END:
  PHY
  PLX
  RTS
.ENDPROC

; -------------------------------------------------------------------
;                              fs_write
; -------------------------------------------------------------------
; unsigned int fs_write(unsigned char fd, unsigned char *buf, unsigned int count);
.PROC _fs_write
  pushAX16
  JSR popax
  storeAX16 BCOS::ZR0
  JSR popa
  STA BCOS::ZR1
  pullAY16
  syscall FS_WRITE
  BCC @END
  LDA #$FF                          ; エラーコード65535
  TAY
@END:
  PHY
  PLX
  RTS
.ENDPROC

; -------------------------------------------------------------------
;                              fs_makef
; -------------------------------------------------------------------
; unsigned char fs_makef(char* path);
.PROC _fs_makef
  PHX
  PLY
  STZ BCOS::ZR0
  syscall FS_MAKE
  BCC @END
  LDA #$FF                        ; エラーコード255
@END:
  RTS
.ENDPROC

