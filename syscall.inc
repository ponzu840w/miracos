; コール場所
SYSCALL             = $0603
; システムコールテーブル
RESET               = 0
CON_IN_CHR          = 1
CON_OUT_CHR         = 2
CON_RAWIN           = 3
  BHA_CON_RAWIN_GetState      = 0
  BHA_CON_RAWIN_NoWaitNoEcho  = 1
  BHA_CON_RAWIN_WaitAndNoEcho = 2
CON_OUT_STR         = 4
FS_OPEN             = 5
FS_CLOSE            = 6
CON_IN_STR          = 7
GCHR_COL            = 8
FS_FIND_FST         = 9
FS_PURSE            = 10
FS_CHDIR            = 11
FS_FPATH            = 12
ERR_GET             = 13
ERR_MES             = 14
UPPER_CHR           = 15
UPPER_STR           = 16
FS_FIND_NXT         = 17
FS_READ_BYTS        = 18
IRQ_SETHNDR_VB      = 19
GET_ADDR            = 20
  BHY_GET_ADDR_zprand16       = 0
  BHY_GET_ADDR_txtvram768     = 1*2
  BHY_GET_ADDR_font2048       = 2*2
  BHY_GET_ADDR_condevcfg      = 3*2
CON_INTERRUPT_CHR   = 21
TIMEOUT             = 22

