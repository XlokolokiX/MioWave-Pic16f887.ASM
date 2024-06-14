;===============================================================================
;MOUTON, ALFONSO - LOPEZ, JOSE - MORÁN, MARCOS
    
;Mioelectric signals response goes from 10 to 500Hz, from Nyquist theorem we 
;just need to sample at 1KHz, but we choose to over sampling at a frequency of 2KHz
;Internal clock of 4MHZ PREESCALER: 2 TMR0: 6
;ADC 2uS TAD -Div:8 
    
;=============================================================================== 
    
    LIST p=16f887
    #include "p16f887.inc"

; CONFIG1
; __config 0x20D4
 __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
; __config 0x3EFF
 __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF 

;========================== CONFIGURATIONS =====================================
;Interruptions
CONF_INTCON	    EQU b'01110000'
CONF_OPTION_REG	    EQU b'00000101'
CONF_PIE1	    EQU b'01000001'
CONF_PIE2	    EQU b'00000000'
;Oscilador
OSCCON_CONF	    EQU b'01100001'
;Ports
CONF_TRISA	    EQU b'00000001'	;RA0:Señal Mioeléctrica RA7:Servo
CONF_TRISB	    EQU b'00000001'	;RB0:Boton RB5:LED RB4: Señal de config_mode
CONF_TRISD	    EQU b'00000000'	;Display Datos
CONF_TRISC	    EQU b'10000000'	;RC6:TX RC7:RX
CONF_TRISE	    EQU b'00000000'	;RE1: Disp0 RE2: Disp1
CONF_WPUB	    EQU b'00000001'
;ADC
CONF_ANSEL	    EQU b'00000001'
CONF_ADCON0	    EQU b'01000001'  
CONF_ADCON1	    EQU b'10000000'  
;Serial_Port
BAUD_VALUE	    EQU b'00001100'	;Baud Rate = 19,2k
RCSTA_CONF	    EQU b'10010000'
TXSTA_CONF	    EQU b'00100100'     ;BRGH = 1 | TXEN = 1
;TMR1
CONF_T1CON	    EQU b'00000001'
;Threshold
THRS_VALUE	    EQU 0X24
;===============================================================================
DATA_START_ADC EQU 0x70		;B1 Datos del Buff Circular
DATA_START_DISPLAY  EQU 0x35
  
    CBLOCK 0x20
    ;Contexto
    LAST_STATUS
    LAST_W
    
    ;Display
    N_DISP
    
    ;MovingAVR
    N_DATA		    ;Número de Datos a aplicar el filtro
    COUNT_DATA_CIRC
    COUNT_MOVING_AVERAGE
    MOVING_AVERAGE_H
    MOVING_AVERAGE_L
    COMPARATION_VALUE	    ;Contiene nibble inf_AvrH y nibble sup_AvrL 
    
    ;PWM
    COUNT_ON
    COUNT_OFF
    THRESHOLD
    SERVO_ON
    PULSO
    
    ;Boton
    COUNTER_A
    COUNTER_B
    CONFIG_MODE
    
    ;Puerto serie
    TX_DATO
    RX_DATO
    ENDC
    
;========================== PROGRAM ============================================
    ORG 0x00
    GOTO SETUP
    ORG 0x04
    GOTO ISR
    
DISPLAY_7SEG
    ADDWF PCL,F
    RETLW b'11000000'	;0
    RETLW b'11111001'	;1
    RETLW b'10100100'	;2
    RETLW b'10110000'	;3
    RETLW b'10011001'	;4
    RETLW b'10010010'	;5
    RETLW b'10000010'	;6
    RETLW b'11111000'	;7
    RETLW b'10000000'	;8
    RETLW b'10010000'	;9
    RETLW b'10001000'	;A
    RETLW b'10000011'	;B
    RETLW b'11000110'	;C
    RETLW b'10100001'	;D
    RETLW b'10000110'	;E
    RETLW b'10001110'	;F
CHANGE_DISPLAY
    ADDWF PCL, F
    RETLW b'11111101'
    RETLW b'11111011'
    
