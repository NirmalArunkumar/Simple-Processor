module Work(
    input CLOCK_50,
    input [9:0] SW,
    input [3:0] KEY,
    output [6:0] HEX0, HEX1, HEX2, HEX5,
    output reg [2:0] LEDR,
    // Add these VGA signals
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B,
    output VGA_HS,
    output VGA_VS,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK
);

reg [7:0] d_ram[0:7];
reg [2:0] riinst,dr_1,sr1_1,sr2_1;
reg [2:0] inst,dr_11,sr1_11,sr2_11;
wire [7:0] q,q1,q2,q3;
reg [7:0] regfile [0:7];


// 16,25,34,21,39,8,2,3 
initial
	$readmemb("Col.txt",d_ram);
	



always@(posedge CLOCK_50)
begin
riinst={SW[2],SW[1],SW[0]};
if (!KEY[0])
inst<=riinst;
end

always@(posedge CLOCK_50)
begin

dr_1={SW[8],SW[7],SW[6]};
sr1_1={SW[5],SW[4],SW[3]};
sr2_1={SW[2],SW[1],SW[0]};

if (!KEY[1])
begin
dr_11<=dr_1;
sr1_11<=sr1_1;
sr2_11<=sr2_1;
end
end

always@(negedge KEY[2])
begin
case(inst)
3'b001 : regfile[dr_11] <= d_ram[sr1_11];
3'b010 : regfile[dr_11] <= regfile[sr1_11] + regfile[sr2_11];
3'b011 : regfile[dr_11] <= regfile[sr1_11] * regfile[sr2_11];
3'b110 : d_ram[dr_11] <= regfile[sr1_11];
endcase
end

assign q = (inst == 3'b110) ? d_ram[dr_11] : ((inst == 3'b000 | inst == 3'b101) ? 8'b00000000 : regfile[dr_11]);
assign q1 = q % 10;
assign q2 = (q / 10) % 10;
assign q3 = (q / 100);

always@(negedge KEY[3])
begin
if((regfile[sr1_11] > regfile[sr2_11]) && inst==3'b101)
begin
LEDR[2] <= 1'b1;
LEDR[1] <= 1'b0;
LEDR[0] <= 1'b0;
end
else if((regfile[sr1_11] < regfile[sr2_11]) && inst==3'b101)
begin
LEDR[2] <= 1'b0;
LEDR[1] <= 1'b1;
LEDR[0] <= 1'b0;
end
else if ((regfile[sr1_11] == regfile[sr2_11]) && inst==3'b101)
begin
LEDR[2] <= 1'b0;
LEDR[1] <= 1'b0;
LEDR[0] <= 1'b1;
end
else
begin
LEDR[2] <= 1'b0;
LEDR[1] <= 1'b0;
LEDR[0] <= 1'b1;
end
end

DISPLAY_IN_N I1 (inst,HEX5);
DISPLAY_N d1 (q1,HEX0);
DISPLAY_N d2 (q2,HEX1);
DISPLAY_N d3 (q3,HEX2);
vga_demo vga_inst(  // Give it an instance name
    .CLOCK_50(CLOCK_50),
    .SW(SW),
    .KEY(KEY),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),
    .VGA_BLANK_N(VGA_BLANK_N),
    .VGA_SYNC_N(VGA_SYNC_N),
    .VGA_CLK(VGA_CLK),
    .q(q)
);

endmodule


module DISPLAY_N (input [7:0] A,output reg [6:0] B);

always@(*)
case(A)
0: B = 7'b1000000;
1: B = 7'b1111001;
2: B = 7'b0100100;
3: B = 7'b0110000;
4: B = 7'b0011001;
5: B = 7'b0010010;
6: B = 7'b0000010;
7: B = 7'b1111000;
8: B = 7'b0000000;
9: B = 7'b0011000;
10: B = 7'b0001000;
11: B = 7'b0000011;
12: B = 7'b1000110;
13: B = 7'b0100001;
14: B = 7'b0000110;
15: B = 7'b0001110;
default: B = 7'b1111111;
endcase

endmodule

module DISPLAY_IN_N (input [2:0] IN_ST,output reg [6:0] Q);

always@(*)
case(IN_ST)
3'b001: Q = 7'b1000111; // L
3'b010: Q = 7'b0001000; // A
3'b011: Q = 7'b0001100; // P
3'b101: Q = 7'b1000110; // C
3'b110: Q = 7'b0010010; // S
default: Q = 7'b1111111;
endcase

endmodule
