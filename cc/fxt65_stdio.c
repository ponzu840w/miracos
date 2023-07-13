#include <stdio.h>
#include <stdarg.h>

extern void coutc(const char c);
extern void couts(const char *str);
extern void cins(const char *str);
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

