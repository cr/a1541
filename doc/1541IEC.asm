; --------------------------------------------------------------------
; Serielle Kommunikation auf dem C64 IEC Bus
; --------------------------------------------------------------------
.DEVICE AT90S8535
.LIST

.EQU SREG      = $3F     ; Statusregister
.EQU SPH       = $3E     ; Stack Pointer High
.EQU SPL       = $3D     ; Stack Pointer Low

.EQU PORTA     = $1B     ; Data Register, Port A
.EQU DDRA      = $1A     ; Data Direction Register, Port A
.EQU PINA      = $19     ; Input Pins, Port A

.EQU PORTB     = $18     ; Data Register, Port B
.EQU DDRB      = $17     ; Data Direction Register, Port B
.EQU PINB      = $16     ; Input Pins, Port B

.EQU PORTC     = $15     ; PORT C Datenregister
.EQU DDRC      = $14     ; PORT C Richtungsregister
.EQU PINC      = $13     ; PORT C Datenregister
; --------------------------------------------------------------------
; UART
; --------------------------------------------------------------------
.EQU UDR       = $0C     ; UART DATA     REGISTER
.EQU USR       = $0B     ; UART STATUS   REGISTER
.EQU UCR       = $0A     ; UART CONTROL  REGISTER
.EQU UBRR      = $09     ; UART BAUDRATE REGISTER

.EQU CLOCK     = 3690000 ;clock frequency
.EQU BAUDRATE  =  115200 ;choose a baudrate
.EQU BAUDCONST = (CLOCK/(16*BAUDRATE))-1

; --------------------------------------------------------------------
; USR
; --------------------------------------------------------------------
.EQU RXC       = 7
.EQU TXC       = 6
.EQU UDRE      = 5

; --------------------------------------------------------------------
;RXCIE
; --------------------------------------------------------------------
.EQU RXCIE     = 7
.EQU TXCIE     = 6
.EQU UDRIE     = 5
.EQU RXEN      = 4
.EQU TXEN      = 3
.EQU CHR9      = 2
.EQU RXB8      = 1
.EQU TXB8      = 0

; --------------------------------------------------------------------
; PORTB
; --------------------------------------------------------------------
.EQU DATA_OUT = 0x01  ; PA0
.EQU DATA_IN  = 0x02  ; PA1 
.EQU CLK_OUT  = 0x04  ; PA2
.EQU CLK_IN   = 0x08  ; PA3
.EQU ATN_OUT  = 0x10  ; PA4
.EQU ATN_IN   = 0x20  ; PA5
.EQU RST_OUT  = 0x40  ; PA6
.EQU RST_IN   = 0x80  ; PA7

; --------------------------------------------------------------------
; IN = 0    OUT = 1
; --------------------------------------------------------------------
.EQU PORT_MASK = 0b01010101

.DEF XL = R26
.DEF XH = R27
.DEF YL = R28
.DEF YH = R29
.DEF ZL = R30
.DEF ZH = R31

; --------------------------------------------------------------------
; EEPROM Segment
; --------------------------------------------------------------------
.ESEG
.ORG 0x00




; --------------------------------------------------------------------
; Data Segment
; --------------------------------------------------------------------
.DSEG
 
 DEVICE_NR: .BYTE 1
 SEK_ADR:   .BYTE 1
 FILE_NR:   .BYTE 1
 OUTBYTE:   .BYTE 1
 STATUS:    .BYTE 1
 WAIT_VAL:  .BYTE 1
 BIT_CNT:   .BYTE 1
 LAST_BYTE: .BYTE 1
 SADR_LO:   .BYTE 1
 SADR_HI:   .BYTE 1
 CMD_TYPE:  .BYTE 1
 CMD_LEN:   .BYTE 1
 CHECKSUM:  .BYTE 1
 TRACKS:    .BYTE 1 
 SECTORS:   .BYTE 1 
 COMMAND:   .BYTE 50
  
; --------------------------------------------------------------------
; Code Segment
; --------------------------------------------------------------------
.CSEG                         ; Interrupt Vectors:
.ORG $000    
             RJMP RESET       ; RESET
             RETI             ; INT0
             RETI             ; INT1
             RETI             ; Timer/Counter 2 Compare Match
             RETI             ; Timer/Counter 2 Overflow
             RETI             ; Timer/Counter 1 Capture Event 
             RETI             ; Timer/Counter 1 Capture Compare Match A
             RETI             ; Timer/Counter 1 Capture Compare Match B
             RETI             ; Timer/Counter 1 Overflow
             RETI             ; Timer/Counter 0 Overflow
             RETI             ; SPI Serial Transfer Complete
             RETI             ; UART: Rx Complete
             RETI             ; UART: Data Register Empty
             RETI             ; UART: Tx Complete
             RETI             ; ADC Conversion Complete
             RETI             ; EEPROM Ready
             RETI             ; Analog Comparator

; -------------------------------------------------------------------
; Initialisierung des Stacks auf 025F ( Ende des SRAMS). Muss
; gemacht werden, da sonst der Stackpointer auf 0x000 zeigt und
; keine Unterprogrammaufrufe möglich wären.
; -------------------------------------------------------------------
RESET:       LDI   R30,LOW(0x25F)    ;
             OUT   SPL,R30           ;
             LDI   R30,HIGH(0x25F)   ;
             OUT   SPH,R30           ;
             RCALL INIT_UART         ;

INIT_PORT:   LDI   R30, PORT_MASK    ; Datenrichtungsregister initialisieren
             OUT   DDRA,R30          ; 
             LDI   R30, 0b00110101   ; Alle Ausgänge HI Alle Pullups OFF
             OUT   PORTA,R30         ;
             LDI   R30, 0b11111111   ; LEDs auf Ausgang
             OUT   DDRC,R30          ;
             LDI   R30, 0b11111111   ; Alle Aus
             OUT   PORTC,R30         ;
             RCALL RST               ; RESET 1541
             RJMP  INSTR_LOOP        ; Wait for Instructions from PC 

INSTR_LOOP:  RCALL GET_COMMAND       ;  
             RCALL DO_COMMAND        ;
             RJMP  INSTR_LOOP        ;

TEST_LOOP:   LDI   R30, 0b11111111   ; Alle Aus
TL1:         OUT   PORTC,R30         ;
             RCALL WAIT_765          ;
             INC   R30               ;
             RJMP     TL1            ;
STOP:        RJMP  STOP              ; 

; -------------------------------------------------------------------------
; DoCommand: Befehl ausführen
; -------------------------------------------------------------------------
 DO_COMMAND: LDS  R30,CMD_TYPE        ;
             CPI  R30,0x00            ; 0 = LOAD
             BREQ DC0                 ;
             RJMP DC1                 ;
        DC0: RJMP CMD_LOAD            ; 
        DC1: CPI  R30,0x01            ; 1 = OPEN 15,8,15
             BRNE DC2                 ;
             RJMP CMD_OPEN            ;
        DC2: CPI  R30,0x02            ; 2 = DRIVE STATUS
             BRNE DC3                 ;
             RJMP CMD_STATUS          ; 
        DC3: CPI  R30,0x03            ; 3 = OPEN
             BRNE DC4                 ;
             RJMP CMD_IECOPEN         ; 
        DC4: CPI  R30,0x04            ; 4 = SEND
             BRNE DC5                 ;
             RJMP CMD_IECSEND         ; 
        DC5: CPI  R30,0x05            ; 5 = MEMORY READ
             BRNE DC6                 ;
             RJMP CMD_MR              ; 
        DC6: CPI  R30,0x06            ; 6 = CLOSE
             BRNE DC7                 ;
             RJMP CMD_CLOSE           ;
        DC7: CPI  R30,0x07            ; 7 = READ DISK
             BRNE DC8                 ;
             RJMP CMD_READ_DISK       ;
        DC8: CPI  R30,0x08            ; 8 = BURST 
             BRNE DC9                 ;
             RJMP CMD_BURST           ;
        DC9: CPI  R30,0x09            ; 9 = MEMORY EXECUTE
             BRNE DC10                ;
             RJMP CMD_MEMEXEC         ;
       DC10:                          ;
             LDI  R30, 0b11001100     ; unknown command
             OUT  PORTC,R30           ;
             RJMP STOP;
             RET

