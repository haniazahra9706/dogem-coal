; COAL PROJECT FALL 2025 (Khadija Rao (24L-3042) & Hania Zahra (24L-3065))
[org 0x0100]

    jmp start

carRow: dw 19			 	; starting row (0–24)
carCol: dw 38 			 	; starting column (0–79)
oldCarCol: dw 38
savedLine: times 160 db 0	; buffer to store the bottom row to move it on top
savedLineCount: db 0		; number of rows saved (in this case 1 row only)

otherCar1Row: dw 0        	; row position of other car 1 (0 = not active)
otherCar1Col: dw 0        	; column position
otherCar2Row: dw 0        	; row position of other car 2
otherCar2Col: dw 0

coin1Row: dw 0              ; row position of coin 1 (0 = not active)
coin1Col: dw 0              ; column position
coin2Row: dw 0              ; row position of coin 2
coin2Col: dw 0
coin3Row: dw 0              ; row position of coin 3
coin3Col: dw 0

isPaused: db 0
waitingForExitConfirm: db 0
randomSeed: dw 0         	; for random number generation
frameCounter: dw 0       	; to track frames for spawning
gameOver: db 0            	; 0 = playing, 1 = game over
score: dw 0                 ; player's score

lane1Col: dw 26
lane2Col: dw 38
lane3Col: dw 50
currentLane: db 2

oldKbdISR: dd 0
oldTimerISR: dd 0
timerTicks: dw 0
timerUpdateFlag: db 0

scoreLabel: db 'SCORE:  '

;screen buffers for pause/exit screens
gameScreenBuffer: times 2000 dw 0
pauseScreenBuffer: times 2000 dw 0
exitScreenBuffer: times 2000 dw 0

; intro screen wala stuff
loading: db 'LOADING... $'
gaemName: db 'dogem $'
gaemName0: db '.___                                   $'
gaemName1: db '  __| _/ ____    ____   ____    _____  $'
gaemName2: db ' / __ | /  _ \  / ___\ / __ \  /     \$' 
gaemName3: db '/ /_/ |(  <_> )/ /_/  >  ___/ |  Y Y  \$'
gaemName4: db '\____ | \____/ \___  / \___  >|__|_|  /$'
gaemName5: db '     \/       /_____/      \/       \/$'
rollNo: db 'Made By: $'
hania: db 'Hania Zahra (24L-3065) $'
khadija: db 'Khadija Rao (24L-3042) $'
course: db 'COAL Fall 2025 $'

; pause screen stuff
pause0: db '  ________                                   .___$'
pause1: db '  \______  \____   __ __  ______ ____   __| _/$'
pause2: db '   |     ___\__  \ |  |  \/  ___// __ \ / __ | $'
pause3: db '   |    |    / __ \|  |  /\___ \\  ___// /_/ | $'
pause4: db '   |____|   (____  /____//____  >\___  >____ | $'
pause5: db '                 \/           \/     \/     \/ $'
resumeMessage: db 'Press R to Resume $'

; final window wala stuff
gaemOver0: db '  ________                        ________                     $'
gaemOver1: db ' /  _____/_____    _____   ____   \_____  \___  __ ___________ $'
gaemOver2: db '/   \  ___\__  \  /     \_/ __ \   /   |   \  \/ // __ \_  __ \$'
gaemOver3: db '\    \_\  \/ __ \|  Y Y  \  ___/  /    |    \   /\  ___/|  | \/$'
gaemOver4: db ' \______  (____  /__|_|  /\___  > \_______  /\_/  \___  >__|   $'
gaemOver5: db '        \/     \/      \/     \/          \/          \/       $' 

pressKeyMsg: db 'Press any key to exit$'
finalScoreMsg: db 'FINAL SCORE: $'
finalTimeMsg: db 'TIME: $'

; exit screen wala stuff
exit0: db '  ___________      .__  __  $'
exit1: db '  \_   _____/__  __|__|/  |_ $'
exit2: db '   |    __)_\  \/  /  \   __| $'
exit3: db '   |        \>    <|  ||  |  $'
exit4: db '  /_______  /__/\_ \__||__| $'
exit5: db '          \/      \/              $'

exitConfirmMsg: db 'Are you sure you want to exit?$'
exitChoiceMsg: db 'Press Y (Yes) or N (No)$'

timerisr:
		push ax
		push ds
		
		mov ax,cs
		mov ds,ax
		
		inc word [timerTicks]
		
		; checks if enough ticks have passed for game updates
		cmp word [timerTicks],1
		jb endTimer
		
		; reset tick counter
		mov word [timerTicks],0
		
		; only updte game logic if not paused and not in exit confirmation
		cmp byte [isPaused],1
		je endTimer
		cmp byte [waitingForExitConfirm],1
		je endTimer
		cmp byte [gameOver],1
		je endTimer
		
		; set flag to indicate timer triggered update
		mov byte [timerUpdateFlag],1
    
endTimer:
		mov al,0x20
		out 0x20,al
		
		pop ds
		pop ax
		iret

kbisr:
		push ax
		push es

		in al,0x60     ; read keyboard scan code

		; if waiting for exit confirmation, only process Y/N
		cmp byte [waitingForExitConfirm],1
		jne normalProcessing

		; exit confirmation mode -> checks Y/N
		cmp al,0x15    ; 'Y' key scan code (make)
		je exitConfirmY
		cmp al,0x31    ; 'N' key scan code (make)  
		je exitConfirmN
		jmp nomatch

