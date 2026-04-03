`timescale 1ns/1ps
module tb_master;

reg        clk, rstb, pready, interrupt;
reg  [7:0] prdata, rfwdata;
wire [31:0] paddr;
wire        pwrite, pena, psel, rdy, request, init;
wire [7:0]  pwdata, rfrdata;

//clock
always #5 clk = ~clk;
//dut
ass_i2c_apb_master dut (
    .clk        (clk), 
    .rstb       (rstb), 
    .pready     (pready),
    .prdata     (prdata), 
    .interrupt  (interrupt), 
    .rfwdata    (rfwdata),
    .paddr      (paddr), 
    .pwrite     (pwrite), 
    .pena       (pena), 
    .psel       (psel),
    .pwdata     (pwdata), 
    .rdy        (rdy), 
    .request    (request), 
    .init       (init), 
    .rfrdata    (rfrdata)
);

integer pass_cnt, fail_cnt;

task check;
    input [31:0] got;
    input [31:0] exp;
    input [127:0] msg;
    begin
        if (got === exp) begin
            $display("[PASS] %s | got=%h", msg, got);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s | got=%h  exp=%h", msg, got, exp);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

// -------------------------------------------------------
//   clk1: interrupt=1 → ctrl: idle→setup / rw: idle→status
//   clk2: ctrl: setup→access(psel=1,pena=0) / rw: status→m_write or m_read (combinational)
//   clk3: pena=1 확인 + pready=1 응답
//   clk4: ctrl: access→idle / rw: m_write or m_read → idle
// -------------------------------------------------------

task do_write;
    input [7:0] wdata;
    input [7:0] exp_pwdata;
    begin
        rfwdata = wdata;
        prdata  = 8'b0000_1000;   // tx_ready=1 미리 세팅

        // clk1: interrupt
        @(posedge clk); interrupt = 1;
        @(posedge clk); interrupt = 0;
        // clk2: setup (psel=1, pena=0)
        @(posedge clk);
        // clk3: access (pena=1) → 체크
        @(posedge clk);
        check(pena,    32'h1,         "write pena=1");
        check(psel,    32'h1,         "write psel=1");
        check(paddr,   32'h0000_0008, "write paddr=txdata_addr");
        check(pwrite,  32'h1,         "write pwrite=1");
        check(pwdata,  exp_pwdata,    "write pwdata");
        check(request, 32'h1,         "write request=1");
    pready = 1;
    @(posedge clk); pready = 0; prdata = 0;
    @(posedge clk);                                // ← 한 클럭 더 대기
    check(psel, 32'h0, "psel=0 after write");   // ← 이제 psel=0
    end
endtask

task do_read;
    input [7:0] rx_data;
    input [7:0] exp_rfrdata;
    begin
        prdata = 8'b0000_0100;   // rx_valid=1 미리 세팅

        // clk1: interrupt
        @(posedge clk); interrupt = 1;
        @(posedge clk); interrupt = 0;
        // clk2: setup
        @(posedge clk);
        // clk3: access (pena=1) → check 
        @(posedge clk);
        check(pena,   32'h1,         "read pena=1");
        check(psel,   32'h1,         "read psel=1");
        check(paddr,  32'h0000_0004, "read paddr=rxdata_addr");
        check(pwrite, 32'h0,         "read pwrite=0");
        prdata = rx_data;
        pready = 1;
        @(posedge clk); pready = 0; prdata = 0;
        // clk4: idle 복귀
        @(posedge clk);
        check(rfrdata, exp_rfrdata, "rfrdata latched");
        check(psel,    32'h0,       "psel=0 after read");
        @(posedge clk);
    end
endtask

initial begin
    $dumpfile("tb.vcd"); $dumpvars(0, tb_master);
    clk=0; rstb=0; pready=0; prdata=0; interrupt=0; rfwdata=0;
    pass_cnt=0; fail_cnt=0;

    repeat(3) @(posedge clk);
    rstb = 1;
    @(posedge clk);

    // ===== TC1: Write x3 =====
    $display("\n===== TC1: Write x3 =====");
    do_write(8'hA1, 8'hA1);
    do_write(8'hB2, 8'hB2);
    do_write(8'hC3, 8'hC3);

    // ===== TC2: Read x3 =====
    $display("\n===== TC2: Read x3 =====");
    do_read(8'h11, 8'h11);
    do_read(8'h22, 8'h22);
    do_read(8'h33, 8'h33);

    // ===== TC3: Write/Read  =====
    $display("\n===== TC3: Write/Read =====");
    do_write(8'hAB, 8'hAB);
    do_read (8'hCD, 8'hCD);
    do_write(8'hEF, 8'hEF);
    do_read (8'hBE, 8'hBE);

    // ===== TC4: seq interrupt x4 =====
    $display("\n===== TC4: Seq interrupt x4 =====");
    begin : continuous_int
        integer i;
        for (i = 0; i < 4; i = i + 1)
            do_write(8'hF0 + i, 8'hF0 + i);
    end

    // ===== final =====
    $display("\n===== Result: PASS=%0d  FAIL=%0d =====", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
        $display(">>> ALL PASS <<<");
    else
        $display(">>> SOME FAILED <<<");

    #20;
end

initial begin
    #100000;
    $display("[TIMEOUT] Simulation hung.");
end

endmodule