; -------------------------------------------------------------------
; COMMAND OPEN
; -------------------------------------------------------------------
 CMD_READ_DISK:
             LDI   R30, 0b10100101    ; 
             OUT   PORTC,R30          ;
             LDI   XL,LOW(COMMAND)    ; Befehlsanfang
             LDI   XH,HIGH(COMMAND)   ; 
             LD    R30, X             ; 1. Byte = FileNr
             INC   R30                ;
             STS   TRACKS,R30         ;
             LDI   R24, 1             ; Track  Nummer
             LDI   R25, 0             ; Sektor Nummer
             ; -------------------------------------------------------
             LDI   R30, 0             ; Open 15,8,15,""
             STS   CMD_LEN, R30       ; 
             RCALL OPEN15815          ;
             LDI   R30, 2             ; Open 2,8,2,"#"
             STS   CMD_LEN, R30       ; 
             LDI   XL,LOW(COMMAND)    ; Befehlsanfang
             LDI   XH,HIGH(COMMAND)   ; 
             LDI   R30, 35            ; #
             ST    X+, R30            ;
             LDI   R30, 48            ; 0
             ST    X+, R30            ;
             LDI   R30, 0x02          ; 
             STS   FILE_NR,R30        ;
             LDI   R30, 0x08          ; 
             STS   DEVICE_NR,R30      ; 
             LDI   R30, 0x02          ; 
             ORI   R30, 0x60          ;
             STS   SEK_ADR,R30        ; 
             RCALL IEC_OPEN           ; (F3D5 im C64 Kernel)
             ; -------------------------------------------------------
        RD0: CPI   R24, 31           ; Tracknummer >= 31 ?
             BRLO  RD1               ; 
             LDI   R30, 17           ; JA->17 Sektoren
             STS   SECTORS, R30      ;
             RJMP  RD4               ;
        RD1: CPI   R24, 25           ; Tracknummer >= 25 ?
             BRLO  RD2               ; 
             LDI   R30, 18           ; JA->18 Sektoren
             STS   SECTORS, R30      ;
             RJMP  RD4               ;
        RD2: CPI   R24, 18           ; Tracknummer >= 18 ?
             BRLO  RD3               ; 
             LDI   R30, 19           ; JA->19 Sektoren
             STS   SECTORS, R30      ;
             RJMP  RD4               ;
        RD3: LDI   R30, 21           ; Tracknummer < 18=> 21 Sektoren
             STS   SECTORS, R30      ;
        RD4: LDS   R30, SECTORS      ; LEDs auf Ausgang
             ; -------------------------------------------------------
             RCALL READ_BLOCK        ; READ BLOCK
             ; -------------------------------------------------------
             LDI   R30, 2            ; 
             STS   FILE_NR,R30       ;
             LDI   R30, 8            ; 
             STS   DEVICE_NR,R30     ; 
             LDI   R30, 2            ; 
             ORI   R30, 0x60         ; 
             STS   SEK_ADR,R30       ; So und jetzt TALK .....
             LDI   R30,0x00          ;
             STS   STATUS, R30       ;
             LDI   R23, 0x00         ;
             RCALL TALK              ; TALK ED09
             RCALL SECTALK           ; Sekundäradresse für TALK senden $EDC7
        RD5: RCALL READ_BYTE         ;
             OUT   PORTC,R29         ; Byte auf LEDs ausgeben
             RCALL UART_SEND         ;
            ;MOV   R29,R23           ;
            ;RCALL UART_SEND         ; 
            ;OUT   PORTC,R29         ;
            ;INC   R23               ;
             LDS   R30,STATUS        ;
             ANDI  R30,0x40          ;
             BREQ  RD5               ;
            ;CPI   R23,0x00          ;
            ;BREQ  RD5b              ;
            ;LDS   R30,STATUS        ;
            ;OUT   PORTC,R30         ;
      ;RD5a: RJMP  RD5a              ;
       RD5b: RCALL UNTALK            ; UNTALK
            ; -------------------------------------------------------
             INC   R25               ; Sektor++
            ;OUT   PORTC,R25         ;
             LDS   R30, SECTORS      ;
             CP    R25,R30           ;
             BRLO  RD0               ;
             LDI   R25, 0            ; Sektor 0
             INC   R24               ; Track++
             LDS   R30, TRACKS       ;
             CP    R24, R30          ;
             BRLO  RD5c              ;
             RJMP  RD6               ;
       RD5c: RJMP  RD0               ;
                                     ;
        RD6: ; -------------------------------------------------------   
             LDI   R30, 0x02         ; Close ALL
             STS   SEK_ADR,R30       ; 
             RCALL CLOSE_FILE        ;
             LDI   R30, 0x0F         ; 
             STS   SEK_ADR,R30       ; 
             RCALL CLOSE_FILE        ;
             RET

