#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// 構造体とか
typedef struct{
  unsigned char BPB_SECPERCLUS;
  unsigned long PT_LBAOFS;      // セクタ番号
  unsigned long FATSTART;       // セクタ番号
  unsigned long DATSTART;       // セクタ番号
  unsigned long BPB_ROOTCLUS;   // クラスタ番号
} dinfo_t;

typedef struct{
  unsigned char Name[11];       // ファイル名 NAMEssssEXT
  unsigned char Attr;           // 属性
  unsigned char NTRes;          // NTフラグ
  unsigned char CrtTimeTenth;   // 作成時刻 1/100sec
  unsigned int  CrtTime;        // 作成時刻
  unsigned int  CrtDate;        // 作成日付
  unsigned int  LstAccDate;     // 最終アクセス日付
  unsigned int  FstClusHI;      // 開始クラスタ番号上位
  unsigned int  WrtTime;        // 最終更新時刻
  unsigned int  WrtDate;        // 最終更新日付
  unsigned int  FstClusLO;      // 開始クラスタ番号下位
  unsigned long FileSize;       // ファイルサイズ
} dirent_t;

typedef struct{
  unsigned char Drv_Num;  // ドライブ番号
  unsigned long Head;     // 先頭クラスタ
  unsigned long Cur_Clus; // 現在クラスタ
  unsigned char Cur_Sec;  // クラスタ内セクタ
  unsigned long Siz;      // サイズ
  unsigned long Seek_Ptr; // シーケンシャルアクセス用ポインタ
  unsigned long Dir_RSec; // ディレクトリエントリの実セクタ
} fctrl_t;

typedef struct{
  // FIB、ファイル詳細情報を取得し、検索などに利用
  unsigned char Sig;                // $FFシグネチャ、フルパス指定と区別
  unsigned char Name[13];           // 8.3ヌル終端
  unsigned char Attr;               // 属性
  unsigned int  WrTime;             // 最終更新時刻
  unsigned int  WrDate;             // 最終更新日時
  unsigned long Head;               // 先頭クラスタ番号
  unsigned long Siz;                // ファイルサイズ
  // 次を検索するためのデータ
  unsigned char Drv_Num;            // ドライブ番号
  unsigned long Dir_Clus;           // 親ディレクトリ現在クラスタ  親の先頭クラスタはどうでもいい？
  unsigned char Dir_Sec;            // 親ディレクトリ現在クラスタ内セクタ
  unsigned char Dir_Ent;            // セクタ内エントリ番号（SDSEEKの下位を右に1シフトしてMSBが後半フラグ
} finfo_t;

// 定数とか
const unsigned int SECTOR_BUFFER=0x300;

// ディレクトリエントリアトリビュート
#define MAX_ARGC 8
#define DIRATTR_READONLY   0x01
#define DIRATTR_HIDDEN     0x02
#define DIRATTR_SYSTEM     0x04
#define DIRATTR_VOLUMEID   0x08
#define DIRATTR_DIRECTORY  0x10
#define DIRATTR_ARCHIVE    0x20
#define DIRATTR_LONGNAME   0x0F

// アセンブラ関数とか
extern unsigned char read_sec_raw();
extern unsigned char write_sec_raw();
extern void dump(char wide, unsigned int from, unsigned int to, unsigned int base);
extern void setGCONoff();
extern void restoreGCON();
extern void cins(const char *str);
extern void coutc(const char c);
extern void couts(const char *str);
//extern unsigned char* path2finfo(unsigned char* path);
extern unsigned char makef(unsigned char* path);
extern void maked(unsigned char* path);
extern unsigned char open(unsigned char* path, unsigned char flags);
extern unsigned int read(unsigned char fd, unsigned char *buf, unsigned int count);
extern unsigned int write(unsigned char fd, unsigned char *buf, unsigned int count);
extern unsigned char search_open(unsigned char* path);
extern char delete(void* path_or_finfo);
extern finfo_t* find_fst(const char* path);
extern finfo_t* find_nxt(finfo_t* finfo, char* name);
extern void err_print();
extern unsigned long seek(unsigned char fd, unsigned char mode, unsigned long offset);

