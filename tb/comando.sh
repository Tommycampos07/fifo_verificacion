#source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh;
rm -rfv `ls |grep -v ".*\.sv\|.*\.sh"`;
#vcs -Mupdate test_bench.sv  -o salida  -full64 -sverilog  -kdb -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L  -P ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab

#vcs -Mupdate test_bench.sv  -o salida  -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert 

vcs -Mupdate test.sv -o salida  -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert 

alias home_dir='/mnt/vol_NFS_rh003/Est_Veri_I_2026/CRUZ_JUAN'

#./salida -cm line+tgl+cond+fsm+branch+assert;

#verdi -cov -covdir salida.vdb&#verdi -cov -covdir salida.vdb&

