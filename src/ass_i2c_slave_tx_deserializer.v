module ass_i2c_slave_tx_deserializer (
    input clk,
    input rstb,
    input shift_tx_en,   
    input load_data,     
    input [7:0] txrdata, 
    output sda_out_bit   
);

    reg [7:0] tx_shift_reg;

    //TX register
    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            tx_shift_reg <= 8'h00;
        end else if (load_data) begin
            tx_shift_reg <= txrdata; 
        end else if (shift_tx_en) begin
            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
        end
    end        
    assign sda_out_bit = tx_shift_reg[7];

endmodule