// アセンブラ変数とか
extern void* sdseek;   // セクタ読み書きのポインタ
extern void* sdcmdprm; // コマンドパラメータ4バイトを指す
#pragma zpsym("sdseek");
#pragma zpsym("sdcmdprm");
extern fctrl_t fwk;
extern finfo_t finfo_wk;
extern unsigned int fd_table;
extern fctrl_t fctrl_res;

// グローバル変数とか
unsigned char putnum_buf[11];
unsigned char filename_buf[15];
dinfo_t* dwk_p=(dinfo_t*)0x514;
unsigned long fatlen;
unsigned long fat2startsec;
finfo_t* finfo_p;
finfo_t finfo_deep_ins;
unsigned char basename[13];

// パス入力を強制する
char* inputpath(unsigned char* l, unsigned char* t){
  if((t=strtok(NULL," "))==NULL){
    couts("path>");
    cins(l);
    t=l;
    coutc('\n');
  }
  printf("path:%s\n",t);
  return t;
}

// $0123-4567形式で表示
char* put32(unsigned long toput){
  sprintf(putnum_buf,"$%04X-%04X",(unsigned int)(toput>>16),(unsigned int)(toput));
  return putnum_buf;
}

// クラスタ番号をセクタ番号に変換
unsigned long Clus2Sec(unsigned long clus){
  return dwk_p->DATSTART+((clus-2)*dwk_p->BPB_SECPERCLUS);
}

// SFN形式のファイル名を.形式に変換
char* SFN_to_dot(unsigned char* name_ptr) {
  unsigned char name[12], ext[4];
  unsigned int i;

  // Extract the filename and pad with '\0' as necessary
  for(i = 0; i < 8 && name_ptr[i] != ' '; i++) {
    name[i] = name_ptr[i];
  }
  name[i] = '\0';

  // Extract the extension and pad with '\0' as necessary
  for(i = 8; i < 8+3 && name_ptr[i] != ' '; i++) {
    ext[i-8] = name_ptr[i];
  }
  ext[i-8] = '\0';

  // Print the filename.extension
  if(ext[0]=='\0'){
    sprintf(filename_buf, "%s", name);
  }else{
    sprintf(filename_buf, "%s.%s", name, ext);
  }
  return filename_buf;
}

// セクタリード
int read_sec(unsigned long sec){
  sdcmdprm=&sec;
  sdseek=(void*)SECTOR_BUFFER;
  return read_sec_raw();
}

// セクタライト
int write_sec(unsigned long sec){
  sdcmdprm=&sec;
  sdseek=(void*)SECTOR_BUFFER;
  return write_sec_raw();
}

// ディレクトリ表示
void showDir(unsigned long sec){
  unsigned char i;
  unsigned int index=0,page=0;
  unsigned char b=1;
  // セクタループ
  do{
    dirent_t* dir_p=(void*)SECTOR_BUFFER;
    read_sec(sec+page);
    // エントリループ
    for(i=0;i<512/32;i++){
      printf("[%03X]",index);
      switch(dir_p[i].Name[0]){
      case 0x0:   // 終わり
        b=0;
        break;
      case 0xE5:  // 消された
        couts("<X>\n");
        break;
      default:    // 有効なエントリ
        if(dir_p[i].Attr==0x0F){
          couts("<LFN>\n");
        }else{
          unsigned long fstclus = (dir_p[i].FstClusHI*0x100000000)+dir_p[i].FstClusLO;
          if(dir_p[i].Attr==0x10){
            couts("<D>\n");
          }else{
            couts("<F>\n");
          }
          printf("      Name   :%s\n",SFN_to_dot(dir_p[i].Name));
          printf("      FstClus:%s\n",put32(fstclus));
          printf("         =Sec:%s\n",put32(Clus2Sec(fstclus)));
          printf("      Size   :%s\n",put32(dir_p[i].FileSize));
        }
      }
      if(!b)break;
      index++;
    }
    page++;
  }while(b);
  couts("<NULL>\n");
}

