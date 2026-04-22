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

    typedef mailbox #(trans_fifo) agt_sb_mbx_t;
    typedef mailbox #(trans_fifo) mon_chkr_mbx_t;
    typedef mailbox #(trans_fifo) sb_chkr_mbx_t;

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
        mon_chkr_mbx_t mon_chkr_mbx;

        function new(virtual fifo_if #(WIDTH) vif, mon_chkr_mbx_t mon_chkr_mbx);
            this.vif = vif;
            this.mon_chkr_mbx = mon_chkr_mbx;
        endfunction

        task run();
            trans_fifo #(WIDTH) tr_mon;

            forever begin
                @(posedge vif.clk);

                if (vif.rst || vif.push || vif.pop) begin

                    tr_mon = new();
                    tr_mon.clean();
                    tr_mon.tiempo = $time;

                    if (vif.rst) begin
                        tr_mon.tipo = reset;
                    end
                    else if (vif.push && vif.pop) begin
                        tr_mon.tipo = lectura_escritura;
                        tr_mon.dato = vif.din;
                    end
                    else if (vif.push) begin
                        tr_mon.tipo = escritura;
                        tr_mon.dato = vif.din;
                    end
                    else if (vif.pop) begin
                        tr_mon.tipo = lectura;
                        tr_mon.dato = vif.dout;
                    end
                
                    mon_chkr_mbx.put(tr_mon);
                    tr_mon.print("Monitor envia");
                end
            end
        endtask

    endclass

    class fifo_checker #(parameter int WIDTH = 8, parameter int DEPTH = 8);

        trans_fifo #(WIDTH) trans_obs;
        trans_fifo #(WIDTH) trans_exp;

        mon_chkr_mbx_t mon_chkr_mbx;
        sb_chkr_mbx_t  sb_chkr_mbx;

        int comparaciones;
        int errores;

        function new();

            comparaciones = 0;
            errores = 0;

        endfunction

        task run();

            $display("[%0t] Checker inicializado", $time);

            forever begin

                mon_chkr_mbx.get(trans_obs);
                sb_chkr_mbx.get(trans_exp);

                comparaciones++;

                $display("\n[%0t] Checker compara transaccion #%0d", $time, comparaciones);
                trans_exp.print("Esperada");
                trans_obs.print("Observada");

                if (trans_obs.tipo !== trans_exp.tipo) begin

                    errores++;
                    $display("[%0t] Checker ERROR: tipo observado=%0d esperado=%0d",
                             $time, trans_obs.tipo, trans_exp.tipo);
                end

                else begin
                    case (trans_exp.tipo)

                        reset: begin

                            $display("[%0t] Checker PASS: reset observado correctamente", $time);

                        end

                        escritura: begin
                            if (trans_obs.dato !== trans_exp.dato) begin

                                errores++;
                                $display("[%0t] Checker ERROR escritura: dato observado=%0h esperado=%0h",
                                         $time, trans_obs.dato, trans_exp.dato);

                            end

                            else begin

                                $display("[%0t] Checker PASS: escritura correcta", $time);

                            end
                        end

                        lectura: begin

                            if (trans_obs.dato !== trans_exp.dato) begin

                                errores++;
                                $display("[%0t] Checker ERROR lectura: dato observado=%0h esperado=%0h",
                                         $time, trans_obs.dato, trans_exp.dato);

                            end

                            else begin

                                $display("[%0t] Checker PASS: lectura correcta", $time);

                            end
                        end

                        lectura_escritura: begin

                            if (trans_obs.dato !== trans_exp.dato) begin

                                errores++;
                                $display("[%0t] Checker ERROR lectura_escritura: dato observado=%0h esperado=%0h",
                                         $time, trans_obs.dato, trans_exp.dato);

                            end

                            else begin

                                $display("[%0t] Checker PASS: lectura_escritura correcta", $time);

                            end

                        end

                        default: begin

                            errores++;
                            $display("[%0t] Checker ERROR: tipo no valido", $time);

                        end

                    endcase

                end

            end

        endtask

    endclass

    class scoreboard #(parameter int WIDTH = 8, parameter int DEPTH = 8);

        trans_fifo #(WIDTH) transaccion_esperada;
        trans_fifo #(WIDTH) tr_chk;

        agt_sb_mbx_t agt_sb_mbx;
        sb_chkr_mbx_t sb_chkr_mbx;
        comando_test_sb_mbx test_sb_mbx;

        int transacciones_esperadas;
        int reportes_generados;

        function new();

            transacciones_esperadas = 0;
            reportes_generados = 0;

        endfunction

        task run();

            solicitud_sb solicitud;

            $display("[%0t] Scoreboard inicializado", $time);

            fork
                forever begin
                    agt_sb_mbx.get(transaccion_esperada);

                    tr_chk = new();
                    tr_chk.dato        = transaccion_esperada.dato;
                    tr_chk.retardo     = transaccion_esperada.retardo;
                    tr_chk.tiempo      = transaccion_esperada.tiempo;
                    tr_chk.tipo        = transaccion_esperada.tipo;
                    tr_chk.max_retardo = transaccion_esperada.max_retardo;

                    transacciones_esperadas++;
                    sb_chkr_mbx.put(tr_chk);

                    tr_chk.print("Scoreboard envia esperado");
                end

                forever begin
                    test_sb_mbx.get(solicitud);

                    case (solicitud)
                        reporte: begin

                            reportes_generados++;
                            $display("\n========== REPORTE SCOREBOARD ==========");
                            $display("Reportes generados        = %0d", reportes_generados);
                            $display("Transacciones esperadas   = %0d", transacciones_esperadas);
                            $display("========================================\n");

                        end

                        retardo_promedio: begin

                            reportes_generados++;
                            $display("\n========== REPORTE SCOREBOARD ==========");
                            $display("Retardo promedio: aun no implementado en esta etapa");
                            $display("========================================\n");

                        end

                        default: begin

                            $display("[%0t] Scoreboard ERROR: solicitud no valida", $time);

                        end

                    endcase

                end

            join_none

        endtask

    endclass

    class agent #(parameter int WIDTH = 8, parameter int DEPTH = 8);

        trans_fifo #(WIDTH) transaccion;
        comando_test_agent_mbx tst_agnt_mbx;
        trans_fifo_mbx ant_drvr_mbx;
        agt_sb_mbx_t agt_sb_mbx;

        int num_transacciones;
        int max_retardo;

        function new();

            num_transacciones = 10;
            max_retardo = 10;

        endfunction

        task generar_y_enviar(trans_fifo #(WIDTH) tr);

            trans_fifo #(WIDTH) tr_sb;

            tr.max_retardo = max_retardo;

            ant_drvr_mbx.put(tr);

            tr_sb = new();

            tr_sb.dato        = tr.dato;
            tr_sb.retardo     = tr.retardo;
            tr_sb.tiempo      = tr.tiempo;
            tr_sb.tipo        = tr.tipo;
            tr_sb.max_retardo = tr.max_retardo;

            agt_sb_mbx.put(tr_sb);

            tr.print("Agent envia");

        endtask

        task run();
            instrucciones_agente instruccion;

            $display("[%0t] Agent inicializado", $time);

            forever begin

                tst_agnt_mbx.get(instruccion);

                case (instruccion)

                    trans_aleatoria: begin

                        transaccion = new();

                        assert(transaccion.randomize())
                        else $display("[%0t] ERROR: no se pudo randomizar transaccion", $time);

                        transaccion.tiempo = $time;
                        generar_y_enviar(transaccion);
                    end

                    trans_especifica: begin

                        transaccion = new();
                        transaccion.tipo = escritura;
                        transaccion.dato = 'hA5;
                        transaccion.retardo = 0;
                        transaccion.tiempo = $time;

                        generar_y_enviar(transaccion);
                    end

                    llenado_aleatorio: begin

                        for (int i = 0; i < DEPTH; i++) begin

                            transaccion = new();
                            transaccion.tipo = escritura;

                            assert(transaccion.randomize() with {
                                tipo == escritura;
                                retardo >= 0;
                                retardo <= max_retardo;
                            })
                            else $display("[%0t] ERROR: no se pudo randomizar llenado", $time);

                            transaccion.tiempo = $time;
                            generar_y_enviar(transaccion);

                        end
                    end

                    sec_trans_aleatorias: begin

                        for (int i = 0; i < num_transacciones; i++) begin

                            transaccion = new();

                            assert(transaccion.randomize())
                            else $display("[%0t] ERROR: no se pudo randomizar secuencia", $time);

                            transaccion.tiempo = $time;
                            generar_y_enviar(transaccion);

                        end
                    end

                    default: begin

                        $display("[%0t] Agent ERROR: instruccion no valida", $time);

                    end

                endcase
            end
        endtask

    endclass

    class ambiente #(parameter int WIDTH = 8, parameter int DEPTH = 8);

        virtual fifo_if #(WIDTH) vif;

        driver     #(WIDTH)        drv;
        monitor    #(WIDTH)        mon;
        fifo_checker    #(WIDTH, DEPTH) chkr;
        scoreboard #(WIDTH, DEPTH) sb;
        agent      #(WIDTH, DEPTH) agt;

        comando_test_agent_mbx tst_agnt_mbx;
        comando_test_sb_mbx    tst_sb_mbx;
        trans_fifo_mbx         ant_drvr_mbx;
        agt_sb_mbx_t           agt_sb_mbx;
        mon_chkr_mbx_t         mon_chkr_mbx;
        sb_chkr_mbx_t          sb_chkr_mbx;

        function new(virtual fifo_if #(WIDTH) vif);

            this.vif = vif;

            tst_agnt_mbx = new();
            tst_sb_mbx   = new();
            ant_drvr_mbx = new();
            agt_sb_mbx   = new();
            mon_chkr_mbx = new();
            sb_chkr_mbx  = new();

            drv  = new(vif, ant_drvr_mbx);
            mon  = new(vif, mon_chkr_mbx);
            chkr = new();
            sb   = new();
            agt  = new();

            agt.tst_agnt_mbx = tst_agnt_mbx;
            agt.ant_drvr_mbx = ant_drvr_mbx;
            agt.agt_sb_mbx   = agt_sb_mbx;

            sb.agt_sb_mbx    = agt_sb_mbx;
            sb.sb_chkr_mbx   = sb_chkr_mbx;
            sb.test_sb_mbx   = tst_sb_mbx;

            chkr.mon_chkr_mbx = mon_chkr_mbx;
            chkr.sb_chkr_mbx  = sb_chkr_mbx;

        endfunction

        task run();

            $display("[%0t] Ambiente inicializado", $time);

            fork

                drv.run();
                mon.run();
                chkr.run();
                sb.run();
                agt.run();

            join_none

        endtask

    endclass

    class test #(parameter int WIDTH = 8, parameter int DEPTH = 8);

    ambiente #(WIDTH, DEPTH) amb;
    virtual fifo_if #(WIDTH) vif;

    int num_transacciones;
    int max_retardo;

    instrucciones_agente instr_agent;
    solicitud_sb instr_sb;

    function new(virtual fifo_if #(WIDTH) vif);

        this.vif = vif;

        num_transacciones = 10;
        max_retardo = 10;

        amb = new(vif);

        amb.agt.num_transacciones = num_transacciones;
        amb.agt.max_retardo = max_retardo;

    endfunction

    task run();
        $display("[%0t] Test inicializado", $time);

        fork
            amb.run();
        join_none

        #10;

        instr_agent = llenado_aleatorio;
        amb.tst_agnt_mbx.put(instr_agent);
        $display("[%0t] Test: envia instruccion llenado_aleatorio", $time);

        #50;

        instr_agent = trans_aleatoria;
        amb.tst_agnt_mbx.put(instr_agent);
        $display("[%0t] Test: envia instruccion trans_aleatoria", $time);

        #50;

        instr_agent = trans_especifica;
        amb.tst_agnt_mbx.put(instr_agent);
        $display("[%0t] Test: envia instruccion trans_especifica", $time);

        #50;

        instr_agent = sec_trans_aleatorias;
        amb.tst_agnt_mbx.put(instr_agent);
        $display("[%0t] Test: envia instruccion sec_trans_aleatorias", $time);
        
        #200

        instr_sb = reporte;
        amb.tst_sb_mbx.put(instr_sb);
        $display("[%0t] Test: solicita reporte al scoreboard", $time);

        #50;

    endtask

    endclass

endpackage