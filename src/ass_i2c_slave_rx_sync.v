module ass_i2c_slave_rx_sync(
	input clk,
	input rstb,
	input scl,
	input sda,
	output scl_rising,
	output scl_falling,
	output sda_in,
	output start_det,
	output stop_det
);
	reg [1:0] scl_sync, sda_sync;
	always @(posedge clk or negedge rstb) begin
	  if (!rstb) begin
	    scl_sync <= 2'b11;
	    sda_sync <= 2'b11;
	  end else begin
	    scl_sync <= {scl_sync[0], scl};
	    sda_sync <= {sda_sync[0], sda};
	  end
	end

	// edge detect 
	assign scl_rising  = (scl_sync[1:0] == 2'b01);
	assign scl_falling = (scl_sync[1:0] == 2'b10);
	assign sda_rising  = (sda_sync[1:0] == 2'b01);
	assign sda_falling = (sda_sync[1:0] == 2'b10);

	//stable data
	assign scl_in = scl_sync[1];
	assign sda_in = sda_sync[1];

	// START/STOP detect (SCL high while SDA edge)
	assign start_det = sda_falling && scl_in ;  //scl=HIGH, sda = HIGH->LOW
	assign stop_det  = sda_rising  && scl_in ;   //scl= HIGH , sda = LOW->HIGH

endmodule