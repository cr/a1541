#include "globals.h"
#include "arduino.h"
#include "serial.h"
#include "iec.h"
#include "c1541.h"

/* Defines and globals **********************************************/

enum {
  STATE_IDLE,
  STATE_SNIFF,
  STATE_LISTEN,
  STATE_LISTEN_IDLE,
  STATE_TALK,
  STATE_TALK_IDLE
};

uint8_t state = STATE_IDLE;

uint8_t hello_dir[64] = { 0x01, 0x04, 0x01, 0x01, 0x00, 0x00, 0x12, 0x22, 0x48, 0x45, 0x4c, 0x4c, 0x4f, 0x57, 0x4f, 0x52, 0x4c, 0x44, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x22, 0x20, 0x30, 0x31, 0x20, 0x32, 0x41, 0x00, 0x01, 0x01, 0x98, 0x02, 0x42, 0x4c, 0x4f, 0x43, 0x4b, 0x53, 0x20, 0x46, 0x52, 0x45, 0x45, 0x2e, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00 };

uint8_t hello_prg[17] = { 0x01, 0x08, 0x0e, 0x08, 0x00, 0x00, 0x99, 0x22, 0x48, 0x45, 0x4c, 0x4c, 0x4f, 0x22, 0x00, 0x00, 0x00 };


int atnCommandHandler() {

  // command handling
  switch( cmd & 0xe0 ) {
      
      case IEC_ATN_LISTEN: // LISTEN
      
        if( (cmd & 0x1f) == device_id ) { // ME
          switch( subcmd ) {
            case IEC_CMD_OPEN:
              state = STATE_LISTEN;
              break;
            default:
              state = STATE_IDLE;
              break;
          }
        } else if( (cmd & 0x1f) == 0x1f ) { // UNLISTEN
          state = STATE_IDLE;

        } else { // IGNORE
          switch( subcmd ) {
            case IEC_CMD_OPEN:
              state = STATE_SNIFF;
              break;
            default:
              state = STATE_IDLE;
              break;
          }
        }
        break;
        
      case IEC_ATN_TALK: // TALK
        if( (cmd & 0x1f) == device_id ) { // ME
          switch( subcmd ) {
            case IEC_CMD_DATA:
              state = STATE_TALK;
              break;
            default:
              state = STATE_IDLE;
              break;
          }
        } else if( (cmd & 0x1f) == 0x1f ) { // UNTALK
          state = STATE_IDLE;
        } else { // IGNORE
          switch( subcmd ) {
            case IEC_CMD_DATA:
              state = STATE_SNIFF;
              break;
            default:
              state = STATE_IDLE;
              break;
          }
        }
        break;
        
      default:
        state = STATE_IDLE;
        break;

  }

  return 0;
}


/* Setup *******************************************************/

void setup() {
  serialSetup();
  iecSetup();

  pinMode( DEBUG_OUT, OUTPUT );
  digitalWrite( DEBUG_OUT, HIGH );
  
}


/* main loop *****************************************************/

void loop() {
  int data;
  int i;
  
  while( true ) {
    switch( state ) {
  
      case STATE_IDLE:
        iecFreeChannel();
        if( iecAtnHandler() ) {
          atnCommandHandler();
        }
        if( state == STATE_IDLE ) serialHandleBuffers( 1 );
        break;
        
      case STATE_LISTEN:
        iecStartListening();
        iecRecvData();
        state = STATE_LISTEN_IDLE;
        break;

      case STATE_LISTEN_IDLE:
        iecFreeChannel();
        if( iecAtnHandler() ) {
          atnCommandHandler();
        }
        if( state == STATE_LISTEN_IDLE ) serialHandleBuffers( 1 );
        break;

      case STATE_TALK:
        iecTalkTurnaroundAck();
        iecStartTalking();
        iecSendData( hello_dir, 64 );
        state = STATE_TALK_IDLE;
        break;

      case STATE_TALK_IDLE:
        iecStartTalking();
        if( iecAtnHandler() ) {
          atnCommandHandler();
        }
        if( state == STATE_TALK_IDLE ) serialHandleBuffers( 1 );
        break;
              
      case STATE_SNIFF:
        iecFreeChannel();
        iecSniff();
        state = STATE_IDLE;
        break;
 
      default: // w00t!
        state = STATE_IDLE;
        break;
    }
  } 
}

