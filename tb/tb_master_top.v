`timescale 1ns/1ps
module tb_master_top;


reg        clk, rstb, pready, interrupt;
reg  [7:0] prdata;

wire [31:0] paddr;
wire        pwrite, pena, psel;
wire [7:0]  pwdata;wire        rdy, request, init;
wire [7:0]  rfrdata;
wire [7:0]  rfwdata;
wire        we, load_addr, inc_addr;
wire [6:0]  addr;

// -------------------------------------------------------
// dut
// -------------------------------------------------------
ass_i2c_apb_master u_master (
    .clk       (clk),
    .rstb      (rstb),
    .pready    (pready),
    .prdata    (prdata),
    .interrupt (interrupt),
    .rfwdata   (rfwdata),
    .paddr     (paddr),
    .pwrite    (pwrite),
    .pena      (pena),
    .psel      (psel),
    .pwdata    (pwdata),
    .rdy       (rdy),
    .request   (request),
    .init      (init),
    .rfrdata   (rfrdata)
);
ass_i2c_pkt_ctrl u_pkt_ctrl (
    .clk       (clk),
    .rstb      (rstb),
    .rdy       (rdy),
    .request   (request),
    .init      (init),
    .we        (we),
    .load_addr (load_addr),
    .inc_addr  (inc_addr)
);
ass_i2c_addr u_addr (
    .clk      (clk),
    .rstb     (rstb),
    .load_addr(load_addr),
    .inc_addr (inc_addr),
    .rfrdata  (rfrdata[6:0]),
    .addr     (addr)
);
ass_i2c_rf u_rf (
    .clk     (clk),
    .rstb    (rstb),
    .we      (we),
    .addr    (addr),
    .rfrdata (rfrdata),
    .rfwdata (rfwdata)
);
always #5 clk = ~clk;

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
// do_read: 
// -------------------------------------------------------
task do_read;
    input [7:0] rx_data;
    input       check_rf; // 1이면 rf mem 저장 확인
    input [6:0] exp_addr; // rf 저장 확인할 주소
    begin
        prdata = 8'b0000_0010; // status[1]=read

        @(posedge clk); interrupt = 1;
        @(posedge clk); interrupt = 0;
        @(posedge clk);  // setup
        @(posedge clk); // access (pena=1)
        check(pena,   32'h1,         "read pena=1");
        check(psel,   32'h1,         "read psel=1");
        check(paddr,  32'h4000_0004, "read paddr=rxdata_addr");
        check(pwrite, 32'h0,         "read pwrite=0");
        prdata = rx_data;
        pready = 1;
        @(posedge clk); //access
         pready = 0; prdata = 0;
        @(posedge clk); //idle
        check(rfrdata, rx_data, "rfrdata latched in register");
        
        @(posedge clk); //
        check(psel,    32'h0,   "psel=0 after read");
        if (check_rf)
            check(u_rf.mem[exp_addr], rx_data, "rf mem written");
    end
endtask
task do_write;
    input [7:0] exp_pwdata;
    begin
        prdata = 8'b0000_0100; // status[2]=write

        @(posedge clk); interrupt = 1;
        @(posedge clk); interrupt = 0;
        @(posedge clk);  // setup
        @(posedge clk);
        // access (pena=1)
        check(pena,    32'h1,         "write pena=1");
        check(psel,    32'h1,         "write psel=1");
        check(paddr,   32'h4000_0008, "write paddr=txdata_addr");
        check(pwrite,  32'h1,         "write pwrite=1");
        check(pwdata,  exp_pwdata,    "write pwdata=rfwdata");
        pready = 1;
        @(posedge clk); pready = 0; prdata = 0;
        @(posedge clk);
        check(request, 32'h1, "write request=1");
        check(psel, 32'h0, "psel=0 after write");
        #1;
    end
endtask

initial begin
    clk=0; rstb=0; pready=0; prdata=0; interrupt=0;
    pass_cnt=0; fail_cnt=0;

    repeat(3) @(posedge clk);
    rstb = 1;
    @(posedge clk);
    
    // ===== TC1: Read x3 =====
    $display("\n===== TC1: Read x3 =====");
    do_read(8'h11, 0, 7'd0);  // 1번째: rf 체크 안함 (pkt_idle→pkt_addr)
    do_read(8'h22, 0, addr);  // 2번째: rf 체크 안함 (주소 로드 타이밍)
    do_read(8'h33, 1, addr);  // 3번째: rf 체크 (pkt_data 도달, we=1)

    // ===== TC2: Write x3 =====
    $display("\n===== TC2: Write x3  =====");
    u_rf.mem[addr] = 8'hA1;
    do_write(8'hA1);
    u_rf.mem[addr] = 8'hB2;
    do_write(8'hB2);
    u_rf.mem[addr] = 8'hC3;
    do_write(8'hC3);
    
    // ===== TC3: Read/Write  =====
    $display("\n===== TC3: Read/Write =====");
    do_read(8'hAB, 1, addr);
    u_rf.mem[addr] = 8'hCD;
    do_write(8'hCD);
    do_read(8'hEF, 1, addr);
    u_rf.mem[addr] = 8'hBE;
    do_write(8'hBE);

    // ===== TC4:seq Read 4회 → addr 증가 확인 =====
    $display("\n===== TC4: seq Read x4 =====");
    begin : addr_test
        integer i;
        reg [6:0] prev_addr;
        for (i = 0; i < 4; i = i + 1) begin
            prev_addr = addr;
            do_read(8'hF0 + i, 1, prev_addr);
            check(addr, prev_addr + 1, "addr incremented");
        end
    end

    // ===== final result =====
    $display("\n===== Result: PASS=%0d  FAIL=%0d =====", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
        $display(">>> ALL PASS <<<");
    else
        $display(">>> SOME FAILED <<<");

end


endmodule