void showFAT(unsigned char fatnum, unsigned long clus){
  unsigned long sec;
  unsigned long* entry_ptr;
  if(fatnum==1)sec=dwk_p->FATSTART;
  else sec=fat2startsec;
  sec=sec+(clus/128);
  entry_ptr=(void*)SECTOR_BUFFER;
  entry_ptr+=clus%128;
  read_sec(sec);
  printf("[%lx]%lx\n",clus,*entry_ptr);
}

// FWK表示
void showFWK(){
  printf("Drive Number: $%02x\n",fwk.Drv_Num);
  printf("Head    Clus: %s\n",put32(fwk.Head));
  printf("Current Clus: %s\n",put32(fwk.Cur_Clus));
  printf("Current Sec : $%02x\n",fwk.Cur_Sec);
  printf("        Size: %s\n",put32(fwk.Siz));
  printf("Seek Pointer: %s\n",put32(fwk.Seek_Ptr));
  printf("     Dir Sec: %s\n",put32(fwk.Dir_RSec));
}

// FINFO_WK表示
void showFINFO(){
  printf("Name: %s\n",finfo_wk.Name);
  printf("Attr: %02x\n",finfo_wk.Attr);
  // 時間省いた
  printf("Head: %s\n",put32(finfo_wk.Head));
  printf("Size: %s\n",put32(finfo_wk.Siz));
  couts("Dir:\n");
  printf("  DrvNum: $%02x\n",finfo_wk.Drv_Num);
  printf("    Clus: %s\n",put32(finfo_wk.Dir_Clus));
  printf("     Sec: $%02x\n",finfo_wk.Dir_Sec);
  printf("     Ent: $%02x\n",finfo_wk.Dir_Ent);
}

// FDテーブル表示
void showFDtable(){
  unsigned char i;
  couts("File Discriptor Table:\n");
  for(i=0;i<7;i++){
    printf("%d:$%04X\n",i,*(&fd_table+i));
  }
}

unsigned char* get_filename_from_path(unsigned char* path) {
    // strrchr関数で最後の'/'の位置を探す
    unsigned char *lastSlash = strrchr(path, '/');
    if (lastSlash) {
        // 最後の'/'の次の文字がファイル名の始まり
        return lastSlash + 1;
    }
    return path;
}

// FINFO_WK表示
void showFINFO2(finfo_t* ptr){
  printf("Sig: %02x\n",ptr->Sig);
  printf("Name: %s\n",ptr->Name);
  printf("Attr: %02x\n",ptr->Attr);
  // 時間省いた
  printf("Head: %s\n",put32(ptr->Head));
  printf("Size: %s\n",put32(ptr->Siz));
  printf("Dir:\n");
  printf("  DrvNum: $%02x\n",ptr->Drv_Num);
  printf("    Clus: %s\n",put32(ptr->Dir_Clus));
  printf("     Sec: $%02x\n",ptr->Dir_Sec);
  printf("     Ent: $%02x\n",ptr->Dir_Ent);
}