normalProcessing:
		; check for esc key first
		cmp al,0x01    ; ESC key scan code
		je exitGamePrompt

		cmp al,0x19    ; scan code for 'P'
		je pauseGame

		cmp al,0x13    ; scan code for 'R'
		je resumeGame

		; if game is paused, ignore movement keys
		cmp byte [isPaused],1
		je nomatch

		cmp al,0x4B    ; left arrow scan code
		je moveLeft

		cmp al,0x4D    ; right arrow scan code
		je moveRight

		jmp nomatch

exitConfirmY:
		; user pressed 'Y' -> confirm exit
		mov byte [waitingForExitConfirm],0
		mov byte [gameOver],1
		jmp nomatch

exitConfirmN:
		; user pressed 'N' -> cancel exit
		mov byte [waitingForExitConfirm],0
		jmp nomatch

exitGamePrompt:
		; only set exit confirmation if game is not over and not already waiting
		cmp byte [gameOver],1
		je nomatch
		cmp byte [waitingForExitConfirm],1
		je nomatch
		mov byte [waitingForExitConfirm],1
		jmp nomatch

pauseGame:
		mov byte [isPaused],1
		jmp nomatch

resumeGame:
		mov byte [isPaused],0
		jmp nomatch

moveLeft:
		cmp byte [currentLane],1
		je nomatch

		; store current position as old position before moving
		mov ax,[carCol]
		mov [oldCarCol],ax

		dec byte [currentLane]

		mov al,[currentLane]
		cmp al,1
		je setLane1
		cmp al,2
		je setLane2
		jmp nomatch

moveRight:
		cmp byte [currentLane],3
		je nomatch

		; store current position as old position before moving
		mov ax,[carCol]
		mov [oldCarCol],ax

		inc byte [currentLane]

		mov al,[currentLane]
		cmp al,2
		je setLane2
		cmp al,3
		je setLane3
		jmp nomatch

setLane1:
		mov ax,[lane1Col]
		mov [carCol],ax
		jmp nomatch

setLane2:
		mov ax,[lane2Col]
		mov [carCol],ax
		jmp nomatch

setLane3:
		mov ax,[lane3Col]
		mov [carCol],ax
		jmp nomatch

nomatch:
		mov al,0x20
		out 0x20,al

		pop es
		pop ax
		iret

hookKeyboard:
		push ax
		push bx
		push es

		xor ax,ax
		mov es,ax
		mov ax,[es:9*4]
		mov [oldKbdISR],ax
		mov ax,[es:9*4+2]
		mov [oldKbdISR+2],ax

		cli
		mov word [es:9*4],kbisr
		mov [es:9*4+2],cs
		sti

		pop es
		pop bx
		pop ax
		ret

unhookKeyboard:
		push ax
		push es

		xor ax,ax
		mov es,ax
		
		cli
		mov ax,[oldKbdISR]
		mov [es:9*4],ax
		mov ax,[oldKbdISR+2]
		mov [es:9*4+2],ax
		sti

		pop es
		pop ax
		ret

; hook timer interrupt
hookTimer:
		push ax
		push es
		
		xor ax, ax
		mov es, ax
		
		; save old timer isr
		mov ax,[es:8*4]
		mov [oldTimerISR],ax
		mov ax,[es:8*4+2]
		mov [oldTimerISR+2],ax
		
		cli
		mov word [es:8*4],timerisr
		mov [es:8*4+2],cs
		sti
		
		pop es
		pop ax
		ret

; unhook timer interrupt
unhookTimer:
		push ax
		push es
		
		xor ax,ax
		mov es,ax
		
		cli
		mov ax,[oldTimerISR]
		mov [es:8*4],ax
		mov ax,[oldTimerISR+2]
		mov [es:8*4+2],ax
		sti
		
		pop es
		pop ax
		ret

; functions to print colored string on intro, final and intermediate screens
prtStrColor:
		push ax
		push bx
		push cx
		push dx
		push si
		
		mov si,dx
printLoop1:
		lodsb
		cmp al,'$'
		je donePrint
		
		mov ah,0x09
		mov bh,0
		mov cx,1
		int 0x10
		
		mov ah,0x03
		mov bh,0
		int 0x10
		
		inc dl
		mov ah,0x02
		mov bh,0
		int 0x10
		
		jmp printLoop1
    
donePrint:
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret

; intro loading window
loadingScreen:
		push ax
		push bx
		push cx
		push es
		push di
		
		mov dh,5
		mov dl,22
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,gaemName0
		mov bl,0x05
		call prtStrColor
		
		mov dh,6
		mov dl,22
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,gaemName1
		mov bl,0x05
		call prtStrColor
		
		mov dh,7
		mov dl,22
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,gaemName2
		mov bl,0x05
		call prtStrColor
		
		mov dh,8
		mov dl,22
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,gaemName3
		mov bl,0x05
		call prtStrColor
		
		mov dh,9
		mov dl,22
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,gaemName4
		mov bl,0x05
		call prtStrColor
		
		mov dh,10
		mov dl,22
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,gaemName5
		mov bl,0x05
		call prtStrColor
		
		mov dh,13
		mov dl,37
		mov ah,0x02
		int 0x10
		mov dx,rollNo
		mov bl,0x0E
		call prtStrColor
		
		mov dh,14
		mov dl,30
		mov ah,0x02
		int 0x10
		mov dx,hania
		mov bl,0x0E
		call prtStrColor
		
		mov dh,15
		mov dl,30
		mov ah,0x02
		int 0x10
		mov dx,khadija
		mov bl,0x0E
		call prtStrColor
		
		mov dh,16
		mov dl,34
		mov ah,0x02
		int 0x10
		mov dx,course
		mov bl,0x0e
		call prtStrColor
		
		mov dh,20
		mov dl,50
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,loading
		mov bl,0x0E
		call prtStrColor
		
		mov ax,0xb800
		mov es,ax
		mov di,2920
		mov ah,0x05
		mov al,0xdb
		mov cx,40
