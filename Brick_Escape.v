module Brick_Escape
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
		  HEX0,
		  HEX1,
		  HEX2,
		  HEX3,
		  HEX4,
		  HEX5,
		  HEX6,
		  HEX7,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input   [9:0]   SW;
	input   [3:0]   KEY;
	output  [7:0]   HEX0;
	output  [7:0]   HEX1;
	output  [7:0]   HEX2;
	output  [7:0]   HEX3;
	output  [7:0]   HEX4;
	output  [7:0]   HEX5;
	output  [7:0]   HEX6;
	output  [7:0]   HEX7;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = ~SW[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [6:0] x;
	wire [6:0] y;
	
	// writeEn will always be high
	wire writeEn = 1'b1;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
	 
	 // RATE DIVIDER TO SLOW DOWN THE UPDATE PROCESS FOR PLAYER AND ENEMIES
	 wire update;		// Will be used to update position of player and enemies
	 rateDivider ratedivider(CLOCK_50, update);
	 
	 
	 // PLAYER PROPERTIES /////////////////////////////////////////////////////////////////
	 wire [6:0] playerx;		// x position of the player
	 wire [6:0] playery;		// y position of the player
	 wire collided;
	 
	 Player player(CLOCK_50, update, resetn, playerx, playery, KEY, wonGame, collided);
	 
	 
	 // ENEMIES PROPERTIES ////////////////////////////////////////////////////////////////
	 wire [6:0] enemyx;
	 wire [6:0] enemyy;
	 wire [6:0] collisionx;
	 wire [6:0] collisiony;
	 wire [6:0] enemyIterator;
	 wire [6:0] collisionIterator;
	 
	 EnemyController enemies(CLOCK_50, update, resetn, enemyx, enemyy, collisionx, collisiony, enemyIterator, collisionIterator);
	 
	 // COLLISION /////////////////////////////////////////////////////////////////////
	 Collision collision(CLOCK_50, clear_screen, playerx, playery, collisionx, collisiony, collided, collisionIterator, wonGame);
	 
	 // CONTROL AND DATAPATH PROPERTIES ///////////////////////////////////
	 wire go_next, clear_screen, print_path, update_player, update_enemy, wait_screen;	// ENABLE SIGNALS
	 
	 Controller controller(CLOCK_50, resetn, go_next, print_path, update_player, update_enemy, wait_screen);
	 
	 Datapath datapath(CLOCK_50, resetn, clear_screen, go_next, print_path, update_player, update_enemy, wait_screen, playerx, playery, enemyx, enemyy, enemyIterator, x, y, colour);
	 
	 // SCORING ///////////////////////////////////////////////////////////////
	 wire wonGame;
	 Score score(CLOCK_50, resetn, playerx, playery, collided, wonGame, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7);

endmodule

/*
*	COLLISION MODULE
*
*	This will assist in detecting collision between the player's position and the enemies/walls in the game.
*
*/
module Collision(clk, clear_screen, playerx, playery, enemyx, enemyy, collided, collisionIterator, wonGame);
	input clk;
	input [6:0] playerx;
	input [6:0] playery;
	input [6:0] enemyx;
	input [6:0] enemyy;
	output reg collided;
	output reg [6:0] collisionIterator; // Iterator to check through each enemy in the enemy array.
	output reg wonGame;
	output reg clear_screen;
	
	always @(posedge clk)
	begin
		collisionIterator = collisionIterator + 1'd1;
		if(collisionIterator > 7'd66) // Hard coded the number of enemies
		begin
			collisionIterator = 1'd0;
		end
		else
		begin
			// Player has collided with the current enemy of the current collision iteration
			if((playerx == enemyx) && (playery == enemyy))
			begin
				collided = 1'd1;
			end
			// Check if the player has collided with the walls
			else if(((7'd11 <= playerx && playerx <= 7'd21) && (7'd0 <= playery && playery <= 7'd40)) ||
			((7'd11 <= playerx && playerx <= 7'd36) && (7'd40 <= playery && playery <= 7'd42)) ||
			((7'd26 <= playerx && playerx <= 7'd36) && (7'd10 <= playery && playery <= 7'd42)) ||
			((7'd36 <= playerx && playerx <= 7'd43) && (7'd10 <= playery && playery <= 7'd30)) ||
			((7'd43 <= playerx && playerx <= 7'd51) && (7'd10 <= playery && playery <= 7'd60)) ||
			((7'd11 <= playerx && playerx <= 7'd51) && (7'd60 <= playery && playery <= 7'd70)) ||
			((7'd11 <= playerx && playerx <= 7'd21) && (7'd70 <= playery && playery <= 7'd75)) ||
			((7'd11 <= playerx && playerx <= 7'd51) && (7'd75 <= playery && playery <= 7'd83)) ||
			((7'd41 <= playerx && playerx <= 7'd51) && (7'd83 <= playery && playery <= 7'd88)) ||
			((7'd11 <= playerx && playerx <= 7'd51) && (7'd88 <= playery && playery <= 7'd94)) ||
			((7'd11 <= playerx && playerx <= 7'd15) && (7'd95 <= playery && playery <= 7'd99)) ||
			((7'd11 <= playerx && playerx <= 7'd66) && (7'd96 <= playery && playery <= 7'd99)) ||
			((7'd56 <= playerx && playerx <= 7'd66) && (7'd10 <= playery && playery <= 7'd96)) ||
			((7'd66 <= playerx && playerx <= 7'd86) && (7'd10 <= playery && playery <= 7'd40)) ||
			((7'd76 <= playerx && playerx <= 7'd77) && (7'd40 <= playery && playery <= 7'd100)) ||
			((7'd11 <= playerx && playerx <= 7'd77) && (7'd101 <= playery && playery <= 7'd110)) ||
			((7'd11 <= playerx && playerx <= 7'd31) && (7'd110 <= playery && playery <= 7'd115)) ||
			((7'd11 <= playerx && playerx <= 7'd96) && (7'd115 <= playery && playery <= 7'd120)) ||
			((7'd86 <= playerx && playerx <= 7'd96) && (7'd50 <= playery && playery <= 7'd115)) ||
			((7'd96 <= playerx && playerx <= 7'd127) && (7'd50 <= playery && playery <= 7'd54)))
			begin
				collided = 1'd0;
				clear_screen = 1'd0;
			end
			else // Player has collided with the wall
			begin
				clear_screen = 1'd1;
				collided = 1'd1;
			end
		end
		// This represents whether the player has reached the end of the stage or not
		if((playerx > 7'd124 && playerx < 7'd126) && (playery > 7'd50 && playery < 7'd55))
			begin
				wonGame = 1'd1;
			end
		else
			begin
				wonGame = 1'd0;
			end
	end
endmodule


/*
*	DATAPATH MODULE
*
*	This will allow data to flow through the program smoothly and in it's correct path.
*/
module Datapath(clk, resetn, clear_screen, go_next, print_path, update_player, update_enemy, wait_screen, playerx, playery, enemyx, enemyy, enemyIterator, x, y, colour);
	input clk;
	input resetn;
	input print_path;
	input update_player;
	input update_enemy;
	input wait_screen;
	input [6:0] playerx;
	input [6:0] playery;
	input [6:0] enemyx;
	input [6:0] enemyy;
	reg [6:0] clear_screen_x;
	reg [6:0] clear_screen_y;
	parameter NUMOFENEMIES = 66;
	reg [6:0] pathx;
	reg [6:0] pathy;
	output reg [6:0] enemyIterator;
	output reg go_next;
	output reg [6:0] x;
	output reg [6:0] y;
	output reg [2:0] colour;
	
	// REGs to help create the hardcoded stage/path
	input clear_screen;
	reg cleared;
	reg path1;
	reg path2;
	reg path3;
	reg path4;
	reg path5;
	reg path6;
	reg path7;
	reg path8;
	reg path9;
	reg path10;
	reg path11;
	reg path12;
	reg path13;
	reg path14;
	reg path15;
	reg path16;
	reg path17;
	reg path18;
	reg path19;
	reg path20;
	reg finishLine;
	reg get_new_path;
	reg [6:0] pathx_beg;
	reg [6:0] pathy_beg;
	reg [6:0] pathx_end;
	reg [6:0] pathy_end;
	
	// Initially get_new_path is 1 thus we will get the first path and display it
	// The rest of the path will follow through from then on.
	initial begin
		get_new_path = 1'd1;
	end
	
	always@(posedge clk)
		begin
			if(~resetn)		// Basic reset functionality
				begin
					go_next = 1'd0;
					x = 7'd15;
					y = 7'd2;
					colour = 3'b011;
				end
			else
				begin
					/* Depending on the value of clear_screen, this will both clear the screen and print out the hard coded stage
					*	If clear_screen is turned off, this will still reprint the path/stage.
					*	(The way the clear screen works is that it will print a black pixel on each pixel of the VGA)
					*/
					if(print_path)
					begin
						go_next = 1'd0;
						// clear_screen is turned on, thus the screen must be cleared.
						if(clear_screen)
						begin
							// Set cleared to 0 (the screen is not cleared yet)
							cleared = 1'b0;
						end
						// This will keep looping until the screen is cleared
						if(!cleared)
						begin
							// Set the x and y value of the vga to the current pixel of the screen to display a black pixel (to be cleared)
							x = clear_screen_x;
							y = clear_screen_y;
							colour = 3'b000;
							// Iterate through each pixel until the whole screen is black
							clear_screen_x = clear_screen_x + 1'd1;	// Continue onto the next pixel to the right
							if(clear_screen_x > 7'd126)	// Iteration reaches the far right of the screen
							begin
								clear_screen_x = 1'd0;	// Restart the iteration back to the beginning (far left of the screen)
								clear_screen_y = clear_screen_y + 1'd1;	// Go one pixel down
							end
							else if(clear_screen_x == 7'd126 && clear_screen_y == 7'd126)	// Iteration reaches the end of the screen (bottom-right corner)
							begin
								clear_screen_x = 1'd0;	// Reset the iteration for future iterations
								clear_screen_y = 1'd0;
								cleared = 1'b1;	// Whole screen has been cleared, print out the path next
							end
						end
						else
						begin
							// This will differentiate the overall path of the stage and the finish line
							// Note that the finish line will be a teal colour while the stage is white.
							// This part will change the colour correspondingly
							if(!path20)
							begin
								colour = 3'b111;
							end
							else
							begin
								colour = 3'b011;
							end
							/*
							* get_new_path will only be 1 everytime an individual path is displayed, this will act as an
							* variable to determine whether properties of a path needs to be initialized. Thus this will
							* help by calling each if statement once and only once in order.
							*/
							if(!path1 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd0;
								pathx = 7'd10;
								pathy = 7'd0;
								pathx_end = 7'd20;
								pathy_end = 7'd40;
								get_new_path = 1'd0;
							end
							if(!path2 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd40;
								pathx = 7'd10;
								pathy = 7'd40;
								pathx_end = 7'd35;
								pathy_end = 7'd42;
								get_new_path = 1'd0;
							end
							if(!path3 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd25;
								pathy_beg = 7'd10;
								pathx = 7'd25;
								pathy = 7'd10;
								pathx_end = 7'd35;
								pathy_end = 7'd42;
								get_new_path = 1'd0;
							end
							if(!path4 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd35;
								pathy_beg = 7'd10;
								pathx = 7'd35;
								pathy = 7'd10;
								pathx_end = 7'd42;
								pathy_end = 7'd30;
								get_new_path = 1'd0;
							end
							if(!path5 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd42;
								pathy_beg = 7'd10;
								pathx = 7'd42;
								pathy = 7'd10;
								pathx_end = 7'd50;
								pathy_end = 7'd60;
								get_new_path = 1'd0;
							end
							if(!path6 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd60;
								pathx = 7'd10;
								pathy = 7'd60;
								pathx_end = 7'd50;
								pathy_end = 7'd70;
								get_new_path = 1'd0;
							end
							if(!path7 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd70;
								pathx = 7'd10;
								pathy = 7'd70;
								pathx_end = 7'd20;
								pathy_end = 7'd75;
								get_new_path = 1'd0;
							end
							if(!path8 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd75;
								pathx = 7'd10;
								pathy = 7'd75;
								pathx_end = 7'd50;
								pathy_end = 7'd83;
								get_new_path = 1'd0;
							end
							if(!path9 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd40;
								pathy_beg = 7'd83;
								pathx = 7'd40;
								pathy = 7'd83;
								pathx_end = 7'd50;
								pathy_end = 7'd88;
								get_new_path = 1'd0;
							end
							if(!path10 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd88;
								pathx = 7'd10;
								pathy = 7'd88;
								pathx_end = 7'd50;
								pathy_end = 7'd94;
								get_new_path = 1'd0;
							end
							if(!path11 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd95;
								pathx = 7'd10;
								pathy = 7'd95;
								pathx_end = 7'd14;
								pathy_end = 7'd99;
								get_new_path = 1'd0;
							end
							if(!path12 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd96;
								pathx = 7'd10;
								pathy = 7'd96;
								pathx_end = 7'd65;
								pathy_end = 7'd99;
								get_new_path = 1'd0;
							end
							if(!path13 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd55;
								pathy_beg = 7'd10;
								pathx = 7'd55;
								pathy = 7'd10;
								pathx_end = 7'd65;
								pathy_end = 7'd96;
								get_new_path = 1'd0;
							end
							if(!path14 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd65;
								pathy_beg = 7'd10;
								pathx = 7'd65;
								pathy = 7'd10;
								pathx_end = 7'd85;
								pathy_end = 7'd40;
								get_new_path = 1'd0;
							end
							if(!path15 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd75;
								pathy_beg = 7'd40;
								pathx = 7'd75;
								pathy = 7'd40;
								pathx_end = 7'd76;
								pathy_end = 7'd100;
								get_new_path = 1'd0;
							end
							if(!path16 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd101;
								pathx = 7'd10;
								pathy = 7'd101;
								pathx_end = 7'd76;
								pathy_end = 7'd110;
								get_new_path = 1'd0;
							end
							if(!path17 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd110;
								pathx = 7'd10;
								pathy = 7'd110;
								pathx_end = 7'd30;
								pathy_end = 7'd115;
								get_new_path = 1'd0;
							end
							if(!path18 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd10;
								pathy_beg = 7'd115;
								pathx = 7'd10;
								pathy = 7'd115;
								pathx_end = 7'd95;
								pathy_end = 7'd120;
								get_new_path = 1'd0;
							end
							if(!path19 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd85;
								pathy_beg = 7'd50;
								pathx = 7'd85;
								pathy = 7'd50;
								pathx_end = 7'd95;
								pathy_end = 7'd115;
								get_new_path = 1'd0;
							end
							if(!path20 && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd95;
								pathy_beg = 7'd50;
								pathx = 7'd95;
								pathy = 7'd50;
								pathx_end = 7'd126;
								pathy_end = 7'd54;
								get_new_path = 1'd0;
							end
							if(!finishLine && get_new_path == 1'd1)
							begin
								pathx_beg = 7'd124;
								pathy_beg = 7'd50;
								pathx = 7'd124;
								pathy = 7'd50;
								pathx_end = 7'd126;
								pathy_end = 7'd54;
								get_new_path = 1'd0;
							end
							// This will iterate through the pixels of the specified path
							if(pathx > pathx_end)
							begin
								pathx = pathx_beg;
								pathy = pathy + 1'd1;
							end
							// Iteration has reached the end of the path
							else if(pathx == pathx_end && pathy == pathy_end)
							begin
								// Prepare and get the new path
								get_new_path = 1'd1;
								// Depending on which path we just finish printing, turn on the reg corresponding to the path
								if(!path1)
									path1 <= 1'd1;
								else if(!path2)
									path2 <= 1'd1;
								else if(!path3)
									path3 <= 1'd1;
								else if(!path4)
									path4 <= 1'd1;
								else if(!path5)
									path5 <= 1'd1;
								else if(!path6)
									path6 <= 1'd1;
								else if(!path7)
									path7 <= 1'd1;
								else if(!path8)
									path8 <= 1'd1;
								else if(!path9)
									path9 <= 1'd1;
								else if(!path10)
									path10 <= 1'd1;
								else if(!path11)
									path11 <= 1'd1;
								else if(!path12)
									path12 <= 1'd1;
								else if(!path13)
									path13 <= 1'd1;
								else if(!path14)
									path14 <= 1'd1;
								else if(!path15)
									path15 <= 1'd1;
								else if(!path16)
									path16 <= 1'd1;
								else if(!path17)
									path17 <= 1'd1;
								else if(!path18)
									path18 <= 1'd1;
								else if(!path19)
									path19 <= 1'd1;
								else if(!path20)
									path20 <= 1'd1;
								else
								// All of the paths have been displayed, go to the next state
								begin
									go_next = 1'd1;
									path1 = 1'd0;
									path2 = 1'd0;
									path3 = 1'd0;
									path4 = 1'd0;
									path5 = 1'd0;
									path6 = 1'd0;
									path7 = 1'd0;
									path8 = 1'd0;
									path9 = 1'd0;
									path10 = 1'd0;
									path11 = 1'd0;
									path12 = 1'd0;
									path13 = 1'd0;
									path14 = 1'd0;
									path15 = 1'd0;
									path16 = 1'd0;
									path17 = 1'd0;
									path18 = 1'd0;
									path19 = 1'd0;
									path20 = 1'd0;
								end
							end
							// Iterate through the x axis of the path
							pathx = pathx + 1'd1;
							x = pathx;
							y = pathy;
						end
					end
					/* This will re-display the updated x and y position of the player
					*/
					if(update_player)
					begin
						go_next = 1'd0;
						x = playerx;
						y = playery;
						colour = 3'b011;
						go_next = 1'd1;
					end
					/* This will re-display the updated x and y position of each enemy
					*/
					if(update_enemy)
					begin
						go_next = 1'd0;
						x = enemyx;
						y = enemyy;
						colour = 3'b100;
						// enemyIterator will act as the enemy array index
						enemyIterator = enemyIterator + 1'd1;
						if(enemyIterator >= NUMOFENEMIES)
						begin
							go_next = 1'd1;
							enemyIterator = 1'd0;
						end
					end
					/* Acts as the end of the refresh
					*/
					if(wait_screen)
					begin
						go_next = 1'd1;
					end
				end
		end
endmodule

/*
*	CONTROLLER MODULE
*
*	This will control the state at which the game is at, note that the game will always be writing something to the vga
*	and will either, print a path, update the player position or update all the enemy's positions.
*/
module Controller(clk, resetn, go_next, print_path, update_player, update_enemy, wait_screen);
	input clk;
	input resetn;
	input go_next;
	output reg print_path;
	output reg update_player;
	output reg update_enemy;
	output reg wait_screen;
	
	reg [1:0] current_state, next_state;
	
	// Represents the different states of the finite state machine
	localparam	S_PRINT_PATH		= 2'd0,
					S_UPDATE_PLAYER	= 2'd1,
					S_UPDATE_ENEMY		= 2'd2,
					S_WAIT_SCREEN		= 2'd3;
	
	always @(*)
		begin: state_table
			case (current_state)
				S_PRINT_PATH: 		next_state = go_next ? S_UPDATE_PLAYER :	S_PRINT_PATH;
				S_UPDATE_PLAYER: 	next_state = go_next ? S_UPDATE_ENEMY	:	S_UPDATE_PLAYER;
				S_UPDATE_ENEMY:	next_state = go_next ? S_WAIT_SCREEN	:	S_UPDATE_ENEMY;
				S_WAIT_SCREEN:		next_state = S_PRINT_PATH;
			endcase
		end
	
	always @(*)
		begin: enable_signals
			print_path = 1'd0;
			update_player = 1'd0;
			update_enemy = 1'd0;
			wait_screen = 1'd0;
			case (current_state)
				S_PRINT_PATH:
					begin
						print_path = 1'd1;
					end
				S_UPDATE_PLAYER:
					begin
						update_player = 1'd1;
					end
				S_UPDATE_ENEMY:
					begin
						update_enemy = 1'd1;
					end
				S_WAIT_SCREEN:
					begin
						wait_screen = 1'd1;
					end
			endcase
		end
	
	always @(posedge clk)
		begin: curr_state_FSM
			if(~resetn)
				current_state <= S_PRINT_PATH;
			else
				current_state <= next_state;
		end
	
endmodule

/*
*	ENEMY CONTROLLER MODULE
*	
*	Instantiates multiple enemies and controls the properties of each enemy with the help of other modules such as
*	the Controller module, Datapath module and Collision module.
*/
module EnemyController(clk, update, resetn, enemyx, enemyy, collisionx, collisiony, enemyIterator, collisionIterator);
	 input update;
	 input resetn;
	 input clk;
	 input [6:0] enemyIterator;
	 input [6:0] collisionIterator;
	 parameter NUMOFENEMIES = 66;
	 output reg [6:0] enemyx;			// x position of the current enemy
	 output reg [6:0] enemyy;			// y position of the current enemy
	 output reg [6:0] collisionx;
	 output reg [6:0] collisiony;
	 wire [6:0] enemyx_array [0:NUMOFENEMIES-1];	// x position of all enemies
	 wire [6:0] enemyy_array [0:NUMOFENEMIES-1];	// y position of all enemies
	 
	 // Instantiate multiple enemies
	 Enemy enemy1(update, resetn, enemyx_array[0], enemyy_array[0], 1'b1, 1'b1, 7'd10, 7'd11, 7'd5);
	 Enemy enemy2(update, resetn, enemyx_array[1], enemyy_array[1], 1'b1, 1'b0, 7'd10, 7'd21, 7'd15);
	 Enemy enemy3(update, resetn, enemyx_array[2], enemyy_array[2], 1'b1, 1'b1, 7'd10, 7'd11, 7'd10);
	 Enemy enemy4(update, resetn, enemyx_array[3], enemyy_array[3], 1'b1, 1'b0, 7'd10, 7'd21, 7'd20);
	 Enemy enemy5(update, resetn, enemyx_array[4], enemyy_array[4], 1'b1, 1'b1, 7'd10, 7'd11, 7'd30);
	 Enemy enemy6(update, resetn, enemyx_array[5], enemyy_array[5], 1'b1, 1'b0, 7'd10, 7'd21, 7'd35);
	 Enemy enemy7(update, resetn, enemyx_array[6], enemyy_array[6], 1'b1, 1'b1, 7'd10, 7'd41, 7'd85);
	 Enemy enemy8(update, resetn, enemyx_array[7], enemyy_array[7], 1'b1, 1'b1, 7'd25, 7'd11, 7'd41);
	 Enemy enemy9(update, resetn, enemyx_array[8], enemyy_array[8], 1'b0, 1'b0, 7'd2, 7'd23, 7'd40);
	 Enemy enemy10(update, resetn, enemyx_array[9], enemyy_array[9], 1'b0, 1'b0, 7'd20, 7'd38, 7'd10);
	 Enemy enemy11(update, resetn, enemyx_array[10], enemyy_array[10], 1'b1, 1'b1, 7'd8, 7'd43, 7'd31);
	 Enemy enemy12(update, resetn, enemyx_array[11], enemyy_array[11], 1'b1, 1'b0, 7'd8, 7'd51, 7'd41);
	 Enemy enemy13(update, resetn, enemyx_array[12], enemyy_array[12], 1'b1, 1'b1, 7'd8, 7'd43, 7'd51);
	 Enemy enemy14(update, resetn, enemyx_array[13], enemyy_array[13], 1'b1, 1'b0, 7'd8, 7'd51, 7'd59);
	 Enemy enemy15(update, resetn, enemyx_array[14], enemyy_array[14], 1'b0, 1'b0, 7'd10, 7'd40, 7'd60);
	 Enemy enemy16(update, resetn, enemyx_array[15], enemyy_array[15], 1'b0, 1'b1, 7'd10, 7'd35, 7'd70);
	 Enemy enemy17(update, resetn, enemyx_array[16], enemyy_array[16], 1'b0, 1'b0, 7'd10, 7'd30, 7'd60);
	 Enemy enemy18(update, resetn, enemyx_array[17], enemyy_array[17], 1'b0, 1'b1, 7'd10, 7'd25, 7'd70);	 
	 Enemy enemy19(update, resetn, enemyx_array[18], enemyy_array[18], 1'b0, 1'b0, 7'd10, 7'd15, 7'd60);
	 Enemy enemy20(update, resetn, enemyx_array[19], enemyy_array[19], 1'b1, 1'b1, 7'd10, 7'd11, 7'd72);
	 Enemy enemy21(update, resetn, enemyx_array[20], enemyy_array[20], 1'b0, 1'b0, 7'd8, 7'd30, 7'd75);
	 Enemy enemy22(update, resetn, enemyx_array[21], enemyy_array[21], 1'b0, 1'b1, 7'd8, 7'd38, 7'd83);
	 Enemy enemy23(update, resetn, enemyx_array[22], enemyy_array[22], 1'b0, 1'b0, 7'd6, 7'd35, 7'd88);
	 Enemy enemy24(update, resetn, enemyx_array[23], enemyy_array[23], 1'b0, 1'b0, 7'd6, 7'd19, 7'd88);
	 Enemy enemy25(update, resetn, enemyx_array[24], enemyy_array[24], 1'b0, 1'b1, 7'd3, 7'd20, 7'd99);
	 Enemy enemy26(update, resetn, enemyx_array[25], enemyy_array[25], 1'b0, 1'b0, 7'd3, 7'd23, 7'd96);
	 Enemy enemy27(update, resetn, enemyx_array[26], enemyy_array[26], 1'b0, 1'b1, 7'd3, 7'd26, 7'd99);
	 Enemy enemy28(update, resetn, enemyx_array[27], enemyy_array[27], 1'b0, 1'b0, 7'd3, 7'd29, 7'd96);
	 Enemy enemy29(update, resetn, enemyx_array[28], enemyy_array[28], 1'b0, 1'b1, 7'd3, 7'd32, 7'd99);
	 Enemy enemy30(update, resetn, enemyx_array[29], enemyy_array[29], 1'b0, 1'b0, 7'd3, 7'd35, 7'd96);
	 Enemy enemy31(update, resetn, enemyx_array[30], enemyy_array[30], 1'b0, 1'b1, 7'd3, 7'd38, 7'd99);
	 Enemy enemy32(update, resetn, enemyx_array[31], enemyy_array[31], 1'b0, 1'b0, 7'd3, 7'd41, 7'd96);
	 Enemy enemy33(update, resetn, enemyx_array[32], enemyy_array[32], 1'b0, 1'b1, 7'd3, 7'd44, 7'd99);
	 Enemy enemy34(update, resetn, enemyx_array[33], enemyy_array[33], 1'b0, 1'b0, 7'd3, 7'd47, 7'd96);
	
	 Enemy enemy35(update, resetn, enemyx_array[34], enemyy_array[34], 1'b1, 1'b1, 7'd10, 7'd56, 7'd88);
	 Enemy enemy36(update, resetn, enemyx_array[35], enemyy_array[35], 1'b1, 1'b0, 7'd10, 7'd66, 7'd80);
	 Enemy enemy37(update, resetn, enemyx_array[36], enemyy_array[36], 1'b1, 1'b1, 7'd10, 7'd56, 7'd70);
	 Enemy enemy38(update, resetn, enemyx_array[37], enemyy_array[37], 1'b1, 1'b0, 7'd10, 7'd66, 7'd65);
	 Enemy enemy39(update, resetn, enemyx_array[38], enemyy_array[38], 1'b1, 1'b1, 7'd10, 7'd56, 7'd55);
	 Enemy enemy40(update, resetn, enemyx_array[39], enemyy_array[39], 1'b1, 1'b0, 7'd10, 7'd66, 7'd50);
	 Enemy enemy41(update, resetn, enemyx_array[40], enemyy_array[40], 1'b0, 1'b1, 7'd4, 7'd76, 7'd40);
	 Enemy enemy42(update, resetn, enemyx_array[41], enemyy_array[41], 1'b1, 1'b1, 7'd6, 7'd73, 7'd40);
	
	 Enemy enemy43(update, resetn, enemyx_array[42], enemyy_array[42], 1'b0, 1'b0, 7'd9, 7'd76, 7'd101);
	 Enemy enemy44(update, resetn, enemyx_array[43], enemyy_array[43], 1'b0, 1'b1, 7'd9, 7'd65, 7'd110);
	 Enemy enemy45(update, resetn, enemyx_array[44], enemyy_array[44], 1'b0, 1'b1, 7'd9, 7'd60, 7'd110);
	 Enemy enemy46(update, resetn, enemyx_array[45], enemyy_array[45], 1'b0, 1'b1, 7'd9, 7'd55, 7'd110);
	 Enemy enemy47(update, resetn, enemyx_array[46], enemyy_array[46], 1'b0, 1'b1, 7'd9, 7'd50, 7'd110);
	
	 Enemy enemy48(update, resetn, enemyx_array[47], enemyy_array[47], 1'b0, 1'b0, 7'd9, 7'd45, 7'd101);
	 Enemy enemy49(update, resetn, enemyx_array[48], enemyy_array[48], 1'b0, 1'b0, 7'd9, 7'd40, 7'd101);
	 Enemy enemy50(update, resetn, enemyx_array[49], enemyy_array[49], 1'b0, 1'b0, 7'd9, 7'd35, 7'd101);
	 Enemy enemy51(update, resetn, enemyx_array[50], enemyy_array[50], 1'b0, 1'b0, 7'd9, 7'd30, 7'd101);
	 
	 Enemy enemy52(update, resetn, enemyx_array[51], enemyy_array[51], 1'b0, 1'b1, 7'd9, 7'd25, 7'd110);
	 Enemy enemy53(update, resetn, enemyx_array[52], enemyy_array[52], 1'b0, 1'b0, 7'd9, 7'd20, 7'd101);
	 Enemy enemy54(update, resetn, enemyx_array[53], enemyy_array[53], 1'b0, 1'b1, 7'd9, 7'd15, 7'd110);
	 Enemy enemy55(update, resetn, enemyx_array[54], enemyy_array[54], 1'b0, 1'b0, 7'd9, 7'd11, 7'd101);
	 
	 Enemy enemy56(update, resetn, enemyx_array[55], enemyy_array[55], 1'b1, 1'b1, 7'd20, 7'd11, 7'd112);
	
	 Enemy enemy57(update, resetn, enemyx_array[56], enemyy_array[56], 1'b0, 1'b0, 7'd5, 7'd35, 7'd115);
	 Enemy enemy58(update, resetn, enemyx_array[57], enemyy_array[57], 1'b0, 1'b0, 7'd5, 7'd40, 7'd115);
	 Enemy enemy59(update, resetn, enemyx_array[58], enemyy_array[58], 1'b0, 1'b1, 7'd5, 7'd45, 7'd120);
	 Enemy enemy60(update, resetn, enemyx_array[59], enemyy_array[59], 1'b0, 1'b1, 7'd5, 7'd50, 7'd120);
	 Enemy enemy61(update, resetn, enemyx_array[60], enemyy_array[60], 1'b0, 1'b0, 7'd5, 7'd55, 7'd115);
	 Enemy enemy62(update, resetn, enemyx_array[61], enemyy_array[61], 1'b0, 1'b0, 7'd5, 7'd60, 7'd115);
	 Enemy enemy63(update, resetn, enemyx_array[62], enemyy_array[62], 1'b0, 1'b1, 7'd5, 7'd65, 7'd120);
	 Enemy enemy64(update, resetn, enemyx_array[63], enemyy_array[63], 1'b0, 1'b1, 7'd5, 7'd70, 7'd120);
	 Enemy enemy65(update, resetn, enemyx_array[64], enemyy_array[64], 1'b0, 1'b0, 7'd5, 7'd75, 7'd115);
	 Enemy enemy66(update, resetn, enemyx_array[65], enemyy_array[65], 1'b0, 1'b0, 7'd5, 7'd80, 7'd115);
	 
	 always @(*)
	 begin
		// Retrieves the corresponding enemies
		enemyx = enemyx_array[enemyIterator];
		enemyy = enemyy_array[enemyIterator];
		collisionx = enemyx_array[collisionIterator];
		collisiony = enemyy_array[collisionIterator];
	 end
	 
endmodule


/*
*	ENEMY MODULE
*
*	Represents a single enemy entity with it's specified properties
*/
module Enemy(update, resetn, enemyx, enemyy, left_and_right, start_right_or_up, max_movement, enemyx_init, enemyy_init);

	input update;
	input resetn;
	input left_and_right; // if 0 the enemy will move up and down, if 1 the enemy will move left and right
	input [6:0] enemyx_init;
	input [6:0] enemyy_init;
	input [6:0] max_movement;
	input start_right_or_up;
	reg [6:0] movement_position;
	reg left_right;	// if 0 move left, if 1 move right
	reg up_down;		// if 0 move up, if 1 move down
	output reg [6:0] enemyx;
	output reg [6:0] enemyy;
	reg initialize;
	
	initial
	begin
		initialize = 1'd1;
	end
	
	always @(posedge update)
	begin
		// Initializes the enemy properties
		if(initialize)
		begin
			enemyx = enemyx_init;
			enemyy = enemyy_init;
			left_right = start_right_or_up;
			up_down = start_right_or_up;
			initialize = 1'd0;
		end
		else if(~resetn)
		begin
			enemyx = 1'd0;
			enemyy = 1'd0;
		end
		else
		begin
			if(left_and_right)	// Enemy will move left and right
			begin
				if(movement_position == max_movement)	// Change direction every time it moves 10 pixels left or right
				begin
					left_right = ~left_right;
					movement_position = 1'd0;
				end
				if(left_right == 1'b0)
				begin
					enemyx = enemyx - 1'd1;			// Move enemy to the left by one pixel
				end
				else
				begin
					enemyx = enemyx + 1'd1;			// Move enemy to the right by one pixel
				end
			end
			else		// Enemy will move up and down
			begin
				if(movement_position == max_movement)	// Change direction everytime it moves 10 pixels up or down
				begin
					up_down = ~up_down;
					movement_position = 1'd0;
				end
				if(up_down == 1'b0)
				begin
					enemyy = enemyy + 1'd1;			// Move enemy down by one pixel
				end
				else
				begin
					enemyy = enemyy - 1'd1;			// Move enemy up by one pixel
				end
			end
			movement_position <= movement_position + 1'b1;	// Iterate how much pixels the enemy has moved by 1
		end
	end
endmodule

module Player(clk, update, resetn, playerx, playery, KEY, wonGame, collided);
	input update;
	input resetn;
	input wonGame;
	input collided;
	input clk;
	output reg [6:0] playerx;
	output reg [6:0] playery;
	input [3:0] KEY;
	
	// Initialize the starting position of the player
	initial
	begin
		playerx = 7'd15;
		playery = 7'd2;
	end
	
	/* This will constantly check for player input and move the player
		accordingly.
	*/
	always @(posedge clk)
	begin
		if(collided || ~resetn || wonGame)
		begin
			playerx = 7'd15;//15
			playery = 7'd2;//2
		end
		else
		begin
			if(update)
			begin
				if(~KEY[3]) // MOVE PLAYER LEFT
				begin
					playerx = playerx - 1'b1;
				end
				if(~KEY[2]) // MOVE PLAYER UP
				begin
					playery = playery - 1'b1;
				end
				if(~KEY[1]) // MOVE PLAYER DOWN
				begin
					playery = playery + 1'b1;
				end
				if(~KEY[0]) // MOVE PLAYER RIGHT
				begin
					playerx = playerx + 1'b1;
				end
			end
		end
	end
endmodule

/*
*	RATE DIVIDER MODULE
*
*	Splits the clock into 8 partition of ticks (50 million / 8). On completion of partition, enable update. 
* Update is used to gauge whether the moving elements in game should be redrawn (player + enemies)
*/
module rateDivider(clk, update);
	input clk;
	output reg update;
	reg [25:0] counter;
	
	always @(posedge clk)
	begin
		counter = counter + 1'd1;
		if(counter > 26'd3124999)
		begin
			counter = 1'd0;
		end
		update = (counter == 1'd0) ? 1 : 0;
	end
endmodule

/*
*	SCORE MODULE
*
*	Increments a death counter on player collision with edge of white path / any enemy.
* If the player reaches the end path (teal strip of wall), present their death count as the new high score (if it's a lower score than previous death count)
*/
module Score(clk, resetn, playerx, playery, collided, wonGame, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7);
		input clk;
		input collided;
		input resetn;
		input [6:0] playerx;
		input [6:0] playery;
		input wonGame;
		reg [9:0] currentScore;
		reg [9:0] bestScore;
		reg [3:0] deathCounter1;
		reg [3:0] deathCounter2;
		reg [3:0] deathCounter3;
		reg [3:0] deathCounter4;
		reg [3:0] high_deathCounter1;
		reg [3:0] high_deathCounter2;
		reg [3:0] high_deathCounter3;
		reg [3:0] high_deathCounter4;
		output [7:0] HEX0;
		output [7:0] HEX1;
		output [7:0] HEX2;
		output [7:0] HEX3;
		output [7:0] HEX4;
		output [7:0] HEX5;
		output [7:0] HEX6;
		output [7:0] HEX7;
		reg highScoreExists;
		reg resetScore;
		
		always @(posedge clk)
		begin
			if(~resetn || resetScore) // Reset the hexes that show the death count on reset
			begin
				deathCounter1 = 1'd0;
				deathCounter2 = 1'd0;
				deathCounter3 = 1'd0;
				deathCounter4 = 1'd0;
				currentScore = 1'd0;
				resetScore = 1'd0;
			end
			else if(collided) // Increment the number of deaths on collision. Ensure to properly carry over bits so hex display only goes up to 9
			begin
				currentScore = currentScore + 1'd1;
				deathCounter1 = deathCounter1 + 1'd1;
				if(deathCounter1 == 4'd10)
				begin
					deathCounter1 = 1'd0;
					deathCounter2 = deathCounter2 + 1'd1;
				end
				if(deathCounter2 == 4'd10)
				begin
					deathCounter2 = 1'd0;
					deathCounter3 = deathCounter3 + 1'd1;
				end
				if(deathCounter3 == 4'd10)
				begin
					deathCounter3 = 1'd0;
					deathCounter4 = deathCounter4 + 1'd1;
				end
			end
			if(wonGame) // Select proper high score to display
			begin
				if(!highScoreExists || (currentScore < bestScore))
				begin
					high_deathCounter1 = deathCounter1;
					high_deathCounter2 = deathCounter2;
					high_deathCounter3 = deathCounter3;
					high_deathCounter4 = deathCounter4;
					bestScore = currentScore;
					highScoreExists = 1'd1;
					resetScore = 1'd1;
				end
			end
		end
		
		// Constantly display all digits of corresponding values
		hex_display hex0(deathCounter1, HEX0);
		hex_display hex1(deathCounter2, HEX1);
		hex_display hex2(deathCounter3, HEX2);
		hex_display hex3(deathCounter4, HEX3);
		hex_display hex4(high_deathCounter1, HEX4);
		hex_display hex5(high_deathCounter2, HEX5);
		hex_display hex6(high_deathCounter3, HEX6);
		hex_display hex7(high_deathCounter4, HEX7);
endmodule

/*
*	HEX DISPLAY MODULE
*
* Takes a 7 bit binary number and display it as an integer in the output hex digit 
*/
module hex_display(IN, OUT);
    input [3:0] IN;
	 output reg [7:0] OUT;
	 
	 always @(*)
	 begin
		case(IN[3:0])
			4'b0000: OUT = 7'b1000000;
			4'b0001: OUT = 7'b1111001;
			4'b0010: OUT = 7'b0100100;
			4'b0011: OUT = 7'b0110000;
			4'b0100: OUT = 7'b0011001;
			4'b0101: OUT = 7'b0010010;
			4'b0110: OUT = 7'b0000010;
			4'b0111: OUT = 7'b1111000;
			4'b1000: OUT = 7'b0000000;
			4'b1001: OUT = 7'b0011000;
			4'b1010: OUT = 7'b0001000;
			4'b1011: OUT = 7'b0000011;
			4'b1100: OUT = 7'b1000110;
			4'b1101: OUT = 7'b0100001;
			4'b1110: OUT = 7'b0000110;
			4'b1111: OUT = 7'b0001110;
			
			default: OUT = 7'b0111111;
		endcase

	end
endmodule
