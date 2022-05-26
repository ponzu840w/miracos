/* hello.c
 * hello,worldする
 */
extern void __fastcall__ couts(char *str);

int main(){
  int i;
  for(i=0;i<5;i++){
  //while(1){
    couts("hello,world\n");
  }
  return (0);
}