; -------------------------------------------------------------------
; READ BLOCK
; -------------------------------------------------------------------
 READ_BLOCK: ;build command: "U1 2 0 TT SS"
             LDI   R30, 12            ; 12 Bytes
             STS   CMD_LEN, R30       ; 
             LDI   XL,LOW(COMMAND)    ; Befehlsanfang
             LDI   XH,HIGH(COMMAND)   ; 
             LDI   R30, 85            ; U
             ST    X+, R30            ;
             LDI   R30, 49            ; 1
             ST    X+, R30            ;
             LDI   R30, 32            ; space
             ST    X+, R30            ;
             LDI   R30, 50            ; 2
             ST    X+, R30            ;
             LDI   R30, 32            ; space
             ST    X+, R30            ;
             LDI   R30, 48            ; 0
             ST    X+, R30            ;
             LDI   R30, 32            ; space
             ST    X+, R30            ;
             
             ; ---------------------------------
             ; TRACK  in ASCII
             ; ---------------------------------                                     
             ; Zehnerstelle ermitteln:
             CPI   R24,40
             BRLO  LL0
             LDI   R30, 52            ; 4
             ST    X+, R30            ;
             MOV   R30,R24            ; R30 = R24
             SUBI  R30,40             ; R30 = R24 - 40
             RJMP  LL4
        LL0: CPI   R24,30
             BRLO  LL1
             LDI   R30, 51            ; 3
             ST    X+, R30            ;
             MOV   R30,R24            ; R30 = R24
             SUBI  R30,30             ; R30 = R24 - 30
             RJMP  LL4
        LL1: CPI   R24,20
             BRLO  LL2
             LDI   R30, 50            ; 2
             ST    X+, R30            ;
             MOV   R30,R24            ; R30 = R24
             SUBI  R30,20             ; R30 = R24 - 20
             RJMP  LL4                ; 
        LL2: CPI   R24,10             ;
             BRLO  LL3
             LDI   R30, 49            ; 1
             ST    X+, R30            ;
             MOV   R30,R24            ; R30 = R24
             SUBI  R30,10             ; R30 = R24 - 10
             RJMP  LL4                ;
        LL3: LDI   R30, 48            ; 0
             ST    X+, R30            ;
             MOV   R30,R24            ;
        LL4: ; Einerstelle ermitteln:
             LDI   R31, 48            ; 0
             ADD   R30, R31           ;
             ST    X+, R30            ; TRACK 
             ; ---------------------------------
             LDI   R30, 32            ; space
             ST    X+, R30            ;
             ; ---------------------------------
             ; SECTOR in ASCII R25
             ; --------------------------------- 
        LE1: CPI   R25,20
             BRLO  LE2
             LDI   R30, 50            ; 2
             ST    X+, R30            ;
             MOV   R30,R25            ; R30 = R25
             SUBI  R30,20             ; R30 = R25 - 20
             RJMP  LE4                ; 
        LE2: CPI   R25,10             ;
             BRLO  LE3
             LDI   R30, 49            ; 1
             ST    X+, R30            ;
             MOV   R30,R25            ; R30 = R25
             SUBI  R30,10             ; R30 = R25 - 10
             RJMP  LE4                ;
        LE3: LDI   R30, 48            ; 0
             ST    X+, R30            ;
             MOV   R30,R25            ;
        LE4: ; Einerstelle ermitteln:
             LDI   R31, 48            ; 0
             ADD   R30, R31           ;
             ST    X+, R30            ; SECTOR
        
             ; --------------------------------------------------------
             ; SEND COMMAND (TO SECONDARY ADRESS 15 !)
             ; --------------------------------------------------------
             LDI   R30, 0x0F          ; 
             STS   FILE_NR,R30        ;
             LDI   R30, 0x08          ; 
             STS   DEVICE_NR,R30      ; 
             LDI   R30, 0x0F          ; 
             ORI   R30, 0x60          ;
             STS   SEK_ADR,R30        ; 
             RCALL IEC_OPEN           ; (F3D5 im C64 Kernel)
             ; --------------------------------------------------------
             ; B-P 2 0: SEND FROM BYTE 0
             ; --------------------------------------------------------
             LDI   R30, 7             ; 12 Bytes
             STS   CMD_LEN, R30       ; 
             LDI   XL,LOW(COMMAND)    ; Befehlsanfang
             LDI   XH,HIGH(COMMAND)   ; 
             LDI   R30, 66            ; B
             ST    X+, R30            ;
             LDI   R30, 45            ; -
             ST    X+, R30            ;
             LDI   R30, 80            ; P
             ST    X+, R30            ;
             LDI   R30, 32            ; space
             ST    X+, R30            ;
             LDI   R30, 50            ; 2
             ST    X+, R30            ;
             LDI   R30, 32            ; space
             ST    X+, R30            ;
             LDI   R30, 48            ; 0
             ST    X+, R30            ;
             ; --------------------------------------------------------
             ; SEND COMMAND (TO SECONDARY ADRESS 15 !)
             ; --------------------------------------------------------
             LDI   R30, 0x0F          ; 
             STS   FILE_NR,R30        ;
             LDI   R30, 0x08          ; 
             STS   DEVICE_NR,R30      ; 
             LDI   R30, 0x0F          ; 
             ORI   R30, 0x60          ;
             STS   SEK_ADR,R30        ; 
             RCALL IEC_OPEN           ; (F3D5 im C64 Kernel)
             RCALL WAIT_765           ;
             ; --------------------------------------------------------
             ; WAIT UNTIL JOB DONE: M-R 0 0 1 13
             ; --------------------------------------------------------
      WUJD:  LDI   R30, 7             ;
             STS   CMD_LEN, R30       ; 
             LDI   XL,LOW(COMMAND)    ; Befehlsanfang
             LDI   XH,HIGH(COMMAND)   ; 
             LDI   R30, 77            ; M
             ST    X+, R30            ;
             LDI   R30, 45            ; -
             ST    X+, R30            ;
             LDI   R30, 82            ; R
             ST    X+, R30            ;
             LDI   R30, 0             ; 0
             ST    X+, R30            ;
             LDI   R30, 0             ; 0
             ST    X+, R30            ;
             LDI   R30, 1             ; 1
             ST    X+, R30            ;
             LDI   R30, 13            ; 13
             ST    X+, R30            ;
             ; --------------------------------------------------------
             ; SEND COMMAND (TO SECONDARY ADRESS 15 !)
             ; --------------------------------------------------------
             LDI   R30, 0x0F          ; 
             STS   FILE_NR,R30        ;
             LDI   R30, 0x08          ; 
             STS   DEVICE_NR,R30      ; 
             LDI   R30, 0x0F          ; 
             ORI   R30, 0x60          ;
             STS   SEK_ADR,R30        ; 
             RCALL IEC_OPEN           ; (F3D5 im C64 Kernel)
             RCALL WAIT_765           ;
             ; --------------------------------------------------------
             ; RECEIVE RESULT
             ; --------------------------------------------------------
             LDI   R30, 15            ; 
             STS   FILE_NR,R30        ;
             LDI   R30, 8             ; 
             STS   DEVICE_NR,R30      ; 
             LDI   R30, 15            ; 
             ORI   R30, 0x60          ; 
             STS   SEK_ADR,R30        ; So und jetzt TALK .....
             LDI   R30,0x00           ;
             STS   STATUS, R30        ;
             LDI   R23, 0x00          ;
             RCALL TALK               ; TALK ED09
             RCALL SECTALK            ; Sekundäradresse für TALK senden $EDC7
        HM0: RCALL READ_BYTE          ;
             ANDI  R29, 0x80          ; MSB gesetzt ? -> job not done
             BRNE  WUJD               ;
             RCALL WAIT_765           ;
             RET;
; -------------------------------------------------------------------
; COMMAND OPEN
; -------------------------------------------------------------------
 CMD_OPEN:   LDI   R30, 0b00111111    ; 
             OUT   PORTC,R30          ;
             RCALL OPEN15815          ; Befehl der mit OPEN kam, senden         
             ;RCALL CLOSE_FILE        ; Kanal wieder schliessen
             RET                      ;

; --------------------------------------------------------------------
; COMMAND LOAD
; --------------------------------------------------------------------
 CMD_LOAD:   LDI   R30, 0b11000111    ; Set a nice pattern for the LEDs
             OUT   PORTC,R30          ; Light the LEDs
             LDI   R30, 0x08          ; device number = 0x08
             STS   DEVICE_NR,R30      ; store the device number
             RCALL LOAD               ; call the real LOAD command
             RET                      ; return to the command handler

; -------------------------------------------------------------------
; COMMAND STATUS (READ 1541 STATUS)
; -------------------------------------------------------------------
 CMD_STATUS: LDI   R30, 0b10000001    ; 
             OUT   PORTC,R30          ;
             LDI   R30, 0x08          ; Gerätenummer    = 0x08
             STS   DEVICE_NR,R30      ;
             LDI   R30, 0x0F          ; 15
             STS   SEK_ADR, R30       ;
             LDI   R30, 0x00          ; 0
             STS   CMD_LEN, R30       ;
             RCALL OPEN15815          ;
                                      ; ffc6->F20E->F237->Eingabe aus logischer Datei
             RCALL TALK               ; TALK ED09
             RCALL SECTALK            ; Sekundäradresse für TALK senden $EDC7
             LDI   R30,0x00           ;
             STS   STATUS, R30        ;
        CM1: RCALL READ_BYTE          ;
             RCALL UART_SEND          ;
             OUT   PORTC,R29          ;
             LDS   R30, STATUS        ;
             ANDI  R30,0x40           ;
             BREQ  CM1                ;

     CM_EOF: RCALL UNTALK             ; UNTALK
             RCALL CLOSE_FILE         ; File schliessen
             RET                      ; 

 CMD_IECSENDTMP: RJMP CMD_IECSEND     ;
 CMD_MR_TMP    : RJMP CMD_MR          ;
 CMD_CLOSETMP  : RJMP CMD_CLOSE       ;

