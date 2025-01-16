# References:
# [1] Rotenberg, A. 1960. A New Pseudo-Random Number Generator. J. ACM 7, 1 (Jan. 1960),
#     75–77. https://doi.org/10.1145/321008.321019
# [2] Thomson, W. E. 1958. A Modified Congruence Method of Generating Pseudo-random Numbers. 
#	  The Computer Journal 1, 2 (Jan. 1958), 83. https://doi.org/10.1093/comjnl/1.2.83

.data
wallSymbol:      .byte '#'
targetSymbol:    .byte 'T'
boxSymbol:       .byte 'B'
emptySymbol:     .byte ' '

seed:            .word 12  # a randomly selected number

boardPtr:        .word 0
backupPtr:       .word 0
characterPtr:    .word 0
targetPtr:       .word 0
scorePtr:		 .word 0
resultPtr:		 .word 0

newLine:        	 .string "\n"
promptMove: 		 .string "Please input your move: "
promptMoveFail: 	 .string "\nInvalid move, please try again or check the user guide for help!\n"
promptNewGame:  	 .string "\nIf you want to start a new game, please input 'r'; \nif you want to quit, please input any other letter: "
promptPlayerNum:	 .string "Please input the number of player: "
promptBoxNum:    	 .string "Please input the number of boxes: "
promptRow:			 .string "Please input the row of the board: "
promptCol:		 	 .string "Please input the column of the board: "
promptPlayer:   	 .string "Please input the number of player: "
promptInitFail:  	 .string "It seems like you've created an unsolvable game, please try again!\n"
promptCurrPlayer:	 .string "\nCurrent player: "
promptEndGame:		 .string "Congratulation! You have finished the puzzle!\n"
promptScore:		 .string "\n----------Score Board----------\n"
promptPlayerScore1:  .string "Player "
promptPlayerScore2:  .string ": "
promptInvalidInput:  .string "Invalid input, please try again or check the user guide for help!\n"

.text
.globl _start

