`timescale 1ns / 1ps

module jtsc_dmem(
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] A,
    input  logic [31:0] WD,
    input  logic        MemWrite,
    input  logic        MemRead,
    input  logic [ 2:0] funct3M,
    output logic [31:0] RD,
    output logic        StallMem,

//AXI INTERFACE 

    output logic         MEM_WRITE,
    output logic         MEM_READ,
//    output         MEM_INSTR, useless i think
    input          MEM_READY,
//    output  [1:0] MEM_ERROR, have to add
    output logic  [31:0] MEM_ADDR,
    output logic  [31:0] MEM_WDATA,
    output logic  [ 3:0] MEM_WSTRB,
    input  logic  [31:0] MEM_RDATA
);

logic [31:0] load_byte;
logic [31:0] load_half;
logic [31:0] rdata_raw;

logic [3:0] wstrb_reg;

//assign MEM_VALID = MemRead || MemWrite;
assign MEM_WRITE = MemWrite;
assign MEM_READ = MemRead;
assign MEM_ADDR = A;
assign MEM_WDATA = WD;
assign MEM_WSTRB = (MemWrite)? wstrb_reg : 4'b0000;
assign StallMem = (MEM_WRITE || MEM_READ) && !MEM_READY;

////////////////////////////////////////////////////
//BYTE ENABLE
///////////////////////////////////////////////////

always_comb
begin 
    if(MemWrite)
    begin
        if(funct3M == 3'b000) wstrb_reg = 4'b0001 << A[1:0];
        else if (funct3M == 3'b001) wstrb_reg = 4'b0011 << A[1:0];
        else if(funct3M == 3'b010) wstrb_reg = 4'b1111;
        else wstrb_reg = 4'b0000;
    end
    else wstrb_reg = 4'b0000;
end   

always_ff@(posedge clk or negedge rst)
begin
    if(!rst)
        rdata_raw <= 32'b0;
        
    else if (MemRead && MEM_READY)
        rdata_raw <= MEM_RDATA;
end

always_comb begin

    load_byte = rdata_raw >> (8*A[1:0]);
    load_half = rdata_raw >> (8*A[  0]);

    case(funct3M)

        3'b000: RD = {{24{load_byte[7]}}, load_byte[7:0]};   // LB

        3'b100: RD = {24'b0, load_byte[7:0]};                // LBU

        3'b001: RD = {{16{load_half[15]}}, load_half[15:0]}; // LH

        3'b101: RD = {16'b0, load_half[15:0]};               // LHU

        3'b010: RD = rdata_raw;                        // LW

        default: RD = 32'b0;
    endcase
end
endmodule