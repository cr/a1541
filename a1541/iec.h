#ifndef __IEC_H
#define __IEC_H

#include <Arduino.h>

//ATN RESPONSE
//If maximum time exceeded, device not present error
#define IEC_T_AT_MIN -
#define IEC_T_AT_TYP -
#define IEC_T_AT_MAX 1000

//LISTENER HOLD-OFF
#define IEC_T_H_MIN 0
#define IEC_T_H_TYP -
#define IEC_T_H_MAX inf  

//NON-EOI RESPONSE TO RFD
//If maximum time exceeded, EOI response required.
#define IEC_T_NE_MIN -
#define IEC_T_NE_TYP 40
#define IEC_T_NE_MAX 200  

//BIT SET-UP TALKER
#define IEC_T_S_MIN 20
#define IEC_T_S_TYP 70
#define IEC_T_S_MAX -  

//DATA VALID
//IEC_T_V_MIN and IEC_T_PR_MIN must be 60µs for external device to be a talker.
#define IEC_T_V_MIN 20
#define IEC_T_V_EXT_MIN 60
#define IEC_T_V_TYP 20
#define IEC_T_V_MAX -

//FRAME HANDSHAKE
//If maximum time exceeded, frame error.
#define IEC_T_F_MIN 0
#define IEC_T_F_TYP 20
#define IEC_T_F_MAX 1000

//FRAME TO RELEASE OF ATN
#define IEC_T_R_MIN 20 
#define IEC_T_R_TYP -
#define IEC_T_R_MAX -

//BETWEEN BYTES TIME
#define IEC_T_BB_MIN 100
#define IEC_T_BB_TYP -
#define IEC_T_BB_MAX -

//EOI RESPONSE TIME
#define IEC_T_YE_MIN 200
#define IEC_T_YE_TYP 250
#define IEC_T_YE_MAX -  

//EOI RESPONSE HOLD TIME
//TEI minimum must be 80µs for external device to be a listener.
#define IEC_T_EI_MIN 60
#define IEC_T_EI_EXT_MIN 80
#define IEC_T_EI_TYP -
#define IEC_T_EI_MAX -

//TALKER RESPONSE LIMIT
#define IEC_T_RY_MIN 0
#define IEC_T_RY_TYP 30
#define IEC_T_RY_MAX 60  

//BYTE-ACKNOWLEDGE
//IEC_T_V_MIN and IEC_T_PR_MIN must be 60µs for external device to be a talker.
#define IEC_T_PR_MIN 20
#define IEC_T_PR_EXT_MIN 60
#define IEC_T_PR_TYP 30
#define IEC_T_PR_MAX -

//TALK-ATTENTION RELEASE
#define IEC_T_TK_MIN 20
#define IEC_T_TK_TYP 30
#define IEC_T_TK_MAX 100 

//TALK-ATTENTION ACKNOWLEDGE
#define IEC_T_DC_MIN 0
#define IEC_T_DC_TYP -
#define IEC_T_DC_MAX - 

//TALK-ATTENTION ACK. HOLD
#define IEC_T_DA_MIN 80
#define IEC_T_DA_TYP -
#define IEC_T_DA_MAX -  

//EOI ACKNOWLEDGE
#define IEC_T_FR_MIN 60
#define IEC_T_FR_TYP -
#define IEC_T_FR_MAX -

// IEC command codes
enum {
  IEC_CMD_DATA  = 0x60,   // Data transfer
  IEC_CMD_CLOSE = 0xe0,   // Close channel
  IEC_CMD_OPEN  = 0xf0    // Open channel
};

// IEC ATN codes
enum {
  IEC_ATN_LISTEN   = 0x20,
  //ATN_UNLISTEN = 0x30,
  IEC_ATN_TALK     = 0x40,
  //ATN_UNTALK   = 0x50
};


/* Prototypes **********************************************************/

void     iecSetup( void );
void     iecFreeChannel( void );
void     iecStartListening( void );
void     iecStartTalking( void );
int      iecTalkTurnaroundAck( void );
int      iecSniff( void );
int      iecAtnHandler( void );
int      iecRecvData( void );
void     iecSendData( uint8_t *data, int len );

#endif // __IEC_H