_start:	
	# use sys time to get random seed
	la t0, seed
	li a7, 30 
    ecall
    sw a0, 0(t0)
	
	askRow:
		# store board row
		li a7, 4
		la a0, promptRow
		ecall 
		li a7, 5
		ecall
		li t0, 5
		blt a0, t0, failRow  # illegal input, row <= 0
		mv s0, a0  # s0 = HEIGHT
		j askCol
		failRow:
			li a7, 4
			la a0, promptInvalidInput
			ecall
			j askRow
	askCol:
		# store board col
		li a7, 4
		la a0, promptCol
		ecall 
		li a7, 5
		ecall
		li t0, 5
		blt a0, t0, failCol  # illegal input
		mv s1, a0  # s1 = WIDTH
		j endAskCol
		failCol:
			li a7, 4
			la a0, promptInvalidInput
			ecall
			j askCol
	endAskCol:
	
	# allocate space for board and backup
	li sp, 0x80000000
	mul t0, s0, s1
	
	sub sp, sp, t0
	andi sp, sp, -4
	la t0, boardPtr
	sw sp, 0(t0)
	
	sub sp, sp, t0
	andi sp, sp, -4
	la t0, backupPtr
	sw sp, 0(t0)
	

    # Randomly generate initial locations for the character(s), box(s), and target(s).
	initMap:
		# init board + edge wall
		la t0, boardPtr
		lw s2, 0(t0)  # s2 = boardPtr
		la t0, backupPtr
		lw s6, 0(t0)  # s6 = backupPtr
		
		la t4, wallSymbol
		lb t4, 0(t4)  # t4 = wallSymbol
		la t5, emptySymbol
		lb t5, 0(t5)  # t5 = emptySymbol
		
		li t0, 0  # t0 = row variant
		boardRow:
			beq t0, s0, endLoopBoard
			li t1, 0  # t1 = col variant
			
			boardCol:
				beq t1, s1, nextBoardRow

				# when edge is reached, place a wall
				beqz t0, addWall
				beqz t1, addWall
				addi a2, s0, -1
				beq t0, a2, addWall
				addi a3, s1, -1
				beq t1, a3, addWall
				
				# otherwise, fill the board with emptySymbol
				# for board:
				mv a0, t0
				mv a1, t1
				mv a2, t5
				mv a3, s2
				jal ra, storeSymbol

				# for backup:
				mv a0, t0
				mv a1, t1
				mv a2, t5
				mv a3, s6
				jal ra, storeSymbol
				
				j nextBoardCol

				addWall:
					# for board:
					mv a0, t0
					mv a1, t1
					mv a2, t4
					mv a3, s2
					jal ra, storeSymbol

					# for backup:
					mv a0, t0
					mv a1, t1
					mv a2, t4
					mv a3, s6
					jal ra, storeSymbol
				
				nextBoardCol:
					addi t1, t1, 1
					j boardCol
			nextBoardRow:
				addi t0, t0, 1
				j boardRow
		endLoopBoard:	
		
		# init players pos + boxes and targets pos
		initRandomParts:
			# creat random position for characters	
			# get player number
			li a7, 4
			la a0, promptPlayer
			ecall
			li a7, 5
			ecall
			bge x0, a0, failAskPlayer  # illegal input, player number <= 0
			mv s9, a0  # s9 = num of player
			j endAskPlayer
			failAskPlayer:
				li a7, 4
				la a0, promptInvalidInput
				ecall
				j initRandomParts
			endAskPlayer:
			
			# allocate space for each player's scores
			sub sp, sp, s9
			andi sp, sp, -4
			la t0, scorePtr
			sw sp, 0(t0)
			
			# allocate space for player pos
			li t0, 2  # stores row AND col -> sp-2
			sub sp, sp, t0
			andi sp, sp, -4
			la t0, characterPtr
			sw sp, 0(t0)
			
			la t0, emptySymbol
			lb t2, 0(t0)
			
			li s4, 10000  # init numRemainingTrial
			li t4, 0  # init successfully generated player num = 0
			characterInitLoop:
				beqz s4, failRandomParts  # too many trials -> impossible solvable game
				bgt t4, x0, endCharacterInit  # player is generated
				
				li a0, 1
				addi a1, s0, -2
				jal ra, random
				mv t0, a0  # t0 = row

				li a0, 1
				addi a1, s1, -2
				jal ra, random
				mv t1, a0  # t1 = col
				
				# if curr random pos is not empty, record fail and try another pos
				mv a0, t0
				mv a1, t1
				mv a2, s2
				jal ra, getSymbol
				bne a0, t2, failCharacterInit
				
				# otherwise, load the player
				mv a0, t0
				mv a1, t1
				addi a2, t4, 80  # ascii for 'P'
				mv a3, s6
				jal ra, storeSymbol  # load on backup
				
				mv a0, t0
				mv a1, t1
				addi a2, t4, 80
				mv a3, s2
				jal ra, storeSymbol  # load on board
				
				# store character pos
				la t6, characterPtr
				lw t6, 0(t6)
				slli t5, t4, 1
				add t6, t6, t5
				sb t0, 0(t6)
				sb t1, 1(t6)
				
				# succeesNum++
				addi t4, t4, 1
				j characterInitLoop
				
				failCharacterInit:
					addi s4, s4, -1
					j characterInitLoop
			endCharacterInit:
			
			
			askBox:
				# get box/target number
				li a7, 4
				la a0, promptBoxNum
				ecall
				li a7, 5
				ecall
				bge x0, a0, failAskBox  # illegal input, box number <= 0
				mv s5, a0  # s9 = num of box/target
				j endAskBox
				failAskBox:
					li a7, 4
					la a0, promptInvalidInput
					ecall
					j askBox
				endAskBox:
					
			
			# allocate space for targets
			slli t0, s5, 1  # stores row AND col -> multiply by 2
			sub sp, sp, t0
			andi sp, sp, -4
			la t0, targetPtr
			sw sp, 0(t0)
			
			# creat random position for targets	
			la t0, emptySymbol
			lb t2, 0(t0)
			la t0, targetSymbol
			lb t3, 0(t0)
			
			li s4, 10000000  # init numRemainingTrial
			li t4, 0  # init successfully generated player num = 0
			targetInitLoop:
				beqz s4, failRandomParts  # too many trials -> impossible solvable game
				beq t4, s5, endTargetInit  # all targets are generated
				
				li a0, 1
				addi a1, s0, -2
				jal ra, random
				mv t0, a0

				li a0, 1
				addi a1, s1, -2
				jal ra, random
				mv t1, a0
				
				# if curr random pos is not empty, record fail and try another pos
				mv a0, t0
				mv a1, t1
				mv a2, s2
				jal ra, getSymbol
				bne a0, t2, failTargetInit
				
				# no corner
				mul t5, t0, s1
				add t5, t5, t1
				mv s10, t5  # s10 = row * WIDTH + col
				
				addi t5, s1, 1
				beq s10, t5, failTargetInit  # upper left corner
				
				slli t5, s1, 1
				addi t5, t5, -2
				beq s10, t5, failTargetInit  # upper right corner
				
				mul t5, s0, s1
				sub t5, t5, s1
				addi t5, t5, -2
				beq s10, t5, failTargetInit  # lower right corner
				
				mul t5, s0, s1
				sub t5, t5, s1
				sub t5, t5, s1
				addi t5, t5, 1
				beq s10, t5, failTargetInit  # lower left corner
				
				# otherwise, load the target
				mv a0, t0
				mv a1, t1
				mv a2, t3
				mv a3, s2
				jal ra, storeSymbol  # load on board
				
				mv a0, t0
				mv a1, t1
				mv a2, t3
				mv a3, s6
				jal ra, storeSymbol  # load on backup
				
				# store target pos
				la t6, targetPtr
				lw t6, 0(t6)
				slli t5, t4, 1
				add t6, t6, t5
				sb t0, 0(t6)
				sb t1, 1(t6)
				
				# succeesNum++
				addi t4, t4, 1
				j targetInitLoop
				
				failTargetInit:
					addi s4, s4, -1
					j targetInitLoop
			endTargetInit:
			
			
			# creat random position for boxes	
			la t0, boxSymbol
			lb t3, 0(t0)
			la t0, emptySymbol
			lb t2, 0(t0)
			
			li s4, 10000000  # init numRemainingTrial
			li t4, 0  # init successfully generated player num = 0
			boxInitLoop:
				beqz s4, failRandomParts  # too many trials -> impossible solvable game
				beq t4, s5, endBoxInit  # all boxes are generated
				
				li a0, 1
				addi a1, s0, -2
				jal ra, random
				mv t0, a0

				li a0, 1
				addi a1, s1, -2
				jal ra, random
				mv t1, a0
				
				# if curr random pos is not empty, record fail and try another pos
				mv a0, t0
				mv a1, t1
				mv a2, s2
				jal ra, getSymbol
				la t2, emptySymbol
				lb t2, 0(t2)
				bne a0, t2, failBoxInit
				
				# check deadlock
				# scenario 1: corner pos
				mul t5, t0, s1
				add t5, t5, t1
				mv s10, t5  # s10 = row * WIDTH + col
				
				addi t5, s1, 1
				beq s10, t5, failBoxInit  # upper left corner
				
				slli t5, s1, 1
				addi t5, t5, -2
				beq s10, t5, failBoxInit  # upper right corner
				
				mul t5, s0, s1
				sub t5, t5, s1
				addi t5, t5, -2
				beq s10, t5, failBoxInit  # lower right corner
				
				mul t5, s0, s1
				sub t5, t5, s1
				sub t5, t5, s1
				addi t5, t5, 1
				beq s10, t5, failBoxInit  # lower left corner

				# scenario 2: edge reached with no enough targets / two boxes next to each other
				li t5, 1
				beq t0, t5, rowEdge  # upper most edge
				beq t1, t5, colEdge  # left most edge
				addi t5, s0, -2
				beq t0, t5, rowEdge  # lower most edge
				addi t5, s1, -2
				beq t1, t5, colEdge  # right most edge
				j checkAdjacent
				rowEdge:					
					mv a0, t0
					li a1, -1
					jal ra, checkEdge
					beq a0, x0, failBoxInit
				colEdge:
					li a0, -1
					mv a1, t1
					jal ra, checkEdge
					beq a0, x0, failBoxInit
					
				# scenario 3: boxes gather together in the middle
				# set current box as the upper left box
				checkAdjacent:
					la t2, boxSymbol
					lb t2, 0(t2)
					# upper right
					addi t5, t1, 1
					mv a0, t0
					mv a1, t5
					mv a2, s2
					jal ra, getSymbol
					bne a0, t2, validBox

					# lower right
					addi t6, t0, 1
					mv a0, t6
					mv a1, t5
					mv a2, s2
					jal ra, getSymbol
					bne a0, t2, validBox

					# lower left
					mv a0, t6
					mv a1, t1
					mv a2, s2
					jal ra, getSymbol
					bne a0, t2, validBox

					# fail all of them -> invalid pos for box
					j failBoxInit
				
				validBox:
					# other than the three scenarios above, curr pos is valid
					mv a0, t0
					mv a1, t1
					mv a2, t3
					mv a3, s2
					jal ra, storeSymbol  # load box on board

					mv a0, t0
					mv a1, t1
					mv a2, t3
					mv a3, s6
					jal ra, storeSymbol  # load box on backup
				
					# succeesNum++
					addi t4, t4, 1
					j boxInitLoop
				
				failBoxInit:
					addi s4, s4, -1
					j boxInitLoop
			endBoxInit:
			
			j endRandomParts
		
		failRandomParts:
			li a7, 4
			la a0, promptInitFail
			ecall
			
			# release stack
			li t0, 0x80000000
			mv t1, sp
			loopResetGenerate:
				sb x0, 0(t1)
				beq t1, t0, _start
				add t1, t1, 1
				j loopResetGenerate
		
		endRandomParts:

   
    # Display the game board.
	li s8, 0
	forEachPlayer:
		beq s8, s9, endGame
		
		li s3, 0  # reset total num of move
	
		li a7, 4
		la a0, promptCurrPlayer
		ecall
		li a7, 1
		mv a0, s8
		ecall
		li a7, 4
		la a0, newLine
		ecall
		
		mv a1, s0
		mv a2, s1
		jal ra, displayBoard
		
		loopMove:
			li a7, 4
			la a0, promptMove
			ecall
			li a7, 12
			ecall  # a0 = dir

			li a1, 114  # ascii for 'r'
			bne a0, a1, playerMakeMove

			# if the player chooses to retry, load backup to board and reset character position
			mul t1, s0, s1  # total num of grids
			li t5, 0   # t5 = offset
			loopLoadBackup:
				beq t1, t5, forEachPlayer
				
				add t6, t5, s6
				lb t6, 0(t6)  # t6 = curr symbol at backup

				# if curr symbol is character, reset corresponding characterPtr
				# otherwise, load directly
				li t4, 80
				bne t6, t4, restoreSymbol

				la t4, characterPtr
				lw t4, 0(t4)
				# row * WIDTH + col = offset -> offset // WIDTH = row, offset % WIDTH = col
				div t0, t5, s1
				sb t0, 0(t4)
				remu t0, t5, s1
				sb t0, 1(t4)

				restoreSymbol:
					add t4, t5, s2
					sb t6, 0(t4)  # store it to corresponding pos at board

					addi t5, t5, 1
					j loopLoadBackup

			playerMakeMove:
				mv a2, a0  # a2 = dir
				
				la t1, characterPtr
				lw t1, 0(t1)
				lb a0, 0(t1)  # a0 = row
				lb a1, 1(t1)  # a1 = col
				
				li a3, 80  # a3 = 'P'
				
				jal ra, playerMove
				beqz a0, loopMove  # if fail, try another move directly
				
				# otherwise, add step
				addi s3, s3, 1

			# check game over and reload targets (in case any targets are covered by other symbols)
			li t1, 0  # t1 = num of targets finished checking
			li t6, 0  # t6 = numFinished (box is on target)
			moveTarget:
				beq t6, s5, nextPlayer
				beq t1, s5, nextMove

				slli t3, t1, 1
				la t2, targetPtr
				lw t2, 0(t2)
				add t2, t2, t3  # t2 = targetPtr[row]

				lb t3, 0(t2)  # t3 = trow
				lb t4, 1(t2)  # t4 = tcol

				mv a0, t3
				mv a1, t4
				mv a2, s2
				jal ra, getSymbol
				# if a box is on the target, numFinished++
				la t5, boxSymbol
				lb t5, 0(t5)
				beq a0, t5, finishTarget
				# if curr pos is not empty, go to next target
				la t5, emptySymbol
				lb t5, 0(t5)
				bne a0, t5, nextTarget
				# otherwise, reload target
				la t5, targetSymbol
				lb t5, 0(t5)
				mul t3, t3, s1
				add t4, t4, t3
				add t4, t4, s2
				sb t5, 0(t4)
				j nextTarget

				finishTarget:
					addi t6, t6, 1
				nextTarget:
					addi t1, t1, 1
					j moveTarget

			nextMove:
				li a7, 4
				la a0, newLine
				ecall
				mv a1, s0
				mv a2, s1
				jal ra, displayBoard

				j loopMove
		
		nextPlayer:
		
			li a7, 4
			la a0, newLine
			ecall
		
			mv a1, s0
			mv a2, s1
			jal ra, displayBoard
			
			li a7, 4
			la a0, promptEndGame
			ecall
			la a0, newLine
			ecall
			
			mul t1, s0, s1  # total num of grids
			li t5, 0   # t5 = offset
			mv t2, s2  # t2 = curr board
			mv t3, s6  # t3 = curr backup
			resetBoard:
				beq t1, t5, updateNextPlayer
				
				add t6, t5, t3
				lb t6, 0(t6)  # t6 = curr symbol at backup

				# if curr symbol is character, reset corresponding characterPtr
				# otherwise, load directly
				li t4, 80
				bne t6, t4, resetSymbol

				la t4, characterPtr
				lw t4, 0(t4)
				# row * WIDTH + col = offset -> offset // WIDTH = row, offset % WIDTH = col
				div t0, t5, s1
				sb t0, 0(t4)
				remu t0, t5, s1
				sb t0, 1(t4)

				resetSymbol:
					add t4, t5, t2
					sb t6, 0(t4)  # store it to corresponding pos at board

					addi t5, t5, 1
					j resetBoard
			
			updateNextPlayer:
				la t1, scorePtr
				lw t1, 0(t1)
				add t1, t1, s8
				sb s3, 0(t1)
			
				addi s8, s8, 1
				j forEachPlayer
	
