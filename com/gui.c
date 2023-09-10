/* gui.c
 * デモ用簡易GUI
 */

#include <stdio.h>

#define SCRN_W 256
#define SCRN_H 192
#define TOP_H  10
#define ENTRY_CNT_X 3
#define ENTRY_CNT_Y 3
#define ENTRY_CNT (ENTRY_CNT_X*ENTRY_CNT_Y)
#define ENTRY_W   (SCRN_W/ENTRY_CNT_X)
#define ENTRY_H   ((SCRN_H-TOP_H)/ENTRY_CNT_Y)
//                    FEDCBA9876543210
#define PAD_A       0b1000000000000000
#define PAD_X       0b0100000000000000
#define PAD_L       0b0010000000000000
#define PAD_R       0b0001000000000000
#define PAD_B       0b0000100000000000
#define PAD_Y       0b0000000001000000
#define PAD_SELECT  0b0000000000100000
#define PAD_START   0b0000000000010000
#define PAD_ARROW_U 0b0000000000001000
#define PAD_ARROW_D 0b0000000000000100
#define PAD_ARROW_L 0b0000000000000010
#define PAD_ARROW_R 0b0000000000000001

typedef struct{
  unsigned char name[16];
  unsigned char path[32];
} entry_t;

extern void coutc(const char c);
extern void couts(const char *str);

extern void disp(const unsigned char display_number);
extern void gcls();
extern void gput(const unsigned char x, const unsigned char y, const unsigned char* str);
extern void rect(const unsigned char x1, const unsigned char y1, const unsigned char x2, const unsigned char y2);
extern void box(const unsigned char x1, const unsigned char y1, const unsigned char x2, const unsigned char y2);
extern void plot(const unsigned char x, const unsigned char y);
extern void gcls();
extern void col(const unsigned char color, const unsigned char backcolor);
extern void gr(const unsigned char display_number);
extern unsigned int pad();

const entry_t main_menu[ENTRY_CNT] ={
  {"INFO", ""},
  {"GAMES", ""},
  {"MOVIE", ""},

  {"PHOTO", ""},
  {"MUSIC", ""},
  {"BASIC", ""},

  {"DOS", ""},
  {"", ""},
  {"", ""}
};

void initDisplay(){
  disp(0b01010101);
  gr(1);
  col(0x44,0xFF);
  gcls();
}

void drawEntry(unsigned char base_x, unsigned char base_y, const entry_t* entry){
  col(0x44,0xFF);
  rect(base_x/2+1, base_y+1, (base_x+ENTRY_W)/2-2, base_y+ENTRY_H-2);
  col(0xFF,0x44);
  gput(base_x/2+2, base_y+2, entry->name);
}

void drawMenu(const entry_t* menu){
  unsigned char x=0, y=0, cnt=0;
  for(; y<ENTRY_CNT_Y ; y++){
    for(x=0; x<ENTRY_CNT_X ; x++){
      drawEntry(ENTRY_W*x, ENTRY_H*y+TOP_H, &menu[cnt++]);
    }
  }
}

void drawCur(unsigned char idx, unsigned char color){
  unsigned char idx_x=idx%ENTRY_CNT_X;
  unsigned char idx_y=idx/ENTRY_CNT_X;
  unsigned char x1=(ENTRY_W*idx_x)/2;
  unsigned char y1=TOP_H+ENTRY_H*idx_y;
  unsigned char x2=(ENTRY_W*(idx_x+1))/2-1;
  unsigned char y2=TOP_H+ENTRY_H*(idx_y+1)-1;
  col(color,0xFF);
  box(x1,y1,x2,y2);
}

int main(){
  unsigned char idx=0;
  initDisplay();
  drawMenu(main_menu);
  drawCur(idx,0x88);
  while(1){
    unsigned int padstat = ~pad();
    printf("%ux\n", padstat);
    if((padstat&PAD_ARROW_R)!=0){
      drawCur(idx++,0xFF);
      drawCur(idx,0x88);
    }
  }
  return 0;
}

