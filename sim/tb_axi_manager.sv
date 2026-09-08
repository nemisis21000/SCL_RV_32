`timescale 1ns / 1ps

module tb_axi_manager;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    logic clk, rst_n;

    // CPU side (driven by TB)
    logic [ADDR_WIDTH-1:0]   mem_addr;
    logic [DATA_WIDTH-1:0]   mem_wdata;
    logic [DATA_WIDTH/8-1:0] mem_wstrb;
    logic                    mem_we;
    logic                    mem_re;
    logic [DATA_WIDTH-1:0]   mem_rdata;
    logic                    mem_ready;

    // AXI side (TB acts as the slave)
    logic [ADDR_WIDTH-1:0]   axi_awaddr;
    logic                    axi_awvalid;
    logic                    axi_awready;

    logic [DATA_WIDTH-1:0]   axi_wdata;
    logic [DATA_WIDTH/8-1:0] axi_wstrb;
    logic                    axi_wvalid;
    logic                    axi_wready;

    logic [1:0]              axi_bresp;
    logic                    axi_bvalid;
    logic                    axi_bready;

    logic [ADDR_WIDTH-1:0]   axi_araddr;
    logic                    axi_arvalid;
    logic                    axi_arready;

    logic [DATA_WIDTH-1:0]   axi_rdata;
    logic [1:0]              axi_rresp;
    logic                    axi_rvalid;
    logic                    axi_rready;

    // Reference "slave memory" that the TB's slave BFM serves from
    logic [31:0] ref_mem [0:1023];

    // Slave BFM configurable ready delays (cycles)
    integer slave_aw_delay, slave_w_delay, slave_ar_delay, slave_resp_delay;

    // What the slave BFM actually captured, for passthrough checking
    logic [31:0] captured_awaddr, captured_araddr;
    logic [31:0] captured_wdata;
    logic [3:0]  captured_wstrb;

    integer test_count, pass_count, fail_count, assertion_failures;
    integer i;

    AXI_Manager #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),

        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_we(mem_we), .mem_re(mem_re),
        .mem_rdata(mem_rdata), .mem_ready(mem_ready),

        .axi_awaddr(axi_awaddr), .axi_awvalid(axi_awvalid), .axi_awready(axi_awready),
        .axi_wdata(axi_wdata),   .axi_wstrb(axi_wstrb), .axi_wvalid(axi_wvalid), .axi_wready(axi_wready),
        .axi_bresp(axi_bresp),   .axi_bvalid(axi_bvalid), .axi_bready(axi_bready),
        .axi_araddr(axi_araddr), .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
        .axi_rdata(axi_rdata),   .axi_rresp(axi_rresp), .axi_rvalid(axi_rvalid), .axi_rready(axi_rready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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

    // ============================================================
    // COVERAGE
    // ============================================================
    bit [31:0] cg_addr;
    bit [3:0]  cg_wstrb;
    bit [1:0]  cg_resp;
    bit        cg_is_write;
    bit        cg_delayed_slave;

    covergroup axi_mgr_cov;
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
        cp_resp  : coverpoint cg_resp { bins OKAY={2'b00}; bins SLVERR={2'b10}; }
        cp_delay : coverpoint cg_delayed_slave { bins IMMEDIATE={1'b0}; bins DELAYED={1'b1}; }
        rw_resp_cross : cross cp_rw, cp_resp;
    endgroup

    axi_mgr_cov cov;

    // ============================================================
    // SLAVE BFM #1: AW/W capture + B response - synchronous, race-free
    // ============================================================
    typedef enum logic [1:0] {S_WAIT, S_CAPTURE, S_RESP} slv_wr_state_t;
    slv_wr_state_t slv_wr_state;
    integer aw_wait_cnt, w_wait_cnt, resp_wait_cnt;
    bit     slv_aw_seen, slv_w_seen;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_awready   <= 1'b0;
            axi_wready    <= 1'b0;
            axi_bvalid    <= 1'b0;
            axi_bresp     <= RESP_OKAY;
            slv_wr_state  <= S_WAIT;
            slv_aw_seen   <= 1'b0;
            slv_w_seen    <= 1'b0;
        end
        else begin
            case (slv_wr_state)

                S_WAIT: begin
                    axi_bvalid <= 1'b0;
                    if (axi_awvalid || axi_wvalid) begin
                        aw_wait_cnt  <= slave_aw_delay;
                        w_wait_cnt   <= slave_w_delay;
                        slv_aw_seen  <= 1'b0;
                        slv_w_seen   <= 1'b0;
                        axi_awready  <= (slave_aw_delay == 0);
                        axi_wready   <= (slave_w_delay  == 0);
                        slv_wr_state <= S_CAPTURE;
                    end
                end

                S_CAPTURE: begin
                    if (!axi_awready && aw_wait_cnt > 0) begin
                        aw_wait_cnt <= aw_wait_cnt - 1;
                        if (aw_wait_cnt == 1) axi_awready <= 1'b1;
                    end
                    if (!axi_wready && w_wait_cnt > 0) begin
                        w_wait_cnt <= w_wait_cnt - 1;
                        if (w_wait_cnt == 1) axi_wready <= 1'b1;
                    end

                    if (axi_awvalid && axi_awready) begin
                        captured_awaddr <= axi_awaddr;
                        axi_awready     <= 1'b0;
                        slv_aw_seen     <= 1'b1;
                    end
                    if (axi_wvalid && axi_wready) begin
                        captured_wdata <= axi_wdata;
                        captured_wstrb <= axi_wstrb;
                        axi_wready     <= 1'b0;
                        slv_w_seen     <= 1'b1;
                    end

                    if ((slv_aw_seen || (axi_awvalid && axi_awready)) &&
                        (slv_w_seen  || (axi_wvalid  && axi_wready))) begin
                        resp_wait_cnt <= slave_resp_delay;
                        slv_wr_state  <= S_RESP;
                    end
                end

                S_RESP: begin
                    if (resp_wait_cnt > 0) begin
                        resp_wait_cnt <= resp_wait_cnt - 1;
                    end
                    else if (!axi_bvalid) begin
                        axi_bresp  <= addr_valid(captured_awaddr) ? RESP_OKAY : RESP_SLVERR;
                        axi_bvalid <= 1'b1;

                        if (addr_valid(captured_awaddr))
                            ref_mem[captured_awaddr[11:2]] <=
                                apply_wstrb(ref_mem[captured_awaddr[11:2]],
                                            captured_wdata, captured_wstrb);
                    end
                    else if (axi_bvalid && axi_bready) begin
                        axi_bvalid   <= 1'b0;
                        slv_wr_state <= S_WAIT;
                    end
                end
            endcase
        end
    end

    // ============================================================
    // SLAVE BFM #2: AR/R response - synchronous, race-free
    // ============================================================
    typedef enum logic [1:0] {S_R_WAIT, S_R_ARDLY, S_R_RESPDLY, S_R_VALID} slv_rd_state_t;
    slv_rd_state_t slv_rd_state;
    integer ar_wait_cnt, r_resp_wait_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_arready  <= 1'b0;
            axi_rvalid   <= 1'b0;
            axi_rresp    <= RESP_OKAY;
            axi_rdata    <= 32'b0;
            slv_rd_state <= S_R_WAIT;
        end
        else begin
            case (slv_rd_state)

                S_R_WAIT: begin
                    axi_arready <= 1'b0;
                    if (axi_arvalid) begin
                        ar_wait_cnt <= slave_ar_delay;
                        slv_rd_state <= S_R_ARDLY;
                    end
                end

                S_R_ARDLY: begin
                    if (ar_wait_cnt > 0) begin
                        ar_wait_cnt <= ar_wait_cnt - 1;
                    end
                    else begin
                        axi_arready <= 1'b1;
                        if (axi_arvalid && axi_arready) begin
                            captured_araddr <= axi_araddr;
                            axi_arready     <= 1'b0;
                            r_resp_wait_cnt <= slave_resp_delay;
                            slv_rd_state    <= S_R_RESPDLY;
                        end
                    end
                end

                S_R_RESPDLY: begin
                    if (r_resp_wait_cnt > 0) begin
                        r_resp_wait_cnt <= r_resp_wait_cnt - 1;
                    end
                    else begin
                        axi_rdata  <= addr_valid(captured_araddr) ? ref_mem[captured_araddr[11:2]] : 32'b0;
                        axi_rresp  <= addr_valid(captured_araddr) ? RESP_OKAY : RESP_SLVERR;
                        axi_rvalid <= 1'b1;
                        slv_rd_state <= S_R_VALID;
                    end
                end

                S_R_VALID: begin
                    if (axi_rvalid && axi_rready) begin
                        axi_rvalid   <= 1'b0;
                        slv_rd_state <= S_R_WAIT;
                    end
                end
            endcase
        end
    end
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
    // CHECK TASKS (verify Manager's protocol passthrough fidelity)
    // ============================================================
    task automatic check_write(input [31:0] addr, input [31:0] data, input [3:0] wstrb);
        begin
            test_count = test_count + 1;
            cpu_write(addr, data, wstrb);

            cg_addr = addr; cg_wstrb = wstrb; cg_is_write = 1'b1;
            cg_resp = addr_valid(addr) ? RESP_OKAY : RESP_SLVERR;
            cg_delayed_slave = (slave_aw_delay > 0 || slave_w_delay > 0 || slave_resp_delay > 0);
            cov.sample();

            if ((captured_awaddr !== addr) || (captured_wdata !== data) || (captured_wstrb !== wstrb)) begin
                fail_count = fail_count + 1;
                $display("FAIL WRITE passthrough addr=%h(got %h) data=%h(got %h) wstrb=%b(got %b)",
                          addr, captured_awaddr, data, captured_wdata, wstrb, captured_wstrb);
            end
            else pass_count = pass_count + 1;

            assert (captured_awaddr === addr)
            else begin $error("Manager AW passthrough mismatch"); assertion_failures = assertion_failures + 1; end
            assert (captured_wdata === data)
            else begin $error("Manager W data passthrough mismatch"); assertion_failures = assertion_failures + 1; end
            assert (captured_wstrb === wstrb)
            else begin $error("Manager WSTRB passthrough mismatch"); assertion_failures = assertion_failures + 1; end
        end
    endtask

    task automatic check_read(input [31:0] addr);
        logic [31:0] rdata, exp_data;
        begin
            test_count = test_count + 1;
            exp_data = addr_valid(addr) ? ref_mem[addr[11:2]] : 32'b0;

            cpu_read(addr, rdata);

            cg_addr = addr; cg_wstrb = 4'b0; cg_is_write = 1'b0;
            cg_resp = addr_valid(addr) ? RESP_OKAY : RESP_SLVERR;
            cg_delayed_slave = (slave_ar_delay > 0 || slave_resp_delay > 0);
            cov.sample();

            if ((captured_araddr !== addr) || (rdata !== exp_data)) begin
                fail_count = fail_count + 1;
                $display("FAIL READ passthrough addr=%h(got %h) exp_data=%h got_data=%h",
                          addr, captured_araddr, exp_data, rdata);
            end
            else pass_count = pass_count + 1;

            assert (captured_araddr === addr)
            else begin $error("Manager AR passthrough mismatch"); assertion_failures = assertion_failures + 1; end
            assert (rdata === exp_data)
            else begin $error("Manager R data passthrough mismatch"); assertion_failures = assertion_failures + 1; end
        end
    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================
    initial begin

        mem_addr = 0; mem_wdata = 0; mem_wstrb = 0; mem_we = 0; mem_re = 0;
        slave_aw_delay = 0; slave_w_delay = 0; slave_ar_delay = 0; slave_resp_delay = 0;

        test_count = 0; pass_count = 0; fail_count = 0; assertion_failures = 0;
        for (i = 0; i < 1024; i = i + 1) ref_mem[i] = 32'bxx;

        cov = new();

        $display("");
        $display("================================================");
        $display(" AXI_Manager VERIFICATION");
        $display("================================================");
        $display("");

        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        assert (mem_ready === 1'b0)
        else begin $error("RESET: mem_ready not clear"); assertion_failures = assertion_failures + 1; end
        rst_n = 1'b1;
        @(posedge clk);

        // ========================================================
        // BASIC FULL READ/WRITE, immediate slave
        // ========================================================
        $display("Basic full-word read/write (immediate slave)...");
        check_write(32'h0000_0000, 32'hDEADBEEF, 4'b1111);
        check_read (32'h0000_0000);

        // ========================================================
        // PARTIAL WRITE (RMW)
        // ========================================================
        $display("Partial write via wstrb...");
        check_write(32'h0000_0004, 32'hFFFFFFFF, 4'b1111);
        for (i = 0; i < 4; i = i + 1)
            check_write(32'h0000_0004, 32'h00000000, (4'b0001 << i));
        check_read(32'h0000_0004);

        // ========================================================
        // SAME-CYCLE vs SPLIT-CYCLE (from the slave's point of view)
        // The Manager always asserts AW+W together; here we vary
        // how the SLAVE completes each channel to test the
        // independent aw_done/w_done tracking in the Manager FSM.
        // ========================================================
        $display("Slave completes AW/W on same cycle vs split cycles...");
        slave_aw_delay = 0; slave_w_delay = 0;
        check_write(32'h0000_0008, 32'hAAAA5555, 4'b1111);   // same-cycle slave response

        slave_aw_delay = 0; slave_w_delay = 3;
        check_write(32'h0000_000C, 32'h5555AAAA, 4'b1111);   // W completes later than AW

        slave_aw_delay = 4; slave_w_delay = 0;
        check_write(32'h0000_0010, 32'h12345678, 4'b1111);   // AW completes later than W
        slave_aw_delay = 0; slave_w_delay = 0;

        // ========================================================
        // BACK-TO-BACK TRANSACTIONS
        // ========================================================
        $display("Back-to-back transactions...");
        for (i = 0; i < 8; i = i + 1)
            check_write(32'h0000_0020 + (i*4), i, 4'b1111);
        for (i = 0; i < 8; i = i + 1)
            check_read(32'h0000_0020 + (i*4));

        // ========================================================
        // INVALID ADDRESS -> SLVERR (manager must still complete)
        // ========================================================
        $display("Invalid address -> SLVERR passthrough...");
        check_write(32'h0000_1000, 32'hBADBADBA, 4'b1111);
        check_read (32'h0000_1000);

        // ========================================================
        // DELAYED SLAVE RANDOM TRAFFIC
        // ========================================================
        $display("");
        $display("Running 1000 randomized transactions with random slave delays...");

        for (i = 0; i < 1000; i = i + 1) begin
            logic [31:0] raddr;
            logic [3:0]  rstrb;
            bit          do_write;

            slave_aw_delay   = $urandom_range(0,3);
            slave_w_delay    = $urandom_range(0,3);
            slave_ar_delay   = $urandom_range(0,3);
            slave_resp_delay = $urandom_range(0,3);

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
        slave_aw_delay = 0; slave_w_delay = 0; slave_ar_delay = 0; slave_resp_delay = 0;

        // ========================================================
        // FINAL REPORT
        // ========================================================
        $display("");
        $display("================================================");
        $display(" AXI_Manager VERIFICATION REPORT");
        $display("================================================");
        $display("Total Tests         = %0d", test_count);
        $display("Passed              = %0d", pass_count);
        $display("Failed              = %0d", fail_count);
        $display("Assertion Failures  = %0d", assertion_failures);
        $display("Functional Coverage = %0.2f%%", cov.get_coverage());
        $display("================================================");
        $display("");

        if ((fail_count == 0) && (assertion_failures == 0))
            $display("******** AXI_Manager VERIFICATION PASSED ********");
        else
            $display("******** AXI_Manager VERIFICATION FAILED ********");

        $display("");
        $finish;
    end

endmodule