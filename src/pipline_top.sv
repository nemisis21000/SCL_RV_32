
`timescale 1ns / 1ps

module pipeline_top(
    input  logic        clk,
    input  logic        rst,
    output logic [31:0] debug_out,

//    //////// APB interface ////////
//    output logic [31:0] ALUResultM,
//    output logic [31:0] WriteDataM,
//    output logic        MemWriteM,
//    output logic [2:0]  funct3M,
//    input  logic [31:0] ReadDataM,

//    output logic        MemReadM,
//    input  logic        pready,
//   input logic mem_done,

    //AXI
    output logic        MEM_WRITE,
    output logic        MEM_READ,
//    output         MEM_INSTR, useless i think
    input  logic        MEM_READY,
//    output  [1:0] MEM_ERROR, have to add
    output logic [31:0] MEM_ADDR,
    output logic [31:0] MEM_WDATA,
    output logic [ 3:0] MEM_WSTRB,
    input  logic [31:0] MEM_RDATA
);

////////////////////////////////////////////////////////////
// PIPELINE WIRE DECLARATIONS
////////////////////////////////////////////////////////////

logic [31:0] InstrD, PcD, PcPlus4D;

logic        RegWriteE;
logic [1:0]  ResultSrcE;
logic        MemWriteE, MemReadE;
logic        jumpE, BranchE;
logic [3:0]  ALUControlE;
logic [1:0]  ALUSrcAE;
logic        ALUSrcBE;
logic [31:0] RD1E, RD2E, PCE;
logic [4:0]  RdE, RS1E, RS2E;
logic [31:0] ImmExtendE, PcPlus4E;
logic [2:0]  funct3E;
logic        MemWriteM, MemReadM;
logic [2:0]  funct3M;
logic        RegWriteM;
logic [1:0]  ResultSrcM;
logic [4:0]  RdM;
logic [31:0] PcPlus4M;
logic [31:0] PcTargetE;
logic        PcSrcE;

logic        RegWriteW;
logic [1:0]  ResultSrcW;
logic [31:0] ALUResultW, ReadDataW;
logic [31:0] WriteDataM;
logic [4:0]  RdW;
logic [31:0] PcPlus4W;
logic [31:0] ResultW;
logic [31:0] ALUResultM;
logic [1:0]  ForwardAE, ForwardBE;
logic [4:0]  Rs1D, Rs2D;
logic        lw_stall;
logic        bus_stall;
////////////////////////////////////////////////////////////
// HAZARD UNIT RAW OUTPUTS
// These are the pure hazard signals - NOT yet combined
// with bus_stall. Combining happens below before use.
////////////////////////////////////////////////////////////

logic StallF_hz;   // raw stall from hazard unit
logic StallD_hz;   // raw stall from hazard unit
logic FlushD_hz;   // raw flush from hazard unit
logic FlushE_hz;   // raw flush from hazard unit

////////////////////////////////////////////////////////////
// COMBINED STALL/FLUSH SIGNALS
// bus_stall ORed with hazard stalls AFTER the hazard unit.
// This is the fix - expressions cannot go on output ports.
////////////////////////////////////////////////////////////

logic StallF_final;
logic StallD_final;
logic FlushD_final;
logic FlushE_final;

assign StallF_final = StallF_hz | bus_stall;
assign StallD_final = StallD_hz | bus_stall;
assign FlushD_final = FlushD_hz;               // flush not gated by bus_stall
assign FlushE_final = FlushE_hz & ~bus_stall;  // don't flush mid-APB-txn


////////////////////////////////////////////////////////////
// FETCH
////////////////////////////////////////////////////////////

IF fetch(
    .clk(clk),
    .rst(rst),
    .PcSrcE(PcSrcE),
    .StallF(StallF_final),
    .PcTargetE(PcTargetE),
    .InstrD(InstrD),
    .PcD(PcD),
    .PcPlus4D(PcPlus4D)
);

////////////////////////////////////////////////////////////
// DECODE
////////////////////////////////////////////////////////////

decode_stage decode(
    .clk(clk),
    .rst(rst),
    .RegWriteW(RegWriteW),
    .InstrD(InstrD),
    .PCD(PcD),
    .PcPlus4D(PcPlus4D),
    .ResultW(ResultW),
    .RdW(RdW),
    .StallD(StallD_final),
    .FlushD(FlushD_final),
    .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),
    .jumpE(jumpE),
    .BranchE(BranchE),
    .ALUControlE(ALUControlE),
    .ALUSrcAE(ALUSrcAE),
    .ALUSrcBE(ALUSrcBE),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .RdE(RdE),
    .RS1E(RS1E),
    .RS2E(RS2E),
    .ImmExtendE(ImmExtendE),
    .PcPlus4E(PcPlus4E),
    .RS1D(Rs1D),
    .RS2D(Rs2D),
    .funct3E(funct3E),
    .MemReadE(MemReadE)

);

////////////////////////////////////////////////////////////
// EXECUTE
////////////////////////////////////////////////////////////

Execute_stage execute(
    .clk(clk),
    .rst(rst),
    .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),
    .jumpE(jumpE),
    .BranchE(BranchE),
    .ALUControlE(ALUControlE),
    .ALUSrcAE(ALUSrcAE),
    .ALUSrcBE(ALUSrcBE),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .RdE(RdE),
    .ImmExtendE(ImmExtendE),
    .PcPlus4E(PcPlus4E),
    .ResultW(ResultW),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .FlushE(FlushE_final),
    .StallM(bus_stall),
    .funct3E(funct3E), 
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .MemWriteM(MemWriteM),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .RdM(RdM),
    .PcPlus4M(PcPlus4M),
    .PcTargetE(PcTargetE),
    .PcSrcE(PcSrcE),
    .ALUResultM_forward(ALUResultM),
    .funct3M(funct3M),
    .MemReadM(MemReadM),
    .MemReadE(MemReadE)
);

////////////////////////////////////////////////////////////
// MEMORY STAGE
////////////////////////////////////////////////////////////

data_mem_stage memory_stage(
    .clk         (         clk),
    .rst         (         rst),
    .RegWriteM   (   RegWriteM),
    .ResultSrcM  (  ResultSrcM),
    .MemWriteM   (   MemWriteM),
    .MemReadM    (    MemReadM),
    .ALUResultM  (  ALUResultM),
    .WriteDataM  (  WriteDataM),
    .funct3M     (     funct3M),
    .RdM         (         RdM),
    .PcPlus4M    (    PcPlus4M),
    .ReadDataW   (   ReadDataW),
    .RegWriteW   (   RegWriteW),
    .ResultSrcW  (  ResultSrcW),
    .ALUResultW  (  ALUResultW),
    .RdW         (         RdW),
    .PcPlus4W    (    PcPlus4W),
    .data_bus_stall (   bus_stall),
    
    //AXI
    .MEM_WRITE   (   MEM_WRITE),
    .MEM_READ    (    MEM_READ),
    .MEM_READY   (   MEM_READY),
    .MEM_ADDR    (    MEM_ADDR),
    .MEM_WDATA   (   MEM_WDATA),
    .MEM_WSTRB   (   MEM_WSTRB),
    .MEM_RDATA   (   MEM_RDATA)
);  

////////////////////////////////////////////////////////////
// WRITE BACK
////////////////////////////////////////////////////////////

write_back_stage wb(
    .ResultSrcW(ResultSrcW),
    .ALUResultW(ALUResultW),
    .ReadDataW(ReadDataW),
    .PcPlus4W(PcPlus4W),
    .ResultW(ResultW)
);

////////////////////////////////////////////////////////////
// HAZARD UNIT
// All four outputs are RAW signals - no expressions here.
// Combining with bus_stall is done via assign above.
////////////////////////////////////////////////////////////

hazard_unit ha(
    .rst(rst),
    .RegWriteM(RegWriteM),
    .RegWriteW(RegWriteW),
    .RdM(RdM),
    .RdW(RdW),
    .Rs1E(RS1E),
    .Rs2E(RS2E),
    .Rs1D(Rs1D),
    .Rs2D(Rs2D),
    .ResultSrcE(ResultSrcE),
    .RdE(RdE),
    .PcSrcE(PcSrcE),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .StallF(StallF_hz),      // raw output - no expression
    .StallD(StallD_hz),      // raw output - no expression
    .FlushD(FlushD_hz),      // raw output - no expression
    .FlushE(FlushE_hz),      // raw output - no expression
    .lw_stall(lw_stall)
);

////////////////////////////////////////////////////////////
// DEBUG
////////////////////////////////////////////////////////////

assign debug_out = ResultW;

endmodule
