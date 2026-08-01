module soc_tb();

logic clk,rst;

logic [31:0] debug_out;

soc_top dut(
    .clk(clk),
    .rst(rst),
    .debug_out(debug_out)
    );
    
initial 
begin
    clk = 0;
    rst = 0;
    #30;
    rst = 1;
    #2000;
    $finish;
end

always #5 clk = ~clk;

    
endmodule