; -------------------------------------------------------------------
; IECOpen Befehl IECOpen(Fnr,DNr,SAdr,Command)
; -------------------------------------------------------------------
 CMD_IECOPEN: LDI   XL,LOW(COMMAND)   ; Befehlsanfang
              LDI   XH,HIGH(COMMAND)  ; 
              LDI   YL,LOW(COMMAND)   ;
              LDI   YH,HIGH(COMMAND)  ;
              LD    R30, X+           ; 1. Byte = FileNr
              STS   FILE_NR,R30       ;
              LD    R30, X+           ; 2. Byte = Device Nr
              STS   DEVICE_NR,R30     ; 
              LD    R30, X+           ; 3. Byte = Sekundäradresse
              ORI   R30, 0x60         ; 
              STS   SEK_ADR,R30       ;
              LDS   R30,CMD_LEN       ; Befehslänge holen
              SUBI  R30,0x03          ; Befehlstext für open ist 3 Byte kürzer
              STS   CMD_LEN,R30       ;
        CIO0: CPI   R30,0x00          ; Alle Bytes kopiert ?
              BREQ  CIO1              ;
              LD    R1 , X+           ; n. Befehlsbyte
              ST    Y+ , R1           ; Kopieren
              DEC   R30               ;
              RJMP  CIO0              ;
 CIO1:        RCALL IEC_OPEN          ; (F3D5 im C64 Kernel)
              RET

; -------------------------------------------------------------------
; Command 5 Memory Read
; -------------------------------------------------------------------
 CMD_MR:     LDI   R30, 0x0F          ; 1. Byte = FileNr
             STS   FILE_NR,R30        ;
             LDI   R30, 0x08          ; Gerätenummer    = 0x08
             STS   DEVICE_NR,R30      ;
             LDI   R30, 0x0F          ; 15
             STS   SEK_ADR, R30       ;
             LDI   R30, 0x00          ; 0
             STS   CMD_LEN, R30       ;
             RCALL OPEN15815          ;
                                      ; CKOUT:ffc9->f250->f279:
             RCALL LISTEN             ; (ED0C im C64 Kernel) Listen an device senden
             RCALL SECLISTEN          ; Sekundäradresse für LISTEN senden  (EDB9 im C64 Kernel)
             LDI   R30, 0x06          ; 5 Byte: M-R001
             STS   CMD_LEN,R30        ;
             LDS   R20,CMD_LEN        ;
             CLR   R21                ;
             LDI   XL,LOW(COMMAND)    ; 
             LDI   XH,HIGH(COMMAND)   ; 
      AA1:   CP    R20,R21            ;   
             BREQ  AA3                ; Befehl ist komplett ausgegeben
             LD    R30, X+            ; 
             STS   OUTBYTE, R30       ; -> als auszugebendes Byte festlegen 
             INC   R21                ;
     AA2:    RCALL SENDBYTE           ; Byte auf den Bus ausgeben bei ATN = HI (EDDD im C64 Kernel)
             RJMP  AA1                ;
     AA3:    RCALL UNLISTEN           ; (F654 im C64 Kernel)
             RCALL TALK               ; TALK ED09
             RCALL SECTALK            ; Sekundäradresse für TALK senden $EDC7
             LDI   R30,0x00           ;
             STS   STATUS, R30        ;
      AA4:   RCALL READ_BYTE          ;
             RCALL UART_SEND          ;
             LDS   R30, STATUS        ;
             ANDI  R30,0x40           ;
             BREQ  AA4                ;
             RCALL UNTALK             ; UNTALK
             RET 

; -------------------------------------------------------------------
; Command 6 IECClose(FNr,DNr,SAdr)
; -------------------------------------------------------------------
 CMD_CLOSE:   
              RET                     ;

; -------------------------------------------------------------------
; IECSend(FileNr,DevNr, SecAdr)
; -------------------------------------------------------------------
 CMD_IECSEND: LDI   XL,LOW(COMMAND)   ; Befhelsanfang
              LDI   XH,HIGH(COMMAND)  ; 
              LD    R30, X+           ; 1. Byte = FileNr
              STS   FILE_NR,R30       ;
              LD    R30, X+           ; 2. Byte = Device Nr
              STS   DEVICE_NR,R30     ; 
              LD    R30, X+           ; 3. Byte = Sekundäradresse
              ORI   R30, 0x60         ; 
              STS   SEK_ADR,R30       ; So und jetzt TALK .....
              RCALL TALK              ; TALK ED09
              RCALL SECTALK           ; Sekundäradresse für TALK senden $EDC7
              LDI   R30,0x00          ;
              STS   STATUS, R30       ;
       IECS1: RCALL READ_BYTE         ;
              RCALL UART_SEND         ;
              OUT   PORTC,R29         ;
              LDS   R30, STATUS       ;
              ANDI  R30,0x40          ;
              BREQ  IECS1             ;
              RCALL UNTALK            ; UNTALK
              RET                     ; 

; -------------------------------------------------------------------
; COMMAND BURST READ
; -------------------------------------------------------------------
  CMD_BURST:  RCALL SET_CLK           ;
              RCALL SET_DATA          ;
              LDI   R29, 0x00         ;
              LDI   R28, 0x08         ; 8 Bit :)

   REC_START: RCALL GET_CLK           ; CLK abfragen
              CPI   R30,CLK_IN        ; CLK Hi ?
              BRNE  REC0_1            ; CLK = LO !
              RCALL GET_DATA          ; DATA abfragen
              CPI   R30,DATA_IN       ; DATA Hi ?
              BRNE  REC1_1            ; DATA = LO !
              RJMP  REC_START         ; 

     REC0_1:  RCALL GET_DATA          ; DATA abfragen
              CPI   R30,DATA_IN       ; DATA Hi ?
              BRNE  REC_EOF           ; DATA = LO => EOF
              RCALL CLEAR_DATA        ;
              CLC                     ; Clear Carry
              ROR   R29               ;
     REC0_2:  RCALL GET_CLK           ; CLK abfragen
              CPI   R30,CLK_IN        ; CLK Hi ?
              BRNE  REC0_2            ; Wait for Clock Hi
              RCALL SET_DATA          ;
              DEC   R28               ;
              BREQ  REC8READY         ;
              RJMP  REC_START         ;

     REC1_1:  RCALL GET_CLK           ; CLK abfragen
              CPI   R30,CLK_IN        ; CLK Hi ?
              BRNE  REC_EOF           ; CLK = LO => EOF
              RCALL CLEAR_CLK         ;
              SEC                     ; Set Carry
              ROR   R29               ;
     REC1_2:  RCALL GET_DATA          ; DATA abfragen
              CPI   R30,DATA_IN       ; DATA Hi ?
              BRNE  REC1_2            ; Wait for DATA HI
              RCALL SET_CLK           ;
              DEC   R28               ;
              BREQ  REC8READY         ;
              RJMP  REC_START         ;
     REC_EOF: RET                     ;

   REC8READY: RCALL UART_SEND         ;
              OUT   PORTC,R29         ;
              RJMP  CMD_BURST         ;
     
; -------------------------------------------------------------------
; COMMAND MEMORY EXECUTE
; -------------------------------------------------------------------
 CMD_MEMEXEC: RET                     ;

; -------------------------------------------------------------------
; C64 OPEN-Routine (F34A) C64 Kernel
; -------------------------------------------------------------------
 OPEN15815:  LDI   R30, 0x0F          ; Logische Filenummer
             STS   FILE_NR,R30        ;
             LDI   R30, 0x08          ; Gerätenummer    = 0x08
             STS   DEVICE_NR,R30      ; 
             LDI   R30, 0x0F          ; Sekundäradresse 15
             ORI   R30, 0x60          ;
             STS   SEK_ADR,R30        ; 
             RCALL IEC_OPEN           ; (F3D5 im C64 Kernel)
             RET                      ;

