#include "serial.h"

/* Serial handler functions ********************************************************/

char ascii[16] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };

uint8_t serial_tx_buffer[256];
uint8_t serial_tx_buffer_head = 0;
uint8_t serial_tx_buffer_tail = 0;

uint8_t serial_rx_buffer[256];
uint8_t serial_rx_buffer_head = 0;
uint8_t serial_rx_buffer_tail = 0;


void serialSetup( void ) {
  Serial.begin( 115200 );
}

void serialTxByte( uint8_t c ) {
  serial_tx_buffer[serial_tx_buffer_head++] = c;
}

void serialTxHex( uint8_t c ) {
  serial_tx_buffer[serial_tx_buffer_head++] = ascii[c>>4];
  serial_tx_buffer[serial_tx_buffer_head++] = ascii[c&0xf];
}

void serialTxStr( char * str ) {
  while( *str != 0 ) serialTxByte( *(str++) );
}

uint8_t serialRxByte() {
  return serial_rx_buffer[serial_rx_buffer_tail++];
}

void serialHandleTxBuffer( int num ) {
  while( serial_tx_buffer_tail != serial_tx_buffer_head && num-- > 0 )
    Serial.write( serial_tx_buffer[serial_tx_buffer_tail++] );
}

void serialFlushTxBuffer() {
  while( serial_tx_buffer_tail != serial_tx_buffer_head )
    Serial.write( serial_tx_buffer[serial_tx_buffer_tail++] );
}

void serialHandleRxBuffer( int num ) {
  while( Serial.available() > 0 && num-- > 0 ) {
    serial_rx_buffer[serial_rx_buffer_head++] = Serial.read();
    // TODO: buffer overflow
  }
}

void serialHandleBuffers( int num ) {
  serialHandleRxBuffer( num );
  serialHandleTxBuffer( num );
}