;========================== MAIN ===============================================
SETUP
    
    CALL INIT_SERIAL
    
    BANKSEL ANSEL	    ;B3
    MOVLW CONF_ANSEL
    MOVWF ANSEL
    CLRF ANSELH
    
    BCF STATUS, RP1	    ;B1
    MOVLW OSCCON_CONF
    MOVWF OSCCON
    MOVLW CONF_TRISA
    MOVWF TRISA
    MOVLW CONF_TRISB
    MOVWF TRISB
    MOVLW CONF_WPUB
    MOVWF WPUB
    MOVLW CONF_TRISC
    MOVWF TRISC
    MOVLW CONF_TRISD
    MOVWF TRISD
    MOVLW CONF_TRISE
    MOVWF TRISE
    MOVLW CONF_PIE1
    MOVWF PIE1
    MOVLW CONF_PIE2
    MOVWF PIE2
    MOVLW CONF_ADCON1
    MOVWF ADCON1
    MOVLW CONF_INTCON
    MOVWF INTCON
    MOVLW CONF_OPTION_REG
    MOVWF OPTION_REG
    
    BCF STATUS, RP0	    ;B0
    MOVLW CONF_ADCON0
    MOVWF ADCON0
    NOP
    NOP
    NOP
    CLRF PORTB
    CALL INIT_DISPLAY
    MOVLW CONF_T1CON
    MOVWF T1CON
    
    MOVLW .100		    ;PRESET TMR0
    MOVWF TMR0
    
    MOVLW 0X9C		    ;PRESET TMR1L 1ms
    MOVWF TMR1L
    MOVLW 0XFF		    ;PRESET TMR1H
    MOVWF TMR1H	
    
    CLRF PIR1
    
    ;Inicialización de Variables
    MOVLW .4
    MOVWF N_DATA
    CLRF COUNT_DATA_CIRC
    CLRF COUNT_MOVING_AVERAGE
    CLRF MOVING_AVERAGE_L
    CLRF MOVING_AVERAGE_H
    CLRF SERVO_ON
    CLRF PULSO
    CLRF CONFIG_MODE
    
    MOVLW THRS_VALUE
    MOVWF THRESHOLD
    
    BSF INTCON, GIE	    ;Enable all interrupts
LOOP
    GOTO LOOP
;===============================================================================   

;========================== INTERRUPCIONES =====================================
ISR
    MOVWF LAST_W
    SWAPF STATUS,W 
    MOVWF LAST_STATUS
    
    BTFSC   INTCON, T0IF    ;TMR0
    GOTO    UPDATE
    BTFSC   PIR1, ADIF	    ;ADC
    GOTO    SAVE_ADC_DATA
    BTFSC   PIR1, TMR1IF    ;TMR1
    GOTO    SERVO
    BTFSC   INTCON, INTF    ;Boton
    GOTO    BUTTON_TOGGLE
    BTFSC   PIR1, RCIF	    ;SERIAL
    GOTO    RECEIVE_DATA
    
ENDISR
    SWAPF LAST_STATUS, W
    MOVWF STATUS
    SWAPF LAST_W, F
    SWAPF LAST_W, W
    RETFIE
;===============================================================================
DELAY_10MS
    MOVLW .15
    MOVWF COUNTER_B
L2
    MOVLW .50
    MOVWF COUNTER_A
L1
    NOP
    DECFSZ COUNTER_A, F
    GOTO L1
    DECFSZ COUNTER_B, F
    GOTO L2
    RETURN
    
;========================== SUBRUTINAS =========================================
;FUNCION BOTON ----------------------------------------------------------------- 
BUTTON_TOGGLE
    BCF	INTCON, INTF
    
    CALL DELAY_10MS	    ;Antirrebote
    BTFSC PORTB, 0
    GOTO ENDISR
    
    ;COMF PORTB, F	    ;Prende Luz Indicadora
    INCF CONFIG_MODE, F
    
    BTFSS CONFIG_MODE, 0
    GOTO DISABLE_CONFIG
    GOTO ENABLE_CONFIG
    
DISABLE_CONFIG
    BANKSEL PIE1
    BCF PIE1, RCIE
    BANKSEL PIR1
    BCF PIR1, RCIF
    BCF PORTB, 5
    BCF PORTB, 4
    ;BSF STATUS, RP0
    ;BSF PIE1, TMR1IE
    ;BCF STATUS, RP0
    GOTO ENDISR

ENABLE_CONFIG
    BCF PIR1, RCIF
    BSF PORTB, 5
    BSF PORTB, 4
    CLRF RCREG
    BANKSEL PIE1
    BSF PIE1, RCIE
    BANKSEL RCREG
    CLRF RCREG
    ;BSF STATUS, RP0
    ;BCF PIE1, TMR1IE
    ;BCF STATUS, RP0
    GOTO ENDISR