endGame:
	li a7, 4
	la a0, newLine
	ecall

	# sort on resultPtr
	slli t0, s9, 1
	sub sp, sp, t0
	andi sp, sp, -4
	la t0, resultPtr  # allocate space for result
	sw sp, 0(t0)
	mv t2, sp  # t2 = resultPtr
	la t1, scorePtr
	lw t1, 0(t1)  # t1 = scorePtr
	li t0, 0  # curr player
	addResults:
		beq t0, s9, endAddResults
		# store index
		sb t0, 0(t2)
		# store element
		addi t2, t2, 1
		lb t3, 0(t1)
		sb t3, 0(t2)
		
		addi t0, t0, 1
		addi t1, t1, 1
		addi t2, t2, 1
		j addResults
	endAddResults:
	
	# bubble sort
	la t0, resultPtr
	lw t0, 0(t0)  # t0 = resultPtr
	li t1, 0  # t1 = i
	ranking_i:
		beq t1, s9, endRanking
		li t2, 0  # t2 = j
		ranking_j:
			sub t3, s9, t1
			addi t3, t3, -1
			beq t2, t3, endRanki
			
			# if result[j*2+1] > result[j*2+3], no need to switch
			slli t3, t2, 1
			addi t3, t3, 1
			add t3, t3, t0  # t3 = &result[j*2+1]
			lb t4, 0(t3)
			lb t5, 2(t3)
			bge t5, t4, endRankj
			
			# switch element
			sb t5, 0(t3)
			sb t4, 2(t3)
			
			# switch index
			addi t3, t3, -1  # t3 = &result[j*2]
			lb t4, 0(t3)
			lb t5, 2(t3)
			sb t5, 0(t3)
			sb t4, 2(t3)
			
		endRankj:
			addi t2, t2, 1
			j ranking_j
	endRanki:
		addi t1, t1, 1
		j ranking_i
	endRanking:
	
	# display scores
	li a7, 4
	la a0, promptScore
	ecall
	la t0, resultPtr
	lw t0, 0(t0)  # t0 = resultPtr
	li t1, 0  # t1 = currNum
	loopScoreBoard:
		beq t1, s9, releaseStack
		
		la a0, promptPlayerScore1
		ecall
		li a7, 1
		lb a0, 0(t0)
		ecall
		li a7, 4
		la a0, promptPlayerScore2
		ecall
		
		addi t0, t0, 1
		li a7, 1
		lb a0, 0(t0)
		ecall
		li a7, 4
		la a0, newLine
		ecall
		
		addi t1, t1, 1
		addi t0, t0, 1
		j loopScoreBoard

	releaseStack:
		li t0, 0x80000000
		mv t1, sp
		loopResetZero:
			sb x0, 0(t1)
			beq t1, t0, askRestart
			add t1, t1, 1
			j loopResetZero
	
	askRestart:
		mv sp, t0  # reset sp

		li a7, 4
		la a0, promptNewGame
		ecall
		li a7, 12
		ecall
		mv t1, a0  # temp store user input
		
		# make sure the user can clearly distingush the new game
		li a7, 4
		la a0, newLine
		ecall
		li a7, 4
		la a0, newLine
		ecall
		li a7, 4
		la a0, newLine
		ecall
		li a7, 4
		la a0, newLine
		ecall
		
		# if the user chooses to retry, jump to start
		li t0, 114  # ascii for 'r'
		beq t1, t0, _start
		# otherwise, exit

