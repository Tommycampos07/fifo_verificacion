source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh;
#rm -rfv `ls |grep -v ".*\.sv\|.*\.sh"`;

vcs -Mupdate tb_top.sv  -o salida  -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert 

#alias home_dir='/mnt/vol_NFS_rh003/Est_Veri_I_2026/CRUZ_JUAN'

./salida 

#Pruebas generales

#./salida +MODO=OVERFLOW +NUM_TRANS=100 +MAX_RETARDO=1 +MIN_RETARDO=0 #OVERFLOW
#./salida +MODO=SIM_BAJO +NUM_TRANS=80 +MAX_RETARDO=15 +MIN_RETARDO=5 #Baja latencia
#./salida +MODO=UNDERFLOW +NUM_TRANS=100 +SEED=$RANDOM #UNDERFLOW
#./salida +MODO=RESET_LLENA +NUM_TRANS=50 +SEED=12345 #RESET llena con seed especifica
#./salida +MODO=SIM_ALTO +NUM_TRANS=20 +MIN_RETARDO=0 +MAX_RETARDO=0 +SEED=777 #SIMULTANEO alta latencia

#Pruebas de esquina
#./salida +MODO=OVERFLOW +NUM_TRANS=1000 +MIN_RETARDO=0 +MAX_RETARDO=0 +SEED=1 #prueba bandera full
#./salida +MODO=UNDERFLOW +NUM_TRANS=500 +MIN_RETARDO=0 +MAX_RETARDO=1 +SEED=55 #prueba bandera pndng
#./salida +MODO=RESET_LLENA +NUM_TRANS=100 +MIN_RETARDO=0 +MAX_RETARDO=2 +SEED=999 #prueba el reset cuando está full
#./salida +MODO=SIM_MEDIO +NUM_TRANS=150 +MIN_RETARDO=1 +MAX_RETARDO=3 +SEED=42 #alterna full y pndng constantemente


#Pruebas de estrés
#./salida +MODO=OVERFLOW +NUM_TRANS=100 +MAX_RETARDO=3 +MIN_RETARDO=0 #OVERFLOW
#./salida +MODO=SIM_BAJO +NUM_TRANS=800 +MAX_RETARDO=15 +MIN_RETARDO=5 #Baja latencia
#./salida +MODO=UNDERFLOW +NUM_TRANS=500 +SEED=$RANDOM #UNDERFLOW
