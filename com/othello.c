// https://daeudaeu.com/othello/
#include <stdio.h>

/* 盤のサイズ */
#define SIZE (8)
#define WIDTH (SIZE)
#define HEIGHT (SIZE)

/* 石の色 */
typedef enum color {
  white,
  black,
  empty
} COLOR;

/* 石を置けるかどうかの判断 */
typedef enum put {
  ok,
  ng
} PUT;

/* 盤を表す二次元配列 */
COLOR b[HEIGHT][WIDTH];

/* 盤を初期化 */
int init_ban(void){
  unsigned char x, y;

  for(y = 0; y < HEIGHT; y++){
    for(x = 0; x < WIDTH; x++){
      b[y][x] = empty;
    }
  }

  /* 盤面の真ん中に石を置く */
  b[HEIGHT / 2][WIDTH / 2] = white;
  b[HEIGHT / 2 - 1][WIDTH / 2 - 1] = white;
  b[HEIGHT / 2 - 1][WIDTH / 2] = black;
  b[HEIGHT / 2][WIDTH / 2 - 1] = black;

  return 0;
}

/* マスを表示 */
int displaySquare(COLOR square){

  switch(square){
  case white:
    /* 白色の石は "o" で表示 */
    printf("o");
    break;
  case black:
    /* 黒色の石は "*" で表示 */
    printf("*");
    break;
  case empty:
    /* 空きは " " で表示 */
    printf(".");
    break;
  default:
    printf("Error");
    return -1;
  }
  return 0; 
}

/* 盤を表示 */
int display(void){
  int x, y;

  for(y = 0; y < HEIGHT; y++){
    /* 盤の横方向のマス番号を表示 */
    if(y == 0){
      printf(" ");
      for(x = 0; x < WIDTH; x++){
        printf("%d", x);
      }
      printf("\n");
    }

    for(x = 0; x < WIDTH; x++){
      /* 盤の縦方向のます番号を表示 */
      if(x == 0){
        printf("%d", y);
      }

      /* 盤に置かれた石の情報を表示 */
      displaySquare(b[y][x]);
    }
    printf("\n");
  }

  return 0;
}

/* 指定された場所に石を置く */
int put(int x, int y, COLOR color){
  int i, j;
  int s, n;
  COLOR other;

  /* 相手の石の色 */
  if(color == white){
    other = black;
  } else if(color == black){
    other = white;
  } else {
    return -1;
  }

  /* 全方向に対して挟んだ石をひっくり返す */
  for(j = -1; j < 2; j++){
    for(i = -1; i < 2; i++){

      /* 真ん中方向はチェックしてもしょうがないので次の方向の確認に移る */
      if(i == 0 && j == 0){
        continue;
      }

      if(y + j <0 || x + i < 0 || y + j >= HEIGHT || x + i >= WIDTH){
        continue;
      }
      /* 隣が相手の色でなければその方向でひっくり返せる石はない */
      if(b[y + j][x + i] != other){
        continue;
      }

      /* 置こうとしているマスから遠い方向へ１マスずつ確認 */
      for(s = 2; s < SIZE; s++){
        /* 盤面外のマスはチェックしない */
        if(
          x + i * s >= 0 &&
          x + i * s < WIDTH &&
          y + j * s >= 0 &&
          y + j * s < HEIGHT
        ){

          if(b[y + j * s][x + i * s] == empty){
            /* 自分の石が見つかる前に空きがある場合 */
            /* この方向の石はひっくり返せないので次の方向をチェック */
            break;
          }

          /* その方向に自分の色の石があれば石がひっくり返せる */
          if(b[y + j * s][x + i * s] == color){
            /* 石を置く */
            b[y][x] = color;

            /* 挟んだ石をひっくり返す */
            for(n = 1; n < s; n++){
              b[y + j * n][x + i * n] = color;
            }
            break;
          }
        }
      }
    }
  }

  return 0;
}

/* 指定された場所に置けるかどうかを判断 */
PUT isPuttable(int x, int y, COLOR color){
  int i, j;
  int s;
  COLOR other;
  int count;

  /* 既にそこに石が置いてあれば置けない */
  if(b[y][x] != empty){
    return ng;
  }

  /* 相手の石の色 */
  if(color == white){
    other = black;
  } else if(color == black){
    other = white;
  } else {
    return ng;
  }
  /* 各方向に対してそこに置くと相手の石がひっくり返せるかを確認 */

  /* １方向でもひっくり返せればその場所に置ける */

  /* 置ける方向をカウント */
  count = 0;

  /* 全方向に対して挟んだ石をひっくり返す */
  for(j = -1; j < 2; j++){
    for(i = -1; i < 2; i++){

      /* 真ん中方向はチェックしてもしょうがないので次の方向の確認に移る */
      if(i == 0 && j == 0){
        continue;
      }

      if(y + j <0 || x + i < 0 || y + j >= HEIGHT || x + i >= WIDTH){
        continue;
      }

      /* 隣が相手の色でなければその方向でひっくり返せる石はない */
      if(b[y + j][x + i] != other){
        continue;
      }

      /* 置こうとしているマスから遠い方向へ１マスずつ確認 */
      for(s = 2; s < SIZE; s++){
        /* 盤面外のマスはチェックしない */
        if(
          x + i * s >= 0 &&
          x + i * s < WIDTH &&
          y + j * s >= 0 &&
          y + j * s < HEIGHT
        ){

          if(b[y + j * s][x + i * s] == empty){
            /* 自分の石が見つかる前に空きがある場合 */
            /* この方向の石はひっくり返せないので次の方向をチェック */
            break;;
          }

          /* その方向に自分の色の石があれば石がひっくり返せる */
          if(b[y + j * s][x + i * s] == color){
            /* 石がひっくり返る方向の数をカウント */
            count++;
          }
        }
      }
    }
  }

  if(count == 0){
    return ng;
  }

  return ok;
}

