module Calculator (switches, reset, buttons, leds, displays, CLOCK);
	input [0:6] switches; // [0:5] for each digit [6] for negative
	input reset; // leftmost switch
	input [0:1] buttons; // the 2 rightmost pushbuttons
	input CLOCK;
	output reg [0:9] leds; // will be on for negative numbers, off for positive
	output reg [0:41] displays = 0; // 6 ssds each with 7 segments each
	
   reg negative; // sign bit for a number, if high, number is negative, if low, number is positive
	reg error; // variable to flag any error thrown
    
	// variables to represent each digit / ssd in bcd
	reg [3:0] d0;
	reg [3:0] d1;
	reg [3:0] d2;
	reg [3:0] d3;
	reg [3:0] d4;
	reg [3:0] d5;
    
	// debounce button inputs to reduce input
	wire[1:0] db_buttons;
	debouncer db0(CLOCK, buttons[0], db_buttons[0]);
	debouncer db1(CLOCK, buttons[1], db_buttons[1]);
    
	reg [20:0] num1; // the first input - max number is 999 999 which requires 20 bits, plus 1 bit allocated for sign
	reg [20:0] num2; // the second input - max number is 999 999 which requires 20 bits, plus 1 bit allocated for sign
	reg [20:0] answer; // answer, - max number is 999 999 which requires 20 bits, plus 1 bit allocated for sign
    
	reg [3:0] operation; // each number corresponds to a type of operation

	reg [3:0] stage = 0; // the current stage in the calculator
	
 	reg[1:0] buttonsHeld = 0; // ensures only 1 increment happens in the always block if the button is held
    
 	always@(posedge CLOCK)
    	begin
        	if (!db_buttons[0] && !buttonsHeld[0])
            	begin
                	if(reset) // if reset is high when you confirm a stage
                    	begin
                        	stage <= 0;
                        	displayReset(displays);
                    	end
                	else if(!error || stage == 0) // only run if there is no error, or stage is 0 so values will be cleared
                    	begin
                        	processStage(stage);
   								  if (stage < 3)
   									 stage <= stage + 1;  // increment stage
									  else
   									 stage <= 1; // if stage = 3, cycle back
                    	end
                	buttonsHeld[0] <= 1;
            	end
        	if (!db_buttons[1] && !buttonsHeld[1])
            	begin
            	if(reset) // if reset is high when try increment in a stage
                	begin
                    	stage <= 0;
                    	displayReset(displays);
                	end
               	 
            	else if(stage == 0) // reset turned off
                	begin
                    	processStage(stage);
                	end
               	 
            	else if(!error && (stage == 1 || stage == 3)) // only incremenets if there is no previous error on an associated stage
                	begin
                    	incrementNumbers(switches[0:6], displays, negative, leds);
                	end
               	 
            	else if(!error && (stage == 2)) // only incremenets if there is no previous error and stage corresponds to picking an operation
                	begin
                    	operation = (operation + 1) % 12; // mods by number of operations
                    	displayOperation(operation, displays);
                	end
                	buttonsHeld[1] <= 1;
            	end
            	 
           	 
        	if (db_buttons[0]) // buttons use negative logic, so being high mean not held
				begin
					buttonsHeld[0] <= 0;
				end
       	 
        	if (db_buttons[1]) // buttons use negative logic, so being high mean not held 
				begin
					buttonsHeld[1] <= 0;
				end
       	 
    	end
   
	/*
		based on the current stage of the program, different assignments and function calls will be made
		Stages description
	
		0: instanciate variables
		1: enter first input
		2: select operator
		3: get second input if needed and display answer, then cycle back to stage 1
	*/
	task processStage (input [2:0] in);
    	case(in)
        	0: begin
                	d0 = 0;
                	d1 = 0;
                	d2 = 0;
                	d3 = 0;
                	d4 = 0;
                	d5 = 0;
                	num1 = 0;
                	num2 = 0;	 
                	answer = 0;
                	error = 0;
                	operation = 0;
                	displayAnswer(answer, displays, leds); // displays all 0s for the next stage
        	end
        	1: begin
   					 
   					assignNumber(negative, num1);    
                	displayOperation(operation, displays);
				end
        	2: begin
					if(operation < 7) // only ask for a second input if the operation needs 2
						displayAnswer(answer, displays, leds); // display zeros so a second number can be added if required
				end
        	3: begin
					assignNumber(negative, num2);
					processOperation(operation, answer);
					if (!error) // only display the answer if there isnt an error thrown
						displayAnswer(answer, displays, leds);
					num1 = answer;
					num2 = 0;
					answer = 0;
					operation = 0;
				end
    	endcase
	endtask
	
	/*
		called for each number, allows the user to increment each digit, as selected by the switches. 
		only switches that are high will change the state.
	*/
	task automatic incrementNumbers(input [0:6] sw, output [0:41] out, output negative, output [0:9] leds);
    	begin
        	if(sw[0])
            	begin
                	d0 = (d0 + 1) % 10;
            	end
        	if(sw[1])
            	begin
                	d1 = (d1 + 1) % 10;
            	end
        	if(sw[2])
            	begin
                	d2 = (d2 + 1) % 10;
            	end
        	if(sw[3])
            	begin
                	d3 = (d3 + 1) % 10;
            	end
        	if(sw[4])
            	begin
                	d4 = (d4 + 1) % 10;
            	end
        	if(sw[5])
            	begin
                	d5 = (d5 + 1) % 10;
            	end
        	if(sw[6]) // if negative switch is high
            	begin
						negative = 1;
                	leds = 10'b1111111111; // light up LEDs as indication of negative
            	end   	 
        	else
				begin
					negative = 0;
            	leds = 0;
				end
				
         // display each digit on the corresponding ssd
			displayNumber(d0, out[0:6]);
			displayNumber(d1, out[7:13]);
			displayNumber(d2, out[14:20]);
			displayNumber(d3, out[21:27]);
			displayNumber(d4, out[28:34]);
			displayNumber(d5, out[35:41]);
		end
	endtask
    
	/*
		assigns the current values of the number to its corresponding variable
	*/
   task automatic assignNumber(input negative, output [20:0] num);
    	begin
			reg [19:0] temp; // magnitude of the number
        	temp = d5*100000 + d4*10000 + d3*1000 + d2*100 + d1*10 + d0;
			
			// concatenates sign bit and the magnitude to the number
			num = {negative, temp};
   
        	leds = 0; // turns leds off for next stage
       	 
        	// sets digits to 0 for next iteration    
        	d0 = 0;
        	d1 = 0;
        	d2 = 0;
        	d3 = 0;
        	d4 = 0;
        	d5 = 0;
    	end
	endtask
    
	/*
		Calls the corresponding operation task
		
		Cases are structured so all stages requiring two stages are grouped together initially
		and all stages requiring 1 are grouped at the end, so we can check an index value to
		determine whether to prompt the user for another input or if the task paramaters are met.
	*/
   task automatic processOperation(input [3:0] operations, output [20:0] answer);
    	begin
        	case(operations)
				0:  add(num1, num2, answer);
				1:  subtract(num1, num2, answer);
				2:  multiply(num1, num2, answer);
				3:  divide(num1, num2, answer);
				4:  exponentiate(num1, num2, answer);
				5:  combination(num1, num2, answer);
				6:  permutation(num1, num2, answer);
				7:  factorial(num1, answer);
				8:  decimal_binary(num1, answer);
				9:  binary_decimal(num1, answer);
				10: boolean_and(num1, switches, answer);
				11: boolean_or(num1, switches, answer);
        	endcase
    	end
	endtask
	
	/*
		will display the operation currently being selected on the switches across the 6 ssds
	*/
	task automatic displayOperation(input [3:0] in, output [0:41] out);
    	begin
        	case (in)
            	0: begin // add
                    	out[35:41] = 7'b0001000; // A
                    	out[28:34] = 7'b1000010; // d
                    	out[21:27] = 7'b1000010; // d
                    	out[14:20] = 7'b1111111; // blank
                    	out[7:13] = 7'b1111111; // blank
                    	out[0:6] = 7'b1111111; // blank
                	end
            	1: begin // subtract
                    	out[35:41] = 7'b0100100; // S
                    	out[28:34] = 7'b1100011; // u
                    	out[21:27] = 7'b1100000; // b
                    	out[14:20] = 7'b1111111; // blank
                    	out[7:13] = 7'b1111111; // blank
                    	out[0:6] = 7'b1111111; // blank
                	end
            	2: begin // multiply
                    	out[35:41] = 7'b0001001; // M - first part
                    	out[28:34] = 7'b0001001; // M - second part
                    	out[21:27] = 7'b1100011; // u
                    	out[14:20] = 7'b1001111; // l
                    	out[7:13] = 7'b1110000; // t
                    	out[0:6] = 7'b1111111; // blank
                	end
            	3: begin // division
                    	out[35:41] = 7'b1000010; // d
                    	out[28:34] = 7'b1111001; // i
                    	out[21:27] = 7'b1000001; // v
                    	out[14:20] = 7'b1111111; // blank
                    	out[7:13] = 7'b1111111; // blank
                    	out[0:6] = 7'b1111111; // blank
                	end
            	4: begin // exponentiate
                    	out[35:41] = 7'b0110000; // E
                    	out[28:34] = 7'b1001000; // x
                    	out[21:27] = 7'b0011000; // p
                    	out[14:20] = 7'b1111111; // blank
                    	out[7:13] = 7'b1111111; // blank
                    	out[0:6] = 7'b1111111; // blank
                	end
            	5:	begin // combination
                    	out[35:41] = 7'b0110001; // C
                    	out[28:34] = 7'b0000001; // O
                    	out[21:27] = 7'b0001001; // m - first part
                    	out[14:20] = 7'b0001001; // m - second part
                    	out[7:13] = 7'b1100000; // b
                    	out[0:6] = 7'b1111111; // blank
                	end
            	6:	begin // permutation
                    	out[35:41] = 7'b0011000; // P
                    	out[28:34] = 7'b0110000; // E
                    	out[21:27] = 7'b0011001;; // r
                    	out[14:20] = 7'b0001001; // m - first
                    	out[7:13] = 7'b0001001; // m - second
                    	out[0:6] = 7'b1111111; // blank
                	end
            	7: begin // factorial
                    	out[35:41] = 7'b0111000; // F
                    	out[28:34] = 7'b0000010; // a
                    	out[21:27] = 7'b1110010; // c
                    	out[14:20] = 7'b1110000; // t
                    	out[7:13] = 7'b1111111; // blank
                    	out[0:6] = 7'b1111111; // blank
                	end
            	8: begin // decimal to binary
                    	out[35:41] = 7'b0000000; // B
                    	out[28:34] = 7'b1111001; // i
                    	out[21:27] =  7'b0001001; // n
                    	out[14:20] = 7'b0000010; // a
                    	out[7:13] = 7'b0011001; // r
                    	out[0:6] = 7'b01000100; //	y
                	end
				 9: begin // binary to decimal
							out[35:41] = 7'b1000010; // d
						   out[28:34] = 7'b0110000; // E
                     out[21:27] = 7'b1110010; // c
                    	out[14:20] = 7'b1111111; //
                    	out[7:13] = 7'b1111111; //
                     out[0:6] = 7'b1111111; //  
						end
				10: begin // boolean AND
						   out[35:41] = 7'b0001000; // A
							out[28:34] = 7'b1101010; // n
							out[21:27] =  7'b1000010; // d
							out[14:20] = 7'b1111111; // blank
							out[7:13] = 7'b1111111; // blank
							out[0:6] = 7'b1111111; // blank
				end
			  11: begin // boolean OR
						   out[35:41] = 7'b0000001; // O
							out[28:34] = 7'b0011001; // R
							out[21:27] =  7'b1111111; // blank
							out[14:20] = 7'b1111111; // blank
							out[7:13] = 7'b1111111; // blank
							out[0:6] = 7'b1111111; // blank
				end
			endcase
    	end
    
	endtask
   
	/*
		displays the corresponding number on the SSDs by calculating the digit number and calling displayNumber for every digit
	*/
	task automatic displayAnswer(input [20:0] num, output [0:41] out, output [0:9] leds);
    	begin
        	if(num[20] == 1) // signed bit is negative
            	begin
                	leds = 10'b1111111111; // LEDS being on indicate a negative answer
            	end
        	else
            	begin
                	leds = 0; // LEDs being off indicate a positive answer
					end
					
         num = num[19:0]; // will take the magnitude of the signed number      	 
			d0 = num % 10;
			d1 = (num / 10) % 10;
			d2 = (num / 100) % 10;
			d3 = (num / 1000) % 10;
			d4 = (num / 10000) % 10;
			d5 = (num / 100000) % 10;
			 
			//displays the bcd digit on each ssd
			displayNumber(d5, out[34:41]);
			displayNumber(d4, out[28:34]);
			displayNumber(d3, out[21:27]);
			displayNumber(d2, out[14:20]);
			displayNumber(d1, out[7:13]);
			displayNumber(d0, out[0:6]);
		end
	endtask
    
	/*
		will display a single digit on the corresponding ssd based on the value passed through
	*/
	task automatic displayNumber(input [3:0] in, output [0:6] out);
    	begin
        	case(in)
        	0 : out = 7'b0000001; // 0
        	1 : out = 7'b1001111; // 1
        	2 : out = 7'b0010010; // 2
        	3 : out = 7'b0000110; // 3
        	4 : out = 7'b1001100; // 4
        	5 : out = 7'b0100100; // 5
        	6 : out = 7'b0100000; // 6
        	7 : out = 7'b0001111; // 7
        	8 : out = 7'b0000000; // 8
        	9 : out = 7'b0000100; // 9
        	default: out = 7'b1111111; // blank
        	endcase
    	end
	endtask
   
	/*
		displays "r-e-s-e-t" on the ssds
	*/
	task automatic displayReset(output [0:41] out);
    	begin
        	out[35:41] = 7'b0011001; // r
        	out[28:34] = 7'b0110000; // E
        	out[21:27] = 7'b0100100; // S
        	out[14:20] = 7'b0110000; // E
        	out[7:13] = 7'b1110000; // t
        	out[0:6] = 7'b1111111; // blank
    	end
	endtask
	
	/*
		displays "e-r-r-o-r" on the ssds, and sets the error variable to high
	*/
   task automatic throwError(output [0:41] out);
    	begin
        	out[35:41] = 7'b0110000; // E
        	out[28:34] = 7'b0011001; // r
        	out[21:27] = 7'b0011001; // r
        	out[14:20] = 7'b0000001; // O
        	out[7:13] = 7'b0011001; // r
        	out[0:6] = 7'b1111111; // blank
       	 
        	error = 1; // sets the error variable to high to block future changes, until reset is pressed
    	end
	endtask


	// ARITHMETIC ===============================================================