upper:
		mov [es:di],ax
		add di,2
		call delay
		loop upper
		
		pop di
		pop es
		pop cx
		pop bx
		pop ax
		ret

; final window
printGameOver:
		push ax
		push bx
		push cx
		push dx
		push si
		push di

		mov ax,0x0003
		int 10h

		mov dh,5
		mov dl,11
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,gaemOver0
		mov bl,0x05
		call prtStrColor
		
		mov dh,6
		mov dl,11
		mov ah,0x02
		int 0x10
		mov dx,gaemOver1
		mov bl,0x05
		call prtStrColor
		
		mov dh,7
		mov dl,11
		mov ah,0x02
		int 0x10
		mov dx,gaemOver2
		mov bl,0x05
		call prtStrColor
		
		mov dh,8
		mov dl,11
		mov ah,0x02
		int 0x10
		mov dx,gaemOver3
		mov bl,0x05
		call prtStrColor
		
		mov dh,9
		mov dl,11
		mov ah,0x02
		int 0x10
		mov dx,gaemOver4
		mov bl,0x05
		call prtStrColor
		
		mov dh,10
		mov dl,11
		mov ah,0x02
		int 0x10
		mov dx,gaemOver5
		mov bl,0x05
		call prtStrColor

		mov dh,13
		mov dl,34
		mov ah,0x02
		int 0x10
		mov dx,finalScoreMsg
		mov bl,0x0E
		call prtStrColor

		mov dh,13
		mov dl,47
		mov ah,0x02
		int 0x10
		mov ax,[score]
		call printNumber

		mov dh,16
		mov dl,30
		mov ah,0x02
		int 0x10
		mov dx, pressKeyMsg
		mov bl,0x0E
		call prtStrColor

		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret

printNumberGray:
		push ax
		push bx
		push cx
		push dx
		push si
		
		mov cx,0
		mov si,10

		cmp ax,0
		jne .convert
		mov al,'0'
		call printChar
		jmp .done

.convert:
		xor dx, dx
		div si
		push dx
		inc cx
		test ax, ax
		jnz .convert

.print:
		pop ax
		add al, '0'
		call printCharGray
		loop .print

.done:
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret

printCharGray:
		push ax
		push bx
		push cx
		
		mov ah,0x09
		mov bh,0
		mov bl,0x0E
		int 0x10
		
		pop cx
		pop bx
		pop ax
		ret

printNumber:
		push ax
		push bx
		push cx
		push dx
		push si
		
		mov cx,0
		mov si,10
		cmp ax,0
		jne convert
		mov al,'0'
		call printChar
		jmp done_print
convert:
		xor dx,dx
		div si
		push dx
		inc cx
		test ax,ax
		jnz convert
print:
		pop ax
		add al,'0'
		call printChar
		loop print
done_print:
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret

printChar:
		push ax
		push bx
		push cx
		
		mov ah,0x09
		mov bh,0            ; page 0
		mov bl,0x0E         ; yewwow
		mov cx,1            ; print 1 character
		int 0x10
		
		; move cursor forward
		mov ah,0x03         ; get cursor position
		mov bh,0
		int 0x10
		inc dl              ; move to next column
		mov ah,0x02         ; set cursor position
		mov bh,0
		int 0x10
		
		pop cx
		pop bx
		pop ax
		ret

; save current screen to buffer
saveScreen:
		push ax
		push cx
		push di
		push si
		push es
		push ds

		mov ax,0xb800
		mov ds,ax
		push cs
		pop es
		
		mov di,si
		xor si,si 
		mov cx,2000
		
		cld
		rep movsw

		pop ds
		pop es
		pop si
		pop di
		pop cx
		pop ax
		ret

; restore screen from buffer
restoreScreen:
		push ax
		push cx
		push di
		push si
		push es
		push ds

		mov ax,cs
		mov ds,ax
		mov ax,0xb800
		mov es,ax
		
		mov di,0
		mov cx,2000
		
		cld
		rep movsw

		pop ds
		pop es
		pop si
		pop di
		pop cx
		pop ax
		ret

clearScreen:
		push ax
		push cx
		push di
		push es

		mov ax,0xb800
		mov es,ax
		xor di,di
		mov ax,0x720
		; mov ah,0x07
		; mov al,' '
		mov cx,2000
		
		cld
		rep stosw

		pop es
		pop di
		pop cx
		pop ax
		ret

; pause screen
showPauseScreen:
		push ax
		push bx
		push cx
		push dx
		push si
		push di
		
		; save current game screen
		mov si,gameScreenBuffer
		call saveScreen
		
		; clear screen
		call clearScreen
		
		; display "paused"
		mov dh,8
		mov dl,16
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,pause0
		mov bl,0x05
		call prtStrColor
		
		mov dh,9
		mov dl,16
		mov ah,0x02
		int 0x10
		mov dx,pause1
		mov bl,0x05
		call prtStrColor
		
		mov dh,10
		mov dl,16
		mov ah,0x02
		int 0x10
		mov dx,pause2
		mov bl,0x05
		call prtStrColor
		
		mov dh,11
		mov dl,16
		mov ah,0x02
		int 0x10
		mov dx,pause3
		mov bl,0x05
		call prtStrColor
		
		mov dh,12
		mov dl,16
		mov ah,0x02
		int 0x10
		mov dx,pause4
		mov bl,0x05
		call prtStrColor
		
		mov dh,13
		mov dl,16
		mov ah,0x02
		int 0x10
		mov dx,pause5
		mov bl,0x05
		call prtStrColor
		
		; display resume message
		mov dh,16
		mov dl,32
		mov ah,0x02
		int 0x10
		mov dx,resumeMessage
		mov bl,0x0E
		call prtStrColor
		
		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret

