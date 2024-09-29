/****************************************************************************
FILENAME     :  video_uut.sv
PROJECT      :  Hack the Hill 2024
****************************************************************************/

/*  INSTANTIATION TEMPLATE  -------------------------------------------------

video_uut video_uut (       
    .clk_i          ( ),//               
    .cen_i          ( ),//
    .vid_sel_i      ( ),//
    .vdat_bars_i    ( ),//[19:0]
    .vdat_colour_i  ( ),//[19:0]
    .fvht_i         ( ),//[ 3:0]
    .fvht_o         ( ),//[ 3:0]
    .video_o        ( ) //[19:0]
);

-------------------------------------------------------------------------- */


module video_uut (
    input  wire         clk_i           ,// clock
    input  wire         cen_i           ,// clock enable
    input  wire		   vid_sel_i       ,// select source video
	input  wire [29:0]  probes_i,
	input  wire [7:0]   square_length_1_i ,
	input  wire [7:0]   square_length_2_i ,
	input  wire [1:0] speed_mult_1_i,
	input  wire [1:0] speed_mult_2_i,
    input  wire [19:0]  vdat_bars_i     ,// input video {luma, chroma}
    input  wire [19:0]  vdat_colour_i   ,// input video {luma, chroma}
    input  wire [3:0]   fvht_i          ,// input video timing signals
    output wire [3:0]   fvht_o          ,// 1 clk pulse after falling edge on input signal
    output wire [19:0]  video_o          // 1 clk pulse after any edge on input signal
); 


// default constants
parameter line_count = 1124;
parameter column_count = 1919;
parameter default_sq_len = 50;
parameter default_speed_mult = 1;

// Colors

parameter color_yellow = 10'h3FC << 20 + 10'h0B0 << 10 + 10'h21F;
//parameter color_red = 10'h3FC << 20 + 10'h215 << 10 + 10'h00F;

parameter luma_sq_2_p = 10'h216;
parameter chroma_b_2_p = 10'h0fd;
parameter chroma_r_2_p = 10'h0cf;
// Config Registers

reg [7:0] square_length_1;
reg [7:0] square_length_2;
reg [1:0] speed_mult_1;
reg [1:0] speed_mult_2;
reg [1:0] speed_mult_3;


// Data Registers

reg [19:0]  vid_d1;
reg [19:0]  vdat_bars_d1;
reg [19:0]  vdat_bars_d2;
reg [3:0]   fvht_d1;
reg [3:0]   fvht_d2;
reg [3:0]   fvht_d3;

reg [11:0] column_counter;
reg [11:0] line_counter; 

reg [9:0] luma_1;
reg [9:0] chroma_b_1;
reg [9:0] chroma_r_1;

reg [9:0] luma_2;
reg [9:0] chroma_b_2;
reg [9:0] chroma_r_2;


reg [11:0] pos_x_1;
reg [11:0] pos_y_1;

reg [11:0] pos_x_2;
reg [11:0] pos_y_2;

reg [3:0] direction; // [1] = Vert (Up high, down low), [0] = Hori (Left low, right high)

// Named Signals
wire h_in, h_d, h_neg;
wire v_in, v_d, new_frame;
wire [29:0] color_sq_1;
wire [29:0] color_sq_2;

wire ballmode;
wire bounce; 
wire[3:0] difference;

assign color_sq_1 = color_yellow;
//assign color_sq_2 = color_red;

assign h_in = fvht_i[1];
assign h_d = fvht_d1[1];

assign v_in = fvht_i[2];
assign v_d = fvht_d1[2];



//assign speed_mult_1

assign h_neg = ~h_in & h_d;
assign h_pos = h_in & ~h_d;
assign new_frame = v_in & ~v_d;


