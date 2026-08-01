`timescale 1ns / 1ps
module Data_RAM(
    input logic        clk,
    input logic [31:0] addr,
    input logic [31:0] write_data,
    input logic [ 3:0] wstrb,
    input logic        read_en,
    input logic        write_en,
    output logic [31:0] read_data
    );
    
    logic [31:0] ram [0:1023];
    logic [9:0] sel_addr;
    
    assign sel_addr = addr[11:2];
    
    always_ff@(posedge clk)
    begin
    
        read_data <= 32'b00;
        
        if(read_en)
            read_data <= ram[sel_addr];
        if(write_en) begin
            for (int i = 0; i < 4; i = i + 1) begin
                if (wstrb[i]) begin
                    ram[sel_addr][8*i +: 8] <= write_data[8*i +: 8];
                end
            end
        end      
    end
endmodule
