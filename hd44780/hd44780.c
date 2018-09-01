
#include <unistd.h>
#include <string.h>
#include <wiringPiI2C.h>
#include <time.h>
#include <ruby.h>


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

#define DELAY_STROBE_1 50
#define DELAY_STROBE_2 50
#define DELAY_WRITE_COMMAND 200

#define DELAY_INIT 35000
#define DELAY_INIT_SHORT 50000

typedef int bool;
enum { false, true };

int fd;
bool backlight = true;
char backlight_mask = LCD_BACKLIGHT;

// clocks EN to latch command
void strobe(char data) {
  wiringPiI2CWrite(fd, (data & ~En) | backlight_mask);
  usleep(DELAY_STROBE_1);
  wiringPiI2CWrite(fd, data | En | backlight_mask);
  usleep(DELAY_STROBE_2);
  wiringPiI2CWrite(fd, ((data & ~En) | backlight_mask));
  usleep(DELAY_STROBE_1);
}

void write_four_bits(char data) {
  strobe(data);
}

void write_command(char cmd) {
  write_four_bits(0 | (cmd & 0xF0));
  write_four_bits(0 | ((cmd << 4) & 0xF0));
  usleep(DELAY_WRITE_COMMAND);
}
void write_data(char cmd) {
  write_four_bits(Rs | (cmd & 0xF0));
  write_four_bits(Rs | ((cmd << 4) & 0xF0));
  usleep(DELAY_WRITE_COMMAND);
}


void init() {
  wiringPiI2CWrite(fd, 0);
  usleep(50000);
  wiringPiI2CWrite(fd, (0 | backlight_mask));

  strobe(0x03);
  usleep(DELAY_INIT);

  strobe(0x03);
  usleep(DELAY_INIT);

  strobe(0x03);
  usleep(DELAY_INIT);

  strobe(0x03);
  usleep(DELAY_INIT);

  strobe(0x02);
  usleep(DELAY_INIT_SHORT);

  write_command(LCD_FUNCTIONSET | LCD_2LINE | LCD_5x8DOTS | LCD_4BITMODE);
  usleep(DELAY_INIT_SHORT);

  write_command(LCD_DISPLAYCONTROL);
  usleep(DELAY_INIT_SHORT);

  write_command(LCD_CLEARDISPLAY);
  usleep(DELAY_INIT);

  write_command(LCD_CLEARDISPLAY);
  usleep(DELAY_INIT);

  write_command(LCD_ENTRYMODESET | LCD_ENTRYLEFT);
  usleep(DELAY_INIT_SHORT);

  write_command(LCD_DISPLAYCONTROL | LCD_DISPLAYON | LCD_CURSORON | LCD_BLINKON);
  usleep(DELAY_INIT_SHORT);
}

void set_backlight(bool value) {
	backlight = value;
	backlight_mask = backlight ? LCD_BACKLIGHT : LCD_NOBACKLIGHT;
  write_command(0x80);
}



void print2(char * str, size_t len, int line) {
	int i;
	static const int addr[] = {0x80, 0xC0, 0x94, 0xD4};
	write_command(addr[line]);
	for(i = 0; i < 16 && i < len; ++i, *str++) {
		write_data(*str);
	}
}

void print(char * str, int line) {
	print2(str, strlen(str), line);
}

VALUE rb_init(VALUE self) {
	init();
	print("Hello!",0);
	return Qnil;
}

VALUE rb_print(VALUE self, VALUE str, VALUE line) {
	Check_Type(line, T_FIXNUM);
	StringValue(str);
	print2(RSTRING_PTR(str), RSTRING_LEN(str), FIX2INT(line));
}

VALUE rb_backlight_get(VALUE self) {
	return backlight ? Qtrue : Qfalse;
}

VALUE rb_backlight_set(VALUE self, VALUE val) {
	set_backlight(val == Qtrue);
	return rb_backlight_get(self);
}

VALUE rb_set_udc(VALUE self, VALUE idx, VALUE val) {
	size_t i;
	VALUE ary = rb_ary_to_ary(val);
	Check_Type(idx, T_FIXNUM);
	if(RARRAY_LEN(val) != 8) {
	  rb_raise(rb_eArgError, "Need to provide array of 8 FixNums");
		return Qnil;
	}

	write_command(0x40 + ((FIX2INT(idx) & 0x07) << 3));
	for(i = 0; i < 8; ++i) {
		VALUE el = rb_ary_entry(ary, i);
		Check_Type(el, T_FIXNUM);
		write_data(FIX2INT(el));
	}
	return Qnil;
}

void Init_hd44780() {
  VALUE HD44780 = rb_define_module("HD44780");
	fd = wiringPiI2CSetup(I2C_ADDRESS);
  rb_define_singleton_method(HD44780, "init", rb_init, 0);
  rb_define_singleton_method(HD44780, "puts", rb_print, 2);
  rb_define_singleton_method(HD44780, "set_udc", rb_set_udc, 2);
  rb_define_singleton_method(HD44780, "backlight=", rb_backlight_set, 1);
  rb_define_singleton_method(HD44780, "backlight", rb_backlight_get, 0);
}
