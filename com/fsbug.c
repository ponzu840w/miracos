#include <stdio.h>

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
  }
  return 0;
}