void searchEntriesToDelete(char* path){
  unsigned char* basename_p = get_filename_from_path(path);
  strcpy(basename, basename_p);
  finfo_p = find_fst(path);  // p <- FINFO_WK
  finfo_deep_ins = *finfo_p;    // FINFOを手元にディープコピー
  printf("KERNEL FINFO:%p\n", finfo_p);
  printf("APP    FINFO:%p\n", &finfo_deep_ins);
  if(finfo_p == NULL) return;
  do{
    printf("%s", finfo_p->Name);
    if((finfo_p->Attr & (DIRATTR_READONLY|DIRATTR_VOLUMEID|DIRATTR_SYSTEM)) != 0){
      couts(" is protected.\n");
    }else{
      coutc('\n');
      if(delete((void*)&finfo_deep_ins)!=0){
        err_print();
        couts("error\n");
      }else{
        couts("ok\n");
      }
    }
    printf("finfo_deep_ins:%s\n",&finfo_deep_ins.Name);
    showFINFO2(&finfo_deep_ins);
    finfo_p = find_nxt(&finfo_deep_ins, basename); // TODO:与えるfinfoにのみ依存する建前に関わらず、deleteによって内部が壊れるのか連続削除できない
    finfo_deep_ins = *finfo_p;
    if(finfo_p != NULL){
      printf("finfo_deep_ins:%s, basename=%s\n",&finfo_deep_ins.Name, basename);
      showFINFO2(&finfo_deep_ins);
    }else{
      printf("end\n");
    }
  }while(finfo_p != NULL);
}

