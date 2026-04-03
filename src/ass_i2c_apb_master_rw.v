module ass_i2c_apb_master_rw (
    input             clk,
    input             rstb,
    input             pready,
    input      [7:0]  prdata,
    input             interrupt,
    input      [7:0]  rfwdata,

    // APB Master -> Slave
    output reg [31:0] paddr,
    output reg        pwrite,
    output reg [7:0]  pwdata,
    // pkt_ctrl
    output reg        rdy,
    output reg        request,
    output         init,
    //RF & addr
    output reg [7:0]  rfrdata,
    output            rw_valid
);

localparam [1:0] m_idle = 2'd0;
localparam [1:0] m_status = 2'd1;
localparam [1:0] m_read = 2'd2;
localparam [1:0] m_write = 2'd3; 

//paddr
localparam [31:0] status_addr = 32'h4000_0000;
localparam [31:0] rxdata_addr = 32'h4000_0004;
localparam [31:0] txdata_addr = 32'h4000_0008;


reg [1:0] m_state, m_state_n;
//___________next state____________________
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        m_state <= m_idle;
    end else begin           
        m_state <= m_state_n;
    end
end
//____________current state________________
wire initiate = prdata[0];
wire read = prdata[1];
wire write = prdata[2];
always @(*) begin
    m_state_n = m_state;
    case (m_state)
        m_idle: if (interrupt) m_state_n = m_status;
        m_status: begin
            if (initiate) begin
                m_state_n = m_idle;
            end else if (read) begin
                m_state_n = m_read;
            end else if (write) begin
                m_state_n = m_write;
            end else begin
                m_state_n = m_idle;
            end
        end
        m_read: if (pready) m_state_n = m_idle;
        m_write: if (pready) m_state_n = m_idle;
    endcase
end

//______________Output logic________________
assign rw_valid = ((m_state == m_status) && !initiate && (read || write));
always @(posedge clk or negedge rstb) begin
    if (!rstb)
        rfrdata <= 8'h0;
    else if (m_state == m_read && pready)
        rfrdata <= prdata;  // rx data to rf
end

//status init
reg init_r;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        init_r <= 1'b0;
    end else begin
        init_r <= (m_state == m_status) && initiate; 
    end
end
assign init = init_r;

//rdy
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        rdy <= 1'b0;
    end else begin
        rdy <= (m_state == m_read) && pready;
    end
end
//request
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        request <= 1'b0;
    end else begin
        request <= (m_state == m_write) && pready;
    end
end

always @(*) begin
    paddr     = 32'h0;
    pwrite    = 1'b0;
    pwdata    = 8'h0;
    case (m_state)
        m_status: begin
            paddr     = status_addr;
            pwrite    = 1'b0;
            pwdata    = 8'h0;
        end
        m_read: begin
            paddr     = rxdata_addr;
            pwrite    = 1'b0;
            pwdata    = 8'h0;
        end
        m_write: begin
            paddr     = txdata_addr;
            pwrite    = 1'b1;
            pwdata    = rfwdata; //rfrwdata (F/Fx)
        end
    endcase
end

endmodule
