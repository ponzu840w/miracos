#include <stdio.h>

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
  printf("File System Debugger.\n");

  // 読み込み対象セクタ指定
  while(1){
    printf(">$");
    scanf("%lx",&sector);
    printf(" read_sec:%s\n",put32(sector));
    sdseek=sector_buffer_512;
    sdcmdprm=&sector;
  }
  return 0;
}

