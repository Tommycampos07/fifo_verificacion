package fifo_p;

    typedef enum {lectura, escritura, reset, lectura_escritura} tipo_trans;

    class trans_fifo #(parameter int WIDTH = 8);
        rand bit [WIDTH-1:0] dato;
        rand int retardo;
        int tiempo;
        rand tipo_trans tipo;
        int max_retardo;

        constraint const_retardo {
            retardo <= max_retardo;
            retardo >= 0;
        }

        function new(bit [WIDTH-1:0] d = '0, tipo_trans t = lectura, int r = 10);
            this.dato = d;
            this.tiempo = 0;
            this.tipo = t;
            this.max_retardo = r;
            this.retardo = 0;
        endfunction

        function void clean();
            this.dato = '0;
            this.retardo = 0;
            this.tiempo = 0;
            this.tipo = lectura;
        endfunction

        function void print(string tag = "");
            $display("[%0s] tiempo=%0d tipo=%0d retardo=%0d dato=0x%0h",
                     tag, this.tiempo, this.tipo, this.retardo, this.dato);
        endfunction
    endclass

    class trans_sb #(parameter int WIDTH = 8);
        bit [WIDTH-1:0] dato_enviado;
        int tiempo_push;
        int tiempo_pop;
        bit completado;
        bit overflow;
        bit underflow;
        bit reset;
        int latencia;

        function void clean();
            this.dato_enviado = '0;
            this.tiempo_push = 0;
            this.tiempo_pop = 0;
            this.completado = 0;
            this.overflow = 0;
            this.underflow = 0;
            this.reset = 0;
            this.latencia = 0;
        endfunction

        task calc_latencia();
            this.latencia = this.tiempo_pop - this.tiempo_push;
        endtask

        function void print(string tag = "");
            $display("[%0s] dato=%0h t_push=%0d t_pop=%0d cmplt=%0b ovr=%0b und=%0b rst=%0b lat=%0d",
                     tag,
                     this.dato_enviado,
                     this.tiempo_push,
                     this.tiempo_pop,
                     this.completado,
                     this.overflow,
                     this.underflow,
                     this.reset,
                     this.latencia);
        endfunction
    endclass

    typedef enum {retardo_promedio, reporte} solicitud_sb;
    typedef enum {llenado_aleatorio, trans_aleatoria, trans_especifica, sec_trans_aleatorias} instrucciones_agente;

    typedef mailbox #(trans_fifo) trans_fifo_mbx;
    typedef mailbox #(trans_sb) trans_sb_mbx;
    typedef mailbox #(solicitud_sb) comando_test_sb_mbx;
    typedef mailbox #(instrucciones_agente) comando_test_agent_mbx;

endpackage