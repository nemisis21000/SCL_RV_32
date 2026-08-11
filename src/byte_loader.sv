// Byte-wide boot loader for instruction memory only. Assembles 4 incoming
// bytes (little-endian: first byte = bits [7:0]) into a 32-bit word and
// writes it into instruction memory, auto-incrementing the write address.
// Data memory is untouched by this loader - filled entirely by the
// program itself once running, via the existing AXI4-Lite path.

module byte_loader #(
    parameter int ADDR_WIDTH = 11   // 1024 words = 4KB instruction memory subject to change
)(
    // ---- external pins ----
    input  logic       ext_clk,
    input  logic       ext_rst_n,    // synchronous active-low reset, raw pin
    input  logic       load_mode,    // 1 = boot-load mode, 0 = run mode    both rst and load can cause the core to reset
    input  logic [7:0] data_in,
    input  logic       byte_strobe,  // pulse: capture data_in this cycle
//    output logic       load_ready,   // high while loader can accept a byte

    output logic       core_rst_n,  // ext_rst_n gated by load_mode

    // ---- instruction memory write port ----
    output logic [ADDR_WIDTH-1:0] instr_waddr,
    output logic [31:0]           instr_wdata,
    output logic                  instr_we
);

    assign core_rst_n = ext_rst_n & ~load_mode; //both rst and load can cause the core to reset independentally

    // Single-cycle capture -> always ready while in load mode.
    //Will depend on the macro
//    assign load_ready = load_mode;

    // ---- byte assembler + address counter ----
    logic [1:0]            byte_cnt;      // which byte of the current word (0..3)
    logic [23:0]           shift_bytes;   // previously captured bytes of current word
    logic [ADDR_WIDTH-1:0] addr_cnt;

    always_ff @(posedge ext_clk or negedge ext_rst_n) begin
        if (!ext_rst_n) begin
            byte_cnt    <= '0;
            shift_bytes <= '0;
            addr_cnt    <= '0;
            instr_we    <= 1'b0;
            instr_waddr <= '0;
            instr_wdata <= '0;
        end else begin
            instr_we <= 1'b0;   // single-cycle write pulse, cleared by default

            if (!load_mode) begin
                // returning to run mode re-arms the loader for next time
                byte_cnt    <= '0;
                shift_bytes <= '0;
                addr_cnt    <= '0;

            end else if (byte_strobe) begin
                if (byte_cnt == 2'd3) begin
                    // 4th byte completes the word: assemble and write
                    byte_cnt    <= '0;
                    instr_wdata <= {data_in, shift_bytes};
                    instr_waddr <= addr_cnt;
                    instr_we    <= 1'b1;
                    addr_cnt    <= addr_cnt + 4'h4; //!!!This is assuming a 32 bits register macro
                end else begin
                    shift_bytes <= {data_in, shift_bytes[23:8]};
                    byte_cnt    <= byte_cnt + 1'b1;
                end
            end
        end
    end

endmodule