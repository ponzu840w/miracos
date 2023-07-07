#include <stdio.h>
#include <stdarg.h>

extern void coutc(const char c);
extern void cins(const char *str);
char _printf_buffer[256];

void pc(char c){
  coutc(c);
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

a[10],t=-9,p,i,s;k(x){a[x]*a[i+x]*a[x+i+i++]%7/6?t=p:0;pc(i>4?10:a[s++]+45);}main(){while(s=0>t){scanf("%d",&p);!a[p]?a[p]=75+t++%2*9:0;for(;i=9>s;k(3),k(s/3),k(1))k(s);}s=t;k(1);}

