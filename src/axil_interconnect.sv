// ==========================================================
// AXI4-Lite Interconnect
// Single Master -> Multi Slave (4 Slaves)
//
// Memory Map
// ----------------------------------------------------------
// Slave 0: RAM
// Slave 1: AXI_to_APB4_Bridge
// ==========================================================

module AXI_Interconnect #(

    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)
(
    input                       clk,
    input                       reset,

    // ===============================
    // AXI MASTER SIDE
    // ===============================

    // WRITE ADDRESS CHANNEL
    input  logic [ADDR_WIDTH - 1:0]   m_axi_awaddr,
    input  logic                      m_axi_awvalid,
    output logic                      m_axi_awready,

    // WRITE DATA CHANNEL
    input  logic [DATA_WIDTH - 1:0]   m_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0]   m_axi_wstrb,
    input  logic                      m_axi_wvalid,
    output logic                      m_axi_wready,

    // WRITE RESPONSE CHANNEL
    output logic [1:0]                m_axi_bresp,
    output logic                      m_axi_bvalid,
    input  logic                      m_axi_bready,

    // READ ADDRESS CHANNEL
    input  logic [ADDR_WIDTH - 1:0]   m_axi_araddr,
    input  logic                      m_axi_arvalid,
    output logic                      m_axi_arready,

    // READ DATA CHANNEL
    output logic [DATA_WIDTH - 1:0]   m_axi_rdata,
    output logic [1:0]                m_axi_rresp,
    output logic                      m_axi_rvalid,
    input  logic                      m_axi_rready,

    // ===============================
    // AXI SLAVE 0: RAM
    // ===============================
    output logic [ADDR_WIDTH - 1:0]   s0_axi_awaddr,
    output logic                      s0_axi_awvalid,
    input  logic                      s0_axi_awready,

    output logic [DATA_WIDTH - 1:0]   s0_axi_wdata,
    output logic [DATA_WIDTH/8-1:0]   s0_axi_wstrb,
    output logic                      s0_axi_wvalid,
    input  logic                      s0_axi_wready,

    input  logic [1:0]                s0_axi_bresp,
    input  logic                      s0_axi_bvalid,
    output logic                      s0_axi_bready,

    output logic [ADDR_WIDTH - 1:0]   s0_axi_araddr,
    output logic                      s0_axi_arvalid,
    input  logic                      s0_axi_arready,

    input  logic [DATA_WIDTH - 1:0]   s0_axi_rdata,
    input  logic [1:0]                s0_axi_rresp,
    input  logic                      s0_axi_rvalid,
    output logic                      s0_axi_rready,

    // ===============================
    // AXI SLAVE 1: APB
    // ===============================
    output logic [ADDR_WIDTH - 1:0]   s1_axi_awaddr,
    output logic                      s1_axi_awvalid,
    input  logic                      s1_axi_awready,

    output logic [DATA_WIDTH - 1:0]   s1_axi_wdata,
    output logic [DATA_WIDTH/8-1:0]   s1_axi_wstrb,
    output logic                      s1_axi_wvalid,
    input  logic                      s1_axi_wready,

    input  logic [1:0]                s1_axi_bresp,
    input  logic                      s1_axi_bvalid,
    output logic                      s1_axi_bready,

    output logic [ADDR_WIDTH - 1:0]   s1_axi_araddr,
    output logic                      s1_axi_arvalid,
    input  logic                      s1_axi_arready,

    input  logic [DATA_WIDTH - 1:0]   s1_axi_rdata,
    input  logic [1:0]                s1_axi_rresp,
    input  logic                      s1_axi_rvalid,
    output logic                      s1_axi_rready
);

    // ==========================================================
    // MEMORY MAP
    // ==========================================================
    localparam RAM_BASE  = 32'h0000_0000;
    localparam RAM_SIZE  = 32'h0000_1000;
    localparam RAM_END   = RAM_BASE + RAM_SIZE - 1;

    localparam SPI_BASE = 32'h1000_0000;
    localparam SPI_SIZE = 32'h0000_0100;
    localparam SPI_END  = SPI_BASE + SPI_SIZE - 1;

    localparam UART_BASE = 32'h2000_0000;
    localparam UART_SIZE = 32'h0000_0100;
    localparam UART_END  = UART_BASE + UART_SIZE - 1;


    // Slave ID encoding
    localparam SEL_RAM  = 1'd0;
    localparam SEL_APB  = 1'd1;

    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    // ==========================================================
    // ADDRESS DECODE - combinational, used only during handshake
    // ==========================================================
    logic dec_ram_write;
    logic dec_spi_write;
    logic dec_uart_write;
    logic dec_apb_write;
    logic dec_hit_write;
    
    logic dec_ram_read;
    logic dec_spi_read;
    logic dec_uart_read;
    logic dec_apb_read;
    logic dec_hit_read;
    
    
    assign dec_ram_write  = (m_axi_awaddr >= RAM_BASE)  && (m_axi_awaddr <= RAM_END);
    assign dec_spi_write = (m_axi_awaddr >= SPI_BASE) && (m_axi_awaddr <= SPI_END);
    assign dec_uart_write = (m_axi_awaddr >= UART_BASE) && (m_axi_awaddr <= UART_END);
    assign dec_apb_write  = (dec_spi_write) || (dec_uart_write);
    assign dec_hit_write  = dec_ram_write | dec_apb_write;

    assign dec_ram_read  = (m_axi_araddr >= RAM_BASE)  && (m_axi_araddr <= RAM_END);
    assign dec_spi_read = (m_axi_araddr >= SPI_BASE) && (m_axi_araddr <= SPI_END);
    assign dec_uart_read = (m_axi_araddr >= UART_BASE) && (m_axi_araddr <= UART_END);
    assign dec_apb_read  = (dec_spi_read) || (dec_uart_read);
    assign dec_hit_read  = dec_ram_read | dec_apb_read;

    // ==========================================================
    // WRITE SEL REGISTER
    // Lock slave selection at the AW handshake
    // Release the lock after B handshake
    // ensures the W channel and B channel are routed to the correct slave
    // Even if the master changes/deasserts AWADDR after the handshake.
    // ==========================================================
    logic sel_write_reg;    // Selected Slave
    logic sel_write_lock;   // 1 = write transaction is in progress
    logic sel_write_err;    // 1 = Address miss -> return SLVERR
    logic dec_write_sel;
    // Slave index determined during the AW handshake
    assign dec_write_sel = dec_ram_write  ? SEL_RAM  :
                           dec_apb_write  ? SEL_APB  : SEL_RAM;

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            sel_write_reg  <= SEL_RAM;
            sel_write_lock <= 1'b0;
            sel_write_err  <= 1'b0;
        end
        else begin
            // Lock on the AW handshake
            if (!sel_write_lock && m_axi_awvalid && m_axi_awready) begin
                sel_write_reg  <= dec_write_sel;
                sel_write_err  <= !dec_hit_write;   // address miss
                sel_write_lock <= 1'b1;
            end

            // Release after the B handshake
            if (m_axi_bvalid && m_axi_bready) begin
                sel_write_lock <= 1'b0;
                sel_write_err  <= 1'b0;
            end
        end
    end

    // Helper: currently selected write slave
    // Gate with !sel_write_err so an address miss (default SEL_RAM)
    // does not get routed to the wrong slave.
    logic sel_w_ram;
    logic sel_w_apb ;
    
    
    assign sel_w_ram  = sel_write_lock && (sel_write_reg == SEL_RAM)  && !sel_write_err;
    assign sel_w_apb  = sel_write_lock && (sel_write_reg == SEL_APB)  && !sel_write_err;

    // ==========================================================
    // READ SEL REGISTER
    // Lock the slave selection at the AR handshake.
    // Release after the R handshake.
    // ==========================================================
    logic sel_read_reg;
    logic sel_read_lock;
    logic sel_read_err;
    logic dec_read_sel;
    
    assign dec_read_sel = dec_ram_read   ? SEL_RAM  :
                          dec_apb_read   ? SEL_APB  : SEL_RAM;
         

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            sel_read_reg  <= SEL_RAM;
            sel_read_lock <= 1'b0;
            sel_read_err  <= 1'b0;
        end
        else begin
            // Lock on the AR handshake
            if (!sel_read_lock && m_axi_arvalid && m_axi_arready) begin
                sel_read_reg  <= dec_read_sel;
                sel_read_err  <= !dec_hit_read;
                sel_read_lock <= 1'b1;
            end

            // Release after the R handshake
            if (m_axi_rvalid && m_axi_rready) begin
                sel_read_lock <= 1'b0;
                sel_read_err  <= 1'b0;
            end
        end
    end

    // Helper: currently selected read slave
    // Gate with !sel_read_err so an address miss (default SEL_RAM)
    // does not get routed to the wrong slave.
    logic sel_r_ram;
    logic sel_r_apb;
    
    assign sel_r_ram  = sel_read_lock && (sel_read_reg == SEL_RAM)  && !sel_read_err;
    assign sel_r_apb  = sel_read_lock && (sel_read_reg == SEL_APB)  && !sel_read_err;

    // ==========================================================
    // When the address does not match any slave,
    // the error slave generates the response itself.
    //
    // It asserts BVALID with SLVERR after
    // both the AW and W handshakes have completed.
    // ==========================================================
    logic err_aw_done;    // Received an AW handshake for an invalid address
    logic err_w_done;     // Received a W handshake for an invalid address
    logic err_bvalid;     // Error slave is asserting BVALID

    logic dec_err_now;

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            err_aw_done <= 1'b0;
            err_w_done  <= 1'b0;
            err_bvalid  <= 1'b0;
        end
        else begin
            // AW handshake with an address miss
            if (!sel_write_lock && m_axi_awvalid && m_axi_awready && !dec_hit_write)
                err_aw_done <= 1'b1;

            // W handshake
            // Use err_aw_done OR dec_err_now to ensure this belongs
            // to an address-miss transaction.
            //
            // dec_err_now handles the case where the master sends
            // AW and W in the same cycle with an invalid address.
            //
            // err_aw_done has not yet been registered in that cycle,
            // so dec_err_now provides a bypass.
            if ((err_aw_done || dec_err_now) && m_axi_wvalid && m_axi_wready)
                err_w_done <= 1'b1;

            // Both AW and W completed -> assert BVALID
            if (err_aw_done && err_w_done && !err_bvalid)
                err_bvalid <= 1'b1;

            // B handshake
            if (err_bvalid && m_axi_bready) begin
                err_bvalid  <= 1'b0;
                err_aw_done <= 1'b0;
                err_w_done  <= 1'b0;
            end
        end
    end

    // ==========================================================
    // When the address does not match any slave,
    // the error slave generates
    // RVALID with an SLVERR response.
    // ==========================================================
    logic err_ar_done;
    logic err_rvalid;

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            err_ar_done <= 1'b0;
            err_rvalid  <= 1'b0;
        end
        else begin
            if (!sel_read_lock && m_axi_arvalid && m_axi_arready && !dec_hit_read)
                err_ar_done <= 1'b1;

            if (err_ar_done && !err_rvalid)
                err_rvalid <= 1'b1;

            if (err_rvalid && m_axi_rready) begin
                err_rvalid  <= 1'b0;
                err_ar_done <= 1'b0;
            end
        end
    end

    // ==========================================================
    // WRITE ADDRESS CHANNEL → Slaves
    // AWREADY must be returned before the write lock is taken
    // (i.e., while no write transaction is active).
    // ==========================================================

    // Forward AW only when there is no active write transaction
    // and the address is valid.
    assign s0_axi_awaddr  = m_axi_awaddr;
    assign s1_axi_awaddr  = m_axi_awaddr;

    assign s0_axi_awvalid = m_axi_awvalid & dec_ram_write  & !sel_write_lock;
    assign s1_axi_awvalid = m_axi_awvalid & dec_apb_write  & !sel_write_lock;

    // AWREADY:
    // Return the selected slave's AWREADY while unlocked.
    // Return 1 immediately for an address miss (absorb the transaction).
    assign m_axi_awready  = !sel_write_lock && (
                                dec_ram_write  ? s0_axi_awready :
                                dec_apb_write  ? s1_axi_awready :
                                                 1'b1            // miss: absorb
                            );

    // ==========================================================
    // WRITE DATA CHANNEL → Slaves
    // Route according to the locked write slave,
    // not according to AWADDR.
    // ==========================================================

    // ==========================================================
    // SAME-CYCLE AW/W SUPPORT
    // AXI4-Lite allows AW and W
    // to be transferred in the same cycle.
    // ==========================================================

    logic aw_handshake;

    assign aw_handshake = m_axi_awvalid && m_axi_awready;

    assign dec_err_now  = aw_handshake && !dec_hit_write;

    // Only bypass during the AW handshake cycle.
    logic dec_w_ram_now;
    logic dec_w_apb_now;
    
    assign dec_w_ram_now  = aw_handshake && dec_ram_write;

    assign dec_w_apb_now  = aw_handshake && dec_apb_write;


    assign s0_axi_wdata  = m_axi_wdata;
    assign s0_axi_wstrb  = m_axi_wstrb;
    assign s1_axi_wdata  = m_axi_wdata;
    assign s1_axi_wstrb  = m_axi_wstrb;

    // Forward WVALID to the locked slave.
    //
    // For an address miss:
    // err_aw_done has already been set,
    // so forward WVALID and return WREADY=1
    // to absorb the write data.
    assign s0_axi_wvalid = m_axi_wvalid & (sel_w_ram  | dec_w_ram_now);
    assign s1_axi_wvalid = m_axi_wvalid & (sel_w_apb  | dec_w_apb_now);
    
    // WREADY:
    // Return the locked slave's WREADY.
    //
    // Return WREADY=1 for an address miss
    // to absorb the write data.
    
    assign m_axi_wready  =
    // locked transaction
    sel_w_ram      ? s0_axi_wready :
    sel_w_apb      ? s1_axi_wready :

    // same-cycle AW/W support
    dec_w_ram_now  ? s0_axi_wready :
    dec_w_apb_now  ? s1_axi_wready :

    // error slave
    sel_write_err ? 1'b1 :
    dec_err_now   ? 1'b1 :
                    1'b0;

    // ==========================================================
    // WRITE RESPONSE CHANNEL ← Slaves
    // BVALID defaults to 0.
    // Assert when either the selected slave
    // or the error slave returns a response.
    // ==========================================================
    assign s0_axi_bready = m_axi_bready & sel_w_ram;
    assign s1_axi_bready = m_axi_bready & sel_w_apb;
    assign m_axi_bvalid  = sel_w_ram    ? s0_axi_bvalid :
                           sel_w_apb    ? s1_axi_bvalid :
                           err_bvalid   ? 1'b1          :   // error slave
                                          1'b0;             // No phantom response

    assign m_axi_bresp   = sel_w_ram    ? s0_axi_bresp  :
                           sel_w_apb    ? s1_axi_bresp  :
                           err_bvalid   ? RESP_SLVERR   :
                                          RESP_OKAY;

    // ==========================================================
    // READ ADDRESS CHANNEL → Slaves
    // ==========================================================
    assign s0_axi_araddr  = m_axi_araddr;
    assign s1_axi_araddr  = m_axi_araddr;

    assign s0_axi_arvalid = m_axi_arvalid & dec_ram_read  & !sel_read_lock;
    assign s1_axi_arvalid = m_axi_arvalid & dec_apb_read  & !sel_read_lock;

    assign m_axi_arready  = !sel_read_lock && (
                                dec_ram_read  ? s0_axi_arready :
                                dec_apb_read  ? s1_axi_arready :
                                                1'b1             // miss: absorb
                            );

    // ==========================================================
    // READ DATA CHANNEL ← Slaves
    // RVALID defaults to 0.
    // Route according to the locked read slave.
    // ==========================================================
    assign s0_axi_rready = m_axi_rready & sel_r_ram;
    assign s1_axi_rready = m_axi_rready & sel_r_apb;

    assign m_axi_rvalid  = sel_r_ram    ? s0_axi_rvalid  :
                           sel_r_apb    ? s1_axi_rvalid  :
                           err_rvalid   ? 1'b1           :   // error slave
                                          1'b0;              // No phantom response

    assign m_axi_rresp   = sel_r_ram    ? s0_axi_rresp   :
                           sel_r_apb    ? s1_axi_rresp   :
                           err_rvalid   ? RESP_SLVERR    :
                                          RESP_OKAY;

    assign m_axi_rdata   = sel_r_ram    ? s0_axi_rdata   :
                           sel_r_apb    ? s1_axi_rdata   :
                                          {DATA_WIDTH{1'b0}};

endmodule