hidePauseScreen:
		push si
		
		; restore the game screen
		mov si,gameScreenBuffer
		call restoreScreen
		
		pop si
		ret

; show exit confirmation screen  
showExitConfirmationScreen:
		push ax
		push bx
		push cx
		push dx
		push si
		push di
		
		; save current game screen
		mov si,gameScreenBuffer
		call saveScreen
		
		; clear screen with red background
		mov ax,0003h
		int 10h
		
		; display "exit"
		mov dh,6
		mov dl,24
		mov bh,0
		mov ah,0x02
		int 0x10
		mov dx,exit0
		mov bl,0x05
		call prtStrColor
		
		mov dh,7
		mov dl,24
		mov ah,0x02
		int 0x10
		mov dx,exit1
		mov bl,0x05
		call prtStrColor
    
		mov dh,8
		mov dl,24
		mov ah,0x02
		int 0x10
		mov dx,exit2
		mov bl,0x05
		call prtStrColor
    
		mov dh,9
		mov dl,24
		mov ah,0x02
		int 0x10
		mov dx,exit3
		mov bl,0x05
		call prtStrColor
		
		mov dh,10
		mov dl,24
		mov ah,0x02
		int 0x10
		mov dx,exit4
		mov bl,0x05
		call prtStrColor
		
		mov dh,11
		mov dl,24
		mov ah,0x02
		int 0x10
		mov dx,exit5
		mov bl,0x05
		call prtStrColor
    
		; display confirmation message
		mov dh,14
		mov dl,24
		mov ah,0x02
		int 0x10
		mov dx,exitConfirmMsg
		mov bl,0x0E
		call prtStrColor
    
		; display choice message
		mov dh,16
		mov dl,27
		mov ah,0x02
		int 0x10
		mov dx,exitChoiceMsg
		mov bl,0x0E
		call prtStrColor
    
		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret

; hide exit confirmation screen
hideExitConfirmationScreen:
		push si
		
		; restore the game screen
		mov si,gameScreenBuffer
		call restoreScreen
		
		pop si
		ret

handleExitConfirmation:
		push ax
		push bx
		push cx
		push dx
		push si
		push di
		push es

		; display full screen exit confirmation
		call showExitConfirmationScreen

; wait for Y/N decision
waitLoop:
		cmp byte [waitingForExitConfirm],0
		jne waitLoop

		; hide the confirmation screen
		call hideExitConfirmationScreen

		pop es
		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret

printLandscape:
		push bp
		mov bp,sp
		push es
		push ax
		push cx
		push di
		
		mov ax,0xb800
		mov es,ax
	
		;left side (cols 0-19,all 25 rows)
		xor di,di
		mov ah,0x20 						; green grass :p
		mov al,' ' 							; 0x20 -> space 
		mov cx,25 							; for all 25 rows
leftLoop:
		push cx
		mov cx,20 							; 20 cols
		cld
		rep stosw
		add di,120
		pop cx
		loop leftLoop
	
		; right side (cols 60-79, all 25 rows)
		mov di,120
		mov cx,25 							; rows
rightLoop:
		push cx
		mov cx,20 							; 20 cols
		cld
		rep stosw
		add di,120
		pop cx
		loop rightLoop
	
		pop di
		pop cx
		pop ax
		pop es
		pop bp
	
		ret

printRoad:
		push bp
		mov bp,sp
		push es
		push ax
		push cx
		push di
		
		mov ax,0xb800
		mov es,ax
	
		; yellow border left (cols 20-21)
		mov di,40
		mov ah,0x0e
		mov al,0xdb
		mov cx,25 							; for all 25 rows
		
yellowLeftLoop:
		push cx
		mov cx,2 							; 2 cols
		rep stosw
		add di,156
		pop cx
		loop yellowLeftLoop
	
		; yellow border right (cols 58-59)
		mov di,116
		mov cx,25 							; for all 25 rows
		
yellowRightLoop:
		push cx
		mov cx,2 							; 2 cols
		rep stosw
		add di,156
		pop cx
		loop yellowRightLoop
	
		;gray road (cols 22-57)
		mov di,44
		mov ah,0x08
		mov al,' '							; 0x20 -> space
		mov cx,25 							; for all 25 rows
roadLoop:
		push cx
		mov cx,36 							; 36 cols
		cld
		rep stosw
		add di,88
		pop cx
		loop roadLoop
	
		; first divider at col 34
		mov di,68 							; (34*2)
		mov ah,0x70							; white dividers
		mov al,' '							; 0x20 -> space 
		mov cx,25 							; for all 25 rows
divider1Loop:
		mov bx,cx
		and bx,7 							; dash pattern every 8 rows
		cmp bx,4 							; length per divider
		jge skipDash1
		mov [es:di],ax
skipDash1:
		add di,160
		loop divider1Loop
	
		; second divider at col 46
		mov di,92 							; (46*2)
		mov cx,25 							; for all 25 rows
divider2Loop:
		mov bx,cx
		and bx,7
		cmp bx,4
		jge skipDash2
		mov [es:di],ax
skipDash2:
		add di,160
		loop divider2Loop
	
		pop di
		pop cx
		pop ax
		pop es
		pop bp
	
		ret
