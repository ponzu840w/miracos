#include <stdio.h>
#include <stdarg.h>

extern void coutc(const char c);
extern void couts(const char *str);
extern void cins(const char *str);
//extern unsigned int read_sec(void *buf, unsigned long secnum);
//extern unsigned int read_sec(int a, unsigned long secnum);
char _printf_buffer[256];

int printf(const char* format, ...){
  int len;
  va_list list;
  va_start(list, format);
  len=vsprintf(_printf_buffer, format, list);
  va_end(list);
  couts(_printf_buffer);
  return len;
}

int scanf(const char* format, ...){
  int len;
  va_list list;
  cins(_printf_buffer);
  va_start(list, format);
  len=vsscanf(_printf_buffer, format, list);
  va_end(list);
  coutc('\n');
  return len;
}

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

