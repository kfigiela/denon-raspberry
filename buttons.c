#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <wiringPi.h>
#include <linux/i2c-dev.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdio.h>

int i2c;
int i2c2;
const char * i2c_filename = "/dev/i2c-1";
#define INTERRUPT_PIN 2
#define I2C_SLAVE_ADDR 0x38

void die(char*arg) {
  printf(arg);
  exit(1);
}

int read_encoder();

void interrupt_handler(void) {
  static uint8_t previous = 0xff;
  static uint8_t previous2 = 0xff;
  uint8_t current;
  uint8_t current2;

  if (read(i2c,&current,1) != 1) {
    printf("Failed to read from the i2c bus.\n");
    return;
  }

  if (read(i2c2,&current2,1) != 1) {
    printf("Failed to read from the i2c bus.\n");
    return;
  }

  printf("%2x %2x\n", current, current2);

  if(current&0x01 && !(previous&0x01)) {
    printf("counter clockwise\n");
  system("mpc prev");
  }
  if(current&0x02&& !(previous&0x02)) {
    printf("clockwise\n");
    system("mpc next");
  }
  if(current&0x04&& !(previous&0x04)) {
    printf("counter clockwise 2\n");
    system("mpc_album prev");
  }
  if(current&0x08 && !(previous&0x08)) {
    printf("clockwise 2\n");
    system("mpc_album next");
  }

	////////////

	if(current&0x10 && !(previous&0x10)) {
    printf("halt\n");
    system("i2cset -y 1 0x39 0xaf; sudo halt");
  }

	///////////

	if(current2&0x80 && !(previous2&0x80)) {
    printf("2 1\n");
    system("mpc toggle");
  }
	if(current2&0x01 && !(previous2&0x01)) {
    printf("2 2\n");
    system("mpc toggle");
  }
  if(current2&0x02 && !(previous2&0x02)) {
    printf("2 3\n");
    system("bash -c 'echo -n source:internet_radio > /dev/udp/10.0.42.42/8080'");
  }
  if(current2&0x04 && !(previous2&0x04)) {
    printf("2 4\n");
    system("bash -c 'echo -n source:online_music > /dev/udp/10.0.42.42/8080'");
  }
  if(current2&0x08 && !(previous2&0x08)) {
    printf("2 5\n");
    system("bash -c 'echo -n denon:display_brightness! > /dev/udp/10.0.42.42/8080'");
  }


  previous  = current;
  previous2 = current2;
}

/* returns change in encoder state (-1,0,1) */
/*
int read_encoder()
{
  static int enc_states[] = {0,-1,1,0,1,0,0,-1,-1,0,0,1,0,1,-1,0};
  static unsigned int old_AB = 0;
  int value = (digitalRead(101) << 1 | digitalRead(102));

  old_AB <<= 2;                   //remember previous state
  old_AB |= ( value & 0x03 );  //add current state
  return ( enc_states[( old_AB & 0x0f )]);
}*/


int main (void)
{
  if ((i2c = open(i2c_filename, O_RDWR)) < 0) {
    perror("Failed to open the i2c bus");
    return 1;
  }

  if (ioctl(i2c, I2C_SLAVE, I2C_SLAVE_ADDR) < 0) {
      perror("Failed to acquire bus access and/or talk to slave.\n");
      return 1;
  }

  if ((i2c2 = open(i2c_filename, O_RDWR)) < 0) {
    perror("Failed to open the i2c bus");
    return 1;
  }

  if (ioctl(i2c2, I2C_SLAVE, I2C_SLAVE_ADDR + 1) < 0) {
      perror("Failed to acquire bus access and/or talk to slave.\n");
      return 1;
  }

	uint8_t val = 0xff;

  if (write(i2c,&val,1) != 1) {
    printf("Failed to write to the i2c bus.\n");
    return;
  }

  if (write(i2c2,&val,1) != 1) {
    printf("Failed to write to the i2c bus.\n");
    return;
  }

  // Setup interrupt handler
  wiringPiSetup();
  pinMode(INTERRUPT_PIN, INPUT);
  pullUpDnControl (INTERRUPT_PIN, PUD_UP);
  wiringPiISR(INTERRUPT_PIN, INT_EDGE_FALLING, interrupt_handler);

  while(1) sleep(100000);

  // Will never happen...

  return 0;
}