printTrees:
		push bp
		mov bp,sp
		push es
		push ax
		push di
		mov ax,0xb800
		mov es,ax
	
		; left side trees
		mov di,666						 ; tree 1 (row 4, col 13) = (3*160 + 13*2)
		call drawTree
	
		mov di,1450 					 ; tree 2 (row 9, col 5) = (9*160 + 5*2)
		call drawTree
	
		mov di,2426 			 		 ; tree 3 (row 15, col 13) = (15*160 + 13*2)
		call drawTree
	
		mov di,3530 					 ; tree 4 (row 22, col 5) = (22*160 + 5*2)
		call drawTree
	
		; right side trees
		mov di,770 						 ; tree 5 (row 4, col 65) = (3*160 + 65*2)
		call drawTree
	
		mov di,1590 					 ; tree 6 (row 9, col 75) = (9*160 + 75*2)
		call drawTree
	
		mov di,2530 					 ; tree 7 (row 15, col 65) = (15*160 + 65*2)
		call drawTree
	
		mov di,3670 					 ; tree 8 (row 22, col 75) = (22*160 + 75*2)
		call drawTree
	
		pop di
		pop ax
		pop es
		pop bp
	
		ret

drawTree:
		push bp
		mov bp,sp
		push di
	
		mov ah,0x2A						 ; bright greeen cuz idk it looks pretty like that
		mov al,0x0F						 ; sun looking symbol :p
	
		; top point
		mov [es:di],ax
	
		; upper
		sub di,160
		mov [es:di-2],ax
		mov [es:di],ax
		mov [es:di+2],ax
	
		; middle
		sub di,160
		mov [es:di-4],ax
		mov [es:di-2],ax
		mov [es:di],ax
		mov [es:di+2],ax
		mov [es:di+4],ax
	
		; lower
		sub di,160
		mov [es:di-2],ax
		mov [es:di],ax
		mov [es:di+2],ax
	
		; trunk
		mov ah,0x067 							 ; brown trunk
		mov al,0x0F								 ; sun looking symbol part 2 cuz texture :p
	
		add di,320
		mov [es:di],ax
	
		add di,160
		mov [es:di],ax
	
		pop di
		pop bp
		ret

printCar:
		push bp
		mov bp,sp
		push es
		push ax
		push di

		mov ax,0xb800
		mov es,ax

		; calculate car start position using globals
		mov ax,[carRow]
		mov bx,160
		mul bx
		mov di,ax

		mov ax,[carCol]
		shl ax,1
		add di,ax

		; top of car
		mov ah,0x55
		mov al,' '
		mov cx,5

printTop:
		mov [es:di],ax
		add di,2
		loop printTop

		; middle row with windshield
		add di,150
		mov ah,0x11
		mov al,0xdb
		mov [es:di+2],ax
		mov [es:di+4],ax
		mov [es:di+6],ax

		mov ah,0x0E
		mov [es:di],ax
		mov [es:di+8],ax

		; red stripe row
		add di,160
		mov ah,0x55; 11001100b
		mov al,' '

		mov cx, 5

printBottom:
		mov [es:di],ax
		add di,2
		loop printBottom

		pop di
		pop ax
		pop es
		pop bp
		ret

printScreens:
		push bp
		mov bp,sp
		push es
		push ax
		push di
		push si
		push cx
		push bx

		mov ax,0xb800
		mov es,ax

		mov di,0
		mov si,scoreLabel
		mov cx,8
		mov ah,0x0e

scoreLabelLoop:
		mov al,[si]
		mov [es:di],ax
		add di,2
		inc si
		loop scoreLabelLoop

		mov ax,[score]
		mov bx,10
		mov cx,0

scoreConvert:
		mov dx,0
		div bx
		push dx
		inc cx
		cmp ax,0
		jne scoreConvert

		mov di,16

scorePrint:
		pop dx
		add dl,'0'
		mov ah,0x0e
		mov al,dl
		mov [es:di],ax
		add di,2
		loop scorePrint

		pop bx
		pop cx
		pop si
		pop di
		pop ax
		pop es
		pop bp
		ret

getRandom:
		push dx
		mov ax,[randomSeed]
		mov dx,0x8405
		mul dx
		inc ax
		mov [randomSeed],ax
		pop dx
		ret

spawnCoins:
		push bp
		mov bp,sp

		mov ax,[frameCounter]
		and ax,63
		cmp ax,10
		jne trySpawnCoin2

		cmp word [coin1Row],0
		jne trySpawnCoin2

		mov word [coin1Row],1
		call getRandom
		mov dx,0
		mov bx,3
		div bx
		cmp dx,0
		je lane1_coin1
		cmp dx,1
		je lane2_coin1
		mov word [coin1Col],51
		jmp trySpawnCoin2

lane1_coin1:
		mov word [coin1Col],28
		jmp trySpawnCoin2

lane2_coin1:
		mov word [coin1Col],40

trySpawnCoin2:
		mov ax,[frameCounter]
		and ax,63
		cmp ax,25
		jne trySpawnCoin3

		cmp word [coin2Row],0
		jne trySpawnCoin3

		mov word [coin2Row],1
		call getRandom
		mov dx,0
		mov bx,3
		div bx
		cmp dx,0
		je lane1_coin2
		cmp dx,1
		je lane2_coin2
		mov word [coin2Col],51
		jmp trySpawnCoin3

lane1_coin2:
		mov word [coin2Col],28
		jmp trySpawnCoin3

lane2_coin2:
		mov word [coin2Col],40

trySpawnCoin3:
		mov ax,[frameCounter]
		and ax,63
		cmp ax,40
		jne spawnCoinsDone

		cmp word [coin3Row],0
		jne spawnCoinsDone

		mov word [coin3Row],1
		call getRandom
		mov dx,0
		mov bx,3
		div bx
		cmp dx,0
		je lane1_coin3
		cmp dx,1
		je lane2_coin3
		mov word [coin3Col],51
		jmp spawnCoinsDone

