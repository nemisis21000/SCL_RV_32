module soc_top(
    input  logic        clk,
    input  logic        rst,
    output logic [31:0] debug_out

); 


//AXI
logic        MEM_WRITE;
logic        MEM_READ;
logic        MEM_READY;
logic [31:0] MEM_ADDR;
logic [31:0] MEM_WDATA;
logic [ 3:0] MEM_WSTRB;
logic [31:0] MEM_RDATA;

pipeline_top cpu (

    .clk(clk),
    .rst(rst),
    .debug_out(debug_out),
     
     //AXI
    .MEM_WRITE   (   MEM_WRITE),
    .MEM_READ    (    MEM_READ),
    .MEM_READY   (   MEM_READY),
    .MEM_ADDR    (    MEM_ADDR),
    .MEM_WDATA   (   MEM_WDATA),
    .MEM_WSTRB   (   MEM_WSTRB),
    .MEM_RDATA   (   MEM_RDATA)
);

    // ========================================
// AXI SUBSYSTEM
// ========================================
AXI_TOP axi_top (

    .clk            (clk),
    .reset          (rst),

    .mem_addr       (MEM_ADDR),
    .mem_wdata      (MEM_WDATA),
    .mem_wstrb      (MEM_WSTRB),

    .mem_we         (MEM_WRITE),
    .mem_re         (MEM_READ),

    .mem_rdata      (MEM_RDATA),
    .mem_ready      (MEM_READY)

);


endmodule