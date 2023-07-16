#include <stdio.h>
#include <string.h>

// 構造体とか
typedef struct{
  /*
  BPB_SECPERCLUS    .RES 1
  PT_LBAOFS         .RES 4  ; セクタ番号
  FATSTART          .RES 4  ; セクタ番号
  DATSTART          .RES 4  ; セクタ番号
  BPB_ROOTCLUS      .RES 4  ; クラスタ番号
  */
  unsigned char BPB_SECPERCLUS;
  unsigned long PT_LBAOFS;
  unsigned long FATSTART;
  unsigned long DATSTART;
  unsigned long BPB_ROOTCLUS;
} dinfo_t;

// 定数とか
const unsigned int SECTOR_BUFFER=0x300;

// アセンブラ関数とか
extern unsigned char read_sec();
extern void dump(char wide, unsigned int from, unsigned int to, unsigned int base);
extern void setGCONoff();
extern void restoreGCON();

// アセンブラ変数とか
extern void* sdseek;   // セクタ読み書きのポインタ
extern void* sdcmdprm; // コマンドパラメータ4バイトを指す
#pragma zpsym("sdseek");
#pragma zpsym("sdcmdprm");

unsigned char putnum_buf[11];

// $0123-4567形式で表示
char* put32(unsigned long toput){
  sprintf(putnum_buf,"$%04X-%04X",(unsigned int)(toput>>16),(unsigned int)(toput));
  return putnum_buf;
}

int main(void){
  unsigned long sector=0;
  unsigned char line[64];
  dinfo_t* dwk_p=(dinfo_t*)0x514;

  printf("File System Debugger.\n");

  while(1){
    printf("fs>");
    scanf("%s",line);

    if(strcmp(line,"help")==0){
      // つかいかた
      printf("help   - Show this message.\n");
      printf("status - Show status.\n");
      printf("sector - Set current sector.\n");
      printf("read   - Read current sector.\n");

    }else if(strcmp(line,"sector")==0){
      // 読み込み対象セクタ指定
      printf("sec32>$");
      scanf("%lX",&sector);
      sdcmdprm=&sector;
      printf(" sector:%s\n",put32(sector));

    }else if(strcmp(line,"status")==0){
      // 状態表示
      printf(" sector:%s\n",put32(sector));

      printf("\n[Master Boot Record]\n");
      printf(" [Partition 1 Info]\n");
      printf("  PT_LbaOfs:%s\n",put32(dwk_p->PT_LBAOFS));

      printf("\n[BIOS Parameter Block of PT1]\n");
      printf("    Sec/Clus   :$%02X\n",dwk_p->BPB_SECPERCLUS);
      printf("  Start of FAT :%s\n",put32(dwk_p->FATSTART));
      printf("  Start of Data:%s\n",put32(dwk_p->DATSTART));
      printf("    RootClus   :%s\n",put32(dwk_p->BPB_ROOTCLUS));

    }else if(strcmp(line,"read")==0){
      // セクタ読み取り
      unsigned char err;
      sdseek=(void*)SECTOR_BUFFER;
      err=read_sec();
      if(err!=0)
        printf("[ERR]:%d\n",err);
      // セクタバッファを表示
      setGCONoff();
      dump(0, SECTOR_BUFFER, SECTOR_BUFFER+0x1FF, 0);
      restoreGCON();

    }else if(strcmp(line,"test")==0){
      // お試し
      unsigned char* ptr;
      unsigned int i;
      ptr=(char*)0x300;
      for(i=0;i<256;i++){
        printf("%x",*ptr++);
      }

    }
  }
  return 0;
}