lane1_coin3:
		mov word [coin3Col],28
		jmp spawnCoinsDone

lane2_coin3:
		mov word [coin3Col],40

spawnCoinsDone:
		pop bp
		ret

printCoin:
		push bp
		mov bp,sp
		push es
		push ax
		push bx
		push di
		
		mov ax,0xb800
		mov es,ax
		
		mov ax,[bp+4]
		mov bx,160
		mul bx
		
		mov bx,[bp+6]
		shl bx,1
		add ax,bx
		mov di,ax
		
		mov ah,0xEE
		mov al,'O'
		mov [es:di],ax
		mov [es:di+2],ax
		
		pop di
		pop bx
		pop ax
		pop es
		pop bp
		ret 4

eraseCoin:
		push bp
		mov bp,sp
		push es
		push ax
		push bx
		push di
		
		mov ax,0xb800
		mov es,ax
		
		mov ax,[bp+4]
		mov bx,160
		mul bx
		
		mov bx,[bp+6]
		shl bx,1
		add ax,bx
		mov di,ax
		
		mov ah,0x08
		mov al,0x20 ; space
		mov [es:di],ax
		mov [es:di+2],ax
		
		pop di
		pop bx
		pop ax
		pop es
		pop bp
		ret 4

updateCoins:
		push bp
		mov bp,sp

		cmp word [coin1Row],0
		je skipCoin1

		push word [coin1Col]
		push word [coin1Row]
		call eraseCoin

		inc word [coin1Row]

		cmp word [coin1Row],25
		jl skipCoin1
		mov word [coin1Row],0

skipCoin1:
		cmp word [coin2Row],0
		je skipCoin2

		push word [coin2Col]
		push word [coin2Row]
		call eraseCoin

		inc word [coin2Row]

		cmp word [coin2Row],25
		jl skipCoin2
		mov word [coin2Row],0

skipCoin2:
		cmp word [coin3Row],0
		je skipCoin3

		push word [coin3Col]
		push word [coin3Row]
		call eraseCoin

		inc word [coin3Row]

		cmp word [coin3Row],25
		jl skipCoin3
		mov word [coin3Row],0

skipCoin3:
		pop bp
		ret

checkCoinCollection:
		push bp
		mov bp,sp
		push ax
		push bx
		push cx
		push dx

		; check coin1
		cmp word [coin1Row],0
		je checkCoin2

		; check vertical overlap (all 3 rows of player car)
		mov ax,[coin1Row]
		mov bx,[carRow]
		mov cx,bx
		add cx,2

		cmp ax,bx
		jl checkCoin2
		cmp ax,cx
		jg checkCoin2

		; check horizontal overlap (all 5 columns of player car)
		mov ax,[coin1Col]
		mov bx,[carCol]
		mov cx,bx
		add cx,4

		cmp ax,bx
		jl checkCoin2
		cmp ax,cx
		jg checkCoin2

		; collision detected -> collect coin
		add word [score],10

		push word [coin1Col]
		push word [coin1Row]
		call eraseCoin
		mov word [coin1Row],0
		jmp coinCheckDone

checkCoin2:
		cmp word [coin2Row],0
		je checkCoin3

		; check vertical overlap
		mov ax,[coin2Row]
		mov bx,[carRow]
		mov cx,bx
		add cx,2

		cmp ax,bx
		jl checkCoin3
		cmp ax,cx
		jg checkCoin3

		; check horizontal overlap
		mov ax,[coin2Col]
		mov bx,[carCol]
		mov cx,bx
		add cx,4

		cmp ax,bx
		jl checkCoin3
		cmp ax,cx
		jg checkCoin3

		; collision detected
		add word [score],10

		push word [coin2Col]
		push word [coin2Row]
		call eraseCoin
		mov word [coin2Row],0
		jmp coinCheckDone

checkCoin3:
		cmp word [coin3Row],0
		je coinCheckDone

		; check vertical overlap
		mov ax,[coin3Row]
		mov bx,[carRow]
		mov cx,bx
		add cx,2

		cmp ax,bx
		jl coinCheckDone
		cmp ax,cx
		jg coinCheckDone

		; check horizontal overlap
		mov ax,[coin3Col]
		mov bx,[carCol]
		mov cx,bx
		add cx,4

		cmp ax,bx
		jl coinCheckDone
		cmp ax,cx
		jg coinCheckDone

		; collision detected
		add word [score],10

		push word [coin3Col]
		push word [coin3Row]
		call eraseCoin
		mov word [coin3Row],0

coinCheckDone:
		pop dx
		pop cx
		pop bx
		pop ax
		pop bp
		ret

spawnOtherCar:
		push bp
		mov bp, sp

		inc word [frameCounter]

		mov ax,[frameCounter]
		and ax,63
		cmp ax,20
		jne individualSpawn

		cmp word [otherCar1Row],0
		jne trySecondCarSimultaneous
		mov word [otherCar1Row],1
		call getRandom
		mov dx,0
		mov bx,3
		div bx
		cmp dx,0
		je lane1_car1_sim
		cmp dx,1
		je lane2_car1_sim
		mov word [otherCar1Col],50
		jmp trySecondCarSimultaneous

lane1_car1_sim:
		mov word [otherCar1Col],26
		jmp trySecondCarSimultaneous

lane2_car1_sim:
		mov word [otherCar1Col],38

trySecondCarSimultaneous:
		cmp word [otherCar2Row],0
		jne spawnDone
		mov word [otherCar2Row],1
		call getRandom
		mov dx,0
		mov bx,3
		div bx
		cmp dx,0
		je lane1_car2_sim
		cmp dx,1
		je lane2_car2_sim
		mov word [otherCar2Col],50
		jmp spawnDone

