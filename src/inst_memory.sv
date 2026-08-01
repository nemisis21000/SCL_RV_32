`timescale 1ns / 1ps

module inst_memory(
    input  [31:0] A,
    output reg [31:0] RD
);

logic [31:0] I_mem [127:0];
    
assign RD = I_mem[{2'b00,A[31:2]}];
    
initial 
begin
        $readmemh("../inst_file.hex", I_mem);
end
endmodule
