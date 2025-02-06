module vga_demo(CLOCK_50, SW, KEY, VGA_R, VGA_G, VGA_B,
                VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK, q);

input CLOCK_50;
input [9:0] SW;
input [3:0] KEY;
input [7:0] q;
output [7:0] VGA_R;
output [7:0] VGA_G;
output [7:0] VGA_B;
output VGA_HS;
output VGA_VS;
output VGA_BLANK_N;
output VGA_SYNC_N;
output VGA_CLK;

// FSM states
parameter IDLE = 3'b000, 
          LOAD = 3'b001, 
          RAM = 3'b010, 
          DISPLAY = 3'b011, 
          ALU = 3'b100, 
          OUTPUT = 3'b101, 
          WRONG = 3'b110;

// State registers and counters
reg [2:0] state, next_state;
reg [7:0] x_reg, x_pro, x_out;
reg [6:0] y_reg, y_pro, y_out;
reg [3:0] digit0, digit1, digit2;

// Pixel counters
reg [7:0] pixel_x;
reg [6:0] pixel_y;

// VGA signals
reg [2:0] VGA_COLOR;
wire [7:0] VGA_X;
wire [6:0] VGA_Y;

// Edge detection
reg key0_prev, key1_prev, key2_prev;
wire key0_edge = (!KEY[0] && key0_prev);
wire key1_edge = (!KEY[1] && key1_prev);
wire key2_edge = (!KEY[2] && key2_prev);

// ROM outputs
wire [2:0] tick_mem_color, x_mem_color;
wire [2:0] image0_color, image1_color, image2_color, image3_color,
           image4_color, image5_color, image6_color, image7_color,
           image8_color, image9_color;

