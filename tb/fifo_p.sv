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
    typedef enum {
        llenado_aleatorio, 
        trans_aleatoria, 
        trans_especifica, 
        sec_trans_aleatorias, 
        overflow_dirigido, 
        underflow_dirigido, 
        reset_dirigido,
        patron_bits,
        simultaneo_bajo,
        simultaneo_medio,
        simultaneo_alto,
        reset_llena,
        reset_vacia
    } instrucciones_agente;

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

    trans_fifo #(WIDTH) obs_fifo[$];
    trans_fifo #(WIDTH) aux;
    bit inicio_completado;

    function new(virtual fifo_if #(WIDTH) vif, mon_chkr_mbx_t mon_chkr_mbx);
        this.vif = vif;
        this.mon_chkr_mbx = mon_chkr_mbx;
        this.inicio_completado = 0;
    endfunction

    task run();
        trans_fifo #(WIDTH) tr_mon;

        forever begin
            @(negedge vif.clk);

            if (vif.rst) begin
                obs_fifo.delete();

                if (inicio_completado) begin
                    tr_mon = new();
                    tr_mon.clean();
                    tr_mon.tiempo = $time;
                    tr_mon.tipo   = reset;
                    tr_mon.dato   = '0;
                
                    mon_chkr_mbx.put(tr_mon);
                    tr_mon.print("Monitor envia");

                end
            end

            else if (vif.push && !vif.pop) begin

                tr_mon = new();
                tr_mon.clean();
                tr_mon.tiempo = $time;
                tr_mon.tipo   = escritura;

                if (!vif.full) begin

                    aux = new();
                    aux.clean();
                    aux.tiempo = $time;
                    aux.tipo   = escritura;
                    aux.dato   = vif.din;
                    obs_fifo.push_back(aux);
                
                    tr_mon.dato = vif.din;
                end
                else begin
                    tr_mon.dato = '0;
                end
            
                mon_chkr_mbx.put(tr_mon);
                tr_mon.print("Monitor envia");
                inicio_completado = 1;
            end

            else if (!vif.push && vif.pop) begin

                tr_mon = new();
                tr_mon.clean();
                tr_mon.tiempo = $time;
                tr_mon.tipo   = lectura;
 
                if (vif.pndng && obs_fifo.size() > 0) begin
                    aux = obs_fifo.pop_front();
                    tr_mon.dato = aux.dato;
                end
                else begin
                    tr_mon.dato = '0;
                end
            
                mon_chkr_mbx.put(tr_mon);
                tr_mon.print("Monitor envia");
                inicio_completado = 1;
            
            end

            else if (vif.push && vif.pop) begin

               tr_mon = new();
               tr_mon.clean();
               tr_mon.tiempo = $time;
               tr_mon.tipo   = lectura_escritura;

               if (vif.pndng && obs_fifo.size() > 0) begin

                   aux = obs_fifo.pop_front();
                   tr_mon.dato = aux.dato;

               end
               else begin

                   tr_mon.dato = '0;
               end
            
               if (!vif.full || vif.pndng) begin

                   aux = new();
                   aux.clean();
                   aux.tiempo = $time;
                   aux.tipo   = escritura;
                   aux.dato   = vif.din;
                   obs_fifo.push_back(aux);
               end
            
               mon_chkr_mbx.put(tr_mon);
               tr_mon.print("Monitor envia");
               inicio_completado = 1;
            
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

        trans_fifo #(WIDTH) ref_fifo[$];
        trans_fifo #(WIDTH) ref_aux;

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
                   tr_chk.clean();
                   tr_chk.tipo   = transaccion_esperada.tipo;
                   tr_chk.tiempo = transaccion_esperada.tiempo;

                   case (transaccion_esperada.tipo)

                       escritura: begin

                           ref_aux = new();
                           ref_aux.dato        = transaccion_esperada.dato;
                           ref_aux.retardo     = transaccion_esperada.retardo;
                           ref_aux.tiempo      = transaccion_esperada.tiempo;
                           ref_aux.tipo        = transaccion_esperada.tipo;
                           ref_aux.max_retardo = transaccion_esperada.max_retardo;

                        if (ref_fifo.size() < DEPTH) begin
                            ref_fifo.push_back(ref_aux);
                            tr_chk.dato = transaccion_esperada.dato;
                        end
                        else begin
                            tr_chk.dato = '0;
                        end

                       end
                   
                       lectura: begin

                           if (ref_fifo.size() > 0) begin

                                ref_aux = ref_fifo.pop_front();
                                tr_chk.dato = ref_aux.dato;

                           end

                           else begin

                               tr_chk.dato = '0;

                           end

                       end
                   
                       reset: begin

                           ref_fifo.delete();
                           tr_chk.dato = '0;

                       end
                   
                       lectura_escritura: begin

                           if (ref_fifo.size() > 0) begin

                               ref_aux = ref_fifo.pop_front();
                               tr_chk.dato = ref_aux.dato;

                           end

                           else begin

                               tr_chk.dato = '0;

                           end
                           if (ref_fifo.size() < DEPTH) begin
                           ref_aux = new();
                           ref_aux.dato        = transaccion_esperada.dato;
                           ref_aux.retardo     = transaccion_esperada.retardo;
                           ref_aux.tiempo      = transaccion_esperada.tiempo;
                           ref_aux.tipo        = escritura;
                           ref_aux.max_retardo = transaccion_esperada.max_retardo;
                       
                           ref_fifo.push_back(ref_aux);
                       end
                   
                       default: begin

                           tr_chk.dato = transaccion_esperada.dato;
                       end

                   endcase
               
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

                    overflow_dirigido: begin

                        for (int i = 0; i < DEPTH + 2; i++) begin

                            transaccion = new();
                            transaccion.tipo = escritura;

                            assert(transaccion.randomize() with {

                                tipo == escritura;
                                retardo >= 0;
                                retardo <= max_retardo;
                            })
                            else $display("[%0t] ERROR: no se pudo randomizar overflow_dirigido", $time);

                            transaccion.tiempo = $time;
                            generar_y_enviar(transaccion);

                        end

                    end

                    underflow_dirigido: begin

                        for (int i = 0; i < DEPTH + 2; i++) begin

                            transaccion = new();
                            transaccion.tipo = lectura;
                            transaccion.retardo = 0;
                            transaccion.tiempo = $time;
                            transaccion.dato = '0;

                            generar_y_enviar(transaccion);

                        end

                    end

                    reset_dirigido: begin

                        for (int i = 0; i < 4; i++) begin

                            transaccion = new();
                            transaccion.tipo = escritura;

                            assert(transaccion.randomize() with {

                                tipo == escritura;
                                retardo >= 0;
                                retardo <= max_retardo;
                            })
                            else $display("[%0t] ERROR: no se pudo randomizar reset_dirigido escritura", $time);

                            transaccion.tiempo = $time;
                            generar_y_enviar(transaccion);
                        end

                         // Aplica reset
                        transaccion = new();
                        transaccion.tipo = reset;
                        transaccion.retardo = 0;
                        transaccion.tiempo = $time;
                        transaccion.dato = '0;
                        generar_y_enviar(transaccion);

                        // Intenta una lectura después del reset
                        transaccion = new();
                        transaccion.tipo = lectura;
                        transaccion.retardo = 0;
                        transaccion.tiempo = $time;
                        transaccion.dato = '0;
                        generar_y_enviar(transaccion);

                    end

                    patron_bits: begin

                        begin

                            automatic bit [WIDTH-1:0] patrones[4] = '{
                            
                                8'h00,   // 0000_0000 — todo ceros                            
                                8'h55,   // 0101_0101 — alternancia baja                           
                                8'hAA,   // 1010_1010 — alternancia alta
                                8'hFF    // 1111_1111 — todo unos
                            
                            };
                            
                            for (int i = 0; i < DEPTH; i++) begin

                                transaccion = new();
                                transaccion.tipo    = escritura;
                                transaccion.dato    = patrones[i % 4];
                                transaccion.retardo = 0;   // back-to-back para mayor estrés
                                transaccion.tiempo  = $time;
                                generar_y_enviar(transaccion);

                            end

                            for (int i = 0; i < DEPTH; i++) begin
                                transaccion = new();
                                transaccion.tipo    = lectura;
                                transaccion.retardo = 0;
                                transaccion.tiempo  = $time;
                                transaccion.dato    = '0;
                                generar_y_enviar(transaccion);
                            end
                        end
                    end

                    simultaneo_bajo: begin
                    // Llena hasta DEPTH/4 (nivel bajo ~25%)
                        begin

                            automatic int nivel = DEPTH / 4;                

                            for (int i = 0; i < nivel; i++) begin

                                transaccion = new();
                                transaccion.tipo = escritura;

                                assert(transaccion.randomize() with {
                                    tipo == escritura;
                                    retardo >= 0;
                                    retardo <= max_retardo;
                                }) else $display("[%0t] ERROR randomize simultaneo_bajo", $time);
                                transaccion.tiempo = $time;
                                generar_y_enviar(transaccion);

                            end             

                            // Ahora hace push+pop simultáneos
                            for (int i = 0; i < num_transacciones; i++) begin

                                transaccion = new();

                                assert(transaccion.randomize() with {
                                    tipo == lectura_escritura;
                                    retardo >= 0;
                                    retardo <= max_retardo;
                                }) else $display("[%0t] ERROR randomize simultaneo_bajo lw", $time);
                                transaccion.tiempo = $time;
                                generar_y_enviar(transaccion);
                            end
                        end
                    end             

                    simultaneo_medio: begin
                        // Llena hasta DEPTH/2 (nivel medio ~50%)
                        begin
                            automatic int nivel = DEPTH / 2;                

                            for (int i = 0; i < nivel; i++) begin
                                transaccion = new();
                                transaccion.tipo = escritura;
                                assert(transaccion.randomize() with {
                                    tipo == escritura;
                                    retardo >= 0;
                                    retardo <= max_retardo;
                                }) else $display("[%0t] ERROR randomize simultaneo_medio", $time);
                                transaccion.tiempo = $time;
                                generar_y_enviar(transaccion);
                            end             

                            for (int i = 0; i < num_transacciones; i++) begin
                                transaccion = new();
                                assert(transaccion.randomize() with {
                                    tipo == lectura_escritura;
                                    retardo >= 0;
                                    retardo <= max_retardo;
                                }) else $display("[%0t] ERROR randomize simultaneo_medio lw", $time);
                                transaccion.tiempo = $time;
                                generar_y_enviar(transaccion);
                            end
                        end
                    end             

                    simultaneo_alto: begin
                        // Llena hasta DEPTH-2 (nivel alto, casi llena)
                        begin
                            automatic int nivel = DEPTH - 2;                

                            for (int i = 0; i < nivel; i++) begin
                                transaccion = new();
                                transaccion.tipo = escritura;
                                assert(transaccion.randomize() with {
                                    tipo == escritura;
                                    retardo >= 0;
                                    retardo <= max_retardo;
                                }) else $display("[%0t] ERROR randomize simultaneo_alto", $time);
                                transaccion.tiempo = $time;
                                generar_y_enviar(transaccion);
                            end             

                            for (int i = 0; i < num_transacciones; i++) begin

                                transaccion = new();
                                assert(transaccion.randomize() with {
                                    tipo == lectura_escritura;
                                    retardo >= 0;
                                    retardo <= max_retardo;
                                }) else $display("[%0t] ERROR randomize simultaneo_alto lw", $time);
                                transaccion.tiempo = $time;
                                generar_y_enviar(transaccion);
                            end
                        end
                    end

                    reset_llena: begin
                        // Llena la FIFO completamente, luego aplica reset
                        for (int i = 0; i < DEPTH; i++) begin
                            transaccion = new();
                            transaccion.tipo = escritura;
                            assert(transaccion.randomize() with {
                                tipo == escritura;
                                retardo >= 0;
                                retardo <= max_retardo;
                            }) else $display("[%0t] ERROR randomize reset_llena", $time);
                            transaccion.tiempo = $time;
                            generar_y_enviar(transaccion);
                        end
                    
                        // Reset con FIFO llena (full=1)
                        transaccion = new();
                        transaccion.tipo    = reset;
                        transaccion.retardo = 0;
                        transaccion.tiempo  = $time;
                        transaccion.dato    = '0;
                        generar_y_enviar(transaccion);
                    
                        // Intenta leer después del reset — debe dar underflow
                        transaccion = new();
                        transaccion.tipo    = lectura;
                        transaccion.retardo = 0;
                        transaccion.tiempo  = $time;
                        transaccion.dato    = '0;
                        generar_y_enviar(transaccion);
                    end

                    reset_vacia: begin
                        // Reset directo sin haber escrito nada (FIFO vacía, pndng=0)
                        transaccion = new();
                        transaccion.tipo    = reset;
                        transaccion.retardo = 0;
                        transaccion.tiempo  = $time;
                        transaccion.dato    = '0;
                        generar_y_enviar(transaccion);
                    
                        // Intenta leer — debe dar underflow
                        transaccion = new();
                        transaccion.tipo    = lectura;
                        transaccion.retardo = 0;
                        transaccion.tiempo  = $time;
                        transaccion.dato    = '0;
                        generar_y_enviar(transaccion);
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

    // Parámetros configurables por plusarg
    int  num_transacciones;
    int  max_retardo;
    int  min_retardo;       // NUEVO — para back-to-back con +MIN_RETARDO=0
    int  seed;              // NUEVO — para reproducibilidad con +SEED=1234
    string modo_prueba;

    instrucciones_agente instr_agent;
    solicitud_sb         instr_sb;

    function new(virtual fifo_if #(WIDTH) vif);
        int tmp;

        this.vif = vif;

        // ── Valores por defecto ──────────────────────────────────────
        num_transacciones = 10;
        max_retardo       = 10;
        min_retardo       = 0;
        seed              = 0;
        modo_prueba       = "SIMULTANEO";

        // ── Lectura de plusargs ANTES de crear el ambiente ───────────
        // Cada if lee el plusarg; si no existe, conserva el default
        if ($value$plusargs("MODO=%s",        modo_prueba))    ;
        if ($value$plusargs("NUM_TRANS=%d",   tmp)) num_transacciones = tmp;
        if ($value$plusargs("MAX_RETARDO=%d", tmp)) max_retardo       = tmp;
        if ($value$plusargs("MIN_RETARDO=%d", tmp)) min_retardo       = tmp;
        if ($value$plusargs("SEED=%d",        tmp)) seed              = tmp;

        // ── Validaciones básicas ─────────────────────────────────────
        if (min_retardo > max_retardo) begin
            $display("[TEST] ADVERTENCIA: MIN_RETARDO > MAX_RETARDO, corrigiendo.");
            min_retardo = 0;
        end

        if (num_transacciones <= 0) begin
            $display("[TEST] ADVERTENCIA: NUM_TRANS invalido, usando 10.");
            num_transacciones = 10;
        end

        // ── Semilla para reproducibilidad ────────────────────────────
        // seed=0 significa "no fijar semilla" (aleatorio cada corrida)
        if (seed != 0)
            process::self().srandom(seed);

        // ── Crear ambiente y propagar configuración ──────────────────
        amb = new(vif);
        amb.agt.num_transacciones = num_transacciones;
        amb.agt.max_retardo       = max_retardo;
        amb.agt.min_retardo       = min_retardo;  // se agrega al agent

        // ── Log de configuración ─────────────────────────────────────
        $display("╔══════════════════════════════════════╗");
        $display("║        CONFIGURACION DEL TEST        ║");
        $display("╠══════════════════════════════════════╣");
        $display("║  MODO          = %0s", modo_prueba);
        $display("║  NUM_TRANS     = %0d", num_transacciones);
        $display("║  MAX_RETARDO   = %0d", max_retardo);
        $display("║  MIN_RETARDO   = %0d", min_retardo);
        $display("║  SEED          = %0s", (seed==0) ? "aleatorio" : $sformatf("%0d", seed));
        $display("╚══════════════════════════════════════╝");

    endfunction

    task run();

        $display("[%0t] Test iniciado — modo: %0s", $time, modo_prueba);

        fork
            amb.run();
        join_none

        // Espera a que el reset inicial del tb_top termine
        wait (vif.rst == 0);
        repeat (2) @(posedge vif.clk);

        // ── Despacho según modo ──────────────────────────────────────
        case (modo_prueba)

            "BASE": begin
                instr_agent = llenado_aleatorio;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: llenado_aleatorio", $time);

                instr_agent = trans_aleatoria;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: trans_aleatoria", $time);

                instr_agent = trans_especifica;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: trans_especifica", $time);

                instr_agent = sec_trans_aleatorias;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: sec_trans_aleatorias", $time);
            end

            "OVERFLOW": begin
                instr_agent = overflow_dirigido;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: overflow_dirigido", $time);
            end

            "UNDERFLOW": begin
                instr_agent = underflow_dirigido;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: underflow_dirigido", $time);
            end

            "RESET": begin
                instr_agent = reset_dirigido;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: reset_dirigido", $time);
            end

            "SIMULTANEO": begin
                instr_agent = sec_trans_aleatorias;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: sec_trans_aleatorias (simultaneo)", $time);
            end

            // ── Casos de esquina nuevos ──────────────────────────────
            "PATRON": begin
                instr_agent = patron_bits;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: patron_bits", $time);
            end

            "SIM_BAJO": begin
                instr_agent = simultaneo_bajo;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: simultaneo_bajo", $time);
            end

            "SIM_MEDIO": begin
                instr_agent = simultaneo_medio;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: simultaneo_medio", $time);
            end

            "SIM_ALTO": begin
                instr_agent = simultaneo_alto;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: simultaneo_alto", $time);
            end

            "RESET_LLENA": begin
                instr_agent = reset_llena;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: reset_llena", $time);
            end

            "RESET_VACIA": begin
                instr_agent = reset_vacia;
                amb.tst_agnt_mbx.put(instr_agent);
                $display("[%0t] Test: reset_vacia", $time);
            end

            default: begin
                $display("[%0t] Test ERROR: modo '%0s' no reconocido", $time, modo_prueba);
            end

        endcase

        // ── Tiempo de drenado y reporte final ────────────────────────
        // Espera suficiente para que todas las transacciones terminen
        // Fórmula: (num_trans + DEPTH) * (max_retardo + 4) ciclos * 10ns
        repeat ((num_transacciones + DEPTH) * (max_retardo + 4) + 50) begin
            @(posedge vif.clk);
        end

        instr_sb = reporte;
        amb.tst_sb_mbx.put(instr_sb);
        $display("[%0t] Test: reporte solicitado al scoreboard", $time);

        repeat (10) @(posedge vif.clk);
        $display("[%0t] Test: fin", $time);
        $finish;

    endtask

endclass

endpackage
