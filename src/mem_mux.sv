// Arbitrates a single-port memory's address/we/wdata inputs between the
// boot loader and the core, based on load_mode. Since the core is held
// in reset for the full duration of load_mode, there's never real
// contention -- this is just a clean mux, not real arbitration logic.
//
// Instantiate one of these per memory (instruction memory, data memory).

module mem_port_mux #(
    parameter int ADDR_WIDTH = 11,
    parameter int DATA_WIDTH = 32
)(
    input  logic                    load_mode,

    // loader side
    input  logic [ADDR_WIDTH-1:0]   ldr_addr,
    input  logic                    ldr_we,
    input  logic [DATA_WIDTH-1:0]   ldr_wdata,

    // core side (fetch-stage read port for instr mem)
    input  logic [ADDR_WIDTH-1:0]   core_addr,

    // memory-facing signals -> wire these to the actual SRAM macro
    output logic [ADDR_WIDTH-1:0]   mem_addr,
    output logic                    mem_we,
    output logic [DATA_WIDTH-1:0]   mem_wdata
);

    assign mem_addr  = load_mode ? ldr_addr  : core_addr;
    assign mem_we    = load_mode ? ldr_we    : 1'b0;
    assign mem_wdata = ldr_wdata;

endmodule