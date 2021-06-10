#####################################################################
#
# All of the files in this directory and all subdirectories are:
# Copyright (c) 2021 Anthony Tedja
#
# Bitmap Display Configuration:
# 
# Unit width in pixels: 8
# Unit height in pixels: 8
# Display width in pixels: 256
# Display height in pixels: 256
# Base Address for Display: 0x10008000 ($gp)
#
# "s" to reset anytime, "j" to move left, "k" to move right
#
#####################################################################

.data
	addressDisplay:	.word	0x10008000	# Base Address for Display
	dataLocation: .word 0x100086bc, 0	# Potition, Acceleration (negative #s to 15)
	dataPlatform: .space 40				# Platform Space Memory Array 10
	dataDifficulty: .word 0, 0			# Speed (0 to 15), Score
	
	colorOrange: .word 0xf58f70			# Doodler Color
	colorYellow: .word 0xffbf00			# Text Color
	colorGrey: .word 0x2F3437			# Background Color
	colorWhite: .word 0xffffff			# Platforms Color
	colorBlue: .word 0x8cc8ff			# Special Platforms Color

.text
	# Load Constants & Data
	lw $s0, addressDisplay
	la $s1, dataLocation
	la $s2, dataPlatform
	la $s3, dataDifficulty

Main:
	# Reset Location Data
	li $t0, 0x100086bc
	sw $t0, 0($s1)
	sw $zero, 4($s1)
	
	# Reset Difficulty & Score Data
	sw $zero, 0($s3)
	sw $zero, 4($s3)
	
	# Initialize Platform Data & Start Game
	jal GeneratePlatforms
	j Game
	
Game:
	# Game Loop Functions
	jal Clean # Reset Display
	jal Draw # Draw Data & Bounce Check
	jal Jump # Adjust View & Doodle Location
	jal KeyboardListener # Keyboard Events
	jal Check # Check Alive
	
	# Calculate Difficulty
	lw $t0, 0($s3)	# Difficulty
	li $t1, 40	# Initial Speed

	ble $t0, 25, gameSpeed	# Initial - Fastest
	addi $t0, $zero, 15	# Fastest
	j gameSet
	
	gameSpeed:
		sub $t0, $t1, $t0
	gameSet:
	
		# Set Speed (Lower -> Faster)
		li $v0, 32
		move $a0, $t0
		syscall
		
		j Game
	
Clean:
	# Load Display info
	lw $t0, colorGrey
	move $t1, $s0
	addi $t2, $s0, 4096 # End of Display (128 * 32 = 4096)
	
	cleanWhile:
		# Fill Display with Background
		sw $t0, 0($t1)
		addi $t1, $t1, 4
		bge $t1, $t2, cleanEnd
		j cleanWhile
	cleanEnd:
		jr $ra
	
Draw:
	# Draw Doodler
	lw $t0, colorOrange
	lw $t1, 0($s1)
	
	sw $t0, -128($t1)
	sw $t0, -124($t1)
	sw $t0, -132($t1)
	sw $t0, -256($t1)
	sw $t0, -4($t1)
	sw $t0, 4($t1)
	
	# Draw Platforms
	li $t2, 0	# Loop 10 Times
	li $t3, 4	# Offset Multiplier
	drawWhile:
		 # Loop through platform locations
		add $t4, $t2, $s2
		lw $t5, 0($t4)
		
		# Check if on platform
		sub $t6, $t5, $t1
		abs $t6, $t6
		bgt $t6, 16, drawPlatform
		
		# Has to be falling down to bounce up
		lw $t1, 4($s1)
		bgt $t1, -1, drawPlatform
		
		beqz $t2, drawBoost
		
		# Set Acceleration positive 15
		li $t0, 15
		sw $t0 , 4($s1)
		
		drawPlatform:
			# Make First Platform Blue
			beqz $t2, drawIf
			lw $t0, colorWhite
			j drawDone
			
			drawIf:
				lw $t0, colorBlue
				sw $t0, -128($t5)
				
			drawDone:
				# Draw platform
				sw $t0, 0($t5)
				sw $t0, 4($t5)
				sw $t0, -4($t5)
				sw $t0, 8($t5)
				sw $t0, -8($t5)
				sw $t0, 12($t5)
				sw $t0, -12($t5)
				j drawLoopGuard
		
		drawBoost:
			# Double bounce on blue platform
			li $t0, 30
			sw $t0 , 4($s1)
			
		drawLoopGuard:
			bge $t2, 36, drawEnd
    			addi $t2, $t2, 4
    			j drawWhile
    	drawEnd:
		jr $ra

