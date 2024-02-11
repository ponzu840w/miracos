/*
 -------------------------------------------------------------------
                              ZDコマンド
 -------------------------------------------------------------------
  雑なテキストエディタ。バッファファイルを持たず、RAMで完結する。
 -------------------------------------------------------------------
*/

#define TEXT_BUFFER_SIZE 1024*8
#define LINE_BUFFER_SIZE 256
#define COMMAND_BUF_SIZE 64
#define FILENAME_BUF_SIZ 16
/* openFile()でファイルを開くときのフラグ */
#define O_TRUNCATE_0SIZE 1  /* 開くときに既存の内容を捨てる */
#define O_UPDATE_DEFAULT 2  /* デフォルトファイルを上書きする */
#define O_ALLOW_NEW_FILE 4  /* 新規ファイル作成を許可する */

#include <stdio.h>
#include <string.h>
//#include <stdlib.h>

// アセンブラ関数とか
extern void coutc(const char c);
extern void couts(const char *str);
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
char command[COMMAND_BUF_SIZE];
char default_filename[FILENAME_BUF_SIZ];
unsigned int cl, addr_left, addr_right, lastl;
unsigned int addr_lines;
unsigned int line_cnt;
unsigned char cmd_index, cmd_verb_index;
unsigned char fd;
unsigned char changed = 0;
unsigned char setup = 1;
unsigned int load_cnt;

/* string.h を使った方が小さい */
/*
unsigned int strlen(const char* const str){
  unsigned int len = 0;
  while(str[len++]);
  return len-1;
}

void strcpy(char* const to, char* const from){
  unsigned int index = 0;
  do{
    to[index] = from[index];
  }while(from[index++]);
}
*/

/* stdlib.h よりちょっと小さい */
unsigned int atoi(const char* str) {
  unsigned int result = 0;

  while('0' <= *str && *str <= '9')
    result = result * 10 + (*(str++) - '0');

  return result;
}

// 1行表示
void put_line(char* str){
  unsigned int i = 0;
  while(str[i]!='\n' && str[i]!='\0')
      coutc(str[i++]);
  coutc('\n');
}

/* 行番号から行のポインタを得る */
/* 最終行+1を指定するとEOTの場所が返る */
/* 副作用として何行目まで数えたかがline_cntに残る */
char* getLine(unsigned int line_num){
  char* ptr = text_buffer;
  line_cnt = 0;

  // 空バッファチェック
  if(text_buffer[0] == '\0') return ptr;

  line_cnt++;

  // 1行目
  if(line_num == 1) return ptr;

  // 1文字ずつのループ
  do{
    if(*ptr == '\n'){
      if(line_num == ++line_cnt) return ++ptr;
    }
  }while(*(ptr++) != '\0');

  /* 改行即EOFは行数に含まない */
  if(*(--ptr -1) == '\n') --line_cnt;

  /* EOFの位置を返す */
  return ptr;
}

/* なんか都合のいいatoi */
/* .と$と+-に対応 */
int super_atoi(){
  unsigned int i = 0;
  unsigned int num;
  unsigned char invert = 0;
  switch(command[cmd_index]){
  case '.': return cl;
  case '$': return lastl;
  case '-': invert = 1;
  case '+': i = cl;
            cmd_index++;
  default : if(!('0' <= command[cmd_index] && command[cmd_index] <= '9')){
              return -1;
            }
            num = atoi(&command[cmd_index]);
  }
  return invert ? i-num : i+num;
}

