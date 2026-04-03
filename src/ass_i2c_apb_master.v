module ass_i2c_apb_master (
    input             clk,
    input             rstb,
    input             pready,
    input      [7:0]  prdata,
    input             interrupt,
    input      [7:0]  rfwdata,

    // APB Master -> Slave
    output wire [31:0] paddr,
    output wire        pwrite,
    output wire        pena,
    output wire        psel,
    output wire [7:0]  pwdata,

    // pkt_ctrl
    output wire        rdy,
    output wire        request,
    output wire        init,
    output wire [7:0]  rfrdata
);

wire rw_valid;
ass_i2c_apb_master_ctrl u_master_ctrl(
	.clk  		(clk),
	.rstb 		(rstb),
	.pready 	(pready),
	.interrupt  (interrupt),
	.rw_valid 	(rw_valid),
	
	.psel 		(psel),
	.pena 		(pena)
	);

ass_i2c_apb_master_rw u_master_rw(
	.clk 		(clk),
	.rstb 		(rstb),
	.pready 	(pready),
	.prdata     (prdata),
	.interrupt  (interrupt),
	.rfwdata 	(rfwdata),

	.paddr 		(paddr),
	.pwrite 	(pwrite),
	.pwdata 	(pwdata),
	.rdy 		(rdy),
	.request 	(request),
	.init       (init),
	.rfrdata 	(rfrdata),
	.rw_valid 	(rw_valid)
);

endmodule
