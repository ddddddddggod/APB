module ass_i2c_slave_bit_counter(
    input clk,
    input rstb,
    input count_clr,           
    input shift_rx_en,
    input shift_tx_en,         
    output count_done     
);

    reg [2:0] cnt_reg;

    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            cnt_reg <= 3'd0;
        end else if (count_clr) begin
            cnt_reg <= 3'd0;
        end else if (shift_rx_en || shift_tx_en) begin
            cnt_reg <= cnt_reg + 1'b1;
        end
    end

    assign count_done = (cnt_reg == 3'd7);

endmodule