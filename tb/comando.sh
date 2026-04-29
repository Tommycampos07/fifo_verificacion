source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh;
#rm -rfv `ls |grep -v ".*\.sv\|.*\.sh"`;

vcs -Mupdate tb_top.sv  -o salida  -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert 

#alias home_dir='/mnt/vol_NFS_rh003/Est_Veri_I_2026/CRUZ_JUAN'

./salida 
#./salida +MODO=1 #OVERFLOW
#./salida +MODO=2 #UNDERFLOW
#./salida +MODO=3 #RESET
#./salida +MODO=1 #SIMULTANEO write/read



