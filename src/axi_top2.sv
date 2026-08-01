// ============================================================================
// Module AXI_TOP
// ----------------------------------------------------------------------------
// AXI4-Lite + APB4 SoC Subsystem
//
// Architecture
// ----------------------------------------------------------------------------
// CPU memory interface
//        |
//        v
// AXI_Manager
//        |
//        v
// AXI_Interconnect
//   |          |             
//   |          |             
//   v          v             
// AXI_RAM   AXI_to_APB4      
//             Bridge
//               |
//               v
//       APB4_Interconnect
//          |          |
//          v          v
//     APB4_SPI    APB4_UART
//
// Memory Map
// ----------------------------------------------------------------------------
// 0x0000_0000 - 0x0000_0FFF : RAM  (AXI)
//
// Reset convention
// ----------------------------------------------------------------------------
// reset = 0 : synchronous reset active
// reset = 1 : normal operation
// ============================================================================

module AXI_TOP #(

    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)
(

    input clk, 
    input reset,

    input [ADDR_WIDTH - 1:0]    mem_addr,
    input [DATA_WIDTH - 1:0]    mem_wdata,
    input [DATA_WIDTH/8 - 1:0]  mem_wstrb,          // Byte enable from CPU
    input                       mem_we,
    input                       mem_re,
    output [DATA_WIDTH - 1:0]   mem_rdata,
    output                      mem_ready
);

    // ==============================================
    // AXI MANAGER INTERFACE
    // ==============================================

    // ================= WRITE ADDRESS ==============
    logic [ADDR_WIDTH - 1:0] m_axi_awaddr;
    logic                    m_axi_awvalid;
    logic                    m_axi_awready;

    // ================= WRITE DATA ==============
    logic [DATA_WIDTH - 1:0] m_axi_wdata;
    logic [DATA_WIDTH/8-1:0] m_axi_wstrb;
    logic                    m_axi_wvalid;
    logic                    m_axi_wready;

    // ================= WRITE RESPONSE ==============
    logic [1:0]              m_axi_bresp;
    logic                    m_axi_bvalid;
    logic                    m_axi_bready;

    // ================= READ ADDRESS ==============
    logic [ADDR_WIDTH - 1:0] m_axi_araddr;
    logic                    m_axi_arvalid;
    logic                    m_axi_arready;

    // ================= READ DATA ==============
    logic [DATA_WIDTH - 1:0] m_axi_rdata;
    logic [1:0]              m_axi_rresp;
    logic                    m_axi_rvalid;
    logic                    m_axi_rready;

    // ==============================================
    // RAM SLAVE AXI
    // ==============================================
    logic [ADDR_WIDTH - 1:0] ram_axi_awaddr;
    logic                    ram_axi_awvalid;
    logic                    ram_axi_awready;

    logic [DATA_WIDTH - 1:0] ram_axi_wdata;
    logic [DATA_WIDTH/8-1:0] ram_axi_wstrb;
    logic                    ram_axi_wvalid;
    logic                    ram_axi_wready;

    logic [1:0]              ram_axi_bresp;
    logic                    ram_axi_bvalid;
    logic                    ram_axi_bready;

    logic [ADDR_WIDTH - 1:0] ram_axi_araddr;
    logic                    ram_axi_arvalid;
    logic                    ram_axi_arready;

    logic [DATA_WIDTH - 1:0] ram_axi_rdata;
    logic [1:0]              ram_axi_rresp;
    logic                    ram_axi_rvalid;
    logic                    ram_axi_rready;

    // =========================================================================
    // AXI MANAGER
    // =========================================================================
    //
    // NOTE:
    // Currently using a standalone AXI Manager to test the subsystem.
    // Later, the CPU_BUS_TO_AXI interface will be connected here.
    //
    // =========================================================================
    AXI_Manager manager (

        .clk                (clk),
        .reset              (reset),

        .mem_addr           (mem_addr),
        .mem_wdata          (mem_wdata),
        .mem_wstrb          (mem_wstrb),
        .mem_we             (mem_we),
        .mem_re             (mem_re),
        .mem_rdata          (mem_rdata),
        .mem_ready          (mem_ready),

        // WRITE ADDRESS
        .axi_awaddr         (m_axi_awaddr),
        .axi_awvalid        (m_axi_awvalid),
        .axi_awready        (m_axi_awready),

        // WRITE DATA
        .axi_wdata          (m_axi_wdata),
        .axi_wstrb          (m_axi_wstrb),
        .axi_wvalid         (m_axi_wvalid),
        .axi_wready         (m_axi_wready),

        // WRITE RESPONSE
        .axi_bresp          (m_axi_bresp),
        .axi_bvalid         (m_axi_bvalid),
        .axi_bready         (m_axi_bready),

        // READ ADDRESS
        .axi_araddr         (m_axi_araddr),
        .axi_arvalid        (m_axi_arvalid),
        .axi_arready        (m_axi_arready),
        
        // READ DATA
        .axi_rdata          (m_axi_rdata),
        .axi_rresp          (m_axi_rresp),
        .axi_rvalid         (m_axi_rvalid),
        .axi_rready         (m_axi_rready)
    );

    // =========================================================================
    // AXI INTERCONNECT
    // + s0 = RAM
    // =========================================================================
    AXI_Interconnect u_interconnect (
        .clk                (clk),
        .reset              (reset),

        // ===============================
        // AXI MASTER SIDE
        // ===============================
        .m_axi_awaddr       (m_axi_awaddr),
        .m_axi_awvalid      (m_axi_awvalid),
        .m_axi_awready      (m_axi_awready),

        .m_axi_wdata        (m_axi_wdata),
        .m_axi_wstrb        (m_axi_wstrb),
        .m_axi_wvalid       (m_axi_wvalid),
        .m_axi_wready       (m_axi_wready),

        .m_axi_bresp        (m_axi_bresp),
        .m_axi_bvalid       (m_axi_bvalid),
        .m_axi_bready       (m_axi_bready),

        .m_axi_araddr       (m_axi_araddr),
        .m_axi_arvalid      (m_axi_arvalid),
        .m_axi_arready      (m_axi_arready),

        .m_axi_rdata        (m_axi_rdata),
        .m_axi_rresp        (m_axi_rresp),
        .m_axi_rvalid       (m_axi_rvalid),
        .m_axi_rready       (m_axi_rready),

        // ===============================
        // RAM SLAVE
        // ===============================
        .s0_axi_awaddr       (ram_axi_awaddr),
        .s0_axi_awvalid      (ram_axi_awvalid),
        .s0_axi_awready      (ram_axi_awready),

        .s0_axi_wdata        (ram_axi_wdata),
        .s0_axi_wstrb        (ram_axi_wstrb),
        .s0_axi_wvalid       (ram_axi_wvalid),
        .s0_axi_wready       (ram_axi_wready),

        .s0_axi_bresp        (ram_axi_bresp),
        .s0_axi_bvalid       (ram_axi_bvalid),
        .s0_axi_bready       (ram_axi_bready),

        .s0_axi_araddr       (ram_axi_araddr),
        .s0_axi_arvalid      (ram_axi_arvalid),
        .s0_axi_arready      (ram_axi_arready),

        .s0_axi_rdata        (ram_axi_rdata),
        .s0_axi_rresp        (ram_axi_rresp),
        .s0_axi_rvalid       (ram_axi_rvalid),
        .s0_axi_rready       (ram_axi_rready)
    );

    // =========================================================================
    // AXI RAM SLAVE
    // =========================================================================
    AXI_RAM_Slave ram_slave (

        .clk                 (clk),
        .reset                (reset),

        .s_axi_awaddr       (ram_axi_awaddr),
//        .s_axil_awprot       (3'b000),
        .s_axi_awvalid      (ram_axi_awvalid),
        .s_axi_awready      (ram_axi_awready),

        .s_axi_wdata        (ram_axi_wdata),
        .s_axi_wstrb        (ram_axi_wstrb),
        .s_axi_wvalid       (ram_axi_wvalid),
        .s_axi_wready       (ram_axi_wready),

        .s_axi_bresp        (ram_axi_bresp),
        .s_axi_bvalid       (ram_axi_bvalid),
        .s_axi_bready       (ram_axi_bready),

        .s_axi_araddr       (ram_axi_araddr),
//        .s_axil_arprot       (3'b000),
        .s_axi_arvalid      (ram_axi_arvalid),
        .s_axi_arready      (ram_axi_arready),

        .s_axi_rdata        (ram_axi_rdata),
        .s_axi_rresp        (ram_axi_rresp),
        .s_axi_rvalid       (ram_axi_rvalid),
        .s_axi_rready       (ram_axi_rready)
    );
endmodule