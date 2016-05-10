module LMS(clk, reset, dac_clk, audioIn, audioOutL, audioOutR);

	input clk, reset, dac_clk;
	input signed [15:0] audioIn;
	output logic signed [15:0] audioOutL, audioOutR;
	control controller(clk, reset, dac_clk, audioIn, audioOutL, audioOutR);
endmodule // LMS

module control(clk, reset, dac_clk, audioIn, audioOutL, audioOutR);

	input clk, reset, dac_clk;
	input signed [15:0] audioIn;
	output signed [15:0] audioOutR, audioOutL;

	parameter [2:0] IDLE_STATE=3'b000, INPUT_STATE=3'b001,  COMPUTE_STATE=3'b010, MEM_STATE=3'b011, INC_BASE_STATE=3'b100, RESTORE_NOISE=3'b101;
	logic signed [15:0] out;
	logic [2:0] state, next_state;
	logic signed [31:0] error;
	logic reset_flag;
	reg signed [31:0] weights [7:0];
	reg signed [31:0] history [7:0];
	reg unsigned [3:0] step;
	logic unsigned [3:0] base_ptr;
	logic input_done, compute_done, mem_done,inc_base_done,restore_noise_done;
	logic signed [31:0] filtered_1, filtered_2, filtered_3, filtered_4, filtered_5, filtered_6, filtered_7, filtered_8;

	multiplier(filtered_1, weights[0], history[7]);
	multiplier(filtered_2, weights[1], history[6]);
	multiplier(filtered_3, weights[2], history[5]);
	multiplier(filtered_4, weights[3], history[4]);
	multiplier(filtered_5, weights[4], history[3]);
	multiplier(filtered_6, weights[5], history[2]);
	multiplier(filtered_7, weights[6], history[1]);
	multiplier(filtered_8, weights[7], history[0]);

	assign step = 4'd2;

	always_comb begin
		case(state)
			IDLE_STATE: next_state = IDLE_STATE;
			INPUT_STATE: next_state = COMPUTE_STATE;
			COMPUTE_STATE: next_state = MEM_STATE;
			MEM_STATE: next_state = INC_BASE_STATE;
			INC_BASE_STATE: next_state = RESTORE_NOISE;
			RESTORE_NOISE: next_state = IDLE_STATE;
		endcase
	end


	always_ff @(posedge clk) begin
		if(~reset)
			state <= IDLE_STATE;
			//reset_flag<=1;
		else
			//reset_flag <= 0;
			if(dac_clk)
				state <= next_state;
			else
				state <= INPUT_STATE
	end

	assign error = {audio_inL, 16'd0}- (filtered_1 + filtered_2 + filtered_3 + filtered_4 + filtered_5 + filtered_6 + filtered_7 + filtered_8);

	always_ff @(negedge dac_clk) begin
		if(~dac_clk) begin
			out <= error[31:16];
		end
	end

	assign audioOutR = out;
	assign audioOutL = out;

	always_ff @(posedge clk) begin
		if (reset) begin
			begin
				integer i;
                for (i=0; i<8; i=i+1)
                    weights[i] <= 32'd0;

            end
			base_ptr<=5'd0;
		end
		else if(dac_clk) begin
			case (state)
				INPUT_STATE: begin
					history[7] <= -{audioIn,16'd0}
					input_done<=1;
				end
				COMPUTE_STATE: begin
					begin
                    	integer i,j;
                    	for (i=0,j=7; i<8; i=i+1,j=j-1)
                     		weights[i] <= weights[i] + (((history[j][31])? -error : error)>>>step);

                  	end
                  	compute_done<=1;
				end
				MEM_STATE: begin
					begin
						integer i,j;
                    	for (i=0; i<8; i=i+1)
                     		memory[base_ptr + i] <= history[i];
                    end
                    mem_done<=1;
				end
				INC_BASE_STATE: begin
					base_ptr <= base_ptr + 4'd1;
					inc_base_done<=1;
				end
				RESTORE_NOISE: begin
					begin
						integer i;
						for (i = 0; i < 8; i++) begin
							history[i] <= memory[base_ptr + i];
						end
					end
					restore_noise_done<=1;
				end
				IDLE_STATE: begin
					restore_noise_done<=0;
					inc_base_done<=0;
					mem_done<=0;
					input_done<=0;
					compute_done<=0;
				end

			endcase
		end

	end




endmodule

module multiplier(out, a, b);

	input signed [31:0] a,b;
	output signed [31:0] out;
	logic signed [63:0] mult;

	assign mult = a * b;
	assign out = {mult[63], mult[60:30]};

endmodule
