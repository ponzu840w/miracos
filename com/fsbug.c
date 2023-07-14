#include <stdio.h>
#include <string.h>

// アセンブラ関数とか
extern unsigned char read_sec();

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

// セクタバッファを表示
void print_secbuf(){
  unsigned char* ptr;
  unsigned int i;
  ptr=sector_buffer_512;
  for(i=0;i<512/16;i++){
    printf("%03x:",ptr-0x300);
    printf("%02x %02x %02x %02x-",*ptr++,*ptr++,*ptr++,*ptr++);
    printf("%02x %02x %02x %02x-",*ptr++,*ptr++,*ptr++,*ptr++);
    printf("%02x %02x %02x %02x-",*ptr++,*ptr++,*ptr++,*ptr++);
    printf("%02x %02x %02x %02x\n",*ptr++,*ptr++,*ptr++,*ptr++);
  }
}

int main(void){
  unsigned long sector;
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
      sdseek=sector_buffer_512;
      err=read_sec();
      printf("[ERR]:%d\n",err);
      print_secbuf();
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