int main(void){
  unsigned long sec_cursor=0;
  unsigned char fd;
  unsigned char line[64];
  unsigned char* tok;

  fatlen=(dwk_p->DATSTART-dwk_p->FATSTART)/2;
  fat2startsec=dwk_p->FATSTART+fatlen;

  couts("File System Debugger.\n");

  while(1){
    couts("fs>");
    cins(line);
    coutc('\n');
    tok=strtok(line," ");

    if(strcmp(tok,"help")==0){
      // つかいかた
      couts("help   - Show this message.\n"
             "stat   - Show status.\n"
             "sec    - Set current sec.\n"
             "read   - Read the sector.\n"
             "dir    - Read the sector as dir.\n"
             "root   - Read root dir.\n"
             "clus   - Calc Clus to Sec\n"
             "fat    - Show FAT\n"
             "makef  - Make new file.\n"
             "maked  - Make new dir.\n"
             "exit   - Exit this tool.\n"
             "work   - Show work area.\n"
             "table  - Show tables.\n"
             "open   - Open file.\n"
             "openw  - Open file with TRUNC.\n"
             "del    - Delete file.\n"
             "r      - Read 3 char from fd.\n"
             "w      - Write 4 char to fd.\n");

    }else if(strcmp(tok,"sec")==0){
      // 読み込み対象セクタ指定
      if((tok=strtok(NULL," "))==NULL){
        couts("sec32>$");
        scanf("%lX",&sec_cursor);
      }else{
        sec_cursor=strtol(tok,NULL,16);
      }
      sdcmdprm=&sec_cursor;
      printf(" sec_cursor:%s\n",put32(sec_cursor));

    }else if(strcmp(tok,"stat")==0){
      // 状態表示
      printf(" sec_cursor:%s\n",put32(sec_cursor));
      printf(" fd        :%d\n",fd);

      printf("\n[Master Boot Record]\n");
      printf(" [Partition 1 Info]\n");
      printf("  PT_LbaOfs(S):%s\n",put32(dwk_p->PT_LBAOFS));

      printf("\n[BIOS Parameter Block of PT1]\n");
      printf("    Sec/Clus   (s):$%02X\n",dwk_p->BPB_SECPERCLUS);
      printf("  Length of FAT(s):%s\n",put32(fatlen));
      printf("  Start of FAT1(S):%s\n",put32(dwk_p->FATSTART));
      printf("  Start of FAT2(S):%s\n",put32(fat2startsec));
      printf("  Start of Data(S):%s\n",put32(dwk_p->DATSTART));
      printf("    RootClus   (C):%s\n",put32(dwk_p->BPB_ROOTCLUS));

    }else if(strcmp(tok,"table")==0){
      showFDtable();
      printf("FCTRL_RES start:$%02X\n",&fctrl_res);

    }else if(strcmp(tok,"work")==0){
      couts("\nFWK:\n");
      showFWK();
      couts("\nFINFO_WK:\n");
      showFINFO();

    }else if(strcmp(tok,"read")==0){
      // セクタ読み取り
      unsigned int err;
      if(err=read_sec(sec_cursor)!=0)
        printf("[ERR]:%d\n",err);
      // セクタバッファを表示
      setGCONoff();
      dump(0, SECTOR_BUFFER, SECTOR_BUFFER+0x1FF, 0);
      restoreGCON();

    }else if(strcmp(tok,"dir")==0){
      setGCONoff();
      showDir(sec_cursor);
      restoreGCON();

    }else if(strcmp(tok,"root")==0){
      setGCONoff();
      showDir(dwk_p->DATSTART);
      restoreGCON();

    }else if(strcmp(tok,"clus")==0){
      unsigned long clus;
      if((tok=strtok(NULL," "))==NULL){
        couts("clus32>$");
        scanf("%lX",&clus);
      }else{
        clus=strtol(tok,NULL,16);
      }
      sec_cursor=Clus2Sec(clus);
      printf(" sec_cursor:%s\n",put32(sec_cursor));

    }else if(strcmp(tok,"write")==0){
      unsigned int i=0;
      unsigned char* ptr;
      ptr=(unsigned char*)SECTOR_BUFFER;
      for(;i<512;i++){
        ptr[i]=(unsigned char)i;
      }
      write_sec(sec_cursor);

    }else if(strcmp(tok,"fat1")==0 || strcmp(tok,"fat2")==0){
      unsigned long clus;
      unsigned char fatnum;
      if(strcmp(tok,"fat1")==0)fatnum=1;
      else fatnum=2;
      if((tok=strtok(NULL," "))==NULL){
        couts("clus32>$");
        scanf("%lX",&clus);
      }else{
        clus=strtol(tok,NULL,16);
      }
      showFAT(fatnum,clus);
    /*
    }else if(strcmp(tok,"makef")==0){
      // ファイル作成
      tok=inputpath(line,tok);
      fd=makef(tok);

    }else if(strcmp(tok,"del")==0){
      // ファイル削除
      tok=inputpath(line,tok);
      delete(tok);

    }else if(strcmp(tok,"maked")==0){
      // ディレクトリ作成
      tok=inputpath(line,tok);
      maked(tok);

      */
    }else if(strcmp(tok,"open")==0){
      // ファイルオープン
      tok=inputpath(line,tok);
      fd=open(tok, 0);
      printf("new fd=%d\n",fd);
      showFDtable();

      /*
    else if(strcmp(tok,"del2")==0){
      // ファイルいっぱい削除
      tok=inputpath(line,tok);
      searchEntriesToDelete(tok);
    }

    }else if(strcmp(tok,"open_t")==0){
      // ファイルオープン、破壊
      tok=inputpath(line,tok);
      fd=open(tok, 1);
      printf("new fd=%d\n",fd);
      showFDtable();
      */
    /*
     * TODO:exitが何でか機能しない
    }else if(strcmp(tok,"exit")==0){
      printf("bye\n");
      exit(0);
      */

    }else if(strcmp(tok,"r")==0){
      unsigned int len=read(fd,line,3);
      line[3]='\0';
      printf("read>[%s]\n",line);

      /*
    }else if(strcmp(tok,"w")==0){
      unsigned int len=write(fd,"hoge",4);
      printf("write>[%d]\n",len);
      */

    /*}else if(strcmp(tok,"search")==0){
      tok=inputpath(line,tok);
      fd=search_open(tok);
      printf("new fd=%d\n",fd);
      showFDtable();
    }*/
    /*
     // いっぱい書き込む
    }else if(strcmp(tok,"w52")==0){
      unsigned int len = write(fd,"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",52);
      printf("write>[%d]\n",len);
    }
    */
    }else if(strcmp(tok,"seek")==0){
      unsigned long offset;
      if((tok=strtok(NULL," "))==NULL){
        couts("offset32>$");
        scanf("%lX",&offset);
      }else{
        offset=strtol(tok,NULL,16);
      }
      printf("seek ret: %lu\n", seek(fd, 0, offset));
    }
  }
  return 0;
}

