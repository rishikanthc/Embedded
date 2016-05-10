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

	logic [3:0] state;
	reg signed [15:0] audioOutTemp;

	reg signed [31:0] w1,
			w2,
			w3,
			w4,
			w5,
			w6,
			w7,
			w8;

	reg signed [31:0] u0,
			u1,
			u2,
			u3,
			u4,
			u5,
			u6,
			u7;

	logic signed [31:0] 	w1_x_u7,
				w2_x_u6,
				w3_x_u5,
				w4_x_u4,
				w5_x_u3,
				w6_x_u2,
				w7_x_u1,
				w8_x_u0;

	logic [3:0] step;
	logic signed [31:0] error;

	multiplier w1xu7(w1_x_u7, w1, u7);
	multiplier w2xu6(w2_x_u6, w2, u6) ;
	multiplier w3xu5(w3_x_u5, w3, u5);
	multiplier w4xu4(w4_x_u4, w4, u4) ;
	multiplier w5xu3(w5_x_u3, w5, u3);
	multiplier w6xu2(w6_x_u2, w6, u2) ;
	multiplier w7xu1(w7_x_u1, w7, u1);
	multiplier w8xu0(w8_x_u0, w8, u0) ;

	assign error = {audioIn, 16'd0}- (w1_x_u7 + w2_x_u6 + w3_x_u5 + w4_x_u4 + w5_x_u3 + w6_x_u2 + w7_x_u1 + w8_x_u0);
	assign step = 4'd2;

	reg signed [31:0]mem[15:0];
	reg unsigned [3:0] base;

	always_ff @(negedge dac_clk) begin
		if(dac_clk == 0)
			audioOutTemp[15:0] <= error[31:16];
	end

	assign audioOutL = audioOutTemp;
	assign audioOutR = audioOutTemp;

	always_ff @(posedge clk) begin
		if(reset) begin
			w1 <= 32'd0 ;
			w2 <= 32'd0 ;
			w3 <= 32'd0 ;
			w4 <= 32'd0 ;
			w5 <= 32'd0 ;
			w6 <= 32'd0 ;
			w7 <= 32'd0 ;
			w8 <= 32'd0 ;
			base<=5'd0;
		end
		else if(dac_clk==0)
			state <=1;
		else begin
			case (state)
				1: begin
					u7<=-{audioIn,16'd0};
					state<=2;
				end
				2:
			begin
			w1 <= w1 + (((u7[31])? -error : error)>>>step);
			w2 <= w2 + (((u6[31])? -error : error)>>>step);
			w3 <= w3 + (((u5[31])? -error : error)>>>step);
			w4 <= w4 + (((u4[31])? -error : error)>>>step);
			w5 <= w5 + (((u3[31])? -error : error)>>>step);
			w6 <= w6 + (((u2[31])? -error : error)>>>step);
			w7 <= w7 + (((u1[31])? -error : error)>>>step);
			w8 <= w8 + (((u0[31])? -error : error)>>>step);
			state<=3;
			end
			3:
			begin
			mem[base+4'd7]<=u7;
			mem[base+4'd6]<=u6;
			mem[base+4'd5]<=u5;
			mem[base+4'd4]<=u4;
			mem[base+4'd3]<=u3;
			mem[base+4'd2]<=u2;
			mem[base+4'd1]<=u1;
			mem[base+4'd0]<=u0;
			state<=4;
			end
			4:
			begin
			base<=base+4'd1;
			state<=5;
			end
			5:
			begin
			u6<=mem[base+4'd6];
			u5<=mem[base+4'd5];
			u4<=mem[base+4'd4];
			u3<=mem[base+4'd3];
			u2<=mem[base+4'd2];
			u1<=mem[base+4'd1];
			u0<=mem[base+4'd0];
			state<=6;
			end
			6:
			begin
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

module testBench();

	logic clk, reset, dac_clk;
	logic signed [15:0] audioIn, audioOutL, audioOutR;
	logic signed [15:0] testData [22049:0];

	integer filehandlerL,filehandlerR;
	initial filehandlerL = $fopen("outputL");
	initial filehandlerR = $fopen("outputR");

	LMS dut(clk, reset, dac_clk, audioIn, audioOutL, audioOutR);

	initial clk=0;
	always #20000 clk = ~clk;

	initial dac_clk=0;
	always #22675736 dac_clk = ~dac_clk;

	initial $readmemh("noisy",testData);

	integer i;
	initial begin
		@(posedge clk);
		reset = 1;

		@(posedge clk);
		reset = 0;

		for (i = 0; i < 22050; i++) begin
			if(i==7) begin
				@(posedge dac_clk);
				reset = 1;
				@(posedge clk);
				reset = 0;
			end
			@(posedge dac_clk);
			#1; audioIn = testData[i][15:0];
			$display($time, " <<audioIn: testData[%d][15:0] = %d >>", i, testData[i][15:0]);
		end

		$finish;
	end

	always @(negedge dac_clk) begin
		$fdisplay(filehandlerL, "%d", audioOutL);
		$fdisplay(filehandlerR, "%d", audioOutR);
	end

endmodule