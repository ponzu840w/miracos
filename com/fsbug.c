#include <stdio.h>
#include <string.h>

// アセンブラ関数とか
extern unsigned char read_sec();
extern void dump(char wide, unsigned int from, unsigned int to, unsigned int base);

// アセンブラ変数とか
//extern unsigned char sector_buffer_512[512]; // セクタバッファ
extern void* sdseek;   // セクタ読み書きのポインタ
extern void* sdcmdprm; // コマンドパラメータ4バイトを指す
#pragma zpsym("sdseek");
#pragma zpsym("sdcmdprm");

const unsigned int SECTOR_BUFFER=0x300;

unsigned char putnum_buf[11];

// $0123-4567形式で表示
char* put32(unsigned long toput){
  sprintf(putnum_buf,"$%04x-%04x",(unsigned int)(toput>>16),(unsigned int)(toput));
  return putnum_buf;
}

int main(void){
  unsigned long sector=0;
  unsigned char line[64];
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
      scanf("%lx",&sector);
      sdcmdprm=&sector;
      printf(" sector:%s\n",put32(sector));

    }else if(strcmp(line,"status")==0){
      // 状態表示
      printf(" sector:%s\n",put32(sector));

    }else if(strcmp(line,"read")==0){
      // セクタ読み取り
      unsigned char err;
      sdseek=(void*)SECTOR_BUFFER;
      err=read_sec();
      if(err!=0)
        printf("[ERR]:%d\n",err);
      // セクタバッファを表示
      dump(0, SECTOR_BUFFER, SECTOR_BUFFER+0x1FF, 0);

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

