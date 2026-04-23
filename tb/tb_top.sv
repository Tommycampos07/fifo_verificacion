`timescale 1ns/1ps

`include "fifo.sv"
`include "fifo_p.sv"
`include "fifo_if.sv"

module tb_top;

    parameter int WIDTH = 8;
    parameter int DEPTH = 8;

    fifo_if #(WIDTH) fifo_vif();

    fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (

        .clk   (fifo_vif.clk),
        .rst   (fifo_vif.rst),
        .push  (fifo_vif.push),
        .pop   (fifo_vif.pop),
        .din   (fifo_vif.din),
        .dout  (fifo_vif.dout),
        .pndng (fifo_vif.pndng),
        .full  (fifo_vif.full)

    );

    test #(WIDTH, DEPTH) tst;

    initial begin

        fifo_vif.clk = 0;

        forever #5 fifo_vif.clk = ~fifo_vif.clk;

    end

    initial begin
        
    fifo_vif.rst  = 1;
    fifo_vif.push = 0;
    fifo_vif.pop  = 0;
    fifo_vif.din  = '0;

    repeat (2) begin
        @(posedge fifo_vif.clk);
    end

    fifo_vif.rst = 0;

    end

    initial begin

        tst = new(fifo_vif);
        tst.run();

    end

    initial begin
        
       #1000
        $display("[%0t] Fin de simulacion por timeout", $time);
        $finish;

    end

endmodule
