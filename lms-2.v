module LMS (

	// Clock Input
	//input         CLOCK_27,    // 27 MHz
	input         CLOCK_50,    // 50 MHz
	//input         EXT_CLOCK,   // External Clock

	// Push Button
	input  [3:0]  KEY,         // Pushbutton[3:0]
	// DPDT Switch
	input  [17:0] SW,          // Toggle Switch[17:0]

	// Audio CODEC
	//inout         AUD_ADCLRCK, // Audio CODEC ADC LR Clock
	//input         AUD_ADCDAT,  // Audio CODEC ADC Data
	//inout         AUD_DACLRCK, // Audio CODEC DAC LR Clock
	input         AUD_DACLRCK, // Audio CODEC DAC LR Clock
	//output        AUD_DACDAT,  // Audio CODEC DAC Data
	//inout         AUD_BCLK,    // Audio CODEC Bit-Stream Clock
	//output        AUD_XCK,      // Audio CODEC Chip Clock

	input [15:0]  audio_inL,
	input [15:0]  audio_inR,
	output [15:0] audio_outL,
	output [15:0] audio_outR
);

/// reset ///////////////////////////////////////////////////////
// reset control
wire reset;
wire reset1;
assign reset = ~KEY[0];
assign reset1= ~KEY[1];

//reg signed [15:0] strike;

/// audio stuff /////////////////////////////////////////////////
// output to audio DAC
// wire signed [15:0] audio_inL, audio_inR;
reg signed [15:0] audio_outLtemp, audio_outRtemp;
reg [3:0]state;

/// LMS /////////////////////////////////////////////////////////////
// LMS registers
// 2 weights
//wire signed [31:0] w1;
//assign w1[31]=SW[5];
//assign w1[29:26]=SW[4:1];
reg signed [31:0] w1,
			w2,
			w3,
			w4,
			w5,
			w6,
			w7,
			w8;
//reg signed [31:0]w[7:0];
// 2 inputs
reg signed [31:0] u0,
			u1,
			u2,
			u3,
			u4,
			u5,
			u6,
			u7;
wire [3:0] step;
// error output (main output)
wire signed [31:0] error_out ;
// two product terms
wire signed [31:0] 	w1_x_u7,
				w2_x_u6,
				w3_x_u5,
				w4_x_u4,
				w5_x_u3,
				w6_x_u2,
				w7_x_u1,
				w8_x_u0;
