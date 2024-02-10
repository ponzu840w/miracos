/*
 -------------------------------------------------------------------
                              ZDコマンド
 -------------------------------------------------------------------
  雑なテキストエディタ。バッファファイルを持たず、RAMで完結する。
 -------------------------------------------------------------------
*/

#define TEXT_BUFFER_SIZE 4096
#define LINE_BUFFER_SIZE 256

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// アセンブラ関数とか
extern void coutc(const char c);
extern void cins(const char *str);
extern unsigned char fs_open(void* finfo_or_path, char flags);
extern unsigned char fs_makef(char* path);
extern void fs_close(unsigned char fd);
extern unsigned int fs_read(unsigned char fd, unsigned char *buf, unsigned int count);
extern unsigned int fs_write(unsigned char fd, unsigned char *buf, unsigned int count);
extern void err_print();

// グローバル変数
char text_buffer[TEXT_BUFFER_SIZE]; /* テキストバッファ */
char line_buffer[LINE_BUFFER_SIZE]; /* ラインバッファ */
char command[64];
char default_filename[64];
unsigned int cl, addr_left, addr_right, lastl;
unsigned int addr_lines;
unsigned int line_cnt;
unsigned char cmd_index, cmd_verb_index;
unsigned char fd;

// 1行表示
void put_line(char* str){
  unsigned int i = 0;
  while(str[i]!='\n' && str[i]!='\0')
      coutc(str[i++]);
  coutc('\n');
}

/* 行番号から行のポインタを得る */
/* 最終行+1を指定するとEOTの場所が返る */
/* 副作用として何行目まで数えたかがline_numに残る */
char* getLine(unsigned int line_num){
  char* ptr = text_buffer;
  line_cnt = 0;

  // 空バッファチェック
  if(text_buffer[0] == '\0')return ptr;

  line_cnt++;

  // 1行目
  if(line_num == 1)return ptr;

  // 1文字ずつのループ
  do{
    if(*ptr == '\n'){
      if(line_num == ++line_cnt)
        return ++ptr;
    }
  }while(*(ptr++)!='\0');

  return --ptr;
}

// なんか都合のいいatoi
// .と$に対応
unsigned int super_atoi(){
  unsigned int i;

  switch(command[cmd_index]){
  case '.':
    return cl;
  case '$':
    return lastl;
  default:
    i = atoi(&command[cmd_index]);
  }

  return i;
}

// コマンドラインのパース
// out: addr_left, addr_right, cmd_verb_index
void purseCommand(){
    addr_left = cl;
    addr_right = cl;
    // コマンドのインデックス取得
    cmd_index = 0;
    while(!('A' <= command[cmd_index] && command[cmd_index] <= 'Z' ||
          'a' <= command[cmd_index] && command[cmd_index] <= 'z' ||
          command[cmd_index] == '=' ||
          command[cmd_index] == '\0'))cmd_index++;
    cmd_verb_index = cmd_index;
    // 対象行取得
    if(cmd_verb_index == 0)return; // 完全省略ならカレント行
    cmd_index = 0;
    // left
    if(command[0] == ','){
      addr_left = 1;
    }else{
      addr_left = super_atoi();
      // 数値スキップ
      do{
        cmd_index++;
      }while('0' <= command[cmd_index] && command[cmd_index] <= '9');
    }
    // right
    if(command[cmd_index] == ','){
      if(++cmd_index == cmd_verb_index){
        addr_right = lastl;         // ,があってそこで終わり
      }else{
        addr_right = super_atoi();  // ,があって右辺がある
      }
    }else{
      addr_right = addr_left;         // ,も右辺もない
    }
}

/* バッファにギャップを作る */
unsigned int makeGap(char* to, char* from){
  unsigned int length = strlen(from);
  char* to_work = to+length;
  char* from_work = from+length;

  /* バッファ超過エラー */
  if(from_work > &text_buffer[TEXT_BUFFER_SIZE-1])
    return 0;

  /* 移動先が移動元より前にあるエラー */
  if(to <= from)
    return 0;

  do{
    //printf("len=%u, from:%d, from_work:%d, char=%c\n",length,from,from_work,*from_work);
    *(to_work--) = *(from_work--);
  }while(length-- > 0);
  return 1;
}

/* バッファのギャップを埋める */
unsigned int closeGap(char* to, char* from){
  /* 移動先が移動元より前にあるエラー */
  if(from <= to)
    return 0;

  do{
    *(to++) = *from;
  }while(*from++ != '\0');
  return 1;
}

/* i,a,c共通部分 */
/* 0 <= line <= lastl+1 */
/* 終了で偽を返す */
unsigned char insertLine(unsigned int line){
  unsigned int len;
  char* ptr = getLine(line);    /* 操作対象行 */
  cins(line_buffer);            /* 入力バッファに入力 */

  /* 終了チェック */
  if(line_buffer[0] == '.' && line_buffer[1] == '\0')
    return 0;

  len = strlen(line_buffer)+1;

  /* 末尾でなければスキマを作る */
  if(line <= lastl){
    makeGap(ptr+len, ptr);
  }else if(line != 1){  /* 前に行があるときの末尾 */
    *(ptr++) = '\n';    /*  EOTを改行にしてポインタを進める */
  }

  /* スキマに入力をコピー */
  strcpy(ptr, line_buffer);

  /* 末尾でなければ挿入の終端を改行にする */
  if(line <= lastl)
    *(ptr+len-1) = '\n';

  /* 1行増えたので最終行を増加 */
  lastl++;

  /* カレント行更新 */
  cl = line;

  return 1;
}