; -------------------------------------------------------------------
; C64 LOAD-routine from address ($F49E) C64 kernel
; -------------------------------------------------------------------
; The device number must be in variable DEVICE_NR
; -------------------------------------------------------------------
LOAD:        CLR   R30                ; 
             STS   LAST_BYTE,R30      ; clear the "last byte" flag (we might send more than one ..)
             STS   STATUS   ,R30      ; clear the status byte
             LDI   R30, 0x60          ; 
             STS   SEK_ADR,R30        ; secondary address = 0x60 (LoByte=0 => load)
             RCALL IEC_OPEN           ; same as $F3D5 in the C64 kernel rom (OPEN)
             RCALL TALK               ; same as $ED09 in the C64 kernel rom (TALK)
             RCALL SECTALK            ; send secondary address for TALK ($EDC7 in the C64 kernel)
             RCALL READ_BYTE          ; receive byte from the drive (lo-byte of the file start address)
             STS   SADR_LO, R29       ; store it (maybe send it some happy day, but not now)
             RCALL READ_BYTE          ; receive byte (hi-byte of the file start address)
             STS   SADR_HI, R29       ; store it (maybe send it some happy day, but not now)
             LDS   R30, STATUS        ; load the current status to R30
             ANDI  R30,0x40           ; clear everything but bit 6 
             BREQ  LOAD1              ; we did not reach EOF (end of file)
             RJMP  EOF                ; EOF was reached so we are almost done->UNTALK and CLOSE
LOAD1:       RCALL READ_BYTE          ; get the next byte from the drive
             RCALL UART_SEND          ; send it to the PC via the internal AVR UART
             OUT   PORTC,R29          ; set port C to watch the received data at the LEDs
             LDS   R30, STATUS        ; watch the status
             ANDI  R30,0x40           ; check if we reached EOF
             BREQ  LOAD1              ; no, not yet => get next byte
             RJMP  EOF                ; ok, that was it. The file was read.
EOF:         RCALL UNTALK             ; send UNTALK to the drive
             RCALL CLOSE_FILE         ; close the file
             RET                      ; ok, file was read and transmitted

; -------------------------------------------------------------------
; open file on the IEC-bus (at $F3D5 in the C64 kernel-rom)
; -------------------------------------------------------------------
IEC_OPEN:    LDS   R30, SEK_ADR       ; Get the secondary address
             ANDI  R30,0x80           ; check MSB of the secondary address
             BREQ  IEO1               ; MSB must not be zero
             RET                      ; if MSB was zero, return
IEO1:        LDS   R30, CMD_LEN       ; get the file length
             CPI   R30, 0x00          ; command or filename with length 0 => done.
             BRNE  IEO2               ; continue
             RET                      ; return if length was zero
IEO2:        CLR   R30                ; status byte: set it to zero
             STS   STATUS   ,R30      ; clear status
             RCALL LISTEN             ; send LISTEN ($ED0C in the C64 kernel rom)
             RCALL SECLISTEN          ; SECLISTEN: send secondary address for LISTEN ($EDB9 C64 kernel)
             LDS   R20,CMD_LEN        ; send the command/filename now
             CLR   R21                ; clear the byte counter
             LDI   XL,LOW(COMMAND)    ; the command/filename is stored at memory address COMMAND 
             LDI   XH,HIGH(COMMAND)   ; bring this address to the X register
IOFNL1:      CP    R20,R21            ; did we send the complete command ?  
             BREQ  IOFNL7             ; yes, we did ! => send UNLISTEN and return.
             LD    R30, X+            ; get next byte of command/filename
             STS   OUTBYTE, R30       ; -> store it to the variable that will be sent by SEND_BYTE 
             INC   R21                ; increase byte-counter
             CP    R20,R21            ; is this going to be the last byte ?
             BRNE  IOFNL6             ; no, there are a few more bytes to send
             LDI   R30,  1            ; yes, this will be our last byte to send =>
             STS   LAST_BYTE,R30      ; set the LAST_BYTE flag to 1 
IOFNL6:      RCALL SENDBYTE          ; send byte to the drive (ATN = HI; $EDDD C64 kernel)
             RJMP  IOFNL1             ; repeat until all bytes were sent
IOFNL7:      RCALL UNLISTEN           ; send UNLISTEN ($F654 C64 kernel)
             RET                      ; finished

; --------------------------------------------------------------------------------------------
; TALK
; --------------------------------------------------------------------------------------------
TALK:        LDS   R30, DEVICE_NR     ; ($ED09 C64 kernel) send TALK
             ORI   R30, 0x40          ; DeviceNr + $40 = TALK Command (-> $ED09)
             RJMP  TKLI               ;
; --------------------------------------------------------------------------------------------
; LISTEN
; --------------------------------------------------------------------------------------------
LISTEN:      LDS   R30, DEVICE_NR     ; ($ED0C C64 kernel) send LISTEN
             ORI   R30, 0x20          ; DeviceNr + $20 = LISTEN Command (-> $ED0C)
TKLI:        STS   OUTBYTE, R30       ; send command (->$ED21)
             RCALL SET_DATA           ; DATA HI (->ED24)
             RCALL CLEAR_ATN          ; ATN  LO (->ED2E)
             RCALL SENDBYTEATN        ; send byte while ATN is LOW
             RET                      ; command complete
 
; -------------------------------------------------------------------
; UNTALK ($EDEF C64 kernel)
; -------------------------------------------------------------------
UNTALK:      RCALL CLEAR_CLK          ; CLK = 0 
             RCALL CLEAR_ATN          ; ATN = 0
             LDI   R30, 0x5F          ; 0x5F = UNTALK
             RCALL TKLI               ; do the same as in LISTEN 
             RJMP  UL1                ; do it
; -------------------------------------------------------------------
; UNLISTEN ($EDFE C64 kernel) 
; -------------------------------------------------------------------
UNLISTEN:    LDI   R30, 0x3F          ; 0x3F = UNLISTEN
             RCALL TKLI               ; do the same as in LISTEN
UL1:         RCALL SET_ATN            ; ATN HI ($EE03 C64 Kernel)
             RCALL WAIT_100           ; wait 100 µs 
             RCALL SET_CLK            ; CLK  = 1
             RCALL SET_DATA           ; DATA = 1
             RET                      ; done.

; -------------------------------------------------------------------
; send secondary address for LISTEN ($EDB9 C64 kernel) 
; -------------------------------------------------------------------
SECLISTEN:   LDS   R30,SEK_ADR        ; this is where the secondary address is stored
             ORI   R30,0xF0           ; the hi-byte must be F for a LISTEN
             STS   OUTBYTE,R30        ; we want to send this byte …
             RCALL SENDBYTEATN        ; ($ED36 C64 kernel) send byte with ATN low
             RCALL SET_ATN            ; ATN HI (the listen command is complete)
             RET                      ; done.
 
; -------------------------------------------------------------------
; send secondary address for TALK ($EDC7)
; -------------------------------------------------------------------
SECTALK:     LDS   R30,SEK_ADR        ; this is where the secondary address is stored
             STS   OUTBYTE,R30        ; we want to send this byte
             RCALL SENDBYTEATN        ; ($ED36 C64 kernel) send byte with ATN low
             RCALL CLEAR_DATA         ; clear the DATA line
             RCALL SET_ATN            ; we need to set ATN (its still a command)
             RCALL WAIT_100           ; wait for 100 µs
             RCALL SET_CLK            ; CLK hi
TALK_1:      RCALL GET_CLK            ; get CLK in R30
             CPI   R30,CLK_IN         ; is it still HIGH ?
             BREQ  TALK_1             ; yes, so wait until the drive sets it to LOW
             RET                      ; done.

; -------------------------------------------------------------------
; close file on IEC-bus ($F642 C64 kernel) 
; -------------------------------------------------------------------
CLOSE_FILE:  LDS   R30,SEK_ADR        ; load secondary address
             ANDI  R30,0x80           ; test MSB
             BREQ  CF1                ; sec address is ok => continue
             RET                      ; not a secondary address => return
CF1:         RCALL LISTEN             ; LISTEN   ($ED0C C64 kernel)
             RCALL SECCLOSE           ; SECCLOSE ($EDB9 C64 kernel)
             RCALL UNLISTEN           ; UNLISTEN ($EDFE C64 kernel)
             RET                      ; done.
 
