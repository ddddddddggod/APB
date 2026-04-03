module ass_i2c_slave_rx_apb_slave(
	input clk,
	input rstb,
	//apb master
	input pwrite,
	input pena,
	input psel,
    input init_signal,

	output reg txwe,
    output reg tx_valid,
    output reg rd_valid,
	output rxre,
	//apb master
	output pready
);


localparam [1:0] apb_idle = 2'd0;
localparam [1:0] apb_setup = 2'd1;
localparam [1:0] apb_access = 2'd2;

reg [1:0] apb_state, apb_state_n;

//next state
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        apb_state <= apb_idle;
    end else if (init_signal) begin
        apb_state <= apb_idle;
    end else begin           
        apb_state <= apb_state_n;
    end
end

//current state
always @(*) begin
    apb_state_n = apb_state;
    case (apb_state)
        apb_idle: apb_state_n = (psel) ? apb_setup : apb_idle;
        apb_setup: apb_state_n = (pena) ? apb_access : apb_setup;
        apb_access: apb_state_n = (pready) ? apb_idle : apb_access; 
    endcase
end

//_____________________Output logic_________________________________
reg rd_valid_r;//wait
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        rd_valid_r <= 1'b0;
    end else begin
        rd_valid_r <= rd_valid;
    end
end
assign pready = (apb_state == apb_access) && (pwrite || rd_valid_r); 
assign rxre = pready & !pwrite; 
assign tx_valid = pwrite && pready; //tx fifo write rdy
assign rd_valid = (apb_state == apb_access) && !pwrite;

always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        txwe <= 1'b0;
    end else begin
        txwe <= tx_valid;
    end
end


endmodule

