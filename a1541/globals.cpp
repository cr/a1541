#include "arduino.h"
#include "globals.h"

uint8_t device_id = 9;
uint8_t ext_device = true;
uint8_t cmd = 0;
uint8_t subcmd = 0;
uint8_t cmdlen = 0;
uint8_t eoi = false;
uint8_t timeout = false;
uint8_t device_not_present = false;
uint8_t last_byte = false;
//uint8_t listening = false;
//uint8_t talking = false;
uint8_t data_buffer[DATA_BUFFER_SIZE];
uint16_t data_buffer_len = 0;

void debug() {
  digitalWrite( DEBUG_OUT, LOW );
  delayMicroseconds( 10 );
  digitalWrite( DEBUG_OUT, HIGH );
}

