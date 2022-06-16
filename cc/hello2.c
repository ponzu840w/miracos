/* hello2.c
 * sprintf
 */
#include <stdio.h>
extern void __fastcall__ couts(char *str);

int main(){
  int i;
  char buf[32];
  for(i=0;i<5;i++){
    //couts("hello,world\n");
    sprintf(buf, "hello,world [%d] hello,stdio", i);
    couts(buf);
  }
  return (0);
}

