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

    class driver #(parameter int WIDTH = 8);

        virtual fifo_if #(WIDTH) vif;
        trans_fifo_mbx drv_mbx;

        function new(virtual fifo_if #(WIDTH) vif, trans_fifo_mbx drv_mbx);
            this.vif = vif;
            this.drv_mbx = drv_mbx;
        endfunction

        task run();
            trans_fifo #(WIDTH) tr;

            forever begin
                drv_mbx.get(tr);

                repeat (tr.retardo) @(posedge vif.clk);

                case (tr.tipo)
                    reset: begin
                        @(posedge vif.clk);
                        vif.rst  <= 1'b1;
                        vif.push <= 1'b0;
                        vif.pop  <= 1'b0;
                        vif.din  <= '0;

                        @(posedge vif.clk);
                        vif.rst <= 1'b0;
                    end

                    escritura: begin
                        @(posedge vif.clk);
                        vif.rst  <= 1'b0;
                        vif.push <= 1'b1;
                        vif.pop  <= 1'b0;
                        vif.din  <= tr.dato;

                        @(posedge vif.clk);
                        vif.push <= 1'b0;
                    end

                    lectura: begin
                        @(posedge vif.clk);
                        vif.rst  <= 1'b0;
                        vif.push <= 1'b0;
                        vif.pop  <= 1'b1;

                        @(posedge vif.clk);
                        vif.pop <= 1'b0;
                    end

                    lectura_escritura: begin
                        @(posedge vif.clk);
                        vif.rst  <= 1'b0;
                        vif.push <= 1'b1;
                        vif.pop  <= 1'b1;
                        vif.din  <= tr.dato;

                        @(posedge vif.clk);
                        vif.push <= 1'b0;
                        vif.pop  <= 1'b0;
                    end
                endcase
            end
        endtask

    endclass


    class monitor #(parameter int WIDTH = 8);

        virtual fifo_if #(WIDTH) vif;
        trans_sb_mbx mon_mbx;

        function new(virtual fifo_if #(WIDTH) vif, trans_sb_mbx mon_mbx);
            this.vif = vif;
            this.mon_mbx = mon_mbx;
        endfunction

        task run();
            trans_sb #(WIDTH) tr_sb;

            forever begin
                @(posedge vif.clk);

                tr_sb = new();
                tr_sb.clean();

                if (vif.rst) begin
                    tr_sb.reset = 1'b1;
                    mon_mbx.put(tr_sb);
                end
                else if (vif.push && !vif.pop) begin
                    tr_sb.dato_enviado = vif.din;
                    tr_sb.tiempo_push  = $time;
                    mon_mbx.put(tr_sb);
                end
                else if (vif.pop && !vif.push) begin
                    tr_sb.dato_enviado = vif.dout;
                    tr_sb.tiempo_pop   = $time;
                    mon_mbx.put(tr_sb);
                end
                else if (vif.push && vif.pop) begin
                    tr_sb.dato_enviado = vif.din;
                    tr_sb.tiempo_push  = $time;
                    tr_sb.tiempo_pop   = $time;
                    mon_mbx.put(tr_sb);
                end
            end
        endtask

    endclass

        class checker #(parameter int WIDTH = 8, parameter int DEPTH = 8);

        trans_fifo #(WIDTH) transaccion;
        trans_fifo #(WIDTH) auxiliar;
        trans_sb   #(WIDTH) to_sb;

        trans_fifo emul_fifo[$];

        trans_sb_mbx   chkr_sb_mbx;
        trans_fifo_mbx drv_chkr_mbx;

        int contador_auxiliar;

        function new();
            this.emul_fifo = {};
            this.contador_auxiliar = 0;
        endfunction

        task run();
            $display("[%0t] Checker inicializado", $time);

            forever begin
                to_sb = new();
                to_sb.clean();

                drv_chkr_mbx.get(transaccion);
                transaccion.print("Checker recibe");

                case (transaccion.tipo)

                    lectura: begin
                        if (emul_fifo.size() > 0) begin
                            auxiliar = emul_fifo.pop_front();

                            if (transaccion.dato == auxiliar.dato) begin
                                to_sb.dato_enviado = auxiliar.dato;
                                to_sb.tiempo_push  = auxiliar.tiempo;
                                to_sb.tiempo_pop   = transaccion.tiempo;
                                to_sb.completado   = 1'b1;
                                to_sb.calc_latencia();
                                to_sb.print("Checker: lectura completada");
                            end
                            else begin
                                $display("[%0t] Checker ERROR: dato leido=%0h esperado=%0h",
                                         $time, transaccion.dato, auxiliar.dato);
                            end
                        end
                        else begin
                            to_sb.tiempo_pop = transaccion.tiempo;
                            to_sb.underflow  = 1'b1;
                            to_sb.print("Checker: underflow");
                        end

                        chkr_sb_mbx.put(to_sb);
                    end

                    escritura: begin
                        if (emul_fifo.size() < DEPTH) begin
                            auxiliar = new();
                            auxiliar.dato    = transaccion.dato;
                            auxiliar.tiempo  = transaccion.tiempo;
                            auxiliar.tipo    = transaccion.tipo;
                            auxiliar.retardo = transaccion.retardo;

                            emul_fifo.push_back(auxiliar);

                            to_sb.dato_enviado = auxiliar.dato;
                            to_sb.tiempo_push  = auxiliar.tiempo;
                            to_sb.print("Checker: escritura aceptada");
                        end
                        else begin
                            to_sb.dato_enviado = transaccion.dato;
                            to_sb.tiempo_push  = transaccion.tiempo;
                            to_sb.overflow     = 1'b1;
                            to_sb.print("Checker: overflow");
                        end

                        chkr_sb_mbx.put(to_sb);
                    end

                    reset: begin
                        contador_auxiliar = emul_fifo.size();

                        for (int i = 0; i < contador_auxiliar; i++) begin
                            auxiliar = emul_fifo.pop_front();
                        end

                        to_sb.reset = 1'b1;
                        to_sb.print("Checker: reset");
                        chkr_sb_mbx.put(to_sb);
                    end

                    lectura_escritura: begin
                        // Version inicial simple:
                        // primero intenta lectura y luego escritura.
                        if (emul_fifo.size() > 0) begin
                            auxiliar = emul_fifo.pop_front();

                            if (transaccion.dato == auxiliar.dato) begin
                                to_sb.dato_enviado = auxiliar.dato;
                                to_sb.tiempo_push  = auxiliar.tiempo;
                                to_sb.tiempo_pop   = transaccion.tiempo;
                                to_sb.completado   = 1'b1;
                                to_sb.calc_latencia();
                            end
                            else begin
                                $display("[%0t] Checker ERROR en lectura_escritura: dato leido=%0h esperado=%0h",
                                         $time, transaccion.dato, auxiliar.dato);
                            end
                        end
                        else begin
                            to_sb.underflow = 1'b1;
                        end

                        if (emul_fifo.size() < DEPTH) begin
                            auxiliar = new();
                            auxiliar.dato    = transaccion.dato;
                            auxiliar.tiempo  = transaccion.tiempo;
                            auxiliar.tipo    = escritura;
                            auxiliar.retardo = transaccion.retardo;
                            emul_fifo.push_back(auxiliar);
                        end
                        else begin
                            to_sb.overflow = 1'b1;
                        end

                        to_sb.print("Checker: lectura_escritura");
                        chkr_sb_mbx.put(to_sb);
                    end

                    default: begin
                        $display("[%0t] Checker ERROR: tipo de transaccion no valido", $time);
                    end

                endcase
            end
        endtask

    endclass

        class scoreboard #(parameter int WIDTH = 8);

        trans_sb #(WIDTH) transaccion_entrante;
        trans_sb_mbx chkr_sb_mbx;
        comando_test_sb_mbx test_sb_mbx;

        int transacciones_completadas;
        int overflows;
        int underflows;
        int resets;
        int retardo_total;
        int reportes_generados;

        function new();

            transacciones_completadas = 0;
            overflows = 0;
            underflows = 0;
            resets = 0;
            retardo_total = 0;
            reportes_generados = 0;

        endfunction

        task run();

            $display("[%0t] Scoreboard inicializado", $time);

            forever begin
                chkr_sb_mbx.get(transaccion_entrante);

                if (transaccion_entrante.completado) begin

                    transacciones_completadas++;
                    retardo_total += transaccion_entrante.latencia;

                end

                if (transaccion_entrante.overflow) begin

                    overflows++;

                end

                if (transaccion_entrante.underflow) begin

                    underflows++;

                end

                if (transaccion_entrante.reset) begin

                    resets++;

                end

                transaccion_entrante.print("Scoreboard recibe");

            end
        endtask

        task reporte();
            int retardo_promedio;

            reportes_generados++;

            if (transacciones_completadas > 0) begin

                retardo_promedio = retardo_total / transacciones_completadas;

            end
            else begin

                retardo_promedio = 0;
                
            end

            $display("\n========== REPORTE SCOREBOARD ==========");
            $display("Reportes generados         = %0d", reportes_generados);
            $display("Transacciones completadas  = %0d", transacciones_completadas);
            $display("Overflows                  = %0d", overflows);
            $display("Underflows                 = %0d", underflows);
            $display("Resets                     = %0d", resets);
            $display("Retardo promedio           = %0d", retardo_promedio);
            $display("========================================\n");
        endtask

    endclass

endpackage