exit:
    li a7, 10
    ecall
    
    
# --- HELPER FUNCTIONS ---

# This function generates a random number between a0 and a1 based on the
# Linear congruential generator (LCG) formula [1, 2]
random:
	# a0, a1: upper and lower bound
	# returns integer in the bound
	# a0: min_val, a1: max_val
	la a2, seed
	lw a2, 0(a2)       # a2 = seed
	li a3, 65793       # a3 = a
	li a4, 4282663     # a4 = c
	li a5, 8388608     # a5 = m = 2^23

	# get new seed
	mul a6, a3, a2     # a6 = a * seed
	add a6, a6, a4     # a6 = a * seed + c

	remu a6, a6, a5    # a6 = (a * seed + c) mod m

	la a2, seed
	sw a6, 0(a2)       # seed = a6

	# restrict range
	srli a6, a6, 8
	li a5, 0x7fff
	and a6, a6, a5
	remu a6, a6, a1   # a6 = seed % max_val
	add a0, a6, a0    # a0 = min_val + seed % max_val
	jr ra

getSymbol:
	# a0: row, a1: col, a2: &board[0]
	# returns symbol at &board[n]
	addi sp, sp, -8
	sw ra, 4(sp)
	sw a2, 0(sp)
	mul a4, a0, s1  # a4 = index of character in BOARD
	add a4, a4, a1  # a4 = row * WIDTH + col
	add a4, a4, a2  # a4 = &board[row * WIDTH + col]
	#slli a4, a4, 2
	lb a0, 0(a4)    # a0 = board[row * WIDTH + col]
	lw a2, 0(sp)
	lw ra, 4(sp)
	addi sp, sp, 8
	jr ra

