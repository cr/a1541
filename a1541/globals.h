#ifndef __GLOBALS_H
#define __GLOBALS_H

#include <Arduino.h>

/* Global defines and variables ************************************/

#define DATA_BUFFER_SIZE 512

extern uint8_t device_id;
extern uint8_t ext_device;
extern uint8_t cmd;
extern uint8_t subcmd;
extern uint8_t cmdlen;
extern uint8_t eoi;
extern uint8_t timeout;
extern uint8_t device_not_present;
//extern uint8_t last_byte;
//extern uint8_t listening ;
//extern uint8_t talking;

extern uint8_t data_buffer[];
extern uint16_t data_buffer_len;

extern void debug( void );

#endif // __GLOBALS_H