// Character position calculation
wire [2:0] char_x = pixel_x[2:0];
wire [2:0] char_y = pixel_y[2:0];
reg [1:0] pixel_stretch_count;
    wire pixel_enable;
    wire [2:0] background_color;
    wire [14:0] pixel_address;

    // Pixel stretch counter
    always @(posedge CLOCK_50) begin
        pixel_stretch_count <= pixel_stretch_count + 1;
    end
    
    assign pixel_enable = (pixel_stretch_count == 2'b11);
    
    // Calculate ROM address from current pixel position
    assign pixel_address = (pixel_y * 160) + pixel_x;
    
    // Background ROM instance
    imagen_mem background_rom (
        .address(pixel_address),
        .clock(CLOCK_50),
        .q(background_color)
    );

// State register
always @(posedge CLOCK_50 or negedge KEY[3]) begin
    if (!KEY[3])
        state <= IDLE;
    else
        state <= next_state;
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (SW[2:0] == 3'b001 && key0_edge)
                next_state = LOAD;
            else if (SW[2:0] != 3'b001)
                next_state = WRONG;
            else
                next_state = IDLE;
        end
        LOAD: begin
            if (key1_edge)
                next_state = RAM;
            else
                next_state = LOAD;
        end
        RAM: begin
            if (key2_edge)
                next_state = DISPLAY;
            else
                next_state = RAM;
        end
        DISPLAY: begin
            if (SW[2:0] == 3'b001 && key0_edge)
                next_state = LOAD;
            else if (SW[2:0] != 3'b001 && key0_edge)
                next_state = ALU;
            else
                next_state = DISPLAY;
        end
        ALU: begin
            if (key1_edge)
                next_state = RAM;
            else if (key2_edge)
                next_state = OUTPUT;
            else
                next_state = ALU;
        end
        OUTPUT: begin
            if (SW[2:0] != 3'b001 && key0_edge)
                next_state = WRONG;
            else
                next_state = OUTPUT;
        end
        WRONG: begin
            if (key0_edge)
                next_state = IDLE;
            else
                next_state = WRONG;
        end
        default: next_state = IDLE;
    endcase
end

// Pixel counter
always @(posedge CLOCK_50 or negedge KEY[3]) begin
    if (!KEY[3]) begin
        pixel_x <= 8'd0;
        pixel_y <= 7'd0;
    end else begin
        if (pixel_x == 8'd159) begin
            pixel_x <= 8'd0;
            if (pixel_y == 7'd119)
                pixel_y <= 7'd0;
            else
                pixel_y <= pixel_y + 1;
        end else
            pixel_x <= pixel_x + 1;
    end
end

// Position update logic
always @(posedge CLOCK_50 or negedge KEY[3]) begin
    if (!KEY[3]) begin
        x_reg <= 8'd0;
        y_reg <= 7'd16;
        x_pro <= 8'd0;
        y_pro <= 7'd88;
        x_out <= 8'd88;
        y_out <= 7'd16;
        digit0 <= 4'd0;
        digit1 <= 4'd0;
        digit2 <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                x_reg <= 8'd0;
                y_reg <= 7'd16;
                x_pro <= 8'd0;
                x_out <= 8'd80;
					 y_out <= 7'd16;
            end
            LOAD, RAM, ALU: begin
                if (key1_edge || key2_edge)
                    x_pro <= x_pro + 8'd8;
            end
            DISPLAY: begin
                if (q < 100) begin  // Only show 2 digits max
        digit0 <= q % 10;           // Units place
        digit1 <= q / 10;           // Tens place
        digit2 <= 4'd0;             // No hundreds place
    end 
	 else begin
        digit0 <= q % 10;
        digit1 <= (q / 10) % 10;
        digit2 <= q / 100;
    end
                if (key0_edge) begin
                    y_reg <= y_reg + 7'd8;
                    if (x_reg >= 8'd24) begin
								x_reg <= 8'd0;
                        y_reg <= y_reg + 7'd8;
                    end
                end
            end
            OUTPUT: begin
                if (q < 100) begin  // Only show 2 digits max
        digit0 <= q % 10;           // Units place
        digit1 <= q / 10;           // Tens place
        digit2 <= 4'd0;             // No hundreds place
    end 
	 else begin
        digit0 <= q % 10;
        digit1 <= (q / 10) % 10;
        digit2 <= q / 100;
    end
                if (key0_edge) begin
                    y_out <= y_out + 7'd8;
						  x_out <= 8'd80;
            end
				end
        endcase
    end
end

// Color selection logic
always @(*) begin
    // Default white background
    VGA_COLOR =background_color;
    
    case (state)
        IDLE: 
            VGA_COLOR = background_color;
            
        LOAD: begin
            if ((pixel_x >=8'd0 ) && (pixel_x < 8'd0 + 8) &&
                (pixel_y >= 7'd88) && (pixel_y < 7'd88 + 8))
                VGA_COLOR = tick_mem_color;
        end
		  RAM: begin
            if ((pixel_x >=8'd32 ) && (pixel_x < 8'd32 + 8) &&
                (pixel_y >= 7'd88) && (pixel_y < 7'd88 + 8))
                VGA_COLOR = tick_mem_color;
        end
		  ALU: begin
            if ((pixel_x >=8'd64 ) && (pixel_x < 8'd64 + 8) &&
                (pixel_y >= 7'd88) && (pixel_y < 7'd88 + 8))
                VGA_COLOR = tick_mem_color;
        end
        
        DISPLAY: begin
            // First, determine how many digits to display
            if ((pixel_x >= x_reg) && (pixel_y >= y_reg) && 
                (pixel_y < y_reg + 8)) begin
                if (digit2 != 0) begin  // Three digit number
                    if (pixel_x < x_reg + 8)
                        VGA_COLOR = digit_rom_color(digit2);
                    else if (pixel_x < x_reg + 16)
                        VGA_COLOR = digit_rom_color(digit1);
                    else if (pixel_x < x_reg + 24)
                        VGA_COLOR = digit_rom_color(digit0);
                end
                else if (digit1 != 0) begin  // Two digit number
                    if (pixel_x < x_reg + 8)
                        VGA_COLOR = digit_rom_color(digit1);
                    else if (pixel_x < x_reg + 16)
                        VGA_COLOR = digit_rom_color(digit0);
                end
                else begin  // Single digit number
                    if (pixel_x < x_reg + 8)
                        VGA_COLOR = digit_rom_color(digit0);
                end
            end
        end
        
        OUTPUT: begin
            // Similar logic for output
            if ((pixel_x >= x_out) && (pixel_y >= y_out) && 
                (pixel_y < y_out + 8)) begin
                if (digit2 != 0) begin  // Three digit number
                    if (pixel_x < x_out + 8)
                        VGA_COLOR = digit_rom_color(digit2);
                    else if (pixel_x < x_out + 16)
                        VGA_COLOR = digit_rom_color(digit1);
                    else if (pixel_x < x_out + 24)
                        VGA_COLOR = digit_rom_color(digit0);
                end
                else if (digit1 != 0) begin  // Two digit number
                    if (pixel_x < x_out + 8)
                        VGA_COLOR = digit_rom_color(digit1);
                    else if (pixel_x < x_out + 16)
                        VGA_COLOR = digit_rom_color(digit0);
                end
                else begin  // Single digit number
                    if (pixel_x < x_out + 8)
                        VGA_COLOR = digit_rom_color(digit0);
                end
            end
        end/*DISPLAY: begin
            // Calculate the relative x position for digit display
            if ((pixel_x >= x_reg) && (pixel_x < x_reg + 24) &&
                (pixel_y >= y_reg) && (pixel_y < y_reg + 8)) begin
                // Calculate position within the 3-digit display area
                if (digit2 != 0 && pixel_x < x_reg + 8)
                    VGA_COLOR = digit_rom_color(digit2);
                else if ((digit1 != 0 || digit2 != 0) && pixel_x < x_reg + 16)
                    VGA_COLOR = digit_rom_color(digit1);
                else
                    VGA_COLOR = digit_rom_color(digit0);
            end
        end
        
        OUTPUT: begin
            if ((pixel_x >= x_out) && (pixel_x < x_out + 24) &&
                (pixel_y >= y_out) && (pixel_y < y_out + 8)) begin
                // Calculate position within the 3-digit display area
                if (digit2 != 0 && pixel_x < x_out + 8)
                    VGA_COLOR = digit_rom_color(digit2);
                else if ((digit1 != 0 || digit2 != 0) && pixel_x < x_out + 16)
                    VGA_COLOR = digit_rom_color(digit1);
                else 
                    VGA_COLOR = digit_rom_color(digit0);
            end
        end*/
        
        WRONG: begin
    // Check each position for X mark
    if ((pixel_x >= 8'd0 && pixel_x < 8'd0 + 8 && 
         pixel_y >= 7'd88 && pixel_y < 7'd88 + 8) ||    // First X position
        (pixel_x >= 8'd32 && pixel_x < 8'd32 + 8 && 
         pixel_y >= 7'd88 && pixel_y < 7'd88 + 8) ||    // Second X position
        (pixel_x >= 8'd64 && pixel_x < 8'd64 + 8 && 
         pixel_y >= 7'd88 && pixel_y < 7'd88 + 8)) begin // Third X position
        VGA_COLOR = x_mem_color;
    end else begin
        VGA_COLOR = background_color;
    end
end
        default: 
            VGA_COLOR = 3'b111;
    endcase
end


// Edge detection
always @(posedge CLOCK_50 or negedge KEY[3]) begin
    if (!KEY[3]) begin
        key0_prev <= 1'b0;
        key1_prev <= 1'b0;
        key2_prev <= 1'b0;
    end else begin
        key0_prev <= KEY[0];
        key1_prev <= KEY[1];
        key2_prev <= KEY[2];
    end
end

// ROM instances
tick_mem tick_rom (
    .address({char_y, char_x}),
    .clock(CLOCK_50),
    .q(tick_mem_color)
);

x_mem x_rom (
    .address({char_y, char_x}),
    .clock(CLOCK_50),
    .q(x_mem_color)
);

// Number ROMs
image0 rom0 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image0_color));
image1 rom1 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image1_color));
image2 rom2 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image2_color));
image3 rom3 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image3_color));
image4 rom4 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image4_color));
image5 rom5 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image5_color));
image6 rom6 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image6_color));
image7 rom7 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image7_color));
image8 rom8 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image8_color));
image9 rom9 (.address({char_y, char_x}), .clock(CLOCK_50), .q(image9_color));

