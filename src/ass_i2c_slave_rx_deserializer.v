module ass_i2c_slave_rx_deserializer (
    input clk,
    input rstb,
    input sda_in,
    input shift_rx_en,     
    output [7:0] wdata 
);

    reg [7:0] rx_shift_reg; 

    //RX register
    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            rx_shift_reg <= 8'h00;
        end else if (shift_rx_en) begin
            rx_shift_reg <= {rx_shift_reg[6:0], sda_in};
        end
    end

    assign wdata = rx_shift_reg;         

endmodule