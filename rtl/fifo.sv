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

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end
        else begin
            case ({push, pop})

                2'b10: begin
                    // Solo push
                    if (!full) begin
                        mem[wr_ptr] <= din;
                        wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                        count  <= count + 1;
                    end
                end

                2'b01: begin
                    // Solo pop
                    if (pndng) begin
                        rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                        count  <= count - 1;
                    end
                end

                2'b11: begin
                    // Push y pop simultáneos
                    if (pndng && !full) begin
                        // Sale uno y entra uno: count no cambia
                        mem[wr_ptr] <= din;
                        wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                        rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                    end
                    else if (!pndng) begin
                        // Vacía: el push sí mete dato, pop no saca nada útil
                        mem[wr_ptr] <= din;
                        wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                        count  <= count + 1;
                    end
                    else if (full) begin
                        // Llena: sale uno y entra uno, count no cambia
                        mem[wr_ptr] <= din;
                        wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                        rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                    end
                end

                default: begin
                    // 2'b00: no hacer nada
                end
            endcase
        end
    end

    always_comb begin
        pndng = (count != 0);
        full  = (count == DEPTH);

        if (pndng) begin
            dout = mem[rd_ptr];
        end
        else begin
            dout = '0;
        end
    end

endmodule