lane1_car2_sim:
		mov word [otherCar2Col],26
		jmp spawnDone

lane2_car2_sim:
		mov word [otherCar2Col],38
		jmp spawnDone

individualSpawn:
		mov ax,[frameCounter]
		and ax,31
		cmp ax,0
		jne trySpawnCar2

		cmp word [otherCar1Row],0
		jne trySpawnCar2

		mov word [otherCar1Row],1
		call getRandom
		mov dx,0
		mov bx,3
		div bx
		cmp dx,0
		je lane1_car1_ind
		cmp dx,1
		je lane2_car1_ind
		mov word [otherCar1Col],50
		jmp trySpawnCar2

lane1_car1_ind:
		mov word [otherCar1Col],26
		jmp trySpawnCar2

lane2_car1_ind:
		mov word [otherCar1Col],38

trySpawnCar2:
		mov ax,[frameCounter]
		and ax,31
		cmp ax,15
		jne spawnDone

		cmp word [otherCar2Row],0
		jne spawnDone

		mov word [otherCar2Row],1
		call getRandom
		mov dx,0
		mov bx,3
		div bx
		cmp dx,0
		je lane1_car2_ind
		cmp dx,1
		je lane2_car2_ind
		mov word [otherCar2Col],50
		jmp spawnDone

lane1_car2_ind:
		mov word [otherCar2Col],26
		jmp spawnDone

lane2_car2_ind:
		mov word [otherCar2Col],38

spawnDone:
		pop bp
		ret

printOtherCar:
		push bp
		mov bp,sp
		push es
		push ax
		push di
		push bx

		mov ax,0xb800
		mov es,ax

		mov ax,[bp+4]
		mov bx,160
		mul bx
		mov bx,[bp+6]
		shl bx,1
		add ax,bx
		mov di,ax

		mov ah,0xcc
		mov al,' '
		mov cx,5
printOtherCarLoop1:	
		mov [es:di],ax
		add di,2
		loop printOtherCarLoop1

		add di,150
		mov ah,0x49
		mov al,0xdb
		mov [es:di+2],ax
		mov [es:di+4],ax
		mov [es:di+6],ax
		
		mov ah,0x0E
		mov [es:di],ax
		mov [es:di+8],ax

		add di,160
		mov ah,0xCC
		mov al,0xdf
		
		mov cx,5
printOtherCarLoop2:	
		mov [es:di],ax
		add di,2
		loop printOtherCarLoop2

		pop bx
		pop di
		pop ax
		pop es
		pop bp
		ret 4

eraseOtherCar:
		push bp
		mov bp,sp
		push es
		push ax
		push di
		push cx

		mov ax,0xb800
		mov es,ax

		mov ax,[bp+4]
		mov bx,160
		mul bx
		mov bx,[bp+6]
		shl bx,1
		add ax,bx
		mov di,ax

		mov ah,0x08
		mov al,0x20

		mov cx,3

eraseOtherCarLoop:
		push cx
		mov cx,5
		rep stosw
		add di,150
		pop cx
		loop eraseOtherCarLoop

		pop cx
		pop di
		pop ax
		pop es
		pop bp
		ret 4

checkCollision:
		push bp
		mov bp, sp
		push ax
		push bx
		push cx
		push dx

		; check collision with otherCar1
		cmp word [otherCar1Row],0
		je checkCar2

		; calculate vertical overlap
		mov ax,[carRow]
		add ax,2
		mov bx,[otherCar1Row]

		cmp ax,bx
		jl noOverlap1

		mov cx,[otherCar1Row]
		add cx,2
		mov dx,[carRow]
		cmp dx,cx
		jg noOverlap1

		; check horizontal overlap
		mov ax,[carCol]
		add ax,4
		mov bx,[otherCar1Col]

		cmp ax,bx
		jl noOverlap1

		mov cx,[otherCar1Col]
		add cx,4
		mov dx,[carCol]
		cmp dx,cx
		jg noOverlap1

		; collision detected
		mov byte [gameOver],1
		jmp collisionDone

noOverlap1:
checkCar2:
		cmp word [otherCar2Row],0
		je collisionDone

		mov ax,[carRow]
		add ax,2
		mov bx,[otherCar2Row]

		cmp ax,bx
		jl noOverlap2

		mov cx,[otherCar2Row]
		add cx,2
		mov dx,[carRow]
		cmp dx,cx
		jg noOverlap2

		; check horizontal overlap
		mov ax,[carCol]
		add ax,4
		mov bx,[otherCar2Col]

		cmp ax,bx
		jl noOverlap2

		mov cx,[otherCar2Col]
		add cx,4
		mov dx,[carCol]
		cmp dx,cx
		jg noOverlap2

		; collision detected :p
		mov byte [gameOver],1

noOverlap2:
collisionDone:
		pop dx
		pop cx
		pop bx
		pop ax
		pop bp
		ret

updateOtherCars:
		push bp
		mov bp, sp

		cmp word [otherCar1Row],0
		je skipCar1

		push word [otherCar1Col]
		push word [otherCar1Row]
		call eraseOtherCar

		inc word [otherCar1Row]

		cmp word [otherCar1Row],25
		jl skipCar1
		mov word [otherCar1Row],0

skipCar1:
		cmp word [otherCar2Row],0
		je skipCar2

		push word [otherCar2Col]
		push word [otherCar2Row]
		call eraseOtherCar

		inc word [otherCar2Row]

		cmp word [otherCar2Row],25
		jl skipCar2
		mov word [otherCar2Row],0

skipCar2:
		pop bp
		ret

