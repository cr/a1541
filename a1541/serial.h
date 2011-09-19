#ifndef __SERIAL_H
#define __SERIAL_H

#include <Arduino.h>

void serialSetup( void );
void serialTxByte( uint8_t c );
void serialTxHex( uint8_t c );
void serialTxStr( char * str );
uint8_t serialRxByte();
void serialHandleRxBuffer( int num );
void serialHandleTxBuffer( int num );
void serialHandleBuffers( int num );
void serialFlushBuffer( void );

#endif // __SERIAL_H