;-------------------------------------------------------------------------------
;FUNCION DISPLAY --------------------------------------------------------------- 
INIT_DISPLAY
    MOVLW .0
    MOVWF 0x30
    MOVLW .0
    MOVWF 0x31
    CLRF N_DISP
    MOVF N_DISP, W
    CALL CHANGE_DISPLAY
    MOVWF PORTE
    MOVLW .0
    CALL DISPLAY_7SEG
    MOVWF PORTD
    RETURN

UPDATE
    BCF INTCON, T0IF
    MOVLW .100
    MOVWF TMR0
    BSF ADCON0, 1
    NOP
    
    ;Colocar Dato
    MOVF N_DISP, W
    ADDLW DATA_START_DISPLAY
    MOVWF FSR
    MOVF INDF, W
    CALL DISPLAY_7SEG
    MOVWF PORTD
    
    ;Multiplexar
    MOVF N_DISP, W
    CALL CHANGE_DISPLAY
    MOVWF PORTE
    INCF N_DISP, F
    MOVF N_DISP, W
    SUBLW .2
    BTFSC STATUS, Z
    CLRF N_DISP

    GOTO ENDISR
;-------------------------------------------------------------------------------  
    
;FUNCION ADQUISICION DATOS  ----------------------------------------------------     
SAVE_ADC_DATA
    BCF PIR1, ADIF
    
    ;Guarda Los Datos en el Buffer Circular
    BCF STATUS, IRP
    MOVLW DATA_START_ADC
    ADDWF COUNT_DATA_CIRC, W
    MOVWF FSR
    BSF STATUS, RP0
    MOVF ADRESL, W
    BCF STATUS, RP0
    MOVWF INDF
    INCF FSR, F
    MOVF ADRESH, W
    MOVWF INDF
    ;Incrementos
    INCF COUNT_DATA_CIRC, F
    INCF COUNT_DATA_CIRC, F
    BCF STATUS, C
    RLF N_DATA, W
    SUBWF COUNT_DATA_CIRC, W
    BTFSC STATUS, Z
    CLRF COUNT_DATA_CIRC
    
    CALL COMPUTE_MOVING_AVERAGE
    CALL COMPARE

    SWAPF MOVING_AVERAGE_H, W
    ANDLW 0xF0
    MOVWF COMPARATION_VALUE
    
    SWAPF MOVING_AVERAGE_L, W
    ANDLW 0x0F
    ADDWF COMPARATION_VALUE
    
    MOVF COMPARATION_VALUE, W
    ANDLW 0x0F
    MOVWF DATA_START_DISPLAY
    SWAPF COMPARATION_VALUE, W
    ANDLW 0x0F
    MOVWF DATA_START_DISPLAY+1
    
    CALL SEND_TX
    
    GOTO ENDISR
;-------------------------------------------------------------------------------    

;FUNCION MOVING AVERAGE --------------------------------------------------------     
COMPUTE_MOVING_AVERAGE        ; Calcula el promedio móvil y lo almacena en MOVING_AVERAGE_H-L
    CLRF MOVING_AVERAGE_L     ; Limpia la parte baja del promedio móvil
    CLRF MOVING_AVERAGE_H     ; Limpia la parte alta del promedio móvil
    
    MOVF N_DATA, W            ; Carga N_DATA
    MOVWF COUNT_MOVING_AVERAGE ; Copia N_DATA a COUNT_MOVING_AVERAGE

    MOVLW DATA_START_ADC      ; Carga la dirección de inicio del buffer
    MOVWF FSR                 ; Inicializa FSR con la dirección de inicio