// mult for weight times ref and weight times phase-shifted ref
signed_mult w1xu7(w1_x_u7, w1, u7);
signed_mult w2xu6(w2_x_u6, w2, u6) ;
signed_mult w3xu5(w3_x_u5, w3, u5);
signed_mult w4xu4(w4_x_u4, w4, u4) ;
signed_mult w5xu3(w5_x_u3, w5, u3);
signed_mult w6xu2(w6_x_u2, w6, u2) ;
signed_mult w7xu1(w7_x_u1, w7, u1);
signed_mult w8xu0(w8_x_u0, w8, u0) ;
//assume noisy signal is on left channel, ref on right channel
assign error_out = {audio_inL, 16'd0}- (w1_x_u7 + w2_x_u6 + w3_x_u5 + w4_x_u4 + w5_x_u3 + w6_x_u2 + w7_x_u1 + w8_x_u0);
assign step=SW[17:13];
//////////////////////////////////////////////////////////////////////
//circulur memory
reg signed [31:0]mem[15:0];
reg unsigned [3:0] base;
//////////////////////////////////

always@(negedge AUD_DACLRCK)
begin
	if(SW[0])
	begin
		//R=noise
		audio_outRtemp<={audio_inR[15],audio_inR[15:1]};
		//	 audio_outR<=audio_inL;
		//L=signal+noise
		audio_outLtemp<={audio_inL[15],audio_inL[15:1]};
		//audio_outL<=audio_inL;
	end

	else if (AUD_DACLRCK==0)
	begin
		audio_outLtemp[15:0]<=error_out[31:16];
		audio_outRtemp[15:0] <=error_out[31:16];
	end
end

assign audio_outL = audio_outLtemp;
assign audio_outR = audio_outRtemp;





//Audio input and DSP
always@(posedge CLOCK_50)
	begin
	if(reset)
		begin
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

	else if (AUD_DACLRCK==0)
		begin
		state<=1;

		end
	else
		begin
		case(state)
			1:
			begin
			u7<=-{audio_inR,16'd0};
			state<=2;
			end
			2:
			begin
			w1 <= w1 + (((u7[31])? -error_out : error_out)>>>step);
			w2 <= w2 + (((u6[31])? -error_out : error_out)>>>step);
			w3 <= w3 + (((u5[31])? -error_out : error_out)>>>step);
			w4 <= w4 + (((u4[31])? -error_out : error_out)>>>step);
			w5 <= w5 + (((u3[31])? -error_out : error_out)>>>step);
			w6 <= w6 + (((u2[31])? -error_out : error_out)>>>step);
			w7 <= w7 + (((u1[31])? -error_out : error_out)>>>step);
			w8 <= w8 + (((u0[31])? -error_out : error_out)>>>step);
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
	end // always end
endmodule

//////////////////////////////////////////////////
//// signed mult of 2.16 format 2'comp////////////
//////////////////////////////////////////////////
module signed_mult (out, a, b);

	output 		[31:0]	out;
	input 	signed	[31:0] 	a;
	input 	signed	[31:0] 	b;

	wire	signed	[31:0]	out;
	wire 	signed	[63:0]	mult_out;

	assign mult_out = a * b;
	//assign out = mult_out[33:17];
	assign out = {mult_out[63], mult_out[60:30]};
endmodule

module tbench();

	reg CLOCK_50;
	reg AUD_DACLRCK;
	reg clk,clk1;
	reg signed [15:0] testData [22049:0];
	reg signed [15:0] noise [22049:0];
	reg [3:0] KEY;
	wire [17:0] SW;
	//assign KEY = 1;
	//assign SW=1;
	assign SW=18'b00110000000000000;

	//assign SW[0]=0;
	reg [15:0]  audio_inL;
	reg [15:0]  audio_inR;
	//reg [15:0] audio_outL;
	//reg [15:0] audio_outR;
	wire  signed [15:0] audio_outL;
	wire  signed [15:0] audio_outR;
	integer filehandlerL,filehandlerR;
	initial filehandlerL = $fopen("outputL");
	initial filehandlerR = $fopen("outputR");
	LMS dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .AUD_DACLRCK(AUD_DACLRCK), .audio_inL(audio_inL), .audio_inR(audio_inR), .audio_outL(audio_outL), .audio_outR(audio_outR));


	//assign CLOCK_50=clk;
//	initial begin
//	clk=0;
//	//assign CLOCK_50=0;
//	//always #20000 clk= ~clk;
//	forever #20000 clk=~clk;
//	end


	initial begin
		CLOCK_50=0;
		forever #20000 CLOCK_50=~CLOCK_50;
	end

	initial begin
	@(posedge CLOCK_50);
	assign KEY = 4'b0000;

	@(posedge CLOCK_50);
	assign KEY = 4'b0001;
	end
// 	initial begin
//	clk1=0;
//	//assign CLOCK_50=0;
//	forever #22675736 clk1= ~clk1;
//	end

//	initial begin
//	assign AUD_DACLRCK=0;
//	//assign CLOCK_50=0;
//	forever #22675736 AUD_DACLRCK= ~AUD_DACLRCK;
//	end

	initial begin
	AUD_DACLRCK=0;
	//assign CLOCK_50=0;
	forever #22675736 AUD_DACLRCK= ~AUD_DACLRCK;
	end

	//assign CLOCK_50=clk;
	//assign AUD_DACLRCK=clk1;
	//always #22675736 AUD_DACLRCK =~AUD_DACLRCK;

	initial $readmemh("noisy", testData);
	initial $readmemh("contaminated", noise);

	integer i;
	initial begin
		for(i=0;i<22050;i=i+1) begin
			if(i==7)
			begin
				@(posedge AUD_DACLRCK);
				assign KEY = 4'b0000;
				@(posedge CLOCK_50);
				assign KEY = 4'b0001;
			end
			@(posedge AUD_DACLRCK);
			$display($time, " <<audio_inR: testData[%d][15:0] = %d >>", i, testData[i][15:0]);
			$display($time, " <<audio_inL: testData[%d][15:0] = %d >>", i, noise[i][15:0]);
			#1; audio_inL = noise[i][15:0]; audio_inR = testData[i][15:0];
		end

		$finish;
	end

	always @(negedge AUD_DACLRCK)begin
		$fdisplay(filehandlerR, "%d", audio_outR);
		$fdisplay(filehandlerL, "%d", audio_outL);
	end

endmodule