storeSymbol:
	# a0: row, a1: col, a2: symbol, a3: &board[0]
	addi sp, sp, -8
	sw ra, 4(sp)
	sw a3, 0(sp)
	mul a4, a0, s1  # a4 = index of character in BOARD
	add a4, a4, a1  # a4 = row * WIDTH + col
	add a4, a4, a3  # a4 = &board[row * WIDTH + col]
	#slli a4, a4, 2
	sb a2, 0(a4)    # board[row * WIDTH + col] = symbol
	lw a3, 0(sp)
	lw ra, 4(sp)
	addi sp, sp, 8
	jr ra

checkEdge:
	# a0: row, a1: col, the one not being checked is set to -1
	# returns 1 if solvable, 0 otherwise
	addi sp, sp, -4
	sw ra, 0(sp)
	
	li a2, 0  # numBoxes at the edge
	li a6, 0  # numTargets at the edge
	
	# the one being checked is the col
	blt a0, zero, checkCol  
	
	# the one being checked is the row
	checkRow:
		li a1, 0
	checkRowEdge:
		beq a1, s1, checkTargetNum  # all col checked, at least no boxes next to each other
		
		# check if two boxes are next to each other (cannot move)
		mul a3, a0, s1
		add a3, a3, a1
		add a3, a3, s2
		lb a4, 0(a3)  # a4 = board[row * WIDTH + col]
	
		la a5, boxSymbol
		lb a5, 0(a5)
		bne a4, a5, checkTargetEdgeRow  # if curr pos is not a box, check for target
		
		# if curr pos is a box
		checkBoxEdgeRow:
			addi a2, a2, 1  # record num boxes
			addi a1, a1, 1  # go to next pos
			
			mul a3, a0, s1
			add a3, a3, a1
			add a3, a3, s2  # &board[row * WIDTH + col + 1]
			lb a4, 0(a3)
			la a5, boxSymbol
			lb a5, 0(a5)
			beq a4, a5, invalidEdge  # two boxes next to each other
		
		checkTargetEdgeRow:
			# check if there is a target
			mul a3, a0, s1
			add a3, a3, a1
			add a3, a3, s2  # &board[row * WIDTH + col]
			lb a4, 0(a3)  # a4 = board[row * WIDTH + col]
			la a5, targetSymbol
			lb a5, 0(a5)
			bne a4, a5, nextRowEdge  # if curr pos is not a target, go to next pos
			addi a6, a6, 1  # if a target is found, numTargets++
		
		nextRowEdge:
			addi a1, a1, 1
			j checkRowEdge
	
	checkCol:
		li a0, 0
	checkColEdge:
		beq a0, s0, checkTargetNum  # all col checked, at least no boxes next to each other
		
		# check if two boxes are next to each other (cannot move)
		mul a3, a0, s1
		add a3, a3, a1
		add a3, a3, s2  # &board[row * WIDTH + col]
		lb a4, 0(a3)
		la a5, boxSymbol
		lb a5, 0(a5)
		bne a4, a5, checkTargetEdgeCol  # if curr pos is not a box, check for target
		
		# if curr pos is a box
		checkBoxEdgeCol:
			addi a2, a2, 1  # record num boxes
			addi a0, a0, 1  # go to next pos
			
			mul a3, a0, s1
			add a3, a3, a1
			add a3, a3, s2  # &board[row * WIDTH + col]
			lb a4, 0(a3)
			la a5, boxSymbol
			lb a5, 0(a5)
			beq a4, a5, invalidEdge  # two boxes next to each other
		
		checkTargetEdgeCol:
			# check if there is a target
			mul a3, a0, s1
			add a3, a3, a1
			add a3, a3, s2  # &board[row * WIDTH + col]
			lb a4, 0(a3)
			la a5, targetSymbol
			lb a5, 0(a5)
			bne a4, a5, nextColEdge  # if curr pos is not a target, go to next pos
			addi a6, a6, 1  # if a target is found, numTargets++
		
		nextColEdge:
			addi a0, a0, 1
			j checkColEdge
	
	validEdge:
		lw ra, 0(sp)
		addi sp, sp, 4
		li a0, 1
		jr ra
	checkTargetNum:
		blt a2, a6, validEdge  # enough targets, no obstacle
	invalidEdge:
		lw ra, 0(sp)
		addi sp, sp, 4
		li a0, 0
		jr ra
		
