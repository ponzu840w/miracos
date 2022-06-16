/* hello.c
 * hello,worldする
 */
extern void couts(char *str);

int main(){
  int i;
  for(i=0;i<5;i++){
  //while(1){
    couts("hello,world\n");
  }
  return (0);
}