LOOP_SUM
    MOVF INDF, W              ; Lee la parte baja del valor en el buffer
    ADDWF MOVING_AVERAGE_L, F ; Suma a MOVING_AVERAGE_L
    BTFSC STATUS, C           ; Si hubo un Carry,
    INCF MOVING_AVERAGE_H, F  ; incrementa MOVING_AVERAGE_H
    
    INCF FSR, F               ; Incrementa FSR para la parte alta del valor
    MOVF INDF, W              ; Lee la parte alta del valor en el buffer
    ADDWF MOVING_AVERAGE_H, F ; Suma a MOVING_AVERAGE_H
    
    INCF FSR, F               ; Incrementa FSR para el siguiente valor
    
    DECF COUNT_MOVING_AVERAGE, F ; Decrementa COUNT_MOVING_AVERAGE
    BTFSS STATUS, Z           ; Si COUNT_MOVING_AVERAGE no es cero,
    GOTO LOOP_SUM             ; repite el bucle

    ; Preparar para la división por N_DATA
    MOVF N_DATA, W            ; Carga N_DATA en W
    MOVWF COUNT_MOVING_AVERAGE ; Copia N_DATA a COUNT_MOVING_AVERAGE
LOOP_DIV
    BCF STATUS, C             ; Asegura que el Carry está limpio
    RRF MOVING_AVERAGE_H, F   ; Rota a la derecha la parte alta
    RRF MOVING_AVERAGE_L, F   ; Rota a la derecha la parte baja
    
    BCF STATUS, C
    RRF COUNT_MOVING_AVERAGE, F
    DECF COUNT_MOVING_AVERAGE, W
    
    BTFSS STATUS, Z
    GOTO LOOP_DIV
    
    RETURN                    ; Retorna de la subrutina
;------------------------------------------------------------------------------- 

;FUNCIONES SERVO  --------------------------------------------------------------
SERVO
    BCF PIR1, 0
    MOVLW 0X9C		    ;PRESET TMR1L 1ms
    MOVWF TMR1L
    MOVLW 0XFF		    ;PRESET TMR1H
    MOVWF TMR1H
    
    BTFSC CONFIG_MODE,0
    GOTO ENDISR
    
    BTFSC PULSO, 0
    GOTO TIME_ON
    GOTO TIME_OFF
    
TIME_ON
    BSF PORTA, 7
    DECFSZ COUNT_ON, F
    GOTO ENDISR
    BCF PULSO, 0
    
    MOVLW .180
    MOVWF COUNT_OFF
    
    GOTO ENDISR
    
TIME_OFF
    BCF PORTA, 7
    DECFSZ COUNT_OFF, F
    GOTO ENDISR
    BSF PULSO, 0
    
    MOVLW .10
    BTFSC SERVO_ON, 0
    MOVLW .20
    MOVWF COUNT_ON
    
    GOTO ENDISR  
    
COMPARE
    MOVF THRESHOLD, W
    SUBWF COMPARATION_VALUE, W
    BTFSC STATUS, C
    GOTO MAYOR_IGUAL
    GOTO MENOR_IGUAL
MAYOR_IGUAL 
    MOVLW .1
    MOVWF SERVO_ON
    RETURN
MENOR_IGUAL
    MOVLW .0
    MOVWF SERVO_ON
    RETURN
;------------------------------------------------------------------------------- 
    
;FUNCIONES TRANSMISION RECEPCION  ----------------------------------------------
INIT_SERIAL
    NOP
    BANKSEL SPBRG
    MOVLW BAUD_VALUE
    MOVWF SPBRG
    CLRF SPBRGH
    MOVLW TXSTA_CONF
    MOVWF TXSTA
    BANKSEL RCSTA
    MOVLW RCSTA_CONF
    MOVWF RCSTA
    CLRF TXREG
    CLRF RCREG
    RETURN
    
    
SEND_TX
    MOVF COMPARATION_VALUE, W
    MOVWF TX_DATO
    
    ;Envio el valor del comparation_value
    MOVF TX_DATO,W
    BANKSEL TXREG
    MOVWF TXREG
    BANKSEL TXSTA
    BTFSS TXSTA, TRMT ;Espero a que el dato se transmita antes de seguir con la ejecución
    GOTO $-1
    
    BCF STATUS, RP0
    RETURN

RECEIVE_DATA
    BCF PIR1, RCIF
    BANKSEL PIE1
    BTFSS PIE1, RCIE ;Verifico si estoy en el modo de configuracion 
    GOTO ENDISR; Si no estoy RCIE estara desactivado por lo tanto salgo de la interrupcion
    BANKSEL RCREG
    MOVF RCREG, W
    MOVWF RX_DATO
    MOVF RX_DATO, W
    MOVWF THRESHOLD ;Guardo el dato recibido en una variable y lo cargo al treshold
    GOTO ENDISR
;------------------------------------------------------------------------------- 
;===============================================================================
    
    END