always @(posedge clk_i) begin : probes_and_delay
	 if(cen_i) begin
		square_length_1 <= (~|square_length_1_i) ? default_sq_len : square_length_1_i;
		square_length_2 <= (~|square_length_2_i) ? default_sq_len : square_length_2_i;
		speed_mult_1 <= (~|speed_mult_1_i) ? default_speed_mult : speed_mult_1_i;
		speed_mult_2 <= (~|speed_mult_2_i) ? default_speed_mult : speed_mult_2_i;
		speed_mult_3 <= speed_mult_2;		
		fvht_d1 <= fvht_i; // Delay TIming singals to detect edges
		vdat_bars_d1 <= vdat_bars_i; // Delay Bars by one extra cycle, to combine with delayed output
		vdat_bars_d2 <= vdat_bars_d1;

		luma_1 <= probes_i[29:20];// color_yellow[29:20];
		chroma_b_1 <= probes_i[19:10];
		chroma_r_2 <= probes_i[9:0];

	    luma_2 <= luma_sq_2_p;
	    chroma_b_2 <= chroma_b_2_p;
	    chroma_r_2 <= chroma_r_2_p;
			
		fvht_d2 <= fvht_d1; // Delay Timings for output
		fvht_d3 <= fvht_d2;
	 end
 end

 
always @(posedge clk_i) begin : counter_logic
    if(cen_i) begin
		 if(h_pos) begin // Detect h positive edge
			if(new_frame) begin // Detect v positive edge
				line_counter <= 0; // Reset Vertical Position (New frame)
			end else begin
				line_counter <= line_counter + 1; //Incrememt Line Counter
			end
		 end
		
		 if(h_neg) begin // Detect h negitive edge
			column_counter <= 0; // Reset column counter
		 end else begin
			column_counter <= column_counter + 1; // Increment column counter
		 end
	end
end

always @(posedge clk_i) begin : move_squares

	if(cen_i) begin
		 if(new_frame) begin	
			// Square One
			if (pos_x_1 > column_count+100 || pos_x_1 < 6) begin
				pos_x_1 <= 6;
				direction[0] <= 0;
			end else if ((pos_x_1 + square_length_1) > column_count) begin
				pos_x_1	<= column_count - square_length_1 - 1; /// sq 1 x
				direction[0] <= 1;
			end else begin
				if(direction[0]) begin
					pos_x_1 <= (pos_x_1 - 2*speed_mult_1*speed_mult_3);
				end else begin
					pos_x_1 <= (pos_x_1 + 2*speed_mult_1*speed_mult_3);
				end// Move image h
			end
			if ((pos_y_1 +square_length_1) >= line_count) begin
				pos_y_1 <= line_count - square_length_1 - 5; /// sq 1 y
				direction[1] <= 1;
			end else if (pos_y_1 <= 45) begin
				pos_y_1 <= 50;
				direction[1] <= 0;
			end else begin 
				if(direction[1]) begin
					pos_y_1 <= (pos_y_1 - 2*speed_mult_1*speed_mult_3);
				end else begin
					pos_y_1 <= (pos_y_1 + 2*speed_mult_1*speed_mult_3);
				end
			end
			// Square Two
			if (pos_x_2 > column_count+100 || pos_x_2 < 6) begin
				pos_x_2 <= 6;
				direction[2] <= 0;
			end else if ((pos_x_2 + square_length_2) >= column_count) begin
				pos_x_2	<= column_count - square_length_2 - 4; /// sq 2 x
				direction[2] <= 1;
			end else begin
				if(direction[2]) begin
					pos_x_2 <= (pos_x_2 - 2*speed_mult_2*speed_mult_3);
				end else begin
					pos_x_2 <= (pos_x_2 + 2*speed_mult_2*speed_mult_3);
				end// Move image h
			end
			if ((pos_y_2 +square_length_2) >= line_count) begin
				pos_y_2 <= line_count - square_length_2 - 1; /// sq 2 y
				direction[3] <= 1;
			end else if (pos_y_2 <= 45) begin
				pos_y_2 <= 50;
				direction[3] <= 0;
			end else begin 
				if(direction[3]) begin
					pos_y_2 <= (pos_y_2 - 2*speed_mult_2*speed_mult_3);
				end else begin
					pos_y_2 <= (pos_y_2 + 2*speed_mult_2*speed_mult_3);
				end
			end
			// if(bounce) begin
			// 	difference[0] = (pos_x_1) < pos_x_2 +square_length_2;   // sq1 hits right plane of sq2
			// 	difference[1] = (pos_y_1 - pos_y_2 -square_length_2) < 0;	// sq1 hits bottom plane of sq2 
			// 	difference[2] = (pos_x_2 - pos_x_1 -square_length_1) < 0;   // sq2 hits plane of right side sq1 
			// 	difference[3] = (pos_y_2 - pos_y_1 -square_length_1) < 0;	// sq2 hits bottom plane of sq1
			// 	// if(((difference[1] && (difference[2])||difference[0]))||(difference[3]&&(difference[0] ||difference[2]))||(difference[2]&&(difference[1]||difference[2]))||(difference[0]&&(difference[1]||difference[3]))) begin
			// 	// 	if(direction[0] & direction[2]) begin
			// 	// 		direction[1] <=!direction[1];
			// 	// 		direction[3] <=!direction[3];
			// 	// 	end else if (direction[1] & direction[3]) begin
			// 	// 		pos_x_1 + 2;
			// 	// 		pos_x_2 - 2;
			// 	// 		direction[0] <=!direction[0];
			// 	// 		direction[2] <=!direction[2]; // if they are moving in same direction refect off the other way
			// 	// 	end else if (direction[1] & !direction[3]) begin
			// 	// 		pos_x_1 - 2;
			// 	// 		pos_x_2 + 2;
			// 	// 		direction[1] <=!direction[1];
			// 	// 		direction[3] <=!direction[3]; // if they are  moving in opposite direction refect off the other way
			// 	// 	end else if (direction[0] & !direction[2]) begin
			// 	// 		direction[0] <=!direction[0];
			// 	// 		direction[3] <=!direction[2]; // if they are moving in opposite direction refect off the other way
			// 	// 	end

			// 	// end
			// 	// if (difference[0]&difference[1])begin
			// 	// 	direction[0] <=!direction[0];
			// 	// end 
			// end
		end
  	end
