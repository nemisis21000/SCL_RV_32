module hazard_unit(

input logic rst,

input logic RegWriteM,
input logic RegWriteW,

input logic [4:0] RdM,
input logic [4:0] RdW,

input logic [4:0] Rs1E,
input logic [4:0] Rs2E,

input logic [4:0] Rs1D,
input logic [4:0] Rs2D,

input logic [4:0] RdE,

input logic [1:0] ResultSrcE,

input logic PcSrcE,

////////////////////
output logic StallF,
output logic StallD,
output logic FlushE,
output logic FlushD,

output logic [1:0] ForwardAE,
output logic [1:0] ForwardBE,

output logic lw_stall
//input logic mem_busy

);
//////////////

//////////////
//////////////////////////////////////////////////////
// FORWARDING
//////////////////////////////////////////////////////

assign ForwardAE =
    (!rst) ? 2'b00 :

    ((RegWriteM) && (RdM != 0) && (RdM == Rs1E)) ? 2'b10 :

    ((RegWriteW) && (RdW != 0) && (RdW == Rs1E)) ? 2'b01 :

    2'b00;

assign ForwardBE =
    (!rst) ? 2'b00 :

    ((RegWriteM) && (RdM != 0) && (RdM == Rs2E)) ? 2'b10 :

    ((RegWriteW) && (RdW != 0) && (RdW == Rs2E)) ? 2'b01 :

    2'b00;
/////////////////



///////////////////////////
//////////////////////////////////////////////////////
// LOAD USE HAZARD
//////////////////////////////////////////////////////

assign lw_stall =
       (ResultSrcE == 2'b01) &&
       (RdE != 5'b00000) &&
       ((RdE == Rs1D) || (RdE == Rs2D));

//////////////////////////////////////////////////////
// STALLS
//////////////////////////////////////////////////////

assign StallF = lw_stall;
assign StallD = lw_stall;

//assign StallF = lw_stall | mem_busy;
//assign StallD = lw_stall | mem_busy;

//////////////////////////////////////////////////////
// FLUSHES
//////////////////////////////////////////////////////

//assign FlushE = PcSrcE;
//assign FlushD = PcSrcE  ;
//assign FlushE = lw_stall | PcSrcE |trap_taken;
assign FlushD = PcSrcE;

assign FlushE = lw_stall | PcSrcE;
endmodule