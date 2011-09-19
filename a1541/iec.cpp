#include "globals.h"
#include "arduino.h"
#include "serial.h"
#include "iec.h"

/* IEC Setup ****************************************************/

void iecSetup( void ) {

  pinMode( RESET_IN,  INPUT );
  pinMode( RESET_OUT, OUTPUT );
  digitalWrite( RESET_OUT, HIGH );

  pinMode( ATN_IN,    INPUT );
  pinMode( ATN_OUT,   OUTPUT );
  digitalWrite( ATN_OUT, HIGH );

  pinMode( CLOCK_IN,  INPUT );
  pinMode( CLOCK_OUT, OUTPUT );
  digitalWrite( CLOCK_OUT, HIGH );

  pinMode( DATA_IN,   INPUT );
  pinMode( DATA_OUT,  OUTPUT );
  digitalWrite( DATA_OUT, HIGH );
  
}

/* timing *******************************************************/

// Arduino 16MHz call time if event true: 14µS
// Arduino 16Mhz call time if timeout: timeout + 20µS
inline int iecWaitEvent( int pin, int target, int timeout ) {
  unsigned long int ref;
  if( digitalRead( pin ) == target ) return true;
  ref = micros();
  while( micros()-ref < timeout )
    if( digitalRead( pin ) == target )
      return true;
  return false;
}


/* Channel signalling *****************************************/

void iecFreeChannel() {
  digitalWrite( DATA_OUT, HIGH );  // Release DATA
  digitalWrite( CLOCK_OUT, HIGH ); // Release CLOCK
}

void iecStartListening() {
  digitalWrite( DATA_OUT, LOW );   // Pull DATA
  digitalWrite( CLOCK_OUT, HIGH ); // Release CLOCK
}

void iecStartTalking() {
  digitalWrite( CLOCK_OUT, LOW ); // Pull CLOCK
  digitalWrite( DATA_OUT, HIGH ); // Release DATA
}

int iecTalkTurnaroundAck() {
  if( !iecWaitEvent( CLOCK_IN, HIGH, IEC_T_TK_MAX ) ) { // Wait for TALK TURNAROUND
    timeout = true;
    //frame_error = true;
    serialTxByte( 'T' );
    serialTxByte( 'O' );
    serialTxByte( '1' );
    return -1;
  }
  //delayMicroseconds( IEC_T_DC_MIN ); // is zero
  digitalWrite( CLOCK_OUT, LOW ); // TALK TURNAROUND ACK
  delayMicroseconds( IEC_T_DA_MIN ); // Pull for at least IEC_T_DA
}



/* Bit bangers **************************************************/

inline void iecOutputDataByte( uint8_t c ) {
  uint8_t b;
  uint8_t value;
  for( b=0 ; b<8 ; b++ ) {
    value = c&1;
    c >>= 1;
    digitalWrite( CLOCK_OUT, LOW );
    digitalWrite( DATA_OUT, value );
    //delayMicroseconds( IEC_T_S_MIN); // Wait IEC_T_S for listener to get ready
    delayMicroseconds( IEC_T_S_TYP); // Wait longer for listener to get ready, else fail
    digitalWrite( CLOCK_OUT, HIGH );
    //delayMicroseconds( IEC_T_V_MIN ); // Wait IEC_T_V if not talking to c64
    delayMicroseconds( IEC_T_V_EXT_MIN ); // Wait IEC_T_V if talking to c64
  }
}

