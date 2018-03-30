// Title         : vending_machine.v
// Author      : Hunjun Lee (hunjunlee7515@snu.ac.kr), Suheon Bae (suheon.bae@snu.ac.kr)

`include "vending_machine_def.v"

module vending_machine (

	clk,							// Clock signal
	reset_n,						// Reset signal (active-low)

	i_input_coin,				// coin is inserted.
	i_select_item,				// item is selected.
	i_trigger_return,			// change-return is triggered

	o_available_item,			// Sign of the item availability
	o_output_item,			   // Sign of the item withdrawal
	o_return_coin,			   // Sign of the coin return
	o_current_total
);

	// Ports Declaration
	input clk;
	input reset_n;

	input [`kNumCoins-1:0] i_input_coin;
	input [`kNumItems-1:0] i_select_item;
	input i_trigger_return;

	output reg [`kNumItems-1:0] o_available_item;
	output reg [`kNumItems-1:0] o_output_item;
	output reg [`kReturnCoins-1:0] o_return_coin;
	output reg [`kTotalBits-1:0] o_current_total;

	// Net constant values (prefix kk & CamelCase)
	wire [31:0] kkItemPrice [`kNumItems-1:0];	// Price of each item
	wire [31:0] kkCoinValue [`kNumCoins-1:0];	// Value of each coin
	assign kkItemPrice[0] = 400;
	assign kkItemPrice[1] = 500;
	assign kkItemPrice[2] = 1000;
	assign kkItemPrice[3] = 2000;
	assign kkCoinValue[0] = 100;
	assign kkCoinValue[1] = 500;
	assign kkCoinValue[2] = 1000;

	// Internal states. You may add your own reg variables.
	reg [`kTotalBits-1:0] current_total;
	reg [`kItemBits-1:0] num_items [`kNumItems-1:0]; //use if needed
	reg [`kCoinBits-1:0] num_coins [`kNumCoins-1:0]; //use if needed

	/* my variable */
	reg [`kTotalBits-1:0] inserted_coins;
	reg [`kTotalBits-1:0] next_inserted;
	// var to simplify o_output_item
	reg [1:0] converted_sel;
	parameter i_num_items = 10;
	parameter i_num_coins = 100;
	integer i;
	/* end of my var */

	// convert i_select_item to sequential number
	always @ (*) begin
		case (i_select_item)
			4'b0001 : converted_sel = 0;
			4'b0010 : converted_sel = 1;
			4'b0100 : converted_sel = 2;
			4'b1000 : converted_sel = 3;
		endcase
	end

	//initializeing
	initial begin
		inserted_coins <= 0;
		for (i = 0; i < `kNumItems; i = i + 1) begin
			num_items[i] = i_num_items;
			num_coins[i] = i_num_coins;
		end
	end


	// Combinational circuit for the next states
	always @(i_input_coin or i_select_item or i_trigger_return) begin

		// input coin!
		if (i_input_coin != 0) begin
			case (i_input_coin) 
				3'b001 : next_inserted = inserted_coins + kkCoinValue[0];
				3'b010 : next_inserted = inserted_coins + kkCoinValue[1];
				3'b100 : next_inserted = inserted_coins	+ kkCoinValue[2];
			endcase	

			// output
			o_output_item = 0;
			o_return_coin = 0;
		end
		// item selected!
		else if (i_select_item != 0) begin
			// if inserted price is sufficient to purchace Item and there is sufficient item
			if ((inserted_coins / kkItemPrice[converted_sel] != 0) && num_items[converted_sel] != 0) begin
				next_inserted = inserted_coins - kkItemPrice[converted_sel];
				o_output_item = i_select_item;
				// sell item
				num_items[converted_sel] = num_items[converted_sel] - 1;
			end
			else begin
				next_inserted = inserted_coins;
				o_output_item = 0;
				$display("Sold out!! : %b", i_select_item);
			end

			o_return_coin = 0;
		end
		// return all coin!
		else if (i_trigger_return != 0) begin
			next_inserted = 0;

			// output
			o_output_item = 0;
			o_return_coin = (inserted_coins / kkCoinValue[2]) 
						  + (inserted_coins % kkCoinValue[2]) / kkCoinValue[1]
						  + (inserted_coins % kkCoinValue[2] % kkCoinValue[1]) / kkCoinValue[0];
		end
		else begin
			next_inserted = inserted_coins;
			
			// output
			o_output_item = 0;
			o_return_coin = 0;
		end

		// available : if item can be divided by price
		o_available_item = 
						 // LSB of output
						   ((next_inserted / kkItemPrice[0] != 0) 
						 & ((num_items[0] != 0) ? 4'b0001 : 0))
						 // 
						 | ((next_inserted / kkItemPrice[1] != 0) << 1  
						 & ((num_items[1] != 0) ? 4'b0001 : 0) << 1)
						 //
					     | ((next_inserted / kkItemPrice[2] != 0) << 2 
						 & ((num_items[2] != 0) ? 4'b0001 : 0) << 2)
						 // MSB of output
						 | ((next_inserted / kkItemPrice[3] != 0) << 3 
						 & ((num_items[3] != 0) ? 4'b0001 : 0) << 3);
						// this is mask for item number..

		o_current_total = next_inserted;
	end


	// Sequential circuit to reset or update the states
	always @(posedge clk) begin
		if (!reset_n) begin
			// TODO: reset all states.
			inserted_coins <= 0;
			for (i = 0; i < `kNumItems; i = i + 1) begin
				num_items[i] = i_num_items;
				num_coins[i] = i_num_coins;
			end			
		end
		else begin
			// TODO: update all states.
			inserted_coins <= next_inserted;
		end
	end

endmodule