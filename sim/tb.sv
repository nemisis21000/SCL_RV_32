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
    // addi x1, x0, 5        -> 0x00500093
    // addi x2, x0, 10       -> 0x00A00113
    // add  x3, x1, x2       -> 0x002081B3   (RAW hazard on x1 and x2, back-to-back)
    // addi x0, x0, 0  (nop) -> 0x00000013
    // addi x0, x0, 0  (nop) -> 0x00000013
    localparam int NUM_WORDS = 5;
    logic [31:0] test [0:NUM_WORDS-1];

    initial begin
        test[0] = 32'h00500093;
        test[1] = 32'h00A00113;
        test[2] = 32'h002081B3;
        test[3] = 32'h00000013;
        test[4] = 32'h00000013;
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
        repeat (30) @(posedge clk);

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