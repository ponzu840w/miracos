#include <stdio.h>
#include <string.h>

// アセンブラ関数とか

// アセンブラ変数とか
extern unsigned char sector_buffer_512[512]; // セクタバッファ
extern void* sdseek;   // セクタ読み書きのポインタ
extern void* sdcmdprm; // コマンドパラメータ4バイトを指す
#pragma zpsym("sdseek");
#pragma zpsym("sdcmdprm");

unsigned char putnum_buf[11];

// $0123-4567形式で表示
char* put32(unsigned long toput){
  sprintf(putnum_buf,"$%04x-%04x",(unsigned int)(toput>>16),(unsigned int)(toput));
  return putnum_buf;
}

int main(void){
  unsigned long sector;
  unsigned char line[64];
  printf("File System Debugger.\n");

  // 読み込み対象セクタ指定
  while(1){
    printf("fs>");
    scanf("%s",line);
    if(strcmp(line,"help")==0){
      printf("help   - Show this message.\n");
      printf("status - Show status.\n");
      printf("sector - Set current sector.\n");
      printf("read   - Read current sector.\n");
    }else if(strcmp(line,"sector")==0){
      printf("sec32>$");
      scanf("%lx",&sector);
      sdcmdprm=&sector;
      printf(" sector:%s\n",put32(sector));
    }else if(strcmp(line,"status")==0){
      printf(" sector:%s\n",put32(sector));
    }else if(strcmp(line,"read")==0){
      sdseek=sector_buffer_512;
    }
  }
  return 0;
}

