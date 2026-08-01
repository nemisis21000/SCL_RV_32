module soc_top(
    input  logic        clk,
    input  logic        rst,
    output logic [31:0] debug_out,

    // SPI
    output logic         spi_clk,
    output logic         spi_csn0,
    output logic         spi_csn1,
    output logic         spi_csn2,
    output logic         spi_csn3,
    output logic [1:0]   spi_mode,
    output logic         spi_sdo0,
    output logic         spi_sdo1,
    output logic         spi_sdo2,
    output logic         spi_sdo3,
    input  logic         spi_sdi0,
    input  logic         spi_sdi1,
    input  logic         spi_sdi2,
    input  logic         spi_sdi3,
    output logic [1:0]   spi_events_o
    // ADD THESE PORTS
//    input  logic [7 :0] gpio_in,
//    output logic [31:0] gpio_out,
//    input  logic        sw_irq,
//    input  logic        ext_irq

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
    .timer_irq(2'b00),
    .sw_irq(1'b0),
    .ext_irq(1'b0),
     
     //AXI
    .MEM_WRITE   (   MEM_WRITE),
    .MEM_READ    (    MEM_READ),
    .MEM_READY   (   MEM_READY),
    .MEM_ADDR    (    MEM_ADDR),
    .MEM_WDATA   (   MEM_WDATA),
    .MEM_WSTRB   (   MEM_WSTRB),
    .MEM_RDATA   (   MEM_RDATA)
);

//    // ========================================
//// AXI SUBSYSTEM
//// ========================================
//AXI_TOP axi_top (

//    .clk            (clk),
//    .reset          (rst),

//    .mem_addr       (MEM_ADDR),
//    .mem_wdata      (MEM_WDATA),
//    .mem_wstrb      (MEM_WSTRB),

//    .mem_we         (MEM_WRITE),
//    .mem_re         (MEM_READ),

//    .mem_rdata      (MEM_RDATA),
//    .mem_ready      (MEM_READY),

//    .SW             (),
    
//    .LEDR           (),

//    .UART_RX        (),
//    .UART_TX        (),
 
//    .HEX0           (),
//    .HEX1           (),
//    .HEX2           (),
//    .HEX3           (),
//    .HEX4           (),
//    .HEX5           (),

//    .spi_clk        (spi_clk),
//    .spi_csn0       (spi_csn0),
//    .spi_csn1       (spi_csn1),
//    .spi_csn2       (spi_csn2),
//    .spi_csn3       (spi_csn3),
//    .spi_mode       (spi_mode),
//    .spi_sdo0       (spi_sdo0),
//    .spi_sdo1       (spi_sdo1),
//    .spi_sdo2       (spi_sdo2),
//    .spi_sdo3       (spi_sdo3),
//    .spi_sdi0       (spi_sdi0),
//    .spi_sdi1       (spi_sdi1),
//    .spi_sdi2       (spi_sdi2),
//    .spi_sdi3       (spi_sdi3),
//    .spi_events_o   (spi_events_o)
//);


endmodule