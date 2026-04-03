module ass_i2c_addr (
    input clk,
    input rstb,
    input load_addr,      
    input inc_addr,       
    input [6:0] rfrdata,      
    output reg [6:0] addr 
);
    
    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            addr <= 7'd0;
        end else if (load_addr) begin
            addr <= rfrdata;     
        end else if (inc_addr) begin
            addr <= addr + 1'b1; 
        end
    end
endmodule