Jump:
	# Load Doodler Data
	lw $t0, 0($s1) # Position
	lw $t1, 4($s1) # Acceleration
	
	# Variable Sleep when near top of parabola for gravity acceleration
	sub $t2, $t1, $zero
	abs $t2, $t2
	bgt $t2, 4, jumpContinue
	
	# Set Sleep time
	li $t3, 10
	mult $t2, $t3
	mflo $t2
	
	li $t3, 50
	sub $t3, $t3, $t2	# Sleep value 10 to 50
	
	# Sleep
	li $v0, 32
	move $a0, $t3
	syscall
	
	jumpContinue:
		# Check direction
		bgtz $t1, jumpUp
		j jumpDown
	
	jumpUp:
		# Check height under midheight area
		addi $t2, $s0, 1664
		bge $t0, $t2, jumpNoAnimate
		
		# Increase Speed & Score
		lw $t3, 0($s3)
		lw $t4, 4($s3)
		
		# Speed up once every 20 height
		addi $t4, $t4, 1
		div $t3, $t4, 20
		
		sw $t3, 0($s3)
		sw $t4, 4($s3)
		
		# Animate Display
		li $t3, 0	# Loop 10 Times
		li $t4, 4	# Offset Multiplier
		
		jumpWhile:
			# Loop through platform locations
			add $t5, $t3, $s2
			lw $t6, 0($t5)
			
			# Move it down once
			addi $t6, $t6, 128
			
			# If still onscreen
			ble $t6, 0x10008ffc, jumpShift
			
			# Generate Random from 0 to 200
			li $a1, 200
			li $v0, 42
			syscall
			
			# Reset Random Platform
			mult $a0, $t4
			mflo $t6
			addi $t6, $t6, 264	# Offset so not too high
			add $t6, $t6, $s0
			
			jumpShift:
				# Store shifted platform
				sw $t6, 0($t5)
				
				# Loop Guard
				bge $t3, 36, jumpDone
				addi $t3, $t3, 4
				j jumpWhile
		j jumpDone
	
	jumpNoAnimate:
		# Move Doodler Up
		addi $t0, $t0, -128
		sw $t0, 0($s1)
		
		j jumpDone
	
	jumpDown:
		# Move Doodler Up
		addi $t0, $t0, 128
		sw $t0, 0($s1)
		
	jumpDone:
		# Decrement Acceleration
		addi $t1, $t1 , -1
		sw $t1, 4($s1)
		jr $ra
	
KeyboardListener:
	# Listen for keyboard press
	lw $t0, 0xffff0000 
	beq $t0, 1, keyboardListenerIf
	j keyboardListenerDone
	
	keyboardListenerIf:
		# When key is pressed
		lw $t1, 0xffff0004
		lw $t0, 0($s1)
		
		# Listen for "s", "j", or "k"
		beq $t1, 106, keyboardListenerLeft
		beq $t1, 107, keyboardListenerRight
		bne $t1, 115, keyboardListenerDone
		
		# Reset when "s" is pressed
		j Main
	
	keyboardListenerLeft:
		# Move Doodler Left
        	addi $t0, $t0, -4
        	sw $t0, 0($s1)
        	j keyboardListenerDone
        	
        keyboardListenerRight:
        	# Move Doodler Right
        	addi $t0, $t0, 4
        	sw $t0, 0($s1)
        	j keyboardListenerDone
        	
        keyboardListenerDone:
        	jr $ra