// Digit color selection function
function [2:0] digit_rom_color(input [3:0] digit);
    case (digit)
        4'd0: digit_rom_color = image0_color;
        4'd1: digit_rom_color = image1_color;
        4'd2: digit_rom_color = image2_color;
        4'd3: digit_rom_color = image3_color;
        4'd4: digit_rom_color = image4_color;
        4'd5: digit_rom_color = image5_color;
        4'd6: digit_rom_color = image6_color;
        4'd7: digit_rom_color = image7_color;
        4'd8: digit_rom_color = image8_color;
        4'd9: digit_rom_color = image9_color;
        default: digit_rom_color = 3'b111;
    endcase
endfunction

// VGA signal assignments
assign VGA_X = pixel_x;
assign VGA_Y = pixel_y;

// VGA adapter instantiation
vga_adapter VGA (
    .resetn(KEY[3]),
    .clock(CLOCK_50),
    .colour(VGA_COLOR),
    .x(VGA_X),
    .y(VGA_Y),
    .plot(1'b1),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),
    .VGA_BLANK_N(VGA_BLANK_N),
    .VGA_SYNC_N(VGA_SYNC_N),
    .VGA_CLK(VGA_CLK)
);

defparam VGA.RESOLUTION = "160x120";
defparam VGA.MONOCHROME = "FALSE";
defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
defparam VGA.BACKGROUND_IMAGE = "imagen.mif";

endmodule
