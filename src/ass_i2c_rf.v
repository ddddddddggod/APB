module ass_i2c_rf (
    input clk,
    input rstb, 
    input we,
    input [6:0] addr,
    input [7:0] rfrdata,
    output [7:0] rfwdata
);
    reg [7:0] mem [0:127]; // 128x8

    //Write
    integer i;
    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            for (i=0; i<128; i=i+1) mem[i] <= 8'h00;
        end else if (we) begin  //we=1 
            mem[addr] <= rfrdata;
        end
    end

    //Read
    assign rfwdata = mem[addr];

endmodule