Check:
	# Check Vertical Potition Lower than Display
	lw $t0, 0($s1)
	addi $t1, $s0, 4092
	bgt $t0, $t1, checkIf
	jr $ra
	checkIf:
		# End Game
		j End

GeneratePlatforms:
	# Randomly Generate Platforms
	li $t0, 0	# Loop 10 Times
	li $t1, 4	# Offset Multiplier
	
	generatePlatformsWhile:
		# Generate Random from 0 to 1000
		li $a1, 1000
    		li $v0, 42
    		syscall
    		
    		# Save Random Address
    		mult $a0, $t1
    		mflo $t2
    		add $t2, $t2, $s0	# Random 0 to 4000
    		
    		# Save New Platform Location in Array
    		add $t3, $t0, $s2
    		sw $t2, 0($t3)
    		
    		bge $t0, 36, generatePlatformsEnd
    		addi $t0, $t0, 4
    		j generatePlatformsWhile
    		
    	generatePlatformsEnd:
    		# Make the first platform right under to start
    		li $t1, 0x10008d3c
    		sw $t1, 0($s2)
    		jr $ra
    	
End:
	# Draw "E"
	lw $t0, colorYellow
	
	sw $t0, 1568($s0)
	sw $t0, 1572($s0)
	sw $t0, 1576($s0)
	sw $t0, 1580($s0)
	
	sw $t0, 1696($s0)
	sw $t0, 1824($s0)
	
	sw $t0, 1952($s0)
	sw $t0, 1956($s0)
	sw $t0, 1960($s0)
	sw $t0, 1964($s0)
	
	sw $t0, 2080($s0)
	sw $t0, 2208($s0)
	sw $t0, 2336($s0)
	
	sw $t0, 2464($s0)
	sw $t0, 2468($s0)
	sw $t0, 2472($s0)
	sw $t0, 2476($s0)
	
	# Draw "N"
	sw $t0, 1592($s0)
	sw $t0, 1720($s0)
	sw $t0, 1848($s0)
	sw $t0, 1976($s0)
	sw $t0, 2104($s0)
	sw $t0, 2232($s0)
	sw $t0, 2360($s0)
	sw $t0, 2488($s0)
	
	sw $t0, 1852($s0)
	sw $t0, 1980($s0)
	sw $t0, 2112($s0)
	sw $t0, 2240($s0)
	
	sw $t0, 1604($s0)
	sw $t0, 1732($s0)
	sw $t0, 1860($s0)
	sw $t0, 1988($s0)
	sw $t0, 2116($s0)
	sw $t0, 2244($s0)
	sw $t0, 2372($s0)
	sw $t0, 2500($s0)
	
	# Draw "D"
	sw $t0, 1616($s0)
	sw $t0, 1744($s0)
	sw $t0, 1872($s0)
	sw $t0, 2000($s0)
	sw $t0, 2128($s0)
	sw $t0, 2256($s0)
	sw $t0, 2384($s0)
	sw $t0, 2512($s0)
	
	sw $t0, 1620($s0)
	sw $t0, 1624($s0)
	sw $t0, 1752($s0)
	
	sw $t0, 2516($s0)
	sw $t0, 2520($s0)
	sw $t0, 2392($s0)
	
	sw $t0, 1756($s0)
	sw $t0, 1884($s0)
	sw $t0, 2012($s0)
	sw $t0, 2140($s0)
	sw $t0, 2268($s0)
	sw $t0, 2396($s0)
	
	# Check for Keyboard Click
	lw $t0, 0xffff0000
	beq $t0, 1, endClickIf
	j End
	endClickIf:
		# Check if "s" is selected
		lw $t1, 0xffff0004
		beq $t1, 115, endDone
		j End
	endDone:
		j Main
	
Exit:
	li $v0, 10 # Terminate Program
	syscall
