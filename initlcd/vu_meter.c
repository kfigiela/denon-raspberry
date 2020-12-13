#include <math.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <wiringPiI2C.h>
#include <time.h>

// commands
#define LCD_CLEARDISPLAY  0x01
#define LCD_RETURNHOME  0x02
#define LCD_ENTRYMODESET  0x04
#define LCD_DISPLAYCONTROL  0x08
#define LCD_CURSORSHIFT  0x10
#define LCD_FUNCTIONSET  0x20
#define LCD_SETCGRAMADDR  0x40
#define LCD_SETDDRAMADDR  0x80

// flags for display entry mode
#define LCD_ENTRYRIGHT  0x00
#define LCD_ENTRYLEFT  0x02
#define LCD_ENTRYSHIFTINCREMENT  0x01
#define LCD_ENTRYSHIFTDECREMENT  0x00

// flags for display on/off control
#define LCD_DISPLAYON  0x04
#define LCD_DISPLAYOFF  0x00
#define LCD_CURSORON  0x02
#define LCD_CURSOROFF  0x00
#define LCD_BLINKON  0x01
#define LCD_BLINKOFF  0x00

// flags for display/cursor shift
#define LCD_DISPLAYMOVE  0x08
#define LCD_CURSORMOVE  0x00
#define LCD_MOVERIGHT  0x04
#define LCD_MOVELEFT  0x00

// flags for function set
#define LCD_8BITMODE  0x10
#define LCD_4BITMODE  0x00
#define LCD_2LINE  0x08
#define LCD_1LINE  0x00
#define LCD_5x10DOTS  0x04
#define LCD_5x8DOTS  0x00

// flags for backlight control
#define LCD_BACKLIGHT  0x08
#define LCD_NOBACKLIGHT  0x00

#define En  0b00000100 // Enable bit
#define Rw  0b00000010 // Read/Write bit
#define Rs  0b00000001 // Register select bit

#define I2C_ADDRESS 0x27

typedef int bool;
enum { false, true };

int fd;
bool backlight = true;
char backlight_mask = LCD_BACKLIGHT;

// clocks EN to latch command
void strobe(char data) {
  wiringPiI2CWrite(fd, (data & ~En) | backlight_mask);
  usleep(10);
  wiringPiI2CWrite(fd, data | En | backlight_mask);
  usleep(1);
  wiringPiI2CWrite(fd, ((data & ~En) | backlight_mask));
  usleep(10);
}


void write_four_bits(char data) {
  strobe(data);
}

void write_command(char cmd) {
  write_four_bits(0 | (cmd & 0xF0));
  write_four_bits(0 | ((cmd << 4) & 0xF0));
  usleep(40);
}
void write_data(char cmd) {
  write_four_bits(Rs | (cmd & 0xF0));
  write_four_bits(Rs | ((cmd << 4) & 0xF0));
  usleep(40);
}


void init() {
  wiringPiI2CWrite(fd, 0);
  usleep(50000);
  wiringPiI2CWrite(fd, (0 | backlight_mask));

  strobe(0x03);
  usleep(5000);

  strobe(0x03);
  usleep(5000);

  strobe(0x03);
  usleep(5000);

  strobe(0x02);
  usleep(200);

  write_command(LCD_FUNCTIONSET | LCD_2LINE | LCD_5x8DOTS | LCD_4BITMODE);
  usleep(200);

  write_command(LCD_DISPLAYCONTROL);
  usleep(200);

  write_command(LCD_CLEARDISPLAY);
  usleep(5000);

  write_command(LCD_CLEARDISPLAY);
  usleep(5000);

  write_command(LCD_ENTRYMODESET | LCD_ENTRYLEFT);
  usleep(200);

  write_command(LCD_DISPLAYCONTROL | LCD_DISPLAYON | LCD_CURSORON | LCD_BLINKON);
  usleep(200);

}


void set_backlight(bool value) {
  backlight = value;
  backlight_mask = backlight ? LCD_BACKLIGHT : LCD_NOBACKLIGHT;
  write_command(0x80);
}

void printLCD(char * str, int line) {
  int i;
  static const int addr[] = {0x80, 0xC0, 0x94, 0xD4};
  write_command(addr[line]);
  for(i = 0; i < 16 && *str; ++i, *str++) {
    write_data(*str);
  }
}

bool run = true;

#define SAMPLES 4410

short buf[2*SAMPLES];


// unsigned int log2( unsigned int x )
// {
//   unsigned int ans = 0 ;
//   while( x>>=1 ) ans++;
//   return ans ;
// }

void bar(float level, int row) {
       if(level < -17) printLCD("|               ", row) ;
  else if(level < -16) printLCD("##              ", row) ;
  else if(level < -15) printLCD("###             ", row) ;
  else if(level < -14) printLCD("####            ", row) ;
  else if(level < -13) printLCD("#####           ", row) ;
  else if(level < -12) printLCD("######          ", row) ;
  else if(level < -11) printLCD("#######         ", row) ;
  else if(level < -10) printLCD("########        ", row) ;
  else if(level < -9) printLCD("#########       ", row) ;
  else if(level < -8) printLCD("##########      ", row) ;
  else if(level < -7) printLCD("###########     ", row);
  else if(level < -6) printLCD("############    ", row);
  else if(level < -4) printLCD("#############   ", row);
  else if(level < -3) printLCD("##############  ", row);
  else if(level < -2) printLCD("############### ", row);
  else if(level < -1) printLCD("################", row);
}

void update_display(FILE * file) {

  short maxL, maxR, i, levelL, levelR;
  maxL = maxR = 0;
  if(fread(buf, sizeof(short), 2*SAMPLES, file) > 0) {
    for(i = 0; i < SAMPLES; ++i) {
      maxL = abs(buf[2*i  ]) > maxL ? abs(buf[2*i  ]) : maxL;
      maxR = abs(buf[2*i+1]) > maxR ? abs(buf[2*i+1]) : maxR;
    }
    levelL = 20*log10(maxL/32767.);
    levelR = 20*log10(maxR/32767.);
    // printf("%d %d %d %d\n", maxL, maxR, levelL, levelR);
    bar(levelL, 0);
    bar(levelR, 1);
  }
}

void handle_sigint(int signal) {
    run = false;
}

int main(int argc, char** argv) {
  fd = wiringPiI2CSetup(I2C_ADDRESS);

  FILE * file;
  file = stdin;
  // file = fopen("/tmp/mpd.fifo", "rb");
  // signal(SIGINT, handle_sigint);

  // if (!file) {
  //   printf("error: can't open fifo");
  //   return 1;
  // }

  while(run) {
    update_display(file);
  }

  fclose(file);

  printf("Done\n");
}
