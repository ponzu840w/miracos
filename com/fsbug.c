#include <stdio.h>
#include <stdarg.h>

extern void coutc(const char c);
extern void couts(const char *str);
extern void cins(const char *str);
extern unsigned int read_sec(void *buf, unsigned long secnum);
char _printf_buffer[256];
char a;

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

int main(void){
  unsigned long l;
  unsigned long tmp;
  l=0x98765432;
  printf("%lx\n",l<<4);
  printf("File System Debugger\n");
  tmp=read_sec(&a, 0x12345678);
  printf("[%lx]\n",tmp);
  printf("End\n");
  return 0;
}

