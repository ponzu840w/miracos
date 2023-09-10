/* gui.c
 * デモ用簡易GUI
 */

//#include <stdio.h>

extern void coutc(const char c);
extern void couts(const char *str);

extern void disp(const unsigned char display_number);
extern void gcls();
extern void gput();
extern void rect(const unsigned char x1, const unsigned char y1, const unsigned char x2, const unsigned char y2);
extern void box(const unsigned char x1, const unsigned char y1, const unsigned char x2, const unsigned char y2);
extern void plot(const unsigned char x, const unsigned char y);
extern void gcls();
extern void col(const unsigned char color, const unsigned char backcolor);
extern void gr(const unsigned char display_number);

int main(){
  disp(0b01010101);
  gr(1);
  col(0x88,0xFF);
  gcls();
  box(10/2,10,50/2,50);
  rect(100/2,10,150/2,50);
  plot(256/4,192/2);
  return 0;
}

