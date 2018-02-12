;****************** main.s ***************
; Program written by: Samed Duzcay, Nikhil Arora
; Date Created: 2/4/2017
; Last Modified: 1/15/2018
; Brief description of the program
;   The LED toggles at 8 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE0 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE0 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 8Hz,
;      which is 8 times per second with a duty-cycle of 20%.
;      Therefore, the LED is ON for (0.2*1/8)th of a second
;      and OFF for (0.8*1/8)th of a second.
;   3) When the button on (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 20% to 40% to 60%
;      to 80% to 100%(ON) to 0%(Off) to 20% to 40% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 8Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 20%.
;      TIP: debugging the breathing LED algorithm and feel on the simulator is impossible.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608

COUNT EQU 50000

     IMPORT  TExaS_Init
     THUMB
     AREA    DATA, ALIGN=2
;global variables go here
	 
     AREA    |.text|, CODE, READONLY, ALIGN=2
     THUMB
     EXPORT  Start
Start	
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init ; voltmeter, scope on PD3
 ; Initialization goes here
     LDR R1, =SYSCTL_RCGCGPIO_R      ; 1) activate clock for Port F and E
    LDR R0, [R1]
    ORR R0, R0, #0x30               ; set bit 5 and 4 to turn on clock
    STR R0, [R1]
	NOP
	NOP
    NOP
    NOP                             ; allow time for clock to finish
    LDR R1, =GPIO_PORTF_LOCK_R      ; 2) unlock the lock register
    LDR R0, =0x4C4F434B             ; unlock GPIO Port F Commit Register
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_CR_R        ; enable commit for Port F
    MOV R0, #0xFF                   ; 1 means allow access
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_DIR_R       ; 5) set direction register
    MOV R0,#0x00                    ; PF4 input
    STR R0, [R1]
    LDR R1, =GPIO_PORTE_DIR_R       ; 5) set direction register
    MOV R0,#0x01                    ; PE0 output, PE1 input
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_AFSEL_R     ; 6) regular port function
    MOV R0, #0                      ; 0 means disable alternate function
    STR R0, [R1]
    LDR R1, =GPIO_PORTE_AFSEL_R     ; 6) regular port function
    MOV R0, #0                      ; 0 means disable alternate function
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_PUR_R       ; pull-up resistors for PF
    MOV R0, #0x10                   ; enable weak pull-up on PF4
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_DEN_R       ; 7) enable Port F digital port
    MOV R0, #0xFF                   ; 1 means enable digital I/O
    STR R0, [R1]
    LDR R1, =GPIO_PORTE_DEN_R       ; 7) enable Port E digital port
    MOV R0, #0xFF                   ; 1 means enable digital I/O
    STR R0, [R1]
	MOV R9, #10 ; constant 10
	MOV R8, #2 ; duty cycle
	MOV R7, R8
	MOV R6, #0 ; PE1 pressed
     CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
loop 
	 LDR R0, =GPIO_PORTE_DATA_R
	 LDR R1, [R0]
	 AND R2, R1, #0x01
	 CMP R2, #0
	 BNE loop_low
	 ; loop high
	 MOV R7, R8
	 B loop_end
loop_low
	 SUB R7, R9, R8
loop_end
	 ; alternate the signal only if duty cycle is not 0
	 CMP R7, #0
	 BEQ loop_end_2
	 EOR R1, R1, #0x01 ; low/high alternate
loop_end_2
	 STR R1, [R0]
	 AND R2, R1, #0x02
	 CMP R2, #2
	 BEQ pe1_pressed
pe1_not_pressed
     CMP R6, #1
	 BEQ increment_duty_cycle ; pressed before and now released
	 B delay
pe1_pressed
	 MOV R6, #1
	 B delay
increment_duty_cycle
	MOV R6, #0 ; reset PE1 pressed status
	ADD R8, #2
	CMP R8, #10
	BGE duty_cycle_mod_10
	B delay
duty_cycle_mod_10
	SUB R8, #10
delay
	LDR R0, =COUNT
	MUL R0, R7
dloop
	SUBS R0, #1
	BGT dloop
	B loop

     ALIGN      ; make sure the end of this section is aligned
     END        ; end of file

