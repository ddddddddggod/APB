`timescale 1ns / 1ps

module tb_apb ();

//================================================================
// Clock & Reset
//================================================================
localparam CLK1_FREQ = 33;  // MHz (I2C)
localparam CLK2_FREQ = 100; // MHz (APB)

reg clk1, clk2;
reg reset_n;

initial clk1 = 1'b0;
always #(1000.0/(2.0*CLK1_FREQ)) clk1 = ~clk1;

initial clk2 = 1'b0;
always #(1000.0/(2.0*CLK2_FREQ)) clk2 = ~clk2;

initial begin
    reset_n = 1'b0;
    repeat(10) @(negedge clk1);
    reset_n = 1'b1;
end

//================================================================
// I2C Bus
//================================================================
wire scl, sda;
pullup(sda);
pullup(scl);

//================================================================
// Signal
//================================================================
wire [31:0] paddr;
wire        pwrite, pena, psel, pready;
wire [7:0]  pwdata, prdata;
wire        rdy, request, init;
wire        we, load_addr, inc_addr;
wire [7:0]  rfrdata, rfwdata;
wire        interrupt;
wire [6:0]  addr;

//================================================================
// I2C Master
//================================================================
i2c_master_top u_i2c_master (
    .clk     (clk1),
    .reset_n (reset_n),
    .scl     (scl),
    .sda     (sda)
);

//================================================================
// DUT: ass_i2c_slave
//================================================================
parameter [6:0] dev_adr = 7'h74;

ass_i2c_slave_rx #(.device_address(dev_adr)) u_dut (
    .clk1      (clk1),
    .clk2      (clk2),
    .rstb      (reset_n),
    .scl       (scl),
    .sda       (sda),
    .paddr     (paddr),
    .pwrite    (pwrite),
    .pena      (pena),
    .psel      (psel),
    .pwdata    (pwdata),
    .pready    (pready),
    .prdata    (prdata),
    .interrupt (interrupt)
);

//================================================================
// APB Master
//================================================================
ass_i2c_apb_master u_apb_master (
    .clk       (clk2),
    .rstb      (reset_n),
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

//================================================================
// pkt_ctrl
//================================================================
ass_i2c_pkt_ctrl u_pkt_ctrl (
    .clk       (clk2),
    .rstb      (reset_n),
    .rdy       (rdy),
    .request   (request),
    .init      (init),
    .we        (we),
    .load_addr (load_addr),
    .inc_addr  (inc_addr)
);

//================================================================
// addr logic
//================================================================
ass_i2c_addr u_addr (
    .clk       (clk2),
    .rstb      (reset_n),
    .load_addr (load_addr),
    .inc_addr  (inc_addr),
    .rfrdata   (rfrdata[6:0]),
    .addr      (addr)
);

//================================================================
// RF
//================================================================
ass_i2c_rf u_rf (
    .clk     (clk2),
    .rstb    (reset_n),
    .we      (we),
    .addr    (addr),
    .rfrdata (rfrdata),
    .rfwdata (rfwdata)
);



reg [7:0] rxr;
reg [7:0] rdata;

initial begin
    #50;

    //----------------------------------------------
    // STEP 1: Write Addr 0x0A -> F5, FB, 77, 88
    //----------------------------------------------
    $display("\n[STEP 1] Write: Addr 0x0A -> F5, FB, 77, 88");
    u_i2c_master.start({dev_adr, 1'b0});
    u_i2c_master.byte (8'h0a, 1'b0, 1'b0, rxr);
    u_i2c_master.byte (8'hf5, 1'b0, 1'b0, rxr);
    u_i2c_master.byte (8'hfb, 1'b0, 1'b0, rxr);
    u_i2c_master.byte (8'h77, 1'b0, 1'b0, rxr);
    u_i2c_master.stop (8'h88, 1'b0, 1'b0, rxr);

    #500
    if (u_rf.mem[7'h0a] === 8'hf5) $display("[PASS] Write 0x0A: %h", u_rf.mem[7'h0a]);
    else                            $display("[FAIL] Write 0x0A: Expected F5, Got %h", u_rf.mem[7'h0a]);
    if (u_rf.mem[7'h0b] === 8'hfb) $display("[PASS] Write 0x0B: %h", u_rf.mem[7'h0b]);
    else                            $display("[FAIL] Write 0x0B: Expected FB, Got %h", u_rf.mem[7'h0b]);
    if (u_rf.mem[7'h0c] === 8'h77) $display("[PASS] Write 0x0C: %h", u_rf.mem[7'h0c]);
    else                            $display("[FAIL] Write 0x0C: Expected 77, Got %h", u_rf.mem[7'h0c]);
    if (u_rf.mem[7'h0d] === 8'h88) $display("[PASS] Write 0x0D: %h", u_rf.mem[7'h0d]);
    else                            $display("[FAIL] Write 0x0D: Expected 88, Got %h", u_rf.mem[7'h0d]);

    //----------------------------------------------
    // STEP 2: Set Read Address 0x0A
    //----------------------------------------------
    #50;
    $display("\n[STEP 2] Set Read Address 0x0A");
    u_i2c_master.start({dev_adr, 1'b0});
    u_i2c_master.stop (8'h0a, 1'b0, 1'b0, rxr);

    //----------------------------------------------
    // STEP 3: Read back from 0x0A, 0x0B
    //----------------------------------------------
    #50;
    $display("\n[STEP 3] Read Data from 0x0A...");
    u_i2c_master.start({dev_adr, 1'b1});
    u_i2c_master.byte (8'h00, 1'b1, 1'b0, rdata);
    if (rdata === 8'hf5) $display("[PASS] Read 1st (0x0A): %h", rdata);
    else                 $display("[FAIL] Read 1st (0x0A): Expected F5, Got %h", rdata);
    u_i2c_master.stop (8'h00, 1'b1, 1'b1, rdata);
    if (rdata === 8'hfb) $display("[PASS] Read 2nd (0x0B): %h", rdata);
    else                 $display("[FAIL] Read 2nd (0x0B): Expected FB, Got %h", rdata);

    //----------------------------------------------
    // STEP 4: Write again Addr 0x02 -> 55, AA
    //----------------------------------------------
    #100;
    $display("\n[STEP 4] Write: Addr 0x02 -> 55, AA");
    u_i2c_master.start({dev_adr, 1'b0});
    u_i2c_master.byte (8'h02, 1'b0, 1'b0, rxr);
    u_i2c_master.byte (8'h55, 1'b0, 1'b0, rxr);
    u_i2c_master.stop (8'haa, 1'b0, 1'b0, rxr);

    
    #500
    if (u_rf.mem[7'h02] === 8'h55) $display("[PASS] Write 0x02: %h", u_rf.mem[7'h02]);
    else                            $display("[FAIL] Write 0x02: Expected 55, Got %h", u_rf.mem[7'h02]);
    if (u_rf.mem[7'h03] === 8'haa) $display("[PASS] Write 0x03: %h", u_rf.mem[7'h03]);
    else                            $display("[FAIL] Write 0x03: Expected AA, Got %h", u_rf.mem[7'h03]);

    //----------------------------------------------
    // STEP 5: Repeated START (0x0C 설정 후 Read)
    // 0x0C = STEP 1에서 77 저장
    //----------------------------------------------
    #100;
    $display("\n[STEP 5] Repeated START: Set 0x0C then Read");
    u_i2c_master.start({dev_adr, 1'b0});
    u_i2c_master.byte (8'h0c, 1'b0, 1'b0, rxr);
    u_i2c_master.start({dev_adr, 1'b1});
    u_i2c_master.stop (8'h00, 1'b1, 1'b1, rdata);


    if (rdata === 8'h77) $display("[PASS] Repeated START Read (0x0C): %h", rdata);
    else                 $display("[FAIL] Repeated START Read (0x0C): Expected 77, Got %h", rdata);

    //----------------------------------------------
    // STEP 6: Zero-length Write
    //----------------------------------------------
    #100;
    $display("\n[STEP 6] Zero-length Write: Address only, No data");
    u_i2c_master.start({dev_adr, 1'b0});
    u_i2c_master.stop (8'h00, 1'b0, 1'b0, rxr);


    $display("[CHECK] Slave recovery check...");
    u_i2c_master.start({dev_adr, 1'b0});
    u_i2c_master.byte (8'h20, 1'b0, 1'b0, rxr);
    u_i2c_master.stop (8'h55, 1'b0, 1'b0, rxr);


    if (u_rf.mem[7'h20] === 8'h55) $display("[PASS] Slave recovered, wrote 0x55 to 0x20");
    else                            $display("[FAIL] Slave hang after zero-length write");

    //----------------------------------------------
    // STEP 8: Memory Boundary Overrun (0x7E -> 4 bytes)
    //----------------------------------------------
    #100;
    $display("\n[STEP 8] Boundary Test: Addr 0x7E -> 4 bytes");
    u_i2c_master.start({dev_adr, 1'b0});
    u_i2c_master.byte (8'h7e, 1'b0, 1'b0, rxr);
    u_i2c_master.byte (8'haa, 1'b0, 1'b0, rxr);
    u_i2c_master.byte (8'hbb, 1'b0, 1'b0, rxr);
    u_i2c_master.byte (8'hcc, 1'b0, 1'b0, rxr);
    u_i2c_master.stop (8'hdd, 1'b0, 1'b0, rxr);


    $display("[CHECK] Verifying Memory Boundary...");
    if (u_rf.mem[7'h7e] === 8'haa && u_rf.mem[7'h7f] === 8'hbb)
        $display("[PASS] Normal range 0x7E-0x7F written successfully.");
    else
        $display("[FAIL] Boundary write failed at 0x7E-0x7F.");

    if (u_rf.mem[7'h00] === 8'hcc)
        $display("[INFO] Memory Rollover: 0x80 wrapped to 0x00");
    else
        $display("[INFO] Overrun discarded: saturated at 0x7F");

end

endmodule
