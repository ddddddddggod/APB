module ass_i2c_slave_rx_mmio(
	input clk,
	input rstb,
	input rxempty,
	input [7:0] rxrdata,
	input txfull,

	//apb master
	input [31:0] paddr,
	input [7:0] pwdata,
    input reg tx_valid,
    input reg rd_valid,
    input init_irq,

	output reg [7:0] prdata,
    output [7:0] txwdata

);

parameter [31:0] status_addr = 32'h4000_0000;
parameter [31:0] rxdata_addr = 32'h4000_0004;
parameter [31:0] txdata_addr = 32'h4000_0008; 


//1. status register
wire init 	  = init_irq;
wire rne      = ~rxempty;
wire tnf      = ~txfull;

wire [2:0] status_next;
assign status_next = {tnf, rne, init};
wire status_ena;
assign status_ena = 1'b1;
reg [31:0] status_reg;
always @(posedge clk or negedge rstb) begin
    if (!rstb)
        status_reg <= 32'h0;
    else if (status_ena)
        status_reg <= {29'h0 ,status_next}; 
end


//2. rx  data register (rx->rf)
reg [31:0] rxdata_reg;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        rxdata_reg   <= 32'h0;
    end else begin
        if (rd_valid) begin
            rxdata_reg <= {24'h0,rxrdata};
        end
    end
end

//3. tx data regiser (rf ->tx)
reg [31:0] txdata_reg;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        txdata_reg <= 32'h0;
    end else if (tx_valid) begin
        txdata_reg <= {24'h0,pwdata};  // RF dout
    end
end

//-----------MASTER INTERFACE--------------
always @(*) begin
    case (paddr)
        status_addr: prdata = status_reg[7:0];
        rxdata_addr: prdata = rxdata_reg[7:0];
        txdata_addr: prdata = txdata_reg[7:0];
        default:     prdata = 8'h0;
    endcase
end

assign txwdata = txdata_reg[7:0];

endmodule
