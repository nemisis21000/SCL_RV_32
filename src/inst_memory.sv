`timescale 1ns / 1ps

module inst_memory(
    input  logic [31:0] A,
    
    //Imem Macro Signals
    output logic [31:0] INSTR_ADD,
    input  logic [31:0] INSTR,
    
    output logic [31:0] RD
);
    
    
assign RD = INSTR;

endmodule
