@echo off
set xv_path=D:\\Xilinx\\Vivado\\2016.4\\bin
call %xv_path%/xsim cpu_tb_behav -key {Behavioral:sim_1:Functional:cpu_tb} -tclbatch cpu_tb.tcl -view D:/Users/lkh116/Desktop/C.O_2018/multi_cpu/cpu_tb_behav.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