; -------------------------------------------------------------------
; send secondary address for close. ($EDB9 C64 kernel)
; -------------------------------------------------------------------
SECCLOSE:    LDS   R30,SEK_ADR        ; load secondary address
             ANDI  R30,0xEF           ; clear MSB
             ORI   R30,0xE0           ; set high nibble except for bit 7
             STS   OUTBYTE, R30       ; 
             RCALL SENDBYTEATN        ; ($ED36 C64 Kernel) Send Byte with ATN low
             RCALL SET_ATN            ; release ATN line => back to 5V  
             RET                      ; done.

; -------------------------------------------------------------------
; SEND BYTE (with ATN low)  (C64 Kernel: $ED36)
; -------------------------------------------------------------------
SENDBYTEATN: RCALL CLEAR_CLK          ; CLK  LO
             RCALL SET_DATA           ; DATA HI 
             RCALL WAIT_765           ; Wait 765 µs
; -------------------------------------------------------------------
; SEND BYTE (C64 Kernel: $ED40)
; -------------------------------------------------------------------
SENDBYTE:    RCALL SET_DATA           ; set DATA output to HI
             RCALL GET_DATA           ; get DATA input from 1541
             CPI   R30, DATA_IN       ; DATA in must be LO 
             BRNE  LST1               ; ok, device is present-> go on !
             LDI   R30, 0b01010101    ; LEDS pattern for "device not present"
             OUT   PORTC,R30          ; status to PORTC
             RJMP  STOP               ; device not present
LST1:        RCALL SET_CLK            ; CLK OUT = HI
LST2:        RCALL GET_DATA           ; DATA -> R30
             CPI   R30, DATA_IN       ; check DATA IN
             BRNE  LST2               ; wait for DATA HI
             LDS   R30,LAST_BYTE      ; check last byte flag
             CPI   R30,0x01           ; ist it the last byte to send ?
             BRNE  SB_NORMAL          ; no, its a normal byte -> SB_NORMAL
SB_LAST:     RCALL GET_DATA           ; check DATA IN (DATA -> R30)
             CPI   R30, DATA_IN       ; 
             BREQ  SB_LAST            ; wait for DATA IN = LO
SBL1:        RCALL GET_DATA           ; check DATA IN (DATA -> R30)
             CPI   R30, DATA_IN       ; 
             BRNE  SBL1               ; wait for DATA IN = HI
SB_NORMAL:   RCALL CLEAR_CLK          ; CLK LO ($ED5F)
             RCALL GET_DATA           ; check DATA IN
             CPI   R30,DATA_IN        ;
             BREQ  LST3               ; DATA is HI -> go on
             LDI   R30, 0b01011111    ; LEDS pattern for "timeout"
             OUT   PORTC,R30          ; status to PORTC
             RJMP  STOP;              ; Timeout if DATA is LO
LST3:        LDS   R18,OUTBYTE        ; load R18 with byte to send
             LDI   R19, 8             ; we want to send 8 bits :)
             RCALL WAIT_20            ;
             RCALL WAIT_20            ; Ts (min 20 µs typ 70 µs max -)
             RCALL WAIT_20            ; lets wait the typical time (which is 70µs)
             RCALL WAIT_10            ;   
LST4:        ROR   R18                ; rotate LSB to CARRY
             BRCS  LST5               ; if carry is set, send a "1"
             RCALL CLEAR_DATA         ; carry is clear => send a "0"
             RJMP  LST6               ;
LST5:        RCALL SET_DATA           ; 
LST6:        RCALL SET_CLK            ; ok, set clock if data line was set ....
             RCALL WAIT_20            ; Tv (min 20µs typ 20µs max -)
             RCALL WAIT_10            ; 20 did not work so we wait for 30µs ...
             RCALL CLEAR_CLK          ; 
             RCALL SET_DATA           ;
             RCALL WAIT_20            ; 
             RCALL WAIT_20            ; Ts (min 20 µs typ 70 µs max -)
             RCALL WAIT_20            ; 
             RCALL WAIT_10            ;   
             DEC   R19                ; decrease bitcounter
             BRNE  LST4               ; one more bit, if counter not 0
             RCALL SET_DATA           ; all bits sent ...
LST7:        RCALL GET_DATA           ;
             ANDI  R30, DATA_IN       ;
             BRNE  LST7               ; wait for ACK from floppy (DATA = LO) (Ack)
             RCALL WAIT_100           ; Tbb min 100µs
             RCALL WAIT_100           ; 200 worked better than 100 ....
             RET                      ; byte was sent successfully

