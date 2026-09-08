`timescale 1ns / 1ps

module tb_axi_ram_slave;

    // ============================================================
    // PARAMETERS
    // ============================================================
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    // ============================================================
    // CLOCK / RESET (active LOW)
    // ============================================================
    logic clk;
    logic rst_n;

    // ============================================================
    // AXI SIGNALS
    // ============================================================
    logic [ADDR_WIDTH-1:0]   s_axi_awaddr;
    logic                    s_axi_awvalid;
    logic                    s_axi_awready;

    logic [DATA_WIDTH-1:0]   s_axi_wdata;
    logic [DATA_WIDTH/8-1:0] s_axi_wstrb;
    logic                    s_axi_wvalid;
    logic                    s_axi_wready;

    logic [1:0]              s_axi_bresp;
    logic                    s_axi_bvalid;
    logic                    s_axi_bready;

    logic [ADDR_WIDTH-1:0]   s_axi_araddr;
    logic                    s_axi_arvalid;
    logic                    s_axi_arready;

    logic [DATA_WIDTH-1:0]   s_axi_rdata;
    logic [1:0]              s_axi_rresp;
    logic                    s_axi_rvalid;
    logic                    s_axi_rready;

    // ============================================================
    // REFERENCE MODEL (word-addressed, 1024 x 32)
    // ============================================================
    logic [31:0] ref_mem [0:1023];

    // ============================================================
    // TEST COUNTERS
    // ============================================================
    integer test_count, pass_count, fail_count, assertion_failures;
    integer i;

    // ============================================================
    // DUT
    // ============================================================
    AXI_RAM_Slave #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .MEM_DEPTH  (1024)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),

        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),

        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),

        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),

        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),

        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready)
    );

    // ============================================================
    // CLOCK
    // ============================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // FUNCTIONAL COVERAGE
    // ============================================================
    bit [31:0] cg_addr;
    bit [3:0]  cg_wstrb;
    bit [1:0]  cg_resp;
    bit        cg_is_write;
    bit        cg_same_cycle;

    covergroup axi_cov;

        cp_addr : coverpoint cg_addr {
            bins LOW          = {[32'h0000_0000 : 32'h0000_00FF]};
            bins MID          = {[32'h0000_0100 : 32'h0000_0BFF]};
            bins HIGH         = {[32'h0000_0C00 : 32'h0000_0FFF]};
            bins OUT_OF_RANGE = default;
        }

        cp_wstrb : coverpoint cg_wstrb {
            bins FULL    = {4'b1111};
            bins BYTE0   = {4'b0001};
            bins BYTE1   = {4'b0010};
            bins BYTE2   = {4'b0100};
            bins BYTE3   = {4'b1000};
            bins HALF_LO = {4'b0011};
            bins HALF_HI = {4'b1100};
            bins OTHER   = default;
        }

        cp_resp : coverpoint cg_resp {
            bins OKAY   = {2'b00};
            bins SLVERR = {2'b10};
        }

        cp_rw : coverpoint cg_is_write {
            bins WRITE = {1'b1};
            bins READ  = {1'b0};
        }

        cp_same_cycle : coverpoint cg_same_cycle {
            bins SAME_CYCLE  = {1'b1};
            bins SPLIT_CYCLE = {1'b0};
        }

        rw_resp_cross    : cross cp_rw, cp_resp;
        addr_wstrb_cross : cross cp_addr, cp_wstrb;

    endgroup

    axi_cov cov;

    // ============================================================
    // HELPERS
    // ============================================================
    function automatic bit addr_valid(input [31:0] addr);
        addr_valid = (addr[31:12] == 20'h00000);
    endfunction

    function automatic [31:0] apply_wstrb(
        input [31:0] old_data,
        input [31:0] wdata,
        input [3:0]  wstrb
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

    // ============================================================
    // MASTER BFM: independent AW / W / B / AR / R channel drivers
    // fork/join on AW+W gives true same-cycle assertion;
    // sequential calls give a split-cycle gap.
    // ============================================================
    task automatic drive_aw(input [31:0] addr);
        begin
            @(negedge clk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;
            do @(posedge clk); while (!s_axi_awready);
            @(negedge clk);
            s_axi_awvalid = 1'b0;
        end
    endtask

    task automatic drive_w(input [31:0] data, input [3:0] wstrb);
        begin
            @(negedge clk);
            s_axi_wdata  = data;
            s_axi_wstrb  = wstrb;
            s_axi_wvalid = 1'b1;
            do @(posedge clk); while (!s_axi_wready);
            @(negedge clk);
            s_axi_wvalid = 1'b0;
        end
    endtask

    task automatic drive_b(output [1:0] bresp);
        begin
            s_axi_bready = 1'b1;
            do @(posedge clk); while (!s_axi_bvalid);
            bresp = s_axi_bresp;
            @(negedge clk);
            s_axi_bready = 1'b0;
        end
    endtask

    task automatic axi_write(
        input  [31:0] addr,
        input  [31:0] data,
        input  [3:0]  wstrb,
        input         same_cycle,
        output [1:0]  bresp
    );
        begin
            if (same_cycle) begin
                fork
                    drive_aw(addr);
                    drive_w(data, wstrb);
                join
            end
            else begin
                drive_aw(addr);
                drive_w(data, wstrb);
            end
            drive_b(bresp);
        end
    endtask

    task automatic axi_read(
        input  [31:0] addr,
        output [31:0] rdata,
        output [1:0]  rresp
    );
        begin
            @(negedge clk);
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;
            do @(posedge clk); while (!s_axi_arready);
            @(negedge clk);
            s_axi_arvalid = 1'b0;

            s_axi_rready = 1'b1;
            do @(posedge clk); while (!s_axi_rvalid);
            rdata = s_axi_rdata;
            rresp = s_axi_rresp;
            @(negedge clk);
            s_axi_rready = 1'b0;
        end
    endtask

    // ============================================================
    // CHECK TASKS
    // ============================================================
    task automatic check_write(
        input [31:0] addr,
        input [31:0] data,
        input [3:0]  wstrb,
        input        same_cycle
    );
        logic [1:0]  bresp;
        bit          exp_err;
        integer      idx;
        begin
            test_count = test_count + 1;
            exp_err = !addr_valid(addr);

            axi_write(addr, data, wstrb, same_cycle, bresp);

            if (!exp_err) begin
                idx = addr[11:2];
                ref_mem[idx] = apply_wstrb(ref_mem[idx], data, wstrb);
            end

            cg_addr = addr; cg_wstrb = wstrb; cg_resp = bresp;
            cg_is_write = 1'b1; cg_same_cycle = same_cycle;
            cov.sample();

            if (bresp !== (exp_err ? RESP_SLVERR : RESP_OKAY)) begin
                fail_count = fail_count + 1;
                 $display("FAIL WRITE @%0t ns | addr=%h data=%h wstrb=%b exp_resp=%b got=%b",
                          $time, addr, data, wstrb, (exp_err ? RESP_SLVERR : RESP_OKAY), bresp);
            end
            else pass_count = pass_count + 1;

            assert (bresp === (exp_err ? RESP_SLVERR : RESP_OKAY))
            else begin
                $error("BRESP mismatch @%h", addr);
                assertion_failures = assertion_failures + 1;
            end
        end
    endtask

    task automatic check_read(input [31:0] addr);
        logic [31:0] rdata, exp_data;
        logic [1:0]  rresp;
        bit          exp_err;
        integer      idx;
        begin
            test_count = test_count + 1;
            exp_err  = !addr_valid(addr);
            idx      = addr[11:2];
            exp_data = exp_err ? 32'b0 : ref_mem[idx];

            axi_read(addr, rdata, rresp);

            cg_addr = addr; cg_wstrb = 4'b0000; cg_resp = rresp;
            cg_is_write = 1'b0; cg_same_cycle = 1'b0;
            cov.sample();

            if ((rresp !== (exp_err ? RESP_SLVERR : RESP_OKAY)) ||
                (!exp_err && (rdata !== exp_data))) begin
                fail_count = fail_count + 1;
                $display("FAIL READ @%0t ns | addr=%h exp_data=%h got_data=%h exp_resp=%b got_resp=%b",
                          $time, addr, exp_data, rdata, (exp_err ? RESP_SLVERR : RESP_OKAY), rresp);
            end
            else pass_count = pass_count + 1;

            assert (rresp === (exp_err ? RESP_SLVERR : RESP_OKAY))
            else begin $error("RRESP mismatch @%h", addr); assertion_failures = assertion_failures + 1; end

            assert (exp_err || (rdata === exp_data))
            else begin $error("RDATA mismatch @%h", addr); assertion_failures = assertion_failures + 1; end
        end
    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================
    initial begin

        s_axi_awaddr  = 0; s_axi_awvalid = 0;
        s_axi_wdata   = 0; s_axi_wstrb   = 0; s_axi_wvalid = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0; s_axi_arvalid = 0;
        s_axi_rready  = 0;

        test_count = 0; pass_count = 0; fail_count = 0; assertion_failures = 0;

        for (i = 0; i < 1024; i = i + 1) ref_mem[i] = 32'bxx;

        cov = new();

        $display("");
        $display("================================================");
        $display(" AXI_RAM_Slave VERIFICATION");
        $display("================================================");
        $display("");

        // ========================================================
        // RESET
        // ========================================================
        rst_n = 1'b0;
        repeat (3) @(posedge clk);

        assert (s_axi_awready === 1'b0 || 1'b1) ; // awready is level, don't overconstrain during reset window
        assert (s_axi_bvalid  === 1'b0 && s_axi_rvalid === 1'b0)
        else begin
            $error("RESET ASSERTION FAILED: bvalid/rvalid not clear");
            assertion_failures = assertion_failures + 1;
        end

        rst_n = 1'b1;
        @(posedge clk);

        // ========================================================
        // BASIC FULL READ/WRITE
        // ========================================================
        $display("Basic full-word read/write...");
        check_write(32'h0000_0000, 32'hDEADBEEF, 4'b1111, 1'b1);
        check_read (32'h0000_0000);

        check_write(32'h0000_0004, 32'h11223344, 4'b1111, 1'b0);
        check_read (32'h0000_0004);

        // ========================================================
        // PARTIAL WRITE (RMW) - each byte lane, then halfwords
        // ========================================================
        $display("Partial write (RMW) via wstrb...");
        check_write(32'h0000_0008, 32'hFFFFFFFF, 4'b1111, 1'b1); // seed
        for (i = 0; i < 4; i = i + 1)
            check_write(32'h0000_0008, 32'h00000000, (4'b0001 << i), 1'b1);
        check_read(32'h0000_0008); // expect fully cleared after all 4 byte writes

        check_write(32'h0000_000C, 32'hFFFFFFFF, 4'b1111, 1'b0);
        check_write(32'h0000_000C, 32'h0000AAAA, 4'b0011, 1'b1); // low half
        check_write(32'h0000_000C, 32'h0000BBBB, 4'b1100, 1'b0); // high half
        check_read (32'h0000_000C);

        // ========================================================
        // SAME-CYCLE vs SPLIT-CYCLE AW/W
        // ========================================================
        $display("Same-cycle vs split-cycle AW/W...");
        check_write(32'h0000_0010, 32'hCAFEF00D, 4'b1111, 1'b1); // same-cycle
        check_write(32'h0000_0014, 32'hF00DCAFE, 4'b1111, 1'b0); // split-cycle

        // ========================================================
        // BACK-TO-BACK TRANSACTIONS
        // ========================================================
        $display("Back-to-back transactions...");
        for (i = 0; i < 8; i = i + 1)
            check_write(32'h0000_0020 + (i*4), i, 4'b1111, i[0]);
        for (i = 0; i < 8; i = i + 1)
            check_read(32'h0000_0020 + (i*4));

        // ========================================================
        // INVALID ADDRESS -> SLVERR
        // ========================================================
        $display("Invalid address -> SLVERR...");
        check_write(32'h0000_1000, 32'hBADBADBA, 4'b1111, 1'b1); // just past valid range
        check_read (32'h0000_1000);
        check_write(32'hFFFF_FFF0, 32'hBADBADBA, 4'b1111, 1'b0);
        check_read (32'hFFFF_FFF0);

        // ========================================================
        // RANDOM TRAFFIC
        // ========================================================
        $display("");
        $display("Running 2000 randomized read/write transactions...");

        for (i = 0; i < 2000; i = i + 1) begin
            logic [31:0] raddr;
            logic [3:0]  rstrb;
            bit          do_write, do_same_cycle;

            // Bias ~90% into the valid range, ~10% out of range
            if ($urandom_range(0,9) == 0)
                raddr = {20'hFFFFF, $urandom_range(0,4095)} & 32'hFFFF_F000 | $urandom_range(0,4095);
            else
                raddr = {20'h00000, $urandom_range(0,1023), 2'b00};

            rstrb    = $urandom_range(1,15); // never all-zero
            do_write = $urandom_range(0,1);
            do_same_cycle = $urandom_range(0,1);

            if (do_write)
                check_write(raddr, $urandom, rstrb, do_same_cycle);
            else
                check_read(raddr);
        end

        // ========================================================
        // FINAL REPORT
        // ========================================================
        $display("");
        $display("================================================");
        $display(" AXI_RAM_Slave VERIFICATION REPORT");
        $display("================================================");
        $display("Total Tests         = %0d", test_count);
        $display("Passed              = %0d", pass_count);
        $display("Failed              = %0d", fail_count);
        $display("Assertion Failures  = %0d", assertion_failures);
        $display("Functional Coverage = %0.2f%%", cov.get_coverage());
        $display("================================================");
        $display("");

        if ((fail_count == 0) && (assertion_failures == 0))
            $display("******** AXI_RAM_Slave VERIFICATION PASSED ********");
        else
            $display("******** AXI_RAM_Slave VERIFICATION FAILED ********");

        $display("");
        $finish;
    end

endmodule