/* IEC SEND BYTE **********************************************************/
void iecSendByte( uint8_t data ) {

  digitalWrite( CLOCK_OUT, HIGH ); // Send TALKER READY TO SEND

  while( digitalRead( DATA_IN ) == LOW ); // Wait for LISTENER READY FOR DATA
//  if( !iecWaitEvent( DATA_IN, HIGH, 60000 ) ) { // Wait for LISTENER READY FOR DATA
//    timeout = true;
//    return -1;
//  }
  
  if( eoi ) { // EOI handshake
    if( !iecWaitEvent( DATA_IN, LOW, IEC_T_YE_TYP+2000 ) ) { // Wait IEC_T_YE for EOI handshake ACK
      timeout = true;
      serialTxByte( 'T' );
      serialTxByte( 'O' );
      serialTxByte( '2' );
      return;
    }
    serialHandleBuffers( 1 ); // We have T_EI_MIN=60uS time     
    while( digitalRead( DATA_IN ) == LOW ); // Wait for LISTENER READY FOR DATA
    //delayMicroseconds( IEC_T_RY_MIN );
  } else {
    serialHandleBuffers( 1 );
    //delayMicroseconds( IEC_T_NE_TYP ); // Should be 0-capable, but...
  }

  //digitalWrite( CLOCK_OUT, LOW ); // Talker sending (outputDataByte does that)
  iecOutputDataByte( data );

  digitalWrite( DATA_OUT, HIGH ); // Release DATA for LISTENER DATA ACCEPTED handshake
  digitalWrite( CLOCK_OUT, LOW );
  
  if( !iecWaitEvent( DATA_IN, LOW, IEC_T_F_MAX ) ) { // Wait for LISTENER DATA ACCEPTED
    timeout = true;
    //frame_error = true;
    serialTxByte( 'T' );
    serialTxByte( 'O' );
    serialTxByte( '3' );
    return;
  }
  
  return;

}

/* IEC SEND DATA **********************************************************/
void iecSendData( uint8_t *data, int len ) {
  int i;
  uint8_t d;

  eoi = false;

  serialTxByte( 'd' );

  for( i=0 ; i<len ; i++ ) {
    d = data[i];
    serialTxHex( d );
    serialTxByte( ' ' );
    if( i != len-1 ) {
      iecSendByte( d );
      serialHandleBuffers( 4 );
      delayMicroseconds( IEC_T_BB_MIN ); // We have lots of time to do stuff here
    } else {
      eoi = true;
      iecSendByte( d );
      serialHandleBuffers( 1 ); // We have time to do stuff here
      while( digitalRead( DATA_IN ) == LOW ); // Wait for Listener EOI ACK
    }
  }

  serialTxByte( 10 );
}



/* IEC INPUT DATA BYTE ***************************************************/
inline uint8_t iecInputDataByte() {
  uint8_t b;
  uint8_t value;
  while( digitalRead( CLOCK_IN ) == HIGH ); // TODO: timeout
  for( b=0, value=0 ; b<8 ; b++ ) {
    while( digitalRead( CLOCK_IN ) == LOW ); // TODO: timeout
    value |= (digitalRead( DATA_IN )) << b;
    while( digitalRead( CLOCK_IN ) == HIGH ); // TODO: timeout
  }
  return value;
}

/* IEC Receive Byte *****************************************************/
uint8_t iecRecvByte() {
  uint8_t data;

  if( !iecWaitEvent( CLOCK_IN, HIGH, 10000 ) ) { // Wait for TALKER READY TO SEND
    timeout = true;
    serialTxByte( 'T' );
    serialTxByte( 'O' );
    serialTxByte( '4' );
    return -1;
  }

  serialHandleBuffers( 4 ); // We have all the time we need

  digitalWrite( DATA_OUT, HIGH ); // Send LISTENER READY FOR DATA
  
  if( !iecWaitEvent( CLOCK_IN, LOW, IEC_T_YE_MIN ) ) { // Wait for TALKER SENDING or EOI timeout
    eoi = true;
    digitalWrite( DATA_OUT, LOW ); // Ack EOI with handshake
    //delayMicroseconds( IEC_T_EI_MIN ); // IEC_T_EI_MIN if talking to external devices
    delayMicroseconds( IEC_T_EI_EXT_MIN ); // longer IEC_T_EI_MIN if talking to c64
    digitalWrite( DATA_OUT, HIGH );
    // TODO: Different talker response IEC_T_RY timeout after EOI
  }

  data = iecInputDataByte();

  delayMicroseconds( IEC_T_F_TYP ); // Wait IEC_T_F (may be 0 for speed)
  serialHandleBuffers( 4 ); // We have up to 1000uS time for stuff

  digitalWrite( DATA_OUT, LOW ); // Send LISTENER DATA ACCEPTED
  
  if( eoi ) { // Send EOI acknowledge
    delayMicroseconds( IEC_T_FR_MIN ); // Hold DATA low for IEC_T_FR_MIN
    serialHandleBuffers( 4 ); // We potentially have lot of time for stuff    
    digitalWrite( DATA_OUT, HIGH ); // EOI ACK
  }

  return data;

}

