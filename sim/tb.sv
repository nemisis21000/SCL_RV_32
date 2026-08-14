// tb_soc_top.sv
//
// Loads a small RV32I test program (exercises a RAW hazard: addi x1,
// addi x2, then add x3,x1,x2 immediately after) via the byte loader,
// then releases run mode and lets the core execute.
//
// NOTE: soc_top currently has no observability output port, so this TB
// cannot self-check register/memory results on its own. It dumps
// waveforms for manual inspection in GTKWave/Verdi, and leaves a
// clearly marked hook where you can add hierarchical references into
// `dut.cpu.<your_regfile_signal>` once you tell me (or look up) the
// actual internal signal names, or better: wire up a real output bus.

`timescale 1ns / 1ps

module tb_soc_top;

    // ---- clock / reset ----
    logic clk;
    logic rst;          // active-low
    logic load_mode;
    logic [7:0] data_in;
    logic byte_strobe;
    logic [31:0] debug_out;
    // 100 MHz-equivalent sim clock -- irrelevant to real Fmax, just a sim clock
    initial clk = 0;
    always #5 clk = ~clk;
 
    // ---- DUT ----
    soc_top dut (
        .clk         (clk),
        .rst         (rst),
        .debug_out   (debug_out),
        .load_mode   (load_mode),
        .data_in     (data_in),
        .byte_strobe (byte_strobe)
    );

    // ---- test program: 32-bit words, RV32I machine code ----
////iteration 1
    // addi x1, x0, 5        -> 0x00500093
    // addi x2, x0, 10       -> 0x00A00113
    // add  x3, x1, x2       -> 0x002081B3   (RAW hazard on x1 and x2, back-to-back)
    // addi x0, x0, 0  (nop) -> 0x00000013
    // addi x0, x0, 0  (nop) -> 0x00000013
////iteration 2
// ---- test program: 32-bit words, RV32I machine code ----
// idx  addr   instruction                    hex          notes
// 0    0x00   addi x1, x0, 5                 0x00500093   x1 = 5
// 1    0x04   addi x2, x0, 5                 0x00500113   x2 = 5
// 2    0x08   addi x3, x0, 10                0x00A00193   x3 = 10
// 3    0x0C   beq  x1, x2, 8                 0x00208463   taken -> 0x14
// 4    0x10   addi x4, x0, 999   (poison)    0x3E700213   MUST be skipped
// 5    0x14   addi x4, x0, 111              0x06F00213   branch target
// 6    0x18   bne  x1, x3, 8                 0x00309463   taken -> 0x20
// 7    0x1C   addi x5, x0, 999   (poison)    0x3E700293   MUST be skipped
// 8    0x20   addi x5, x0, 222              0x0DE00293   branch target
// 9    0x24   bne  x1, x2, 8                 0x00209463   NOT taken (x1==x2)
// 10   0x28   addi x6, x0, 333              0x14D00313   fallthrough, executes
// 11   0x2C   blt  x1, x3, 8                 0x0030C463   taken -> 0x34
// 12   0x30   addi x7, x0, 999   (poison)    0x3E700393   MUST be skipped
// 13   0x34   addi x7, x0, 444              0x1BC00393   branch target
// 14   0x38   bge  x3, x1, 8                 0x0011D463   taken -> 0x40
// 15   0x3C   addi x8, x0, 999   (poison)    0x3E700413   MUST be skipped
// 16   0x40   addi x8, x0, 555               0x22B00413   branch target
// 17   0x44   bltu x1, x3, 8                 0x0030E463   taken -> 0x4C
// 18   0x48   addi x9, x0, 999   (poison)    0x3E700493   MUST be skipped
// 19   0x4C   addi x9, x0, 666               0x29A00493   branch target
// 20   0x50   bgeu x3, x1, 8                 0x0011F463   taken -> 0x58
// 21   0x54   addi x10, x0, 999  (poison)    0x3E700513   MUST be skipped
// 22   0x58   addi x10, x0, 777              0x30900513   branch target
// 23   0x5C   addi x0, x0, 0  (nop)          0x00000013
// 24   0x60   addi x0, x0, 0  (nop)          0x00000013
// 25   0x64   addi x11, x0, 3                0x00300593   loop counter = 3
// 26   0x68   LOOP: addi x11, x11, -1        0xFFF58593   decrement
// 27   0x6C   bne  x11, x0, -4               0xFE059EE3   backward branch -> 0x68
// 28   0x70   addi x0, x0, 0  (nop)          0x00000013
// 29   0x74   addi x0, x0, 0  (nop)          0x00000013
// 30   0x78   sw   x10, 0(x0)                0x00a02023
// 31   0x7c   lw   x12, 0(x0)                0x00002603
// 32   0x80   addi x13,x0, -1                0xfff00693
// 33   0x84   sh x13, 4(x0)                  0x00d01223
// 34   0x88   sh x13, 10(x0)                 0x00d01523
    localparam int NUM_WORDS = 41   ;
    logic [31:0] test [0:NUM_WORDS-1];

initial begin
////interation 1
//        test[0] = 32'h00500093;
//        test[1] = 32'h00A00113;
//        test[2] = 32'h002081B3;
//        test[3] = 32'h00000013;
//        test[4] = 32'h00000013;
////iteration 2
test[0]  = 32'h00500093;
test[1]  = 32'h00500113;
test[2]  = 32'h00A00193;
test[3]  = 32'h00208463;
test[4]  = 32'h3E700213;
test[5]  = 32'h06F00213;
test[6]  = 32'h00309463;
test[7]  = 32'h3E700293;
test[8]  = 32'h0DE00293;
test[9]  = 32'h00209463;
test[10] = 32'h14D00313;
test[11] = 32'h0030C463;
test[12] = 32'h3E700393;
test[13] = 32'h1BC00393;
test[14] = 32'h0011D463;
test[15] = 32'h3E700413;
test[16] = 32'h22B00413;
test[17] = 32'h0030E463;
test[18] = 32'h3E700493;
test[19] = 32'h29A00493;
test[20] = 32'h0011F463;
test[21] = 32'h3E700513;
test[22] = 32'h30900513;
test[23] = 32'h00000013;
test[24] = 32'h00000013;
test[25] = 32'h00300593;
test[26] = 32'hFFF58593;
test[27] = 32'hFE059EE3;
test[28] = 32'h00000013;
test[29] = 32'h00000013;
test[30] = 32'h00a02023;
test[31] = 32'h00002603;
test[32] = 32'hfff00693;
test[33] = 32'h00d01223;
test[34] = 32'h00d01523;
test[35] = 32'h00000013;
test[36] = 32'h00000013;
test[37] = 32'h00000013;
test[38] = 32'h00000013;
test[39] = 32'h00000013;
test[40] = 32'h00000013;
test[41] = 32'h00000013;
end

    // ---- task: send one byte over the loader interface ----
    task automatic send_byte(input logic [7:0] b);
        @(posedge clk);
        data_in     <= b;
        byte_strobe <= 1'b1;
        @(posedge clk);
        byte_strobe <= 1'b0;
    endtask

    // ---- task: send one 32-bit word, little-endian (LSB byte first) ----
    task automatic send_word(input logic [31:0] w);
        send_byte(w[7:0]);
        send_byte(w[15:8]);
        send_byte(w[23:16]);
        send_byte(w[31:24]);
    endtask

    // ---- main stimulus ----
    initial begin
        // waveform dump for manual inspection since there's no output bus yet
        $dumpfile("tb_soc_top.vcd");
        $dumpvars(0, tb_soc_top);

        // initial state: reset asserted, loader idle
        rst         = 1'b0;   // active-low
        load_mode   = 1'b0;
        data_in     = 8'h00;
        byte_strobe = 1'b0;

        repeat (5) @(posedge clk);
        rst         = 1'b1;
        // enter boot-load mode. Per byte_loader design, load_mode also
        // gates core_rst_n, so the core stays held in reset for all of this
        // regardless of the external rst pin's state.
        load_mode = 1'b1;
        repeat (2) @(posedge clk);

        $display("[%0t] Loading %0d-word test program...", $time, NUM_WORDS);
        for (int i = 0; i < NUM_WORDS; i++) begin
            send_word(test[i]);
            $display("[%0t]   wrote word %0d = 0x%08h", $time, i, test[i]);
        end

        // leave load mode, release external reset -> core starts fetching from addr 0
        repeat (2) @(posedge clk);
        load_mode = 1'b0;
        rst       = 1'b1;
        $display("[%0t] Load complete, releasing core to run mode.", $time);

        // ---- run and observe ----
        // Run enough cycles to cover: 1-cycle Imem read latency (discussed
        // earlier) + 5 instructions + pipeline drain.
        repeat (500) @(posedge clk);

        // ==== RESULT-CHECK HOOK ====
        // No observability output exists yet, so there's nothing to assert
        // against automatically. Once you either (a) tell me the actual
        // hierarchical path to your register file inside `pipeline_top`,
        // or (b) add a real output bus, this is where a self-check goes, e.g.:
        //
        //   if (dut.cpu.<regfile_path>[3] !== 32'd15)
        //     $error("x3 mismatch: expected 15, got %0d", dut.cpu.<regfile_path>[3]);
        //   else
        //     $display("PASS: x3 = 15 as expected");
        //
        // Expected result for this program: x1=5, x2=10, x3=15.

        $display("[%0t] Simulation complete. Inspect tb_soc_top.vcd for results.", $time);
        $finish;
    end

    // safety timeout in case something hangs (e.g. loader stuck, no fetch progress)
    initial begin
        #10000;
        $display("[%0t] TIMEOUT -- simulation did not finish in time.", $time);
        $finish;
    end

endmodule