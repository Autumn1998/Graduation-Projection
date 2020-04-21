ts=1
tilt=2
bin=1024
out_addr='/home/liutong/eel-'$bin'/'$ts'_mace_'$tilt'.mrc'
in_addr='/home/liutong/BIN_data/eel-tomo4'
#in_addr='/home/liutong/UCSD_data/eel-tomo4-data/eel-tomo4'
a_st=$in_addr'a.st'
a_txbr=$in_addr'a.txbr'
b_st=$in_addr'b.st'
b_txbr=$in_addr'b.txbr'
c_st=$in_addr'c.st'
c_txbr=$in_addr'c.txbr'
d_st=$in_addr'd.st'
d_txbr=$in_addr'd.txbr'
e_st=$in_addr'e.st'
e_txbr=$in_addr'e.txbr'
f_st=$in_addr'f.st'
f_txbr=$in_addr'f.txbr'
g_st=$in_addr'g.st'
g_txbr=$in_addr'g.txbr'
h_st=$in_addr'h.st'
h_txbr=$in_addr'h.txbr'
i_st=$in_addr'i.st'
i_txbr=$in_addr'i.txbr'
j_st=$in_addr'j.st'
j_txbr=$in_addr'j.txbr'
k_st=$in_addr'k.st'
k_txbr=$in_addr'k.txbr'
l_st=$in_addr'l.st'
l_txbr=$in_addr'l.txbr'
m_st=$in_addr'm.st'
m_txbr=$in_addr'm.txbr'
n_st=$in_addr'n.st'
n_txbr=$in_addr'n.txbr'
o_st=$in_addr'o.st'
o_txbr=$in_addr'o.txbr'
p_st=$in_addr'p.st'
p_txbr=$in_addr'p.txbr'

make clean
make
rm $out_addr
#./MAIN -lx 32 -ly 32 -n 2 -s 0.2 -m 0.2 -of /home/liutong/eel-1024/eel_result.mrc -fn 2 ~/UCSD_data/eel-tomo4-data/eel-tomo4a.st ~/UCSD_data/eel-tomo4-data/eel-tomo4a.txbr ~/UCSD_data/eel-tomo4-data/eel-tomo4b.st ~/UCSD_data/eel-tomo4-data/eel-tomo4b.txbr 

#./MAIN -lx 32 -ly 32 -n 30 -s 0.2 -m 0.2 -of $out_addr -fn 1 ~/UCSD_data/eel-tomo4-bin4/eel-tomo4a.st ~/UCSD_data/eel-tomo4-bin4/eel-tomo4a.txbr ~/UCSD_data/eel-tomo4-bin4/eel-tomo4b.st ~/UCSD_data/eel-tomo4-bin4/eel-tomo4b.txbr 

#nvprof ./MAIN -lx 8 -ly 8 -lz 8 -n 1 -s 0.2 -m 0.5 -of $out_addr -fn 2  $a_st $a_txbr $b_st $b_txbr 
if [ $1 == "1" ]; then
	nvprof ./MAIN -lx 8 -ly 8 -lz 8 -ncc 1 -n $ts -s 0.2 -m 0.5 -of $out_addr -fn	$tilt $a_st $a_txbr $b_st $b_txbr $c_st $c_txbr $d_st $d_txbr $e_st $e_txbr $f_st $f_txbr $g_st $g_txbr $h_st $h_txbr $i_st $i_txbr $j_st $j_txbr $k_st $k_txbr $l_st $l_txbr $m_st $m_txbr $n_st $n_txbr $o_st $o_txbr $p_st $p_txbr 
else
	./MAIN -lx 8 -ly 8 -lz 8 -ncc 1 -n $ts -s 0.2 -m 0.5 -of $out_addr -fn	$tilt $a_st $a_txbr $b_st $b_txbr $c_st $c_txbr $d_st $d_txbr $e_st $e_txbr $f_st $f_txbr $g_st $g_txbr $h_st $h_txbr $i_st $i_txbr $j_st $j_txbr $k_st $k_txbr $l_st $l_txbr $m_st $m_txbr $n_st $n_txbr $o_st $o_txbr $p_st $p_txbr 
fi
# ./main  32 5 0.2  /home/liutong/eel-1024/eel-tomo4a.st  /home/liutong/eel-1024/eel-tomo4a_result_10.mrc  /home/liutong/eel-1024/eel-tomo4a.txbr 