/* コマンドラインのパース */
/* out: addr_left, addr_right, cmd_verb_index */
unsigned char purseCommand(){
    addr_left = cl;
    addr_right = cl;
    /* コマンドのインデックス取得 */
    cmd_index = 0;
    while(!('A' <= command[cmd_index] && command[cmd_index] <= 'Z' ||
            'a' <= command[cmd_index] && command[cmd_index] <= 'z' ||
            '=' == command[cmd_index] ||
            '%' == command[cmd_index] ||
           '\0' == command[cmd_index] )) cmd_index++;
    cmd_verb_index = cmd_index;
    /* 対象行取得 */
    /* 完全省略ならカレント行 */
    if(cmd_verb_index == 0) return 1;
    /* left */
    cmd_index = 0;
    if(command[0] == ','){
      addr_left = (lastl == 0) ? 0 : 1;
    }else{
      if((addr_left = super_atoi()) == -1) return 0;
      /* 数値スキップ */
      do{ cmd_index++; } while('0' <= command[cmd_index] && command[cmd_index] <= '9');
    }
    /* right */
    if(command[cmd_index] == ','){
      if(++cmd_index == cmd_verb_index){
        /* ,があってそこで終わり */
        addr_right = lastl;
      }else{
        /* ,があって右辺がある */
        if((addr_right = super_atoi()) == -1) return 0;
      }
    }else{
      /* ,も右辺もない */
      addr_right = addr_left;
    }
    return 1;
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

  strcpy(to,from);
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
  }else if(*(ptr-1) != '\n' && line != 1){
    /* NOEOLな末尾（1行目でない） */
    *(ptr++) = '\n';  /*  改行してEOTの次までポインタを進める */
  }

  /* スキマに入力をコピー */
  strcpy(ptr, line_buffer);

  /* 挿入の終端を改行にする */
  *(ptr+len-1) = '\n';

  /* 末尾なら終端する */
  if(line > lastl) *(ptr+len) = '\0';

  /* 1行増えたので最終行を増加 */
  lastl++;
  changed = 1;

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
  changed = 0;
}

/* 行数を数える */
void countLines(){
  getLine(65535u);  // 副作用を期待して数えさせる
  lastl = line_cnt;
}

/* スペース区切り文字列から次の引数の文字列を返す */
char* getNextArg(char* arg_str){
  unsigned char index = 0;
  char arg_exist = 0;
  char arg_search_status = 0; /* 0:サブコマンドの一部 1:連続したスペース */

  /* 次のトークンを探す */
  do{
    switch(arg_search_status){
    case 0:
      if(arg_str[index] == ' ')
        arg_search_status++;
      break;
    case 1:
      if(arg_str[index] != ' ')
        return &arg_str[index];
    default:
      break;
    }
  }while(arg_str[++index] != '\0');

  return NULL;
}

/* 未保存の変更があったら警告する */
unsigned char isUnSaved(){
  if(changed){
    couts("[Warning] Unsaved Changes!\n");
    changed = 0;
    return 1;
  }
  return 0;
}

/* ファイルを開く */
char openFile(char* arg_str, char openflags){
  char* filename;

  /* 指定かデフォルトのファイル名を使う */
  if(arg_str != NULL && arg_str[0] != '\0'){
    filename = arg_str;
    /* デフォルトファイル名の更新 */
    if(default_filename[0] == '\0' || (openflags & O_UPDATE_DEFAULT)){
      strcpy(default_filename, filename);
    }
  }else if(default_filename[0] != '\0'){
    filename = default_filename;
  }else{
    if(!setup) couts("[ERR] File Name?\n");
    return 0;
  }
  //printf("[DBG]filename=[%s]\n",filename);

  /* ファイルオープン */
  if((fd = fs_open(filename, openflags & O_TRUNCATE_0SIZE)) != 255u)
    return 1;

  if((openflags & O_ALLOW_NEW_FILE) && (fd = fs_makef(filename)) != 255u)
    return 1;

  err_print();
  return 0;
}

/* eコマンド */
char e_command(char* arg_str){
  if(!openFile(arg_str, O_UPDATE_DEFAULT)) return 0;
  load_cnt = fs_read(fd, text_buffer, TEXT_BUFFER_SIZE);
  fs_close(fd);

  /* 読み込んだバイト数に応じた例外 */
  switch(load_cnt){
  case 65535u:
    err_print();
    return 0;
  case TEXT_BUFFER_SIZE:
    couts("[ERR] Out of Buffer.\n");
    text_buffer[0] = '\0';
    lastl = 0;
    cl = 0;
    return 0;
  default:
    break;
  }

  printf("%u bytes loaded.\n", load_cnt);

  /* 終端する */
  text_buffer[load_cnt] = '\0';
  countLines();
  cl = lastl;

  return 1;
}

void showMem(){
  unsigned int cnt_i = 0;
  while(text_buffer[cnt_i++] != '\0' && cnt_i < TEXT_BUFFER_SIZE);
  printf("BufferUsage: %u/%u[B],=%lu%%\n", cnt_i, TEXT_BUFFER_SIZE,
      ((unsigned long)cnt_i) * 100ul / ((unsigned long)TEXT_BUFFER_SIZE));
}