/*
	Perform an addition of two numbers
	*/
	task automatic add (input [20:0] num1, num2, output [20:0] answer);
		integer magnitude1;
		integer magnitude2;
		integer sum;
		reg[19:0] sumBits;
		
		if(num1[20]) //num1 is negative
			begin
				magnitude1 = num1 [19:0]; //get the magnitude portion of num1
				magnitude1 = magnitude1 * (-1); //make it a negative integer
			end
		else
			magnitude1 = num1; //positive
			
		if(num2[20]) //num2 is negative
			begin
				magnitude2 = num2 [19:0]; //get the magnitude portion of num2
				magnitude2 = magnitude2 * (-1); //make it a negative integer
			end
		else
			magnitude2 = num2; //positive
			
		if(((magnitude1 + magnitude2) > 999999) || ((magnitude1 + magnitude2) < -999999)) //avoid overflows
			throwError(displays);
		else
			sum = magnitude1 + magnitude2; //compute the sum as an integer
		
		if(sum < 0) //if sum is negative, output the number in sign-magnitude binary form
			begin
				sum = sum * (-1); //get the positive number to store its magnitude in binary
				sumBits = sum;
				answer = {1'b1, sumBits}; //concatenate a leading 1 to indicate negative number
			end
		else
			answer = sum;
		
	endtask
   
	/*
	Perform a subtraction of two numbers
	*/
	task automatic subtract (input [20:0] num1, num2, output [20:0] answer);
		integer magnitude1;
		integer magnitude2;
		integer difference;
		reg[19:0] differenceBits;
		
		if(num1[20]) //num1 negative
			begin
				magnitude1 = num1 [19:0]; //get magnitude
				magnitude1 = magnitude1 * (-1); //make negative integer
			end
		else
			magnitude1 = num1; //positive
			
		if(num2[20]) //num2 negative
			begin
				magnitude2 = num2 [19:0]; //get magnitude
				magnitude2 = magnitude2 * (-1); //make negative integer
			end
		else
			magnitude2 = num2;
		
    	if(((magnitude1 - magnitude2) > 999999) || ((magnitude1 - magnitude2) < -999999)) //avoid overflows
			throwError(displays);
    	else
        	difference = magnitude1 - magnitude2; //compute difference
		
		if(difference < 0) //if difference is negative, output in sign-magnitude form
			begin
				difference = difference * (-1); //get the positive number to store its magnitude in binary
				differenceBits = difference;
				answer = {1'b1, differenceBits}; //concatenate a leading 1 to indicate negative number
			end
		else
			answer = difference;
	endtask
   
	/*
	Perform a multiplication of two numbers
	*/
	task automatic multiply (input [20:0] num1, num2, output [20:0] answer);
    	
		integer magnitude1;
		integer magnitude2;
		integer product;
		reg[19:0] productBits;
		
		if(num1[20])
			begin
				magnitude1 = num1 [19:0];
				magnitude1 = magnitude1 * (-1);
			end
		else
			magnitude1 = num1;
			
		if(num2[20])
			begin
				magnitude2 = num2 [19:0];
				magnitude2 = magnitude2 * (-1);
			end
		else
			magnitude2 = num2;
		
		if(((magnitude1 * magnitude2) > 999999) || ((magnitude1 * magnitude2) < -999999))
        	throwError(displays);
		else
			begin  
				product = magnitude1 * magnitude2;
   	   end
			
		if(product < 0)
			begin
				product = product * (-1);
				productBits = product;
				answer = {1'b1, productBits};
			end
		else
			answer = product;
	endtask
   
	/*
	Perform a division of two numbers
	*/
	task automatic divide (input [20:0] num1, num2, output [20:0] answer);
    	
		integer magnitude1;
		integer magnitude2;
		integer quotient;
		reg[19:0] quotientBits;
		
		if(num1[20])
			begin
				magnitude1 = num1 [19:0];
				magnitude1 = magnitude1 * (-1);
			end
		else
			magnitude1 = num1;
			
		if(num2[20])
			begin
				magnitude2 = num2 [19:0];
				magnitude2 = magnitude2 * (-1);
			end
		else
			magnitude2 = num2;
		
		if(num2 == 0) 
			begin //avoid division by zero
				throwError(displays);
			end 
		else 
			begin
				quotient = magnitude1 / magnitude2; //integer divide
   	   end
		
		if(quotient < 0)
			begin
				quotient = quotient * (-1);
				quotientBits = quotient;
				answer = {1'b1, quotientBits};
			end
		else
			answer = quotient;
	endtask

    
	// OTHER Operations =================================================================
	 
	 /*
	 Perform an exponentiation
		num1 is the base
		num2 is the exponent (non-negative)
	 */
	 task automatic exponentiate (input [20:0] num1, num2, output [20:0] answer);
		
		integer magnitude1;
		integer magnitude2;
		reg[19:0] resultBits;
		
		if(num1[20])
			begin
				magnitude1 = num1 [19:0];
				magnitude1 = magnitude1 * (-1);
			end
		else
			magnitude1 = num1;
			
		if(num2[20]) //if there is a negative exponent, throw an error
			begin
				throwError(displays);
			end
		else
			magnitude2 = num2;
			
		if(!error)
			begin
				if(magnitude2 > 5) //max exponent of 5
					throwError(displays);
				else
					begin
							integer a = 1;
							integer i;
							for(i = 0; i < magnitude2 && i < 6; i = i + 1) //needed to restrict iteration depth (we choose max exponent of 5), for verilog to compile
								begin
									a = a * magnitude1;
								end
							if(a > 999999 || a < -999999)
								throwError(displays);
							else
								if(a < 0) //if the answer is negative
									begin
										a = a * (-1); //get the positive magnitude
										resultBits = a;
										answer = {1'b1, resultBits}; //concatenate a 1 to indicate negative sign-magnitude binary number
									end
								else
									answer = a;
					end
				end
	endtask


	/*
	Perform (num1 nCr num2)
	*/
	task automatic combination (input [20:0] num1, num2, output [20:0] answer);
		
		if(num1[20] || num2[20]) //throw an error if either number is negative
			throwError(displays);
		else
			begin
				reg[19:0] nFact;
				reg[19:0] xFact;
				reg[19:0] rFact;
				reg[19:0] r;
				 
				if(num2 > num1)
						answer = 0; //cannot choose num2 items from a set of num1 if num2 > num1
				else if(num1 >= 0 && num1 <= 9 && num2 >= 0) //this implies both num1 and num2 in range [0, 9] (we already know num1 >= num2)
						begin
							factorial(num1, nFact); //compute the factorial on the numerator
							factorial(num2, xFact); //compute one of the factorials in the denominator
							r = num1 - num2; //r will never be negative since we verify num1 >= num2
							factorial(r, rFact); //compute the (n-x)! term in the denominator
							//we know rFact will not be an overflow since num1-num2 must be in range [0, 9]
							answer = nFact / (xFact * rFact);
						end
				else
						throwError(displays); //if either number if out of range [0, 9]
			end
	endtask
   
	/*
	Perform (num1 nPr num2)
	*/
	task automatic permutation (input [20:0] num1, num2, output [20:0] answer);
        	
		if(num1[20] || num2[20]) //throw an error if either number is negative
			throwError(displays);
		else
			begin
				reg[19:0] nFact;
				reg[19:0] rFact;
				reg[19:0] r;
				 
				if(num2 > num1)
						answer = 0; //cannot arrange num2 members from a set of num1 elements if num2 > num1
				else if(num1 >= 0 && num1 <= 9 && num2 >= 0) //this implies both num1 and num2 in range [0:9]
						begin
							factorial(num1, nFact);
							r = num1 - num2; //r will never be negative since we verify num1 >= num2 (we already know num1 >= num2)
							factorial(r, rFact); //compute the (n-r)! in the denominator
							answer = nFact / rFact;
						end
				else
						throwError(displays); //if either number if out of range [0, 9]
			end
	endtask
	
	/*
	Perform num1! (num1 factorial)
	*/
	task automatic factorial (input [20:0] num1, output [20:0] answer);
		
		if(num1[20]) //can't have factorial of a negative (throw an error)
			throwError(displays);
		else
        	begin
				if(num1 >= 0 && num1 <= 9) //anything greater the 9! is overflow, and cannot compute factorial of a negative number
						begin
							integer a = 1;
							integer i;
				 
							for(i = 2; i <= num1 && i < 250; i = i + 1) //needed for loop condition (i<250) for verilog to compile (avoid exceeding max iteration depth)
								begin
										a = a * i;
								end
							answer = a;
						end
				else
						throwError(displays);
			end
	endtask

  
 // BINARY CONVERSIONS ===========================================================================================
    
    task automatic decimal_binary(input[20:0] num, output[20:0] answer);

   	 integer b = 0; // is the binary number, but represented in decimal (10 is three in binary, but ten in decimal)
   	 integer multiplier = 1;
   	 if (num < 64) begin
   		 integer i;
   		 for (i = 0; i < 6; i = i + 1)
   			 begin
   				 b = b + num[i] * multiplier; // num[i] will be either 0 or 1
   				 multiplier = multiplier * 10; // move to the next place over
   			 end
   		 answer = b;
   	 end else begin
   		 throwError(displays);
   	 end
   	 
    endtask

    task automatic binary_decimal(input[20:0] num, output[20:0] answer);
   	 
   		 integer exponent = 0;
   		 integer divisor = 1;
   		 integer d = 0;
   		 
   		 integer n = num[19:0];
   		 // checks that ALL digits are less than 2 (either 0 or 1)
   		 if ((n / 100000 < 2) && (n / 10000) % 10 < 2 && (n / 1000) % 10 < 2 && (n / 100) % 10 < 2 && (n / 10) % 10 < 2 && (n % 10) < 2 && num[20] == 0) begin
   			 integer i;
   			 for (i = 0; i < 6; i = i + 1)
   				 begin
   					 d = d + ((n / divisor) % 10) * (2 ** exponent); // (n / divisor) will increment through each place, (2**exponent) will be the corresponding power of 2
   					 divisor = divisor * 10;
   					 exponent = exponent + 1;
   				 end
   			 answer = d;
   		 end else begin
   			 throwError(displays);
   		 end
    endtask
    
    task automatic boolean_and (input[20:0] num, input[0:6] sw, output[20:0] answer);
    
   	 integer a = 1;
    
   	 if (num < 7 && num[20] == 0) begin // checks the number isn't negative and is less that 7 (only 6 switches available)
   	 
   		 integer i;
   		 for (i = 0; i < num && i < 7; i = i + 1) begin
   		 
   			 if (switches[i] == 0)
   				 a = 0; // will set a to 0 if ANY digit is 0
   		 
   		 end
   	 
   	 end else begin
   		 throwError(displays);
   	 end
   	 
   	 answer = a;
    
    endtask
    
    task automatic boolean_or (input[20:0] num, input[0:6] sw, output[20:0] answer);
    
   	 integer a = 0;
    
   	 if (num < 7 && num[20] == 0) begin
   	 
   		 integer i;
   		 for (i = 0; i < num && i < 7; i = i + 1) begin
   			 if (switches[i] == 1) // will set a to 1 if ANY digit is 1
   				 a = 1;
   		 end
   	 
   	 end else begin
   		 throwError(displays);
   	 end
   	 
   	 answer = a;
    
    endtask

endmodule

/*
	debouncer taken from UM Learn. The document states
	explicitly to use the code provided when using a button debouncer.
*/
module debouncer(clk, key, keydb); 
	input clk, key;
	output reg keydb;
    
	reg key1, key2;
	reg[15:0] count;
    
	always@(posedge clk)
    	begin
        	key1 <= key;
        	key2 <= key1;
        	if (keydb == key2)
            	count <= 0;
        	else begin
            	count <= count + 1'b1;
            	if (count == 16'hffff)
                	keydb <= ~keydb;
        	end
    	end
endmodule



