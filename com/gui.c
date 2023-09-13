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
#define PAD_B       0b0000000010000000
#define PAD_Y       0b0000000001000000
#define PAD_SELECT  0b0000000000100000
#define PAD_START   0b0000000000010000
#define PAD_ARROW_U 0b0000000000001000
#define PAD_ARROW_D 0b0000000000000100
#define PAD_ARROW_L 0b0000000000000010
#define PAD_ARROW_R 0b0000000000000001
#define PAD_ALL     (PAD_A|PAD_X|PAD_L|PAD_R|PAD_B|PAD_Y|PAD_SELECT|PAD_START|PAD_ARROW_U|PAD_ARROW_D|PAD_ARROW_L|PAD_ARROW_R)

typedef struct ENTRY entry_t;
struct ENTRY{
  unsigned char name[16];       // 表示する文字列
  const entry_t *submenu_ptr;   // サブメニューへのポインタ（NULLならシェルコマンド）
  unsigned char cmd[32];        // CCPに渡すコマンド
  unsigned char char_color;     // 文字色
  unsigned char back_color;     // 背景色
};

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

const entry_t main_menu[];
const entry_t info_menu[];
const entry_t game_menu[];
const entry_t movie_menu[];
const entry_t photo_menu[];
const entry_t music_menu[];

void initDisplay(){
  disp(0b01010101);
  gr(1);
  col(0x44,0xFF);
  gcls();
}

void drawEntry(unsigned char base_x, unsigned char base_y, const entry_t* entry){
  col(entry->back_color,entry->char_color);
  rect(base_x/2+1, base_y+1, (base_x+ENTRY_W)/2-2, base_y+ENTRY_H-2);
  col(entry->char_color,entry->back_color);
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

// PADの押下を取得
unsigned int waitNewPadPush(){
  unsigned int padstat, padstat_old, diff, found;
  padstat = (~pad())&PAD_ALL;
  do{
    padstat_old = padstat;
    padstat = (~pad())&PAD_ALL;
    diff = padstat ^ padstat_old;
    found = diff & padstat;
  }while(found==0);
  return found;
}

unsigned char nextidx(unsigned char idx, unsigned int button){
  switch(button){
  case PAD_ARROW_R:
    if(idx!=ENTRY_CNT-1)idx++;
    break;
  case PAD_ARROW_L:
    if(idx!=0)idx--;
    break;
  case PAD_ARROW_U:
    if((idx/ENTRY_CNT_X)!=0)idx-=ENTRY_CNT_X;
    break;
  case PAD_ARROW_D:
    if((idx/ENTRY_CNT_X)!=ENTRY_CNT_Y-1)idx+=ENTRY_CNT_X;
    break;
  }
  return idx;
}

void openMenu(unsigned char* idx, const entry_t* menu){
  *idx=0;
  initDisplay();
  drawMenu(menu);
  drawCur(*idx,0x88);
}

int main(){
  unsigned char idx=0, newidx=0;
  unsigned int button;
  const entry_t* current_menu=&main_menu[0];

  // メインメニューを開く
  openMenu(&idx,current_menu);

  // メインループ ボタン駆動
  while(1){
    // 押下ボタン取得
    button=waitNewPadPush();
    // ボタンごとの処理
    if(button&(PAD_ARROW_R|PAD_ARROW_L|PAD_ARROW_U|PAD_ARROW_D)){
      // 十字キーでカーソル移動
      newidx=nextidx(idx, button);
    }else if((button & PAD_A) && (current_menu[idx].submenu_ptr != NULL)){
      // Aボタンで遷移
      current_menu=current_menu[idx].submenu_ptr;
      openMenu(&idx, current_menu);
    }
    // idxに変化があればカーソルを更新
    if(idx!=newidx){
      drawCur(idx,0xFF);
      drawCur(newidx,0x88);
    }
    idx=newidx;
  }

  return 0;
}

const entry_t main_menu[ENTRY_CNT] ={
//{name,      submenu,  cmd, char_color, back_color}
  {"\x9E\xA2\xB2\x92",    // せつめい
    &info_menu[0],
    "",
    0x00, 0xBB },
  {"\xD9\xBE\x90\xF1",    // ゲーム
    &game_menu[0],
    "",
    0x00, 0xDD },
  {"\xA4\xBE\x93\xC5",    // と゛うが
    &movie_menu[0],
    "",
    0xBB, 0x99 },

  {"\x9C\x8C\x9C\xBD",    // しゃしん
    &photo_menu[0],
    "",
    0x00, 0x77},
  {"\x95\xBD\xC5\x98",
    &music_menu[0],
    "",
    0x00, 0x33},
  {"BASIC",
    NULL,
    "BASIC",
    0x00, 0xFF},

  {"DOS\xDC\xCA\xF9",     // DOSシェル
    NULL,
    "",
    0xFF, 0x44},
  {"", NULL, "", 0xFF, 0x00},
  {"", NULL, "", 0xFF, 0x00},
};

const entry_t info_menu[ENTRY_CNT] ={
//{name,      submenu, cmd, char_color, back_color}
  {"SYSTEM",  NULL,    "", 0xFF, 0x77},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"return",  &main_menu[0],    "", 0xFF, 0x00}
};

const entry_t game_menu[ENTRY_CNT] ={
//{name,      submenu, cmd, char_color, back_color}
  {"SNAKE",  NULL,    "", 0xFF, 0x77},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"return",  &main_menu[0],    "", 0xFF, 0x00}
};

const entry_t movie_menu[ENTRY_CNT] ={
//{name,      submenu, cmd, char_color, back_color}
  {"SNAKE",  NULL,    "", 0xFF, 0x77},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"return",  &main_menu[0],    "", 0xFF, 0x00}
};

const entry_t photo_menu[ENTRY_CNT] ={
//{name,      submenu, cmd, char_color, back_color}
  {"SNAKE",  NULL,    "", 0xFF, 0x77},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"return",  &main_menu[0],    "", 0xFF, 0x00}
};

const entry_t music_menu[ENTRY_CNT] ={
//{name,      submenu, cmd, char_color, back_color}
  {"SNAKE",  NULL,    "", 0xFF, 0x77},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},

  {"",        NULL,    "", 0xFF, 0x00},
  {"",        NULL,    "", 0xFF, 0x00},
  {"return",  &main_menu[0],    "", 0xFF, 0x00}
};