/* 編集モード */
void edit(unsigned int line){
  unsigned int flag;
  do{
    flag = insertLine(line++);
    coutc('\n');
  }while(flag == 1);
}

/* 削除 */
void delete(){
  closeGap(getLine(addr_left), getLine(addr_right+1));
  lastl -= addr_lines;      /* 最終行繰り上がり */
}

/* 行数を数える */
void countLines(){
  getLine(65535u);  // 副作用を期待して数えさせる
  lastl = line_cnt;
}

/* サブコマンドの引数を探す */
char getArg(){
  char arg_exist = 0;
  char arg_search_status = 0; /* 0:サブコマンドの一部 1:連続したスペース */

  /* 次のトークンを探す */
  cmd_index = cmd_verb_index;
  do{
    switch(arg_search_status){
    case 0:
      if(command[cmd_index] == ' ')
        arg_search_status++;
      break;
    case 1:
      if(command[cmd_index] != ' ')
        return 1;
    default:
      break;
    }
  }while(command[++cmd_index] != '\0');

  return 0;
}

/* ファイルを開く */
char openFile(char update_defaut_filename, char make_file){
  char* filename;

  /* 指定かデフォルトのファイル名を使う */
  if(getArg()){
    filename = &command[cmd_index];
    /* デフォルトファイル名の更新 */
    if(default_filename[0] == '\0' || update_defaut_filename){
      strcpy(default_filename, filename);
    }
  }else if(default_filename[0] != '\0'){
    filename = default_filename;
  }else{
    printf("[ERR] File Name?");
    return 0;
  }
  printf("[DBG]filename=[%s]\n",filename);

  /* ファイルオープン */
  if((fd = fs_open(filename, 0)) != 255u)
    return 1;

  if(make_file && (fd = fs_makef(filename)) != 255u)
    return 1;

  err_print();
  return 0;
}

int main(void){
  char verb;
  unsigned char n_switch;
  unsigned int load_cnt;

  // テスト用テキストでバッファを初期化
  strcpy(text_buffer,"Line1. This is Text Buffer.\nLine2. New Line\nLine3.\nLine4. Good Bye.");
  /* デフォルトファイル名初期化 */
  default_filename[0] = '\0';

  printf("sample_text:\n%s\n",text_buffer);
  printf("text_buffer:%d\n",&text_buffer);

  //printf("makeGap:%u\n",makeGap(getLine(3),getLine(2)));
  //printf("gaped_text:\n%s\n",text_buffer);

  cl = 1;
  lastl = 4;

  // REPL
  while(1){
    // コマンドライン取得
    coutc('@');
    cins(command);
    coutc('\n');
    purseCommand();
    //printf("[DBG]purse left:%u, right %u, verb_index %u\n",addr_left,addr_right,cmd_verb_index);

    // 例外処理:範囲指定がひっくり返ってる
    if(addr_left > addr_right){
      printf("[ERR] left > right.\n");
      continue;
    }

    // 例外処理:最終行を突破
    if(addr_right > lastl){
      printf("[ERR] Over range.\n");
      continue;
    }

    addr_lines = addr_right - addr_left +1;

    // コマンド実行
    verb = command[cmd_verb_index];
    n_switch = 0;
    switch(verb){

    case 'n': /* number */
      n_switch = 1;
    case 'p': /* print */
      cl = addr_left;
      do{
        if(n_switch)
          printf("%-3u|",cl);
        put_line(getLine(cl));
      }while(cl++ < addr_right);
      break;

    case 'd': /* delete */
      delete();
      cl = addr_left;
      break;

    case 'i': /* insert */
      if(addr_right == 0)addr_right = 1;
      edit(addr_right);
      break;

    case 'a': /* append */
      edit(addr_right+1);
      break;

    case 'c': /* change */
      delete();
      edit(addr_right);
      break;

    case '=': /* 指定行番号表示 */
      /* デフォルトは$ */
      if(cmd_verb_index == 0){
        cl = lastl;
      }else{
        cl = addr_right;
      }
      printf("%u\n", cl);
      break;

    case 'e': /* edit */
      if(!openFile(1,0))continue;
      load_cnt = fs_read(fd, text_buffer, TEXT_BUFFER_SIZE);
      fs_close(fd);

      /* 読み込んだバイト数に応じた例外 */
      switch(load_cnt){
      case 65535u:
        err_print();
        continue;
      case TEXT_BUFFER_SIZE:
        printf("[ERR] Out of Buffer.\n");
        text_buffer[0] = '\0';
        lastl = 0;
        cl = 0;
        continue;
      default:
        break;
      }

      printf("%u bytes loaded.\n", load_cnt);

      /* 終端する */
      text_buffer[load_cnt] = '\0';
      countLines();
      cl = lastl;
      break;

    case 'w': /* write */
      if(!openFile(0,1))
        continue;
      load_cnt = fs_write(fd, text_buffer, getLine(65535u) - text_buffer -1);
      fs_close(fd);
      break;
    default:
      break;
    }

    /* カレント行が間違っても最終行を超えないように。 */
    if(cl > lastl)cl = lastl;
  }
  return 0;
}

