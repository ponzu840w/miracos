/* gui.c
 * デモ用簡易GUI
 */

//#include <stdio.h>

#define SCRN_W 256
#define SCRN_H 192
#define TOP_H  10
#define ENTRY_CNT_X 3
#define ENTRY_CNT_Y 3
#define ENTRY_CNT (ENTRY_CNT_X*ENTRY_CNT_Y)
#define ENTRY_W   (SCRN_W/ENTRY_CNT_X)
#define ENTRY_H   ((SCRN_H-TOP_H)/ENTRY_CNT_Y)

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
  rect(base_x/2, base_y, (base_x+ENTRY_W-10)/2, base_y+ENTRY_H-10);
  col(0xFF,0x44);
  gput(base_x/2, base_y, entry->name);
}

void drawMenu(const entry_t* menu){
  unsigned char x=0, y=0, cnt=0;
  for(; y<ENTRY_CNT_Y ; y++){
    for(x=0; x<ENTRY_CNT_X ; x++){
      drawEntry(ENTRY_W*x, ENTRY_H*y+TOP_H, &menu[cnt++]);
    }
  }
}

int main(){
  initDisplay();
  drawMenu(main_menu);
  return 0;
}