/* プレイヤーが石を置く */
void play(COLOR color){
  int x, y;

  /* 置く場所が決まるまで無限ループ */
  while(1){
    /* 置く場所の入力を受付 */
    printf("X address?");
    scanf("%d", &x);
    printf("Y address?");
    scanf("%d", &y);

    /* 入力された場所におけるならループを抜ける */
    if(isPuttable(x, y, color) == ok){
      break;
    }

    /* 入力された場所に石が置けない場合の処理 */

    printf("You can't put it there!!\n");
    printf("Available location list:\n");

    /* 置ける場所を表示 */
    for(y = 0; y < HEIGHT; y++){
      for(x = 0; x < WIDTH; x++){
        if(isPuttable(x, y, color) == ok){
          printf("(%d, %d)\n", x, y);
        }
      }
    }
  }

  /* 最後に石を置く */
  put(x, y, black);

}

/* COMが石を置く */
void com(COLOR color){
  int x, y;

  /* 置ける場所を探索 */
  for(y = 0; y < HEIGHT; y++){
    for(x = 0; x < WIDTH; x++){
      if(isPuttable(x, y, color) == ok){
        /* 置けるなら即座にその位置に石を置いて終了 */
        put(x, y, color);
        printf("I put in (%d,%d).\n", x, y);
        return ;
      }
    }
  }
}

/* 結果を表示する */
void result(void){
  int x, y;
  int white_count, black_count;

  /* 盤上の白石と黒石の数をカウント */
  white_count = 0;
  black_count = 0;
  for(y = 0; y < HEIGHT; y++){
    for(x = 0; x < WIDTH; x++){
      if(b[y][x] == white){
        white_count++;
      } else if(b[y][x] == black){
        black_count++;
      }
    }
  }

  /* カウント数に応じて結果を表示 */
  if(black_count > white_count){
    printf("You Win!");
  } else if(white_count > black_count){
    printf("You Lose!");
  } else {
    printf("It's draw.");
  }
  printf("(Black:%d / White:%d)\n", black_count, white_count);

}

COLOR nextColor(COLOR now){
  COLOR next;
  int x, y;

  /* まずは次の石の色を他方の色の石に設定 */
  if(now == white){
    next = black;
  } else {
    next = white;
  }

  /* 次の色の石が置けるかどうかを判断 */
  for(y = 0; y < HEIGHT; y++){
    for(x = 0; x < WIDTH; x++){
      if(isPuttable(x, y, next) == ok){
        /* 置けるのであれば他方の色の石が次のターンに置く石 */
        return next;
      }
    }
  }

  /* 他方の色の石が置けない場合 */

  /* 元々の色の石が置けるかどうかを判断 */
  for(y = 0; y < HEIGHT; y++){
    for(x = 0; x < WIDTH; x++){
      if(isPuttable(x, y, now) == ok){
        /* 置けるのであれば元々の色の石が次のターンに置く石 */
        return now;
      }
    }
  }

  /* 両方の色の石が置けないのであれば試合は終了 */
  return empty;
}

int main(void){
  COLOR now, next;

  /* 盤を初期化して表示 */
  init_ban();
  display();

  /* 最初に置く石の色 */
  now = black;

  /* 決着がつくまで無限ループ */
  while(1){
    if(now == black){
      /* 置く石の色が黒の場合はあなたがプレイ */
      play(now);
      //com(now);
    } else if(now == white){
      /* 置く石の色が白の場合はCOMがプレイ */
      com(now);
    }

    /* 石を置いた後の盤を表示 */
    display();

    /* 次のターンに置く石の色を決定 */
    next = nextColor(now);
    if(next == now){
      /* 次も同じ色の石の場合 */
      printf("Skipping because there is no place to put it there.\n");
    } else if(next == empty){
      /* 両方の色の石が置けない場合 */
      printf("Game is over.\n");

      /* 結果表示して終了 */
      result();
      return 0;
    }

    /* 次のターンに置く石を設定 */
    now = next;
 
  }
  return 0;
}
