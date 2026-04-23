module fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 8,
    localparam int ADDR_W = $clog2(DEPTH)
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             push,
    input  logic             pop,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout,
    output logic             pndng,
    output logic             full
);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_W-1:0] wr_ptr;
    logic [ADDR_W-1:0] rd_ptr;
    logic [ADDR_W:0]   count;

    assign pndng = (count != 0);
    assign full  = (count == DEPTH);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            dout   <= '0;
        end
        else begin
            case ({push, pop})

                2'b10: begin
                    if (!full) begin
                        mem[wr_ptr] <= din;
                        wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                        count  <= count + 1;

                        if (!pndng)
                            dout <= din;
                    end
                end

                2'b01: begin
                    if (pndng) begin
                        dout <= mem[rd_ptr];
                        rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                        count  <= count - 1;
                    end
                    else begin
                        dout <= '0;
                    end
                end

                2'b11: begin
                    if (pndng && !full) begin
                        dout <= mem[rd_ptr];
                        mem[wr_ptr] <= din;
                        wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                        rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                    end
                    else if (!pndng) begin
                        mem[wr_ptr] <= din;
                        wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                        count  <= count + 1;
                        dout   <= din;
                    end
                    else if (full) begin
                        dout <= mem[rd_ptr];
                        mem[wr_ptr] <= din;
                        wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                        rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                    end
                end

                default: begin
                end
            endcase
        end
    end

endmodule