; -------------------------------------------------------------------
; READ IEC BYTE
; ------------------------------------------------------------------- 
READ_BYTE:   CLR   R29                ; we will store the received byte here 
             CLR   R31                ; initialise bit-counter
             CLR   R27                ; initialise timeout-counter
             STS   BIT_CNT, R31       ; set bit counter to zero 
             RCALL SET_CLK            ; CLK HIGH (don't pull it down)
RB1:         RCALL GET_CLK            ; read the CLK line
             CPI   R30, CLK_IN        ;  
             BRNE  RB1                ; wait until the CLK line is HIGH
             RCALL SET_DATA           ; set the DATA line as ACK
             ; if the CLK line is not going down for 200µs the sender wants to send the last byte.
             ; in this case, the listener has to send an acknowledge, by pulling the DATA line down.
RB1_B:       LDI   R28,20             ; 20*10 µs=200µs no CLK low => pull DATA low
             RJMP  RB2_A              ; 
RB2:         RCALL WAIT_10            ; wait for 10 µs
RB2_A:       DEC   R28                ; we waited 10 µs
             BREQ  RB2_B              ; did we already wait 20 times 10µs ? yes => timeout => send ACK
             RCALL GET_CLK            ; read CLK line
             CPI   R30, CLK_IN        ;
             BREQ  RB2                ; wait until CLK = 0 or 200µs are over
             RJMP  RB2_F              ; CLK is LOW before 200µs timeout => normal byte will be sent
RB2_B:       TST   R27                ; lets hope this is our first timeout !
             BRNE  TIMEOUT            ; ups .. more than one timeout is a timeout error 
             INC   R27                ; remember the current timeout !       
             RCALL CLEAR_DATA         ; pull DATA line LOW => acknowledge last byte
             RCALL SET_CLK            ; release CLK line
             LDS   R30,STATUS         ; EOF (BIT 6 = 1)
             ORI   R30,0x40           ; 
             STS   STATUS,R30         ; set status byte to EOF (the last byte is the end of our file)
             RCALL WAIT_100           ; wait 100 µs 
             RCALL SET_DATA           ; set DATA to high
             RJMP  RB1_B              ; repeat it, but now we need a CLK low faster than last time 
TIMEOUT:     LDS   R30,STATUS         ; get current status
             ORI   R30,0x02           ; timeout error
             STS   STATUS,R30         ; store the timeout error in our status byte
             RJMP  UL1                ; special UNLISTEN
             LDI   R30, 0b11001100    ; set the timeout error pattern to our LED port
             OUT   PORTC,R30          ; light the LEDs
             RJMP  STOP               ; critical STOP. Interface OFF 
RB2_F:       LDI   R30,8              ; there should be received 8 bits now 
             STS   BIT_CNT, R30       ; set the bit-counter 
RB3:         RCALL GET_CLK            ; read the CLK line
             CPI   R30,CLK_IN         ; is it HIGH or LOW ?
             BRNE  RB3                ; if CLK still 0 then data is not yet valid
             RCALL GET_DATA           ; cool! CLK is 1 now => the DATA line is valid
             CPI   R30,DATA_IN        ; read the DATA line
             BRNE  RB4                ; DATA line = 0 => CLEAR CARRY FLAG
             SEC                      ; DATA line = 1 => SET   CARRY FLAG
             RJMP  RB7                ;
RB4:         CLC                      ;
RB7:         ROR   R29                ; shift the carry into the MSB 
             LDS   R31,BIT_CNT        ; 
             DEC   R31                ; decrement bit-counter
             BREQ  RB5                ; all bits received ? yes => acknowledge received byte
             STS   BIT_CNT,R31        ; no, we still need a few more bits …
RB6:         RCALL GET_CLK            ; read the CLK line
             CPI   R30, CLK_IN        ;
             BREQ  RB6                ; wait until CLK is LOW
             RJMP  RB3                ; now wait for the next bit
RB5:         RCALL CLEAR_DATA         ; OK ! 8 bits received => send acknowledge (DATA = LOW)
             RCALL WAIT_100           ; 
             RCALL WAIT_100           ;
             RCALL WAIT_100           ; 300µs should be long enough
             TST   R27                ; was it the last byte ?
             BREQ  RB8                ; no: done !
             RCALL SET_CLK            ; release CLK line
             RCALL SET_DATA           ; release DATA line
RB8:         RET                      ; done.

; -------------------------------------------------------------------
; IEC: SET_DATA
; ------------------------------------------------------------------- 
SET_DATA:    IN   R30  ,PINA          ; read port A voltage
             ANDI R30  ,PORT_MASK     ; clear the input lines (no pullups) 
             ORI  R30  ,DATA_OUT      ; set the DATA line to HIGH (5V)
             OUT  PORTA,R30           ; set port A
             RET                      ; done.
 
; -------------------------------------------------------------------
; IEC: CLEAR_DATA
; ------------------------------------------------------------------- 
CLEAR_DATA:  IN   R30  ,PINA          ; read port A voltage
             ANDI R30  ,PORT_MASK     ; clear the input lines (no pullups)
             ANDI R30  ,~DATA_OUT     ; set the DATA line to LOW (0V)
             OUT  PORTA,R30           ; set port A
             RET                      ; done.

; -------------------------------------------------------------------
; IEC: SET_CLK
; ------------------------------------------------------------------- 
SET_CLK:     IN   R30  ,PINA          ; read port A voltage
             ANDI R30  ,PORT_MASK     ; clear the input lines (no pullups) 
             ORI  R30  ,CLK_OUT       ; set the CLK line to HIGH (5V)
             OUT  PORTA,R30           ; set port A
             RET                      ; done.
 
; -------------------------------------------------------------------
; IEC: CLEAR_CLK
; ------------------------------------------------------------------- 
CLEAR_CLK:   IN   R30  ,PINA          ; read port A voltage
             ANDI R30  ,PORT_MASK     ; clear the input lines (no pullups) 
             ANDI R30  ,~CLK_OUT      ; set the CLK line to LOW (0V)
             OUT  PORTA,R30           ; set port A
             RET                      ; done.

; -------------------------------------------------------------------
; IEC: SET_ATN
; ------------------------------------------------------------------- 
SET_ATN:     IN   R30  ,PINA          ; read port A voltage
             ANDI R30  ,PORT_MASK     ; clear the input lines (no pullups) 
             ORI  R30  ,ATN_OUT       ; set the ATN line to HIGH (5V)
             OUT  PORTA,R30           ; set port A
             RET                      ; done.

; -------------------------------------------------------------------
; IEC: CLEAR_ATN
; ------------------------------------------------------------------- 
CLEAR_ATN:   IN   R30  ,PINA          ; read port A voltage
             ANDI R30  ,PORT_MASK     ; clear the input lines (no pullups)
             ANDI R30  ,~ATN_OUT      ; set the ATN line to LOW (0V)
             OUT  PORTA,R30           ; set port A
             RET                      ; done.

; -------------------------------------------------------------------
; IEC: SET_RST
; ------------------------------------------------------------------- 
SET_RST:     IN   R30  ,PINA          ; read port A voltage
             ANDI R30  ,PORT_MASK     ; clear the input lines (no pullups) 
             ORI  R30  ,RST_OUT       ; set the RST line to HIGH (5V)
             OUT  PORTA,R30           ; set port A
             RET                      ; done.

; -------------------------------------------------------------------
; IEC: CLEAR_RST
; ------------------------------------------------------------------- 
CLEAR_RST:   IN   R30  ,PINA          ; read port A voltage
             ANDI R30  ,PORT_MASK     ; clear the input lines (no pullups)
             ANDI R30  ,~RST_OUT      ; set the RST line to LOW (0V)
             OUT  PORTA,R30           ; set port A
             RET                      ; done.

; -------------------------------------------------------------------
; IEC: GET_DATA
; -------------------------------------------------------------------
GET_DATA:    IN   R30, PINA           ; Port A lesen
             NOP                      ; kurz warten
             IN   R31, PINA           ; Port A lesen 
             CP   R30,R31             ; Gleich => keine Flanke
             BRNE GET_DATA            ; Nicht gleich => Flanke => nochmal
             ANDI R30, DATA_IN        ; Nur das DATA Bit ist interessant
             RET                      ; Fertig

; -------------------------------------------------------------------
; IEC: GET_CLK
; -------------------------------------------------------------------
GET_CLK:     IN   R30, PINA           ; Port A lesen
             NOP                      ; kurz warten
             IN   R31, PINA           ; Port A lesen 
             CP   R30,R31             ; Gleich => keine Flanke
             BRNE GET_CLK             ; Nicht gleich => Flanke => nochmal
             ANDI R30, CLK_IN         ; Nur das CLK_IN Bit ist interessant
             RET                      ; Fertig

; -------------------------------------------------------------------
; 10 µs: (Incl. Aufruf und Rücksprung)
; 3.69 MHz => 3.69 Ticks pro µs 
; 10 µs sind dann ca 37 Ticks         ; TICK NR.: 7 TICKS für RCALL und RET = bleiben noch 30
; -------------------------------------------------------------------
WAIT_10:    LDI  R16, 10              ; 1 Tick => noch 29  (9 mal 3 Ticks) und (1 mal 2)
WT10_1:     DEC  R16                  ; 1 Tick
            BRNE WT10_1               ; 2 Ticks
            RET                       ; done.

; -------------------------------------------------------------------
; 20 µs: (Incl. Aufruf und Rücksprung)
; 3.69 MHz => 3.69 Ticks pro µs 
; 20 µs sind dann ca 74 Ticks         ; TICK NR. 7 TICKS für RCALL und RET = bleiben noch 67
; -------------------------------------------------------------------
WAIT_20:    LDI  R16, 22              ; 1 Tick => noch 66  (22 mal 3 Ticks)
WT20_1:     DEC  R16                  ; 1 Tick
            BRNE WT20_1               ; 2 Ticks
            NOP                       ; 1 Tick (letzter Branch braucht nur einen Tick)
            RET                       ;
; -------------------------------------------------------------------
; 100 µs: (Incl. Aufruf und Rücksprung)
; 3.69 MHz => 3.69 Ticks pro µs 
; 100 µs sind dann ca 370 Ticks       ; TICK NR. 7 TICKS für RCALL und RET = bleiben noch 363
; -------------------------------------------------------------------
WAIT_100:   LDI  R16, 121             ; 1 Tick => noch 362 =>  120*3 + 2 = 362
WT100_1:    DEC  R16                  ; 1 Tick
            BRNE WT100_1              ; 2 Ticks
            RET                       ;
; -------------------------------------------------------------------
; 765 µs: (Incl. Aufruf und Rücksprung)
; 3.69 MHz => 3.69 Ticks pro µs 
; 765 µs sind dann ca 2823 Ticks      ; TICK NR. 7 TICKS für RCALL und RET = bleiben noch 2816
; -------------------------------------------------------------------
WAIT_765:   LDI R16, 234              ;       1 Tick  => noch 2815 Ticks warten
WT765_1:    DEC R16                   ; 1     1 Tick
            NOP                       ; 2     1 Tick
            NOP                       ; 3     1 Tick 
            NOP                       ; 4     1 Tick 
            NOP                       ; 5     1 Tick 
            NOP                       ; 6     1 Tick 
            NOP                       ; 7     1 Tick 
            NOP                       ; 8     1 Tick 
            NOP                       ; 9     1 Tick 
            NOP                       ; 10    1 Tick 
            BRNE WT765_1              ; 11/12 2 Ticks
                                      ; Das hat (234*12)-1 = 2807 Ticks gedauert => noch 8
            NOP                       ; 1 Tick 
            NOP                       ; 1 Tick 
            NOP                       ; 1 Tick 
            NOP                       ; 1 Tick 
            NOP                       ; 1 Tick 
            NOP                       ; 1 Tick 
            NOP                       ; 1 Tick 
            NOP                       ; 1 Tick 
            RET                       ;

; -------------------------------------------------------------------
; RESET 1541
; -------------------------------------------------------------------
 RST:       RCALL CLEAR_RST;
            LDI   R30,0xFF
      RST1: RCALL WAIT_765;         
            RCALL WAIT_765;
            DEC   R30
            BRNE  RST1;
            RCALL SET_RST;
            LDI   R30,0xFF
      RST2: RCALL WAIT_765;         
            RCALL WAIT_765;
            RCALL WAIT_765;
            RCALL WAIT_765;
            RCALL WAIT_765;
            RCALL WAIT_765;
            RCALL WAIT_765;
            RCALL WAIT_765;
            RCALL WAIT_765;
            RCALL WAIT_765;
            RCALL WAIT_765;
            DEC   R30
            BRNE  RST2;
            RET    

INIT_UART:  LDI R30, BAUDCONST ; 
            OUT UBRR,R30        ;load baudrate
            RET                 ;

UART_SEND:  SBI  UCR, TXEN           ;
            SBIS USR, UDRE           ; Data Register empty ?
            RJMP UART_SEND           ;
            OUT  UDR, R29            ;
            CBI  UCR, TXEN           ;
            RET                      ;

; -------------------------------------------------------------------------
; BEFEHLESFORMAT:
; 01: Immer  NR: Befehl CT: Anzahl der Bytes
; 
; 01 NR CT X1 X2 X3 X4 X5 .....
; -------------------------------------------------------------------------
; BEISPIEL: LOAD Befehl:  z.B. LOAD "$",8,1
; NR: BEFEHLSNUMMER   (Beispiel  0 ) 
; CT: LÄNGE DER FOLGENDEN BEFEHLSSEQUENZ (Beispiel 3)
; X1: DEVICE NR       (Beispiel  8 )  Byte 1
; X2: SEKUNDÄRADRESSE (Beispiel  1 )  Byte 2
; X3 - ...: DATEINAME (Beispiel "$")  Byte 3
; -------------------------------------------------------------------------
GET_COMMAND:LDI   R30, 0b00111100     ; Warte auf Befehl
            OUT   PORTC,R30           ;
            RCALL INIT_CMD            ;
            LDI   XL,LOW(COMMAND)     ; Speicherplatz für den Befehl (LOW )
            LDI   XH,HIGH(COMMAND)    ; Speicherplatz für den Befehl (HIGH)
UR1:        SBI   UCR, RXEN           ; 
            SBIS  USR, RXC            ; RX Complete ? 
            RJMP  UR1                 ;
            IN    R30, UDR            ;
            CBI   UCR, RXEN           ; 
            CBI   USR, RXC            ;
            CPI   R30, 0x01           ; Befehlsstart ? (01)
            BRNE  UR1                 ; Nein, kein Befehlsstart, dann weiter warten
            MOV   R25,R30             ; Checksumme erstes Byte
UR2:        SBI   UCR, RXEN           ; 
            SBIS  USR, RXC            ; RX Complete ? 
            RJMP  UR2                 ; Befehlstyp
            IN    R30, UDR            ;
            CBI   UCR, RXEN           ; 
            CBI   USR, RXC            ;
            STS   CMD_TYPE,R30        ;
            EOR   R25, R30            ; R25 = R25 EOR R30
UR3:        SBI   UCR, RXEN           ; 
            SBIS  USR, RXC            ; 
            RJMP  UR3                 ; Byte 3 ist die Befehlslänge
            IN    R30, UDR            ;
            CBI   UCR, RXEN           ; 
            CBI   USR, RXC            ;
            STS   CMD_LEN,R30         ; Befehlslänge speichern
            EOR   R25, R30            ;
            MOV   R20, R30            ; Dest,Source
UR5:        SBI   UCR, RXEN           ; 
            SBIS  USR, RXC            ; RX Complete ? 
            RJMP  UR5                 ; 
            IN    R30, UDR            ;
            ST    X+,R30              ; Byte Speichern
            DEC   R20                 ;
            CPI   R20, 0x00           ;
            BREQ  UR6                 ;
            EOR   R25, R30            ;
            RJMP  UR5                 ;
UR6:        CP    R25,R30             ; Checksummenvergleich
            BRNE  UR_ERR              ;
            LDS   R30,CMD_LEN         ;
            DEC   R30                 ;
            STS   CMD_LEN, R30        ;
            RET                       ; Befehl gelesen: Typ in CMD_TYPE ; Sequenz in COMMAND
UR_ERR:     LDS   R30, CHECKSUM       ; Checksum error
            OUT   PORTC,R30           ; 
            LDS   R30, 0b11001110     ; Checksum error
            OUT   PORTC,R30           ; 
            RJMP  STOP                ;

INIT_CMD:   LDI  XL,LOW(COMMAND)     ; Speicherplatz für den Befehl (LOW )
            LDI  XH,HIGH(COMMAND)    ; Speicherplatz für den Befehl (HIGH)
            LDI  R20,50              ;
            LDI  R30,0x00            ;
I1:         ST   X+,R30              ; Byte Speichern
            DEC  R20                 ;
            BRNE I1                  ;
            RET                      ;


MARK1:      LDI   R30, 0b11111110    ; 
            OUT   PORTC,R30          ;
            RET                   
    
MARK2:      LDI   R30, 0b11111101    ; 
            OUT   PORTC,R30          ;
            RET                   

MARK3:      LDI   R30, 0b11111011    ; 
            OUT   PORTC,R30          ;
            RET                   

MARK4:      LDI   R30, 0b11110111    ; 
            OUT   PORTC,R30          ;
            RET                   

MARK5:      LDI   R30, 0b11101111    ; 
            OUT   PORTC,R30          ;
            RET                   


                                     ; Parameter setzen (C64 $ffba) -> $FE00
                                     ;                      C64  ATMEL
                                     ; logische Filenummer  $B8  FILE_NR  
                                     ; Geräteadresse        $BA  DEVICE_NR
                                     ; Sekundäradresse      $B9  SEK_ADR  
  
                                     ; Parameter setzen (C64 $ffbd) -> $FDF9
                                     ;                          C64  ATMEL
                                     ; File-/Befehlslänge       $B7  CMD_LEN
                                     ; Startadresse Befehl(LO)  $BB  LOW(COMMAND)
                                     ; Startadresse Befehl(HI)  $BC  HIGH(COMMAND)
             
                                     ; Open Routine (C64 $ffc0) -> $F34A

; Funktionen        : C64-Kernel :
; ================================
; SET_DATA          :            :
; CLEAR_DATA        :            :
; SET_CLK           :            :
; CLEAR_CLK         :            :
; SET_ATN           :            :
; CLEAR_ATN         :            :
; SET_RST           :            :
; CLEAR_RST         :            :
; GET_DATA          :            :
; GET_CLK           :            :
; READ_BYTE         :            :
; UNLISTEN          :            :
; UNTALK            :            :
; CLOSE_FILE        : F642       :
; SECLISTEN         :            :
; SECTALK           :            :
; SECCLOSE          :            :
; TALK              :            :
; LISTEN            : ED0C       :
; SEND_BYTE         :            :
; SEND_NOWAITBYTE   :            :
; LOAD              :            :
; IEC_OPEN          :            :
