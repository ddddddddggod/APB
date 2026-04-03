module ass_i2c_slave_rx_interrupt_gen(
	input clk,
	input rstb,
	input request_req,
	input init_req,
	input rdy_req,
    input rxre,
    input tx_valid,


	output request_ack,
	output init_ack,
	output rdy_ack,
	output interrupt,
    output reg init_irq,
    output init_signal
);

//_________________CDC ACK_____________
reg [1:0] init_req_r;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        init_req_r <= 2'b00;
    end else begin
        init_req_r <= {init_req_r[0], init_req};
    end
end
assign init_ack = init_req_r[1];
assign init_signal = init_req_r[0] & ~init_req_r[1]; //edge detect

reg [1:0] request_req_r;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        request_req_r <= 2'b00;
    end else begin
        request_req_r <= {request_req_r[0], request_req};
    end
end
assign request_ack = request_req_r[1];
assign request_sinal = request_req_r[0] & ~request_req_r[1]; //edge detect


reg [1:0] rdy_req_r;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        rdy_req_r <= 2'b00;
    end else begin
        rdy_req_r <= {rdy_req_r[0], rdy_req};
    end
end
assign rdy_ack = rdy_req_r[1];
assign rdy_signal = rdy_req_r[0] & ~rdy_req_r[1]; //edge detect


//_______________interrupt______________________
//init
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        init_irq <= 1'b0;
    end else if (init_signal) begin
        init_irq <= 1'b1;
    end else begin
        init_irq <= 1'b0;
    end
end

//request
reg request_irq;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        request_irq <= 1'b0;
    end else if (tx_valid) begin
        request_irq <= 1'b0;
    end else if (request_sinal) begin
        request_irq <= 1'b1;
    end
end

//rdy
reg rdy_irq;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        rdy_irq <= 1'b0;
    end else if (rxre) begin
        rdy_irq <= 1'b0;
    end else if (rdy_signal) begin
        rdy_irq <= 1'b1;
    end
end

//_____________________Output logic_________________________________
assign interrupt = rdy_irq || request_irq || init_irq;

endmodule
