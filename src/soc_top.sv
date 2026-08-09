module soc_top(
    input  logic        clk,
    input  logic        rst,
    output logic [31:0] debug_out,

//Byte Loading
    input  logic       load_mode,    // 1 = boot-load mode, 0 = run mode    both rst and load can cause the core to reset
    input  logic [7:0] data_in,
    input  logic       byte_strobe,
    output logic       load_ready
); 

//Byte loader
logic        core_rst_n;
logic [9:0]  instr_waddr;
logic [31:0] instr_wdata;
logic        instr_we;

//AXI
logic        MEM_WRITE;
logic        MEM_READ;
logic        MEM_READY;
logic [31:0] MEM_ADDR;
logic [31:0] MEM_WDATA;
logic [ 3:0] MEM_WSTRB;
logic [31:0] MEM_RDATA;


byte_loader instr_in(
    .ext_clk     (clk),
    .ext_rst_n   (rst),
    .load_mode   (load_mode),
    .data_in     (data_in),
    .byte_strobe (byte_strobe),
    .load_ready  (load_ready),
    
    .core_rst_n  (core_rst_n),
    .instr_waddr (),
    .instr_wdata (),
    .instr_we    ()
);
pipeline_top cpu (

    .clk(clk),
    .rst(core_rst_n),
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