end


wire [19:0] square_1_o;

wire [19:0] square_2_o;

wire [19:0] out_color;

always @(posedge clk_i) begin : draw_squares
	if(cen_i) begin
		// Bars with moving square
			 if( (pos_x_1 < column_counter && column_counter < pos_x_1+square_length_1) &&
					 (pos_y_1 < line_counter && line_counter < pos_y_1+square_length_1 )) begin // horizontal position and probe 2 active
				 if(column_counter % 2 == 0) begin
						square_1_o <= {luma_1, chroma_b_1}; //draw blue
					 end else begin
						square_1_o <= {luma_1, chroma_r_1}; //draw red
				  end
			  end else begin
			  			 square_1_o <= 0;      /// dont draw square 1
			  end
			  
			 if( (pos_x_2 < column_counter && column_counter < pos_x_2+square_length_2) &&
					 (pos_y_2 < line_counter && line_counter < pos_y_2+square_length_2 )) begin // horizontal position and probe 2 active
				 if(column_counter % 2 == 0) begin
						square_2_o <= {luma_2, chroma_b_2};
					 end else begin
						square_2_o <= {luma_2, chroma_r_2};  // draw square 2 
				  end
			 end else begin
					square_2_o <= 0;   
			 end
			 if(vid_sel_i) begin
				if(!square_1_o && !square_2_o) begin
					//out_color <= {10'h050,10'h200};
					out_color <= vdat_bars_d1;
				end else if(!square_1_o) begin
					//out_color <= square_2_o;
					out_color <= { (vdat_bars_d1[19:10]+square_2_o[19:10]), (vdat_bars_d1[9:0]+square_2_o[9:0]) >>> 1};
				end else if (!square_2_o) begin
					//out_color <= square_1_o;
					out_color <= { (square_1_o[19:10]+vdat_bars_d1[19:10]), (square_1_o[9:0]+vdat_bars_d1[9:0]) >>> 1};
				end else begin
					out_color <= { (square_1_o[19:10]+square_2_o[19:10]), (square_1_o[9:0]+square_2_o[9:0]) >>> 1};
				end
			 end else begin
				if(!square_1_o && !square_2_o) begin
					out_color <= {10'h050,10'h200};
				end else if(!square_1_o) begin
					out_color <= square_2_o;
				end else if (!square_2_o) begin
					out_color <= square_1_o;
				end else begin
					out_color <= { (square_1_o[19:10]+square_2_o[19:10]), (square_1_o[9:0]+square_2_o[9:0]) >>> 1};
				end
			end
				
			 
			 vid_d1 <= out_color;
	 end
			  
end
// OUTPUT
assign fvht_o  = fvht_d3;
assign video_o = vid_d1;

endmodule

