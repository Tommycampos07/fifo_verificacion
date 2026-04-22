package fifo_p;

    typedef enum {lectura, escritura, lectura_escritura, reset} tipo_trans;

    class trans_fifo #(parameter WIDTH = 8);
        rand tipo_trans tipo;
        rand bit [WIDTH-1:0] dato;
        rand int retardo;

        constraint c_retardo {
            retardo >= 0;
            retardo <= 10;
        }

        function void print(string tag = "");
            $display("[%0s] tipo=%0d dato=0x%0h retardo=%0d",
                     tag, tipo, dato, retardo);
        endfunction
    endclass

    class trans_sb #(parameter WIDTH = 8);
        bit [WIDTH-1:0] dato_enviado;
        int tiempo_push;
        int tiempo_pop;
        bit completado;
        bit overflow;
        bit underflow;
        bit reset;
        int latencia;

        function void clean();
            dato_enviado = '0;
            tiempo_push  = 0;
            tiempo_pop   = 0;
            completado   = 0;
            overflow     = 0;
            underflow    = 0;
            reset        = 0;
            latencia     = 0;
        endfunction
    endclass

    typedef mailbox #(trans_fifo) trans_fifo_mbx;
    typedef mailbox #(trans_sb)   trans_sb_mbx;

endpackage