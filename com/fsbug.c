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

// 定数とか
const unsigned int SECTOR_BUFFER=0x300;

// アセンブラ関数とか
extern unsigned char read_sec_raw();
extern void dump(char wide, unsigned int from, unsigned int to, unsigned int base);
extern void setGCONoff();
extern void restoreGCON();
extern void cins(const char *str);

// アセンブラ変数とか
extern void* sdseek;   // セクタ読み書きのポインタ
extern void* sdcmdprm; // コマンドパラメータ4バイトを指す
#pragma zpsym("sdseek");
#pragma zpsym("sdcmdprm");

// グローバル変数とか
unsigned char putnum_buf[11];
unsigned char filename_buf[15];
dinfo_t* dwk_p=(dinfo_t*)0x514;

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
        printf("<Deleted>\n");
        break;
      default:    // 有効なエントリ
        if(dir_p[i].Attr==0x0F){
          printf("<LFN>\n");
        }else{
          unsigned long fstclus = (dir_p[i].FstClusHI*0x100000000)+dir_p[i].FstClusLO;
          if(dir_p[i].Attr==0x10){
            printf("<Dir>\n");
          }else{
            printf("<File>\n");
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
  printf("<NULL>\n");
}

int main(void){
  unsigned long sec_cursor=0;
  unsigned char line[64];
  unsigned char* tok;

  unsigned long fatlen=(dwk_p->DATSTART-dwk_p->FATSTART)/2;
  unsigned long fat2startsec=dwk_p->FATSTART+fatlen;

  printf("File System Debugger.\n");

  while(1){
    printf("fs>");
    cins(line);
    printf("\n");
    tok=strtok(line," ");

    if(strcmp(tok,"help")==0){
      // つかいかた
      printf("help   - Show this message.\n");
      printf("stat   - Show status.\n");
      printf("sec    - Set current sec.\n");
      printf("read   - Read the sector.\n");
      printf("dir    - Read the sector as dir.\n");
      printf("root   - Read root dir.\n");
      printf("clus   - Calc Clus to Sec\n");

    }else if(strcmp(tok,"sec")==0){
      // 読み込み対象セクタ指定
      tok=strtok(NULL," ");
      sec_cursor=strtol(tok,NULL,16);
      sdcmdprm=&sec_cursor;
      printf(" sec_cursor:%s\n",put32(sec_cursor));

    }else if(strcmp(tok,"stat")==0){
      // 状態表示
      printf(" sec_cursor:%s\n",put32(sec_cursor));

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
      tok=strtok(NULL," ");
    }

    //}else if(strcmp(tok,"test")==0){
    //  // お試し
    //}
  }
  return 0;
}

