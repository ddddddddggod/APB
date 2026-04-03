module ass_i2c_slave_rx_ctrl #(parameter [6:0] SLAVE_ADDR = 7'h74) (
    input        clk,
    input        rstb,
    input        start_det,
    input        stop_det,
    input        scl_rising,
    input        scl_falling,
    input        count_done,
    input        sda_in,
    input  [7:0] wdata,
    input        sda_out_bit,
    input        rxfull,
    input        txempty,
    input        init_ack,
    input        request_ack,
    input        rdy_ack,

    output reg   sda_oe,
    output       count_clr,
    output       shift_rx_en,
    output       shift_tx_en,
    output       rxwe,
    output       txre,
    output       load_data,
    output       init_req,
    output       request_req,
    output       rdy_req
);

localparam [2:0] st_idle   = 3'd0;
localparam [2:0] st_rx     = 3'd1;
localparam [2:0] st_rx_ack = 3'd2;
localparam [2:0] st_tx     = 3'd3;
localparam [2:0] st_tx_ack = 3'd4;

reg [2:0] state, state_n;
reg       first_byte, rx_done;

wire addr_match   = (wdata[7:1] == SLAVE_ADDR);
wire rx_ack_fall  = (state == st_rx_ack && scl_falling);
wire tx_ack_fall  = (state == st_tx_ack && scl_falling);
wire rx_rise      = (state == st_rx     && scl_rising);
wire rx_fall      = (state == st_rx     && scl_falling);
wire tx_fall      = (state == st_tx     && scl_falling);

wire write_valid  = !first_byte && addr_match;
wire read_req     = (rx_ack_fall && first_byte && addr_match && wdata[0]);
wire seq_read_req = (tx_ack_fall && sda_in == 1'b0);
wire valid_phase  = first_byte ? addr_match : 1'b1;

//--------CDC ack--------------------
reg [1:0] init_ack_o;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        init_ack_o <= 2'b00;
    end else begin
        init_ack_o <= {init_ack_o[0],init_ack};
    end
end
assign init_ack_r = init_ack_o[1];


reg [1:0] request_ack_o;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        request_ack_o <= 2'b00;
    end else begin
        request_ack_o <= {request_ack_o[0], request_ack};
    end
end
assign request_ack_r = request_ack_o[1];


reg [1:0] rdy_ack_o;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        rdy_ack_o <= 2'b00;
    end else begin
        rdy_ack_o <= {rdy_ack_o[0], rdy_ack};
    end
end
assign rdy_ack_r = rdy_ack_o[1];


//--------CDC request---------------------
assign init = start_det || stop_det;
reg init_r;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        init_r <= 1'b0;
    end else if (init_ack_r) begin
        init_r <= 1'b0;
    end else if (init) begin
        init_r <= 1'b1;
    end
end
assign init_req = init_r;


assign request = read_req || seq_read_req;
reg request_r;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        request_r <= 1'b0;
    end else if (request_ack_r && !request) begin
        request_r <= 1'b0;
    end else if (request) begin
        request_r <= 1'b1;
    end
end
assign request_req = request_r;

wire rdy = rx_fall && rx_done && !first_byte; //write
reg rdy_r;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        rdy_r <= 1'b0;
    end else if (rdy_ack_r) begin
        rdy_r <= 1'b0;
    end else if (rdy) begin
        rdy_r <= 1'b1;
    end
end
assign rdy_req = rdy_r;

//--------current state----------------
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        state <= st_idle;
    end else if (stop_det) begin
        state <= st_idle;
    end else if (start_det) begin
        state <= st_rx;
    end else begin
        state <= state_n;
    end
end


//flag : first_byte
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin 
        first_byte <= 1'b1;
    end else if (init) begin
        first_byte <= 1'b1;
    end else if (rx_ack_fall) begin
        first_byte <= 1'b0;
    end
end

// flag : rx_done 
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        rx_done <= 1'b0;
    end else if (count_clr) begin
        rx_done <= 1'b0;
    end else if (rx_rise && count_done) begin
        rx_done <= 1'b1;
    end
end

//-------Next state-------------------------------------
wire [2:0] ack_next_state = (first_byte && wdata[0]) ? st_tx : st_rx;

always @(*) begin
    state_n = state;
    case (state)
        st_idle:   state_n = st_idle;
        st_rx:     state_n = (scl_falling && rx_done) ? st_rx_ack : st_rx;
        st_rx_ack: state_n = scl_falling ? (valid_phase ? ack_next_state : st_idle) : st_rx_ack;
        st_tx:     state_n = (scl_falling && count_done) ? st_tx_ack : st_tx;
        st_tx_ack: state_n = scl_falling ? ((sda_in == 1'b0) ? st_tx : st_idle) : st_tx_ack;
    endcase
end

//-----------output logic---------------------------------------------
assign rxwe       = rdy & ~rxfull;//rx_fall && rx_done && write_valid & ~rxfull;
assign shift_rx_en = rx_rise;
assign shift_tx_en = tx_fall;
assign count_clr  = rx_ack_fall || tx_ack_fall || (state == st_idle) || init;


// tx_pop
reg txre_o;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        txre_o <= 1'b0;
    end else if (init) begin
        txre_o <= 1'b0;
    end else if (request) begin
        txre_o <= 1'b1;
    end
end
assign txre = txre_o && !txempty;

// load_data delay : data load to serializer
reg txre_r;
always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        txre_r <= 1'b0;
    end else begin
        txre_r <= txre;
    end
end
assign load_data = txre_r;

//sda_oe
always @(*) begin
    if (state == st_rx_ack) begin
        sda_oe = valid_phase;
    end else if (state == st_tx) begin
        sda_oe = ~sda_out_bit;
    end else begin
        sda_oe = 1'b0;
    end
end

endmodule