int main(void){
  char verb;
  char* eff_addr_left;
  unsigned int write_size;

  unsigned int* zr0=(unsigned int*)0;       /* ZR0を指す */
  unsigned char* arg=(unsigned char*)*zr0;  /* ZR0の指すところを指す コマンドライン引数 */

  /*
  // テスト用テキストでバッファを初期化
  strcpy(text_buffer,"Line1. This is Text Buffer.\nLine2. New Line\nLine3.\nLine4. Good Bye.");
  cl = 1;
  lastl = 4;
  */

  /* バッファを初期化 */
  text_buffer[0] = '\0';
  /* デフォルトファイル名初期化 */
  default_filename[0] = '\0';
  /* 行変数を初期化 */
  cl = 0;
  lastl = 0;

  /* コマンドライン引数を処理 */
  //printf("[DBG]arg:%4X, '%s'\n", &arg, arg);
  e_command(arg);
  setup = 0;

  //printf("Buffer= %u bytes @ $%4X\n", TEXT_BUFFER_SIZE, &text_buffer);
  showMem();

  // REPL
  while(1){
    // コマンドライン取得
    printf("(%u)@", cl);
    cins(command);
    coutc('\n');
    if(!purseCommand()){
      couts("[ERR] Wrong Command.\n");
      continue;
    }
    //printf("[DBG]purse left:%u, right %u, verb_index %u\n",addr_left,addr_right,cmd_verb_index);

    // 例外処理:範囲指定がひっくり返ってる
    if(addr_left > addr_right){
      couts("[ERR] left > right.\n");
      continue;
    }

    // 例外処理:最終行を突破
    if(addr_right > lastl){
      couts("[ERR] Over range.\n");
      continue;
    }

    addr_lines = addr_right - addr_left +1;

    /* サブコマンド先頭文字 */
    verb = command[cmd_verb_index];
    /* 例外処理:空テキスト非対応コマンド */
    if(lastl == 0){
      switch(verb){
      case 'n':
      case 'p':
      case 'd':
      case '\0':
        couts("[ERR] No text.\n");
        continue;
      default:
        break;
      }
    }
    /* サブコマンド実行 */
    switch(verb){
    case 'n': /* number */
    case 'p': /* print */
              cl = addr_left;
              do{
                if(verb == 'n') printf("%-3u|",cl);
                put_line(getLine(cl));
              }while(cl++ < addr_right);
              cl--;
              break;
    case 'd': /* delete */
              delete();
              cl = addr_left;
              break;
    case 'i': /* insert */
              if(addr_right == 0) addr_right = 1;
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
    case 'E': /* force edit */
              changed = 0;
    case 'e': /* edit */
              if(isUnSaved()) continue;
              if(!e_command(getNextArg(&command[cmd_verb_index]))) continue;
              showMem();
              changed = 0;
              break;
    case 'w': /* write */
              /* デフォルトは1,$ */
              if(cmd_verb_index == 0){
                addr_left = 1;
                addr_right = lastl;
              }
              if(!openFile(getNextArg(&command[cmd_verb_index]), O_ALLOW_NEW_FILE | O_TRUNCATE_0SIZE))
                continue;
              load_cnt = 0;
              if(addr_right != 0 && addr_left != 0){ /* 0行目があれば空ファイル生成にとどまる */
                eff_addr_left = getLine(addr_left);
                write_size = getLine(addr_right +1) - eff_addr_left;
                //printf("[DBG]eff_addr_left=%u, write_size=%u\n", eff_addr_left, write_size);
                load_cnt = fs_write(fd, eff_addr_left, write_size);
                if(cmd_verb_index == 0) changed = 0; /* デフォルト範囲指定の時のみセーブ判定 */
              }
              printf("%u bytes wrote.\n", load_cnt);
              fs_close(fd);
              break;
    case 'Q': /* force quit */
              changed = 0;
    case 'q': /* quit */
              if(isUnSaved()) continue;
              else return 0;
    case '\0':/* ENTER */
              cl = addr_right;
              if(cmd_verb_index == 0){
                if(cl == lastl){ couts("[ERR] Last line.\n"); break; }
                cl++;
              }
              put_line(getLine(cl));
              break;
    case '%': /* Memory Usage */
              showMem();
              break;
    default:
              break;
    }

    /* カレント行が間違っても最終行を超えないように。 */
    if(cl > lastl) cl = lastl;
  }
  return 0;
}