storeRow:
		push bp
		mov bp,sp
		push ax
		push cx
		push si
		push di
		push es
		push ds

		mov ax,[bp+4]
		mov word [savedLineCount],ax

		mov ax,0xb800
		mov ds,ax
		mov ax,cs
		mov es,ax

		mov si,3840
		mov di,savedLine

		mov ax,[bp+4]
		mov cx,80
		mul cx
		mov cx,ax

		cld
		rep movsw

		pop ds
		pop es
		pop di
		pop si
		pop cx
		pop ax
		pop bp
		ret 2

restoreRow:
		push bp
		mov bp,sp
		push ax
		push cx
		push si
		push di
		push es
		push ds

		cmp word [savedLineCount],0
		je done

		mov ax,cs
		mov ds,ax
		mov ax,0xb800
		mov es,ax

		mov si,savedLine
		mov di,160

		mov ax,[savedLineCount]
		mov cx,80
		mul cx
		mov cx,ax

		cld
		rep movsw

done:
		pop ds
		pop es
		pop di
		pop si
		pop cx
		pop ax
		pop bp
		ret

moveScreen:
		push bp
		mov bp, sp
		push es
		push ds
		push cx
		push ax
		push si
		push di

		mov ax,[bp+4]
		push ax
		call storeRow

		mov ax,80
		mul byte[bp+4]
		push ax
		shl ax,1

		mov si,4000
		sub si,ax

		mov cx,4000
		sub cx,ax

		mov ax,0xb800
		mov es,ax
		mov ds,ax

		mov di,4000

		std
		rep movsw

		mov ax,0x0720
		pop cx
		mov di,cx
		rep stosw

		call restoreRow

		pop di
		pop si
		pop ax
		pop cx
		pop ds
		pop es
		pop bp
		ret 2

delay:
		push ax
		push cx
		push dx

		mov cx,4
delayOuter:
		mov dx,0xffff
delayInner:
		dec dx
		jnz delayInner
		loop delayOuter

		pop dx
		pop cx
		pop ax
		ret

eraseCar:
		push bp
		mov bp,sp
		push es
		push ax
		push di

		mov ax,0xb800
		mov es,ax

		mov ax,[carRow]
		mov bx,160
		mul bx
		mov di,ax
		mov ax,[carCol]
		shl ax,1
		add di,ax

		mov ah,0x08
		mov al,' '

		mov cx,3
clearCarLoop:
		push cx
		mov cx,5
		rep stosw
		add di,150
		pop cx
		loop clearCarLoop

		pop di
		pop ax
		pop es
		pop bp
		ret

eraseOldCar:
		push bp
		mov bp,sp
		push es
		push ax
		push di
		push cx

		mov ax,0xb800
		mov es,ax

		mov ax,[carRow]
		mov bx,160
		mul bx
		mov di,ax
		mov ax,[oldCarCol]
		shl ax,1
		add di,ax

		mov ah,0x08
		mov al,' '

		mov cx,3
eraseOldCarLoop:
		push cx
		mov cx,5
		rep stosw
		add di,150
		pop cx
		loop eraseOldCarLoop

		pop cx
		pop di
		pop ax
		pop es
		pop bp
		ret

start:
		call hookKeyboard
		call hookTimer
		mov ah,0
		int 0x1A
		mov [randomSeed],dx

		call clearScreen
		call loadingScreen
		
		call printLandscape
		call printRoad
		call printTrees

		mov word [score],0
		mov byte [isPaused],0
		mov byte [waitingForExitConfirm],0
		mov byte [timerUpdateFlag],0

		call printScreens
		call printCar

gameLoop:
		cmp byte [gameOver],1
		je gameOverScreen

		cmp byte [waitingForExitConfirm],1
		jne checkPaused

		call handleExitConfirmation
		jmp afterGameLogic

checkPaused:
		cmp byte [isPaused],1
		jne checkTimerUpdate

		call showPauseScreen
    
pauseLoop:
		cmp byte [isPaused],0
		jne pauseLoop
		
		call hidePauseScreen
		jmp gameLoop

checkTimerUpdate:
		cmp byte [timerUpdateFlag],1
		jne afterGameLogic
		
		; reset the flag
		mov byte [timerUpdateFlag],0
		
		; gaem
		call eraseCar
		call eraseOldCar
		call spawnOtherCar
		call spawnCoins
		call updateOtherCars
		call updateCoins
		call checkCoinCollection
		call checkCollision

		cmp byte [gameOver],1
		je gameOverScreen

		mov ax,1
		push ax
		call moveScreen

		call printScreens
		call printCar

		cmp word [otherCar1Row],0
		je skipDrawCar1
		push word [otherCar1Col]
		push word [otherCar1Row]
		call printOtherCar

skipDrawCar1:
		cmp word [otherCar2Row],0
		je skipDrawCar2
		push word [otherCar2Col]
		push word [otherCar2Row]
		call printOtherCar

skipDrawCar2:
		cmp word [coin1Row],0
		je skipDrawCoin1
		push word [coin1Col]
		push word [coin1Row]
		call printCoin

skipDrawCoin1:
		cmp word [coin2Row],0
		je skipDrawCoin2
		push word [coin2Col]
		push word [coin2Row]
		call printCoin

skipDrawCoin2:
		cmp word [coin3Row],0
		je skipDrawCoin3
		push word [coin3Col]
		push word [coin3Row]
		call printCoin

skipDrawCoin3:

afterGameLogic:
		jmp gameLoop

gameOverScreen:
		call unhookKeyboard
		call unhookTimer 
		call printGameOver

		mov ah,0
		int 0x16
terminate:
		mov ax,0x4c00
		int 0x21