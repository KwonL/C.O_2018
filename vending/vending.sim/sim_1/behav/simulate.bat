@echo off
set xv_path=C:\\Xilinx\\Vivado\\2016.4\\bin
call %xv_path%/xsim vending_machine_tb_behav -key {Behavioral:sim_1:Functional:vending_machine_tb} -tclbatch vending_machine_tb.tcl -view D:/Desktop/C.O_2018/vending/successful_sim.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
