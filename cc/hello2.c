/* hello2.c
 * sprintf
 */
#include <stdio.h>
#include <string.h>
extern void couts(char *str);

int main(){
  int i;
  char str1[32]="ABC";
  char str2[]="123";
  char* cptr;
  for(i=0;i<5;i++){
    couts("hello,world\n");
    strcat(str1,str2);                      // 機能する
    sprintf(cptr, "hello,stdio [%d]\n", i);
    couts(cptr);
    couts(str1);
  }
  return (0);
}

