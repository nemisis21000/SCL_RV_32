`timescale 1ns / 1ps

module inst_memory(
    input  [31:0] A,
    output reg [31:0] RD
);

always @(*) begin
    case (A[11:2])


//////////////////////////////////////////////////////
////// Enable Global Interrupt
//////////////////////////////////////////////////////
  
////10'd0 : RD = 32'h00800593; // addi x11,x0,8
////10'd1 : RD = 32'h3005A073; // csrrs x0,mstatus,x11

//////////////////// TIMER ENABLE CHECK/////////////////

////////////////////////////////////////////////////////
//////// Enable MTIE
////////////////////////////////////////////////////////

////10'd2 : RD = 32'h08000613; // addi x12,x0,128
////10'd3 : RD = 32'h30462073; // csrrs x0,mie,x12
////               ///////////////////////////
////               ///TIMER DISABLE CHECK//
////               ///////////////////////////


//////////////////////////////////////////////////////
////// Disable MTIE
//////////////////////////////////////////////////////

////10'd2 : RD = 32'h08000613; // addi x12,x0,128
////10'd3 : RD = 32'h30463073; // csrrc x0,mie,x12

//// ///////////////software interrupt enable test /////
 
////// 10'd2 : RD = 32'h00800613; // addi x12,x0,8
//////10'd3 : RD = 32'h30462073; // csrrs x0,mie,x12


////////////////SOFTWARE INTERRUPT DISABLE TEST////
////// 10'd2 : RD = 32'h00800613; // addi x12,x0,8
//////10'd3 : RD = 32'h30463073; // csrrc x0,mie,x12



////////////////EXTERNAL INTERRUPT ENABLE TEST /////////////

//////10'd2 : RD = 32'h00001637; // lui x12,0x1  -> x12=0x1000
//////10'd3 : RD = 32'h80060613; // addi x12,x12,-2048 -> x12=0x800
//////10'd4 : RD = 32'h30462073; // csrrs x0,mie,x12

/////////////////EXTERNAL INTERRUPT DISABLE TEST///////
//////10'd2 : RD = 32'h00001637; // lui x12,0x1  -> x12=0x1000
//////10'd3 : RD = 32'h80060613; // addi x12,x12,-2048 -> x12=0x800
//////10'd4 : RD = 32'h30463073; // csrrc
//////////////////////////////////////////////////////
////// mtvec = 0x40
//////////////////////////////////////////////////////
   
    
////10'd4  : RD = 32'h04000113; // addi x2,x0,64
////10'd5  : RD = 32'h30511073; // csrrw x0,mtvec,x2

//////////////////////////////////////////////////////
////// Read back CSRs
//////////////////////////////////////////////////////

////10'd6  : RD = 32'h300026F3; // csrrs x13,mstatus,x0
////10'd7  : RD = 32'h30402773; // csrrs x14,mie,x0
////10'd8  : RD = 32'h305021F3; // csrrs x3,mtvec,x0

//////////////////////////////////////////////////////
////// Timer base = 0x200
//////////////////////////////////////////////////////

////10'd9  : RD = 32'h20000293; // addi x5,x0,0x200

//////////////////////////////////////////////////////
////// Compare value = 20
//////////////////////////////////////////////////////

////10'd10 : RD = 32'h01400313; // addi x6,x0,20

//////////////////////////////////////////////////////
////// SW x6,8(x5) -> compare register
//////////////////////////////////////////////////////

////10'd11 : RD = 32'h0062A423;

//////////////////////////////////////////////////////
////// Enable timer
//////////////////////////////////////////////////////

////10'd12 : RD = 32'h00100393; // addi x7,x0,1

//////////////////////////////////////////////////////
////// SW x7,4(x5) -> timer enable
//////////////////////////////////////////////////////

////10'd13 : RD = 32'h0072A223;

//////////////////////////////////////////////////////
////// Main program
//////////////////////////////////////////////////////

//////10'd14 : RD = 32'h00100893; // addi x17,x0,1
//////10'd15 : RD = 32'h00200913; // addi x18,x0,2

//////10'd14 : RD = 32'h00000073; // ECALL
//////10'd15 : RD = 32'h00100893; // should never execute

////// 10'd14 : RD = 32'h00100073; // EBREAK
//////10'd15 : RD = 32'h00100893; // should never execute

//////10'd14 : RD = 32'hFFFFFFFF; // Illegal
//////10'd15 : RD = 32'h00100893; // should never execute

////10'd14 : RD = 32'h00200093; // addi x1,x0,2
////10'd15 : RD = 32'h0000A103; // lw x2,0(x1)
//////////////////////////////////////////////////////
////// mtvec = 0x40
////// PC = 0x40 => instruction index 16
//////////////////////////////////////////////////////

//////////////////////////////////////////////////////
////// Interrupt Handler
//////////////////////////////////////////////////////

////10'd16 : RD = 32'h342028F3; // csrrs x17,mcause,x0
////10'd17 : RD = 32'h34102973; // csrrs x18,mepc,x0
////10'd18 : RD = 32'h30200073; // mret
////10'd0 : RD = 32'h04000113; // addi x2,x0,64
////10'd1 : RD = 32'h30511073; // csrrw x0,mtvec,x2

////10'd2 : RD = 32'h00200093; // addi x1,x0,2
////10'd3 : RD = 32'h0000A103; // lw x2,0(x1)

////10'd16 : RD = 32'h342028F3; // csrrs x17,mcause,x0
////10'd17 : RD = 32'h34102973; // csrrs x18,mepc,x0
////10'd18 : RD = 32'h30200073; // mret
////10'd0 : RD = 32'h04000113; // mtvec = 0x40
////10'd1 : RD = 32'h30511073;

////10'd2 : RD = 32'h00000013; // nop
////10'd3 : RD = 32'h00000073; // ecall

////// Handler @ 0x40
////10'd16 : RD = 32'h341028F3; // csrrs x17,mepc,x0
////10'd17 : RD = 32'h30200073; // mret
////10'd0 : RD = 32'h04000113; // mtvec = 0x40
////10'd1 : RD = 32'h30511073;

////10'd2 : RD = 32'h00000073; // ECALL

////10'd3 : RD = 32'h06300A13; // addi x20,x0,99

////// Handler
////10'd16 : RD = 32'h342028F3;
////10'd17 : RD = 32'h30200073;
////////////////////////////////////////////////////
//// mtvec = 0x40
////////////////////////////////////////////////////

//10'd0 : RD = 32'h04000113; // addi x2,x0,64
//10'd1 : RD = 32'h30511073; // csrrw x0,mtvec,x2

////////////////////////////////////////////////////
//// Main Program
////////////////////////////////////////////////////

//10'd2 : RD = 32'h00100893; // addi x17,x0,1

//// Trap occurs here
//10'd3 : RD = 32'h00000073; // ECALL

////// MUST BE FLUSHED
////10'd4 : RD = 32'h06300A13; // addi x20,x0,99

////// Should execute AFTER mret returns
////10'd5 : RD = 32'h00200913; // addi x18,x0,2
////10'd6 : RD = 32'h00300993; // addi x19,x0,3

//10'd4 : RD = 32'h00400C13; // addi x24,x0,4
//10'd5 : RD = 32'h00500C93; // addi x25,x0,5
//10'd6 : RD = 32'h00600D13; // addi x26,x0,6
//10'd7 : RD = 32'h00700D93; // addi x27,x0,7

////////////////////////////////////////////////////
//// Handler @ 0x40
//// PC=0x40 => instruction index 16
////////////////////////////////////////////////////

////10'd16 : RD = 32'h30002AF3; // csrrs x21,mstatus,x0
////10'd17 : RD = 32'h34102B73; // csrrs x22,mepc,x0
////10'd18 : RD = 32'h34202BF3; // csrrs x23,mcause,x0
////10'd19 : RD = 32'h30200073; // mret

//10'd16 : RD = 32'h34102AF3; // csrrs x21,mepc,x0
//10'd17 : RD = 32'h004A8A93; // addi x21,x21,4
//10'd18 : RD = 32'h341A9073; // csrrw x0,mepc,x21
//10'd19 : RD = 32'h30200073; // mret
//default : RD = 32'h00000013;


//10'd0  : RD = 32'h04000113; // addi x2,x0,64
//10'd1  : RD = 32'h30511073; // csrrw x0,mtvec,x2

////////////////////////////////////////////////////
//// MAIN PROGRAM
////////////////////////////////////////////////////

//10'd2  : RD = 32'h00100893;	//addi x17,x0,1

//10'd3  : RD = 32'h00000073; // ECALL

//10'd4  : RD = 32'h34102af3; // csrrs x21,mepc,x0
//10'd5  : RD = 32'h00500C93; // addi x25,x0,5
//10'd6  : RD = 32'h00600D13; // addi x26,x0,6
//10'd7  : RD = 32'h00700D93; // addi x27,x0,7

////////////////////////////////////////////////////
//// HANDLER @ 0x40
////////////////////////////////////////////////////

//10'd16 : RD = 32'h34102AF3; // csrrs x21,mepc,x0
//10'd17 : RD = 32'h004A8A93; // addi x21,x21,4
//10'd18 : RD = 32'h341A9073; // csrrw x0,mepc,x21
//10'd19 : RD = 32'h30200073; // mret

//default : RD = 32'h00000013;

//10'd0  : RD = 32'haaaab2b7; // lui  x5,0xAAAAB
//10'd1  : RD = 32'haaa28293; // addi x5,x5,-1366

//10'd1  : RD = 32'hfff00293; // addi x5,x0,-1

////////////////////////////////////////////////////
//// MAIN PROGRAM
////////////////////////////////////////////////////

//10'd2  : RD = 32'h00502023;	//sw x5,0(x0)

//10'd3  : RD = 32'h00500223; //sb x5,4(x0)
//10'd4  : RD = 32'h005004a3; //sb x5,9(x0)
//10'd5  : RD = 32'h00500723; //sb x5,14(x0)
//10'd6  : RD = 32'h005009a3; //sb x5,19(x0)

//10'd7  : RD = 32'h00501a23; //sh x5,20(x0)
//10'd8 : RD = 32'h00501d23; //sh x5,26(x0)

//10'd9 : RD = 32'h00002f83; //lw x31,0(x0)

//10'd10 : RD = 32'h00001f83; //lh x31,0(x0)
//10'd11 : RD = 32'h00201f83; //lh x31,2(x0)

//10'd12 : RD = 32'h00005f83; //lhu x31, 0(x0)
//10'd13 : RD = 32'h00205f83; //lhu x31, 2(x0)

//10'd14 : RD = 32'h00004f83; //lb x31,0(x0)
//10'd15 : RD = 32'h00104f83; //lb x31,1(x0)
//10'd16 : RD = 32'h00204f83; //lb x31,2(x0)
//10'd17 : RD = 32'h00304f83; //lb x31,3(x0)
//default : RD = 32'h00000013;

//////////////////////////////////////////////////
// SETUP: Set mtvec trap handler at 0x100
//////////////////////////////////////////////////
//10'd0  : RD = 32'h04000113; // addi x2, x0, 64        → x2 = 0x40 (handler addr)
//10'd1  : RD = 32'h30511073; // csrrw x0, mtvec, x2    → mtvec = 0x40

////////////////////////////////////////////////////
//// FILL REGISTER FILE
////////////////////////////////////////////////////
//10'd2  : RD = 32'hAAAAB537; // lui   x10, 0xAAAB0      → x10 = 0xAAAB0000
//10'd3  : RD = 32'hAAA50513; // addi  x10, x10, 0xAAA   → x10 = 0xAAAAAAAA
//10'd4  : RD = 32'hBBBBC5B7; // lui   x11, 0xBBBC0      → x11 = 0xBBBC0000
//10'd5  : RD = 32'hBBB58593; // addi  x11, x11, 0xBBB   → x11 = 0xBBBBBBBB
//10'd6  : RD = 32'hCCCCD637; // lui   x12, 0xCCCD0      → x12 = 0xCCCD0000
//10'd7  : RD = 32'hCCC60613; // addi  x12, x12, 0xCCC   → x12 = 0xCCCCCCCC
//10'd8  : RD = 32'hDDDDE6B7; // lui   x13, 0xDDDE0      → x13 = 0xDDDE0000
//10'd9  : RD = 32'hDDD68693; // addi  x13, x13, 0xDDD   → x13 = 0xDDDDDDDD
//10'd10 : RD = 32'hEEEEF737; // lui   x14, 0xEEEF0      → x14 = 0xEEEF0000
//10'd11 : RD = 32'hEEE70713; // addi  x14, x14, 0xEEE   → x14 = 0xEEEEEEEE
//10'd12 : RD = 32'h00000013; // addi  x00, x00, 0x000   → x15 = 0x00000000
//10'd13 : RD = 32'hFFF00793; // addi  x15, x15, 0xFFF   → x15 = 0xFFFFFFFF
//10'd14 : RD = 32'h12345837; // lui   x16, 0x12345      → x16 = 0x12345000
//10'd15 : RD = 32'h67880813; // addi  x16, x16, 0x678   → x16 = 0x12345678
//10'd16 : RD = 32'hDEADC8b7; // lui   x17, 0xDEAD8      → x17 = 0xDEAD8000
//10'd17 : RD = 32'hEEF88893; // addi  x17, x17, 0xEEF   → x17 = 0xDEADBEEF
//10'd18 : RD = 32'hCAFEC937; // lui   x18, 0xCAFEB      → x18 = 0xCAFEB000
//10'd19 : RD = 32'hABE90913; // addi  x18, x18, 0xABE   → x18 = 0xCAFEBABE
//10'd20 : RD = 32'h00000993; // addi  x19, x0, 0        → x19 = 0x00000000 (base addr)
//10'd21 : RD = 32'h00100A13; // addi  x20, x0, 1        → x20 = 1 (byte offset increment)

////////////////////////////////////////////////////
//// STORE FULL WORDS across memory
//// DMEM base = 0x0000_0000
////////////////////////////////////////////////////
//10'd22 : RD = 32'h00A9A023; // sw  x10, 0(x19)         → mem[0x000] = 0xAAAAAAAA
//10'd23 : RD = 32'h00B9A223; // sw  x11, 4(x19)         → mem[0x004] = 0xBBBBBBBB
//10'd24 : RD = 32'h00C9A423; // sw  x12, 8(x19)         → mem[0x008] = 0xCCCCCCCC
//10'd25 : RD = 32'h00D9A623; // sw  x13, 12(x19)        → mem[0x00C] = 0xDDDDDDDD
//10'd26 : RD = 32'h00E9A823; // sw  x14, 16(x19)        → mem[0x010] = 0xEEEEEEEE
//10'd27 : RD = 32'h00F9AA23; // sw  x15, 20(x19)        → mem[0x014] = 0xFFFFFFFF
//10'd28 : RD = 32'h0109AC23; // sw  x16, 24(x19)        → mem[0x018] = 0x12345678
//10'd29 : RD = 32'h0119AE23; // sw  x17, 28(x19)        → mem[0x01C] = 0xDEADBEEF
//10'd30 : RD = 32'h0329A023; // sw  x18, 32(x19)        → mem[0x020] = 0xCAFEBABE

//// Store at higher addresses in range
//10'd31 : RD = 32'h40000A37; // lui  x20, 0x40000       → x20 = 0x40000000? No - use offset
//// Better: use immediate offset from x19=0
//10'd31 : RD = 32'h7F09A823; // sw  x16, 2032(x19)      → mem[0x7F0] = 0x12345678
//10'd32 : RD = 32'h7F09AA23; // sw  x17, 2036(x19)      → mem[0x7F4] = 0xDEADBEEF
//10'd33 : RD = 32'h7F09AC23; // sw  x18, 2040(x19)      → mem[0x7F8] = 0xCAFEBABE
//10'd34 : RD = 32'h7FC9AE23; // sw  x12, 2044(x19)      → mem[0x7FC] = 0xCCCCCCCC

////////////////////////////////////////////////////
//// LOAD FULL WORDS - verify stored values
////////////////////////////////////////////////////
//10'd35 : RD = 32'h0009A103; // lw  x2,  0(x19)         → x2  should = 0xAAAAAAAA
//10'd36 : RD = 32'h0049A183; // lw  x3,  4(x19)         → x3  should = 0xBBBBBBBB
//10'd37 : RD = 32'h0089A203; // lw  x4,  8(x19)         → x4  should = 0xCCCCCCCC
//10'd38 : RD = 32'h00C9A283; // lw  x5,  12(x19)        → x5  should = 0xDDDDDDDD
//10'd39 : RD = 32'h7F09A303; // lw  x6,  2032(x19)      → x6  should = 0x12345678
//10'd40 : RD = 32'h7F49A383; // lw  x7,  2036(x19)      → x7  should = 0xDEADBEEF
//10'd41 : RD = 32'h7F89A403; // lw  x8,  2040(x19)      → x8  should = 0xCAFEBABE
//10'd42 : RD = 32'h7FC9A483; // lw  x9,  2044(x19)      → x9  should = 0xCCCCCCCC

////////////////////////////////////////////////////
//// STORE HALFWORDS - test partial writes
//// Store lower 16 bits of registers
////////////////////////////////////////////////////
//10'd43 : RD = 32'h11099023; // sh  x16, 256(x19)       → mem[0x100][15:0]  = 0x5678
//10'd44 : RD = 32'h11199123; // sh  x17, 258(x19)       → mem[0x100][31:16] = 0xBEEF
//// Now mem[0x100] = 0xBEEF5678

//10'd45 : RD = 32'h11299223; // sh  x18, 260(x19)       → mem[0x104][15:0]  = 0xBABE
//10'd46 : RD = 32'h10A99323; // sh  x10, 262(x19)       → mem[0x104][31:16] = 0xAAAA
//// Now mem[0x104] = 0xAAAABABE

////////////////////////////////////////////////////
//// STORE BYTES - test single-byte partial writes
////////////////////////////////////////////////////
//10'd47 : RD = 32'h21098023; // sb  x16, 512(x19)       → mem[0x200][7:0]   = 0x78
//10'd48 : RD = 32'h211980A3; // sb  x17, 513(x19)       → mem[0x200][15:8]  = 0xEF
//10'd49 : RD = 32'h21298223; // sb  x18, 514(x19)       → mem[0x200][23:16] = 0xBE
//10'd50 : RD = 32'h213981A3; // sb  x19, 515(x19)       → mem[0x200][31:24] = 0x00
//// Now mem[0x200] = 0x00BEEF78

//10'd51 : RD = 32'h20A98223; // sb  x10, 516(x19)       → mem[0x204][7:0]   = 0xAA
//10'd52 : RD = 32'h20B982A3; // sb  x11, 517(x19)       → mem[0x204][15:8]  = 0xBB
//10'd53 : RD = 32'h20C98323; // sb  x12, 518(x19)       → mem[0x204][23:16] = 0xCC
//10'd54 : RD = 32'h20D983A3; // sb  x13, 519(x19)       → mem[0x204][31:24] = 0xDD
//// Now mem[0x204] = 0xDDCCBBAA

////////////////////////////////////////////////////
//// OVERWRITE BYTES IN PREVIOUSLY STORED WORDS
//// mem[0x000] was 0xAAAAAAAA - change byte 0 to 0xBB
////////////////////////////////////////////////////
//10'd55 : RD = 32'h00B98023; // sb  x11, 0(x19)         → mem[0x000][7:0]   = 0xBB
//// Now mem[0x000] = 0xAAAAABB (RMW test: bytes 1,2,3 must be preserved)

//// mem[0x004] was 0xBBBBBBBB - change upper halfword
//10'd56 : RD = 32'h01099223; // sh  x16, 4(x19)         → mem[0x004][15:0]  = 0x5678
//// Now mem[0x004] = 0xBBBB5678 (RMW test: upper 2 bytes preserved)

//// mem[0x01C] was 0xDEADBEEF - change only byte 2
//10'd57 : RD = 32'h00C9A423; // sw  x12, 8(x19)  (re-store first to known value)
//10'd58 : RD = 32'h00C98623; // sb  x12, 12(x19)        → mem[0x00C][7:0]   = 0xCC
//// Now mem[0x00C] = 0xDDDDDDCC

////////////////////////////////////////////////////
//// LOAD HALFWORDS - signed and unsigned
////////////////////////////////////////////////////
//10'd59 : RD = 32'h10099103; // lh  x2,  256(x19)  → x2  = sign_ext(0x5678) = 0x00005678
//10'd60 : RD = 32'h10299183; // lh  x3,  258(x19)  → x3  = sign_ext(0xBEEF) = 0xFFFFBEEF
//10'd61 : RD = 32'h10099203; // lhu x4,  256(x19)  → x4  = zero_ext(0x5678) = 0x00005678
//10'd62 : RD = 32'h10299283; // lhu x5,  258(x19)  → x5  = zero_ext(0xBEEF) = 0x0000BEEF

//10'd63 : RD = 32'h10499303; // lh  x6,  260(x19)  → x6  = sign_ext(0xBABE) = 0xFFFFBABE
//10'd64 : RD = 32'h10699383; // lh  x7,  262(x19)  → x7  = sign_ext(0xAAAA) = 0xFFFFAAAA
//10'd65 : RD = 32'h10499403; // lhu x8,  260(x19)  → x8  = zero_ext(0xBABE) = 0x0000BABE
//10'd66 : RD = 32'h10699483; // lhu x9,  262(x19)  → x9  = zero_ext(0xAAAA) = 0x0000AAAA

////////////////////////////////////////////////////
//// LOAD BYTES - signed and unsigned
////////////////////////////////////////////////////
//10'd67 : RD = 32'h20098103; // lb  x2,  512(x19)  → x2  = sign_ext(0x78) = 0x00000078
//10'd68 : RD = 32'h20198183; // lb  x3,  513(x19)  → x3  = sign_ext(0xEF) = 0xFFFFFFEF
//10'd69 : RD = 32'h20298203; // lb  x4,  514(x19)  → x4  = sign_ext(0xBE) = 0xFFFFFFBE
//10'd70 : RD = 32'h20398283; // lb  x5,  515(x19)  → x5  = sign_ext(0x00) = 0x00000000

//10'd71 : RD = 32'h20098303; // lbu x6,  512(x19)  → x6  = zero_ext(0x78) = 0x00000078
//10'd72 : RD = 32'h20198383; // lbu x7,  513(x19)  → x7  = zero_ext(0xEF) = 0x000000EF
//10'd73 : RD = 32'h20298403; // lbu x8,  514(x19)  → x8  = zero_ext(0xBE) = 0x000000BE
//10'd74 : RD = 32'h20398483; // lbu x9,  515(x19)  → x9  = zero_ext(0x00) = 0x00000000

//10'd75 : RD = 32'h20498503; // lbu x10, 516(x19)  → x10 = 0x000000AA
//10'd76 : RD = 32'h20598583; // lbu x11, 517(x19)  → x11 = 0x000000BB
//10'd77 : RD = 32'h20698603; // lbu x12, 518(x19)  → x12 = 0x000000CC
//10'd78 : RD = 32'h20798683; // lbu x13, 519(x19)  → x13 = 0x000000DD

////////////////////////////////////////////////////
//// VERIFY RMW - load back overwritten words
////////////////////////////////////////////////////
//10'd79 : RD = 32'h0009A703; // lw  x14, 0(x19)    → x14 = 0xAAAAAAAABB → should be 0xAAAAABB
//// (check byte 0 changed, bytes 1-3 preserved from RMW)

//10'd80 : RD = 32'h0049A783; // lw  x15, 4(x19)    → x15 = should be 0xBBBB5678
//// (check lower half changed, upper half preserved)

//10'd81 : RD = 32'h00C9A803; // lw  x16, 12(x19)   → x16 = should be 0xDDDDDDCC
//// (check byte 0 changed from 0xDD to 0xCC, rest preserved)
10'd0  : RD = 32'h300000B7; // lui  x1, 0x30000       → x1 = 0x30000000 (SPI base addr)
10'd1  : RD = 32'h00400113; // addi x2, x0, 4         → x2 = 0x00000004 (CLKDIV value)
10'd2  : RD = 32'h0020A223; // sw   x2, 4(x1)         → mem[0x30000004]=4, watch spi_clk_div_valid pulse HIGH 1 cycle
10'd3  : RD = 32'h00080137; // lui  x2, 0x80          → x2 = 0x00080000 (SPILEN: data_len=8)
10'd4  : RD = 32'h0020A823; // sw   x2, 16(x1)        → mem[0x30000010]=0x00080000, spi_data_len becomes 8 internally
10'd5  : RD = 32'hAB000137; // lui  x2, 0xAB000       → x2 = 0xAB000000 (byte to send, left-justified)
10'd6  : RD = 32'h0020AC23; // sw   x2, 24(x1)        → mem[0x30000018]=0xAB000000, TXFIFO push, u_txfifo.elements: 0→1
10'd7  : RD = 32'h10200113; // addi x2, x0, 0x102     → x2 = 0x00000102 (STATUS: spi_wr=1, csreg=CS0)
10'd8  : RD = 32'h0020A023; // sw   x2, 0(x1)         → mem[0x30000000]=0x102, THIS IS THE TRIGGER: spi_wr pulses HIGH,
                            //                               spi_csn0 drops LOW, spi_clk starts toggling, state: IDLE→DATA_TX
10'd9  : RD = 32'h0000A183; // lw   x3, 0(x1)         → x3 = current STATUS readback (poll loop start)
10'd10 : RD = 32'h0011F193; // andi x3, x3, 1         → x3 = STATUS[0] only (the IDLE bit)
10'd11 : RD = 32'hFE018CE3; // beq  x3, x0, -8        → loop back to 10'd9 while x3==0 (not idle yet)
//10'd12 : RD = 32'h0000006F; // jal  x0, 0             → halt (infinite self-loop, reached once x3!=0 i.e. STATUS[0]=1 again)
//////////////////////////////////////////////////
//end of test
//////////////////////////////////////////////////

default : RD = 32'h00000013; // nop (addi x0,x0,0)
endcase

end

endmodule
