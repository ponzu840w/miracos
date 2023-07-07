/* hello3.c
 * 自作printf
 */
#include <stdio.h>
#include <stdarg.h>

extern void couts(const char *str);
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

int main(){
  int i;
  for(i=0;i<5;i++){
    printf("hello, %d\n",33);
  }
  return 0;
}