/* IEC Data packet functions *********************************************/
int iecRecvData() {
  int data;
  data_buffer_len = 0;
  eoi = false;

  serialTxByte( 'd' );

  while( !eoi ) {
    data = iecRecvByte(); // sets global eoi
    if( data != -1 && data_buffer_len < DATA_BUFFER_SIZE-2 ) {
      data_buffer[data_buffer_len++] = data;
      serialTxHex( data );
      serialTxByte( ' ' );
    }
  }
  data_buffer[data_buffer_len] = 0; // mind the off-by-one
  //eoi = false;
  serialTxByte( 10 );
  return data_buffer_len;
}


/* iecSniff() ************************************************************/
int iecSniff() {
  uint8_t data;
  
  data_buffer_len = 0;

  //while( digitalRead( CLOCK_IN ) == HIGH );
  serialTxByte( 'd' );


  eoi = false;
  while( !eoi ) {

    while( digitalRead( CLOCK_IN ) == LOW );
    while( digitalRead( DATA_IN ) == LOW );

    if( !iecWaitEvent( CLOCK_IN, LOW, 256 ) ) {
      eoi = true;
      if( !iecWaitEvent( CLOCK_IN, LOW, 1000 ) && digitalRead( DATA_IN ) == HIGH ) { // FILE NOT FOUND
        data_buffer_len = 0;
        serialTxStr( "ERR\n" );
        return -1;
      }
    }
    data = iecInputDataByte();
    data_buffer[data_buffer_len++] = data; // TODO: buffer overflow
    serialTxHex( data );
    serialTxByte( ' ' );

    // CAVE: this might be timing-critical    
    serialHandleBuffers( 4 );

  }
  data_buffer[data_buffer_len] = 0; // mind off-by-one
  serialTxByte( 10 );
  return data_buffer_len;
}


/* ATN handler ***********************************************/

int iecAtnCheck() {
  return digitalRead( ATN_IN ) == LOW;
}

int iecAtnHandler() {
  if( digitalRead( ATN_IN ) == LOW ) {

    iecStartListening();
    serialTxByte( 'd' );
    serialTxByte( 'A' );
    while( digitalRead( CLOCK_IN ) == LOW ); // TODO: timeout
    iecFreeChannel();
    //while( digitalRead( CLOCK_IN ) == HIGH ); // TODO: timeout
    cmd = iecInputDataByte();
    cmdlen = 1;

    // CAVE: takes loooong
    //Serial.print( cmd, HEX );
    serialTxHex( cmd );

    delayMicroseconds( 50 );
    digitalWrite( DATA_OUT, LOW ); // DATA ACK
    delayMicroseconds( 20 ); // keep low for IEC_T_R=20uS

    // If ATN stays low, a subcommand is coming
    while( digitalRead( CLOCK_IN ) == LOW
        && digitalRead( ATN_IN ) == LOW ); // TODO: timeout

    if( digitalRead( ATN_IN ) == LOW ) { // get subcommand byte
      digitalWrite( DATA_OUT, HIGH ); // READY FOR DATA
      while( digitalRead( CLOCK_IN ) == HIGH ); // TODO: timeout
      subcmd = iecInputDataByte();
      cmdlen = 2;
      
      // CAVE: might be time-critical
      serialTxHex( subcmd );

      delayMicroseconds( 10 );
      digitalWrite( DATA_OUT, LOW ); // DATA ACK
      delayMicroseconds( 20 ); // keep low for IEC_T_R=20uS

    } else {
      subcmd = 0;
    }

    serialTxByte( 10 );
    
    while( digitalRead( ATN_IN ) == LOW ); // TODO: timeout
    return true;

  } else {

    return false;
  }
}