playerMove:
	# a0: row, a1: col, a2: dir (wasd), a3: 'P'
	li a3, 80
	# returns 0 when fail, 1 otherwise
	li a4, 119  # ascii for 'w'
	beq a2, a4, pUp
	li a4, 115  # ascii for 's'
	beq a2, a4, pDown
	li a4, 97   # ascii for 'a'
	beq a2, a4, pLeft
	li a4, 100  # ascii for 'd'
	beq a2, a4, pRight
	j failMove
	
	pUp:
		addi a5, a0, -1  # a5 = nrow
		mv a6, a1        # a6 = ncol
		
		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		lb a4, 0(a4)  # a4 = board[nrow * WIDTH + ncol]
		
		la a2, wallSymbol
		lb a2, 0(a2)
		beq a4, a2, failMove  # if next pos is wall, invalid move
		
		# if next pos is empty/target, update player pos
		la a2, emptySymbol
		lb a2, 0(a2)
		beq a4, a2, updatePlayer
		la a2, targetSymbol
		lb a2, 0(a2)
		beq a4, a2, updatePlayer
		
		la a2, boxSymbol
		lb a2, 0(a2)
		# if next pos is box, move box
		# otherwise, next pos is another player, fail move
		bne a4, a2, failMove
		
		# move box
		addi a5, a5, -1  # a5 = next nrow
		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		lb a4, 0(a4)  # a4 = board[nrow * WIDTH + ncol]
		# if next pos is not target/empty, fail move
		la a2, targetSymbol
		lb a2, 0(a2)
		beq a4, a2, moveBoxUp
		la a2, emptySymbol
		lb a2, 0(a2)
		beq a4, a2, moveBoxUp
		j failMove
		
		moveBoxUp:
			la a2, boxSymbol
			lb a2, 0(a2)
			# otherwise, move box
			mul a4, a5, s1
			add a4, a4, a6
			add a4, a4, s2
			sb a2, 0(a4)  # store boxSymbol at next npos
			addi a5, a5, 1  # go back to npos
			j updatePlayer
		
	pDown:
		addi a5, a0, 1   # a5 = nrow
		mv a6, a1        # a6 = ncol
		
		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		lb a4, 0(a4)  # a4 = board[nrow * WIDTH + ncol]
		
		la a2, wallSymbol
		lb a2, 0(a2)
		beq a4, a2, failMove  # if next pos is wall, invalid move
		
		# if next pos is empty/target, update player pos
		la a2, emptySymbol
		lb a2, 0(a2)
		beq a4, a2, updatePlayer
		la a2, targetSymbol
		lb a2, 0(a2)
		beq a4, a2, updatePlayer
		
		la a2, boxSymbol
		lb a2, 0(a2)
		# if next pos is box, move box
		# otherwise, next pos is another player, fail move
		bne a4, a2, failMove
		
		# move box
		addi a5, a5, 1  # a5 = next nrow
		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		lb a4, 0(a4)  # a4 = board[nrow * WIDTH + ncol]
		# if next pos is not target/empty, fail move
		la a2, targetSymbol
		lb a2, 0(a2)
		beq a4, a2, moveBoxDown
		la a2, emptySymbol
		lb a2, 0(a2)
		beq a4, a2, moveBoxDown
		j failMove
		
		moveBoxDown:
			la a2, boxSymbol
			lb a2, 0(a2)
			# otherwise, move box
			mul a4, a5, s1
			add a4, a4, a6
			add a4, a4, s2
			sb a2, 0(a4)  # store boxSymbol at next npos
			addi a5, a5, -1  # go back to npos
			j updatePlayer
		
	pLeft:
		mv a5, a0        # a5 = nrow
		addi a6, a1, -1  # a6 = ncol

		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		lb a4, 0(a4)  # a4 = board[nrow * WIDTH + ncol]
		
		la a2, wallSymbol
		lb a2, 0(a2)
		beq a4, a2, failMove  # if next pos is wall, invalid move
		
		# if next pos is empty/target, update player pos
		la a2, emptySymbol
		lb a2, 0(a2)
		beq a4, a2, updatePlayer
		la a2, targetSymbol
		lb a2, 0(a2)
		beq a4, a2, updatePlayer
		
		la a2, boxSymbol
		lb a2, 0(a2)
		# if next pos is box, move box
		# otherwise, next pos is another player, fail move
		bne a4, a2, failMove
		
		# move box
		addi a6, a6, -1  # a6 = next col
		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		lb a4, 0(a4)  # a4 = board[nrow * WIDTH + ncol]
		# if next pos is not target/empty, fail move
		la a2, targetSymbol
		lb a2, 0(a2)
		beq a4, a2, moveBoxLeft
		la a2, emptySymbol
		lb a2, 0(a2)
		beq a4, a2, moveBoxLeft
		j failMove
		
		moveBoxLeft:
			la a2, boxSymbol
			lb a2, 0(a2)
			# otherwise, move box
			mul a4, a5, s1
			add a4, a4, a6
			add a4, a4, s2
			sb a2, 0(a4)  # store boxSymbol at next npos
			addi a6, a6, 1  # go back to npos
			j updatePlayer
		
	pRight:
		mv a5, a0        # a5 = nrow
		addi a6, a1, 1   # a6 = ncol

		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		lb a4, 0(a4)  # a4 = board[nrow * WIDTH + ncol]
		
		la a2, wallSymbol
		lb a2, 0(a2)
		beq a4, a2, failMove  # if next pos is wall, invalid move
		
		# if next pos is empty/target, update player pos
		la a2, emptySymbol
		lb a2, 0(a2)
		beq a4, a2, updatePlayer
		la a2, targetSymbol
		lb a2, 0(a2)
		beq a4, a2, updatePlayer
		
		la a2, boxSymbol
		lb a2, 0(a2)
		# if next pos is box, move box
		# otherwise, next pos is another player, fail move
		bne a4, a2, failMove
		
		# move box
		addi a6, a6, 1  # a6 = next col
		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		lb a4, 0(a4)  # a4 = board[nrow * WIDTH + ncol]
		# if next pos is not target/empty, fail move
		la a2, targetSymbol
		lb a2, 0(a2)
		beq a4, a2, moveBoxRight
		la a2, emptySymbol
		lb a2, 0(a2)
		beq a4, a2, moveBoxRight
		j failMove
		
		moveBoxRight:
			la a2, boxSymbol
			lb a2, 0(a2)
			# otherwise, move box
			mul a4, a5, s1
			add a4, a4, a6
			add a4, a4, s2
			sb a2, 0(a4)  # store boxSymbol at next npos
			addi a6, a6, -1  # go back to npos
			j updatePlayer
	
	updatePlayer:
		# store character pos to ptr
		la a4, characterPtr
		lw a4, 0(a4)
		sb a5, 0(a4)
		sb a6, 1(a4)
	
		la a2, emptySymbol
		lb a2, 0(a2)
		mul a4, a0, s1
		add a4, a4, a1
		add a4, a4, s2
		sb a2, 0(a4)  # store emptySymbol at curr pos
	
		mul a4, a5, s1
		add a4, a4, a6
		add a4, a4, s2
		sb a3, 0(a4)  # store characterSymbol at npos
		
		li a0, 1
		jr ra
	
	failMove:
		li a7, 4
		la a0, promptMoveFail
		ecall 
		li a0, 0
		jr ra

displayBoard:
	# a1: HEIGHT, a2: WIDTH
	# returns NONE
	addi sp, sp, -8
	sw ra, 4(sp)
	sw s2, 0(sp)
	
	li a4, 0
	displayRow:
		beq a4, a1, endDisplay
		li a5, 0
		displayCol:
			beq a5, a2, endDisplayCol
			
			# curr element
			lb a0, 0(s2)
			# display curr element
			li a7, 11
			ecall
			
			nextDisplayCol:
				addi s2, s2, 1
				addi a5, a5, 1
				j displayCol
			
			endDisplayCol:
				li a7, 11
				la a0, newLine
				lb a0, 0(a0)  # next row
				ecall
			
				addi a4, a4, 1
				j displayRow
				
	endDisplay:
		lw s2, 0(sp)
		lw ra, 4(sp)
		addi sp, sp, 8
		jr ra
