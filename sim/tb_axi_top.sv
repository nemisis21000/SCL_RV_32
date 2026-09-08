`timescale 1ns / 1ps

module tb_axi_top;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    logic clk, rst_n;

    logic [ADDR_WIDTH-1:0]   mem_addr;
    logic [DATA_WIDTH-1:0]   mem_wdata;
    logic [DATA_WIDTH/8-1:0] mem_wstrb;
    logic                    mem_we;
    logic                    mem_re;
    logic [DATA_WIDTH-1:0]   mem_rdata;
    logic                    mem_ready;

    logic [31:0] ref_mem [0:1023];

    integer test_count, pass_count, fail_count, assertion_failures;
    integer i;

    function automatic bit addr_valid(input [31:0] addr);
        addr_valid = (addr[31:12] == 20'h00000);
    endfunction

    function automatic [31:0] apply_wstrb(
        input [31:0] old_data, input [31:0] wdata, input [3:0] wstrb
    );
        logic [31:0] merged;
        begin
            merged = old_data;
            if (wstrb[0]) merged[7:0]   = wdata[7:0];
            if (wstrb[1]) merged[15:8]  = wdata[15:8];
            if (wstrb[2]) merged[23:16] = wdata[23:16];
            if (wstrb[3]) merged[31:24] = wdata[31:24];
            apply_wstrb = merged;
        end
    endfunction

    AXI_TOP #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_we(mem_we), .mem_re(mem_re),
        .mem_rdata(mem_rdata), .mem_ready(mem_ready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // COVERAGE
    // ============================================================
    bit [31:0] cg_addr;
    bit [3:0]  cg_wstrb;
    bit        cg_is_write;
    bit        cg_valid_addr;

    covergroup axi_top_cov;
        cp_rw : coverpoint cg_is_write { bins WRITE={1'b1}; bins READ={1'b0}; }
        cp_addr : coverpoint cg_addr {
            bins LOW  = {[32'h0000_0000:32'h0000_00FF]};
            bins MID  = {[32'h0000_0100:32'h0000_0BFF]};
            bins HIGH = {[32'h0000_0C00:32'h0000_0FFF]};
            bins OUT_OF_RANGE = default;
        }
        cp_wstrb : coverpoint cg_wstrb {
            bins FULL      = {4'b1111};
            bins PARTIAL[] = {4'b0001,4'b0010,4'b0100,4'b1000,4'b0011,4'b1100};
            bins OTHER     = default;
        }
        cp_valid : coverpoint cg_valid_addr { bins VALID={1'b1}; bins INVALID={1'b0}; }
        rw_valid_cross : cross cp_rw, cp_valid;
    endgroup

    axi_top_cov cov;
    // ============================================================
    // CPU-SIDE DRIVER TASKS
    // ============================================================
    task automatic cpu_write(input [31:0] addr, input [31:0] data, input [3:0] wstrb);
        begin
            @(negedge clk);
            mem_addr  = addr;
            mem_wdata = data;
            mem_wstrb = wstrb;
            mem_we    = 1'b1;
            mem_re    = 1'b0;

            do begin
                @(posedge clk);
                #1;
            end while (!mem_ready);

            @(negedge clk);
            mem_we = 1'b0;
        end
    endtask

    task automatic cpu_read(input [31:0] addr, output [31:0] rdata);
        begin
            @(negedge clk);
            mem_addr = addr;
            mem_we   = 1'b0;
            mem_re   = 1'b1;

            do begin
                @(posedge clk);
                #1;
            end while (!mem_ready);

            rdata = mem_rdata;
            @(negedge clk);
            mem_re = 1'b0;
        end
    endtask
    // ============================================================
    // BACKDOOR READ into the physical SPRAM
    // Path: dut(AXI_TOP).ram_slave(AXI_RAM_Slave).Dmem(SPRAM_1024x36).mem[]
    // ============================================================
    function automatic [31:0] backdoor_read(input [31:0] addr);
        backdoor_read = dut.ram_slave.Dmem.mem[addr[11:2]][31:0];
    endfunction

    // ============================================================
    // CHECK TASKS
    // ============================================================
    task automatic check_write(input [31:0] addr, input [31:0] data, input [3:0] wstrb);
        integer idx;
        logic [31:0] exp_val, hw_val;
        begin
            test_count = test_count + 1;
            idx = addr[11:2];

            cpu_write(addr, data, wstrb);

            cg_addr = addr; cg_wstrb = wstrb; cg_is_write = 1'b1;
            cg_valid_addr = addr_valid(addr);
            cov.sample();

            if (addr_valid(addr)) begin
                ref_mem[idx] = apply_wstrb(ref_mem[idx], data, wstrb);
                exp_val = ref_mem[idx];
                hw_val  = backdoor_read(addr);

                if (hw_val !== exp_val) begin
                    fail_count = fail_count + 1;
                    $display("FAIL WRITE backdoor mismatch addr=%h exp=%h got=%h", addr, exp_val, hw_val);
                end
                else pass_count = pass_count + 1;

                assert (hw_val === exp_val)
                else begin $error("Backdoor RAM mismatch @%h", addr); assertion_failures = assertion_failures + 1; end
            end
            else begin
                pass_count = pass_count + 1; // completed handshake despite invalid addr is the expectation
            end
        end
    endtask

    task automatic check_read(input [31:0] addr);
        logic [31:0] rdata, exp_data;
        begin
            test_count = test_count + 1;
            exp_data = addr_valid(addr) ? ref_mem[addr[11:2]] : 32'b0;

            cpu_read(addr, rdata);

            cg_addr = addr; cg_wstrb = 4'b0; cg_is_write = 1'b0;
            cg_valid_addr = addr_valid(addr);
            cov.sample();

            if (rdata !== exp_data) begin
                fail_count = fail_count + 1;
                $display("FAIL READ addr=%h exp=%h got=%h", addr, exp_data, rdata);
            end
            else pass_count = pass_count + 1;

            assert (rdata === exp_data)
            else begin $error("Read data mismatch @%h", addr); assertion_failures = assertion_failures + 1; end
        end
    endtask

    // ============================================================
    // RESET-MID-TRANSACTION TEST
    // ============================================================
    task automatic reset_mid_transaction_test;
        logic [31:0] pre_val;
        begin
            test_count = test_count + 1;
            pre_val = ref_mem[32'h0000_0040 >> 2];

            @(negedge clk);
            mem_addr  = 32'h0000_0040;
            mem_wdata = 32'hCAFEBABE;
            mem_wstrb = 4'b1111;
            mem_we    = 1'b1;
            mem_re    = 1'b0;

            repeat (1) @(posedge clk);
            rst_n  = 1'b0;
            mem_we = 1'b0;
            mem_re = 1'b0;
            repeat (3) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);

            if (mem_ready !== 1'b0) begin
                fail_count = fail_count + 1;
                $display("FAIL: mem_ready asserted spuriously after reset-mid-transaction");
            end
            else pass_count = pass_count + 1;

            assert (mem_ready === 1'b0)
            else begin $error("Reset-mid-transaction left mem_ready asserted"); assertion_failures = assertion_failures + 1; end

            test_count = test_count + 1;
            if (backdoor_read(32'h0000_0040) === pre_val)
                pass_count = pass_count + 1;
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: aborted write during reset corrupted memory @0x40");
            end

            // Bus must be fully usable again after reset
            check_write(32'h0000_0040, 32'hCAFEBABE, 4'b1111);
            check_read (32'h0000_0040);
        end
    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================
    initial begin

        mem_addr = 0; mem_wdata = 0; mem_wstrb = 0; mem_we = 0; mem_re = 0;
        test_count = 0; pass_count = 0; fail_count = 0; assertion_failures = 0;
        for (i = 0; i < 1024; i = i + 1) ref_mem[i] = 32'bxx;

        cov = new();

        $display("");
        $display("================================================");
        $display(" AXI_TOP END-TO-END VERIFICATION");
        $display("================================================");
        $display("");

        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        assert (mem_ready === 1'b0)
        else begin $error("RESET: mem_ready not clear"); assertion_failures = assertion_failures + 1; end
        rst_n = 1'b1;
        @(posedge clk);

        // ========================================================
        // BASIC FULL READ/WRITE
        // ========================================================
        $display("Basic full-word read/write end-to-end...");
        check_write(32'h0000_0000, 32'hDEADBEEF, 4'b1111);
        check_read (32'h0000_0000);

        // ========================================================
        // PARTIAL WRITE (RMW)
        // ========================================================
        $display("Partial write (RMW) via wstrb, end-to-end...");
        check_write(32'h0000_0004, 32'hFFFFFFFF, 4'b1111);
        for (i = 0; i < 4; i = i + 1)
            check_write(32'h0000_0004, 32'h00000000, (4'b0001 << i));
        check_read(32'h0000_0004);

        check_write(32'h0000_0008, 32'hFFFFFFFF, 4'b1111);
        check_write(32'h0000_0008, 32'h0000AAAA, 4'b0011);
        check_write(32'h0000_0008, 32'h0000BBBB, 4'b1100);
        check_read (32'h0000_0008);

        // ========================================================
        // SAME-CYCLE vs SPLIT-CYCLE
        // In AXI_TOP the AW/W same-/split-cycle behavior is entirely
        // internal (Manager <-> RAM slave); it is exercised
        // automatically as part of every write. These two entries
        // just add address diversity for coverage.
        // ========================================================
        $display("AW/W internal handshake coverage...");
        check_write(32'h0000_000C, 32'h12345678, 4'b1111);
        check_write(32'h0000_0010, 32'h87654321, 4'b1111);

        // ========================================================
        // BACK-TO-BACK TRANSACTIONS
        // ========================================================
        $display("Back-to-back transactions, end-to-end...");
        for (i = 0; i < 8; i = i + 1)
            check_write(32'h0000_0020 + (i*4), i, 4'b1111);
        for (i = 0; i < 8; i = i + 1)
            check_read(32'h0000_0020 + (i*4));

        // ========================================================
        // INVALID ADDRESS -> SLVERR (bus must still complete cleanly)
        // ========================================================
        $display("Invalid address handling, end-to-end...");
        check_write(32'h0000_1000, 32'hBADBADBA, 4'b1111);
        check_read (32'h0000_1000);

        // ========================================================
        // RESET MID-TRANSACTION
        // ========================================================
        $display("Reset asserted mid-transaction...");
        reset_mid_transaction_test();

        // ========================================================
        // RANDOM END-TO-END TRAFFIC
        // ========================================================
        $display("");
        $display("Running 2000 randomized end-to-end transactions...");

        for (i = 0; i < 2000; i = i + 1) begin 
            logic [31:0] raddr;
            logic [3:0]  rstrb;
            bit          do_write;

            if ($urandom_range(0,9) == 0)
                raddr = 32'h0000_1000 + $urandom_range(0,4095);
            else
                raddr = {20'h00000, $urandom_range(0,1023), 2'b00};

            rstrb    = $urandom_range(1,15);
            do_write = $urandom_range(0,1);

            if (do_write)
                check_write(raddr, $urandom, rstrb);
            else
                check_read(raddr);
        end

        // ========================================================
        // FINAL FULL-MEMORY BACKDOOR DIFF
        // ========================================================
        $display("");
        $display("Running full-memory backdoor diff against reference model...");
        begin
            integer mismatches;
            mismatches = 0;
            for (i = 0; i < 1024; i = i + 1) begin
                test_count = test_count + 1;
                if (backdoor_read(i << 2) !== ref_mem[i]) begin
                    mismatches = mismatches + 1;
                    fail_count = fail_count + 1;
                    $display("FAIL FULL-MEM DIFF idx=%0d addr=%h exp=%h got=%h",
                              i, (i<<2), ref_mem[i], backdoor_read(i<<2));
                end
                else pass_count = pass_count + 1;
            end
            assert (mismatches == 0)
            else begin $error("Full-memory backdoor diff found mismatches"); assertion_failures = assertion_failures + 1; end
        end

        // ========================================================
        // FINAL REPORT
        // ========================================================
        $display("");
        $display("================================================");
        $display(" AXI_TOP VERIFICATION REPORT");
        $display("================================================");
        $display("Total Tests         = %0d", test_count);
        $display("Passed              = %0d", pass_count);
        $display("Failed              = %0d", fail_count);
        $display("Assertion Failures  = %0d", assertion_failures);
        $display("Functional Coverage = %0.2f%%", cov.get_coverage());
        $display("================================================");
        $display("");

        if ((fail_count == 0) && (assertion_failures == 0))
            $display("******** AXI_TOP VERIFICATION PASSED ********");
        else
            $display("******** AXI_TOP VERIFICATION FAILED ********");

        $display("");
        $finish;
    end

endmodule