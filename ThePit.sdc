# Root clocks and vendor/framework PLL clocks are defined by sys/sys_top.sdc.
# No local derived fabric clocks or multicycle paths. clk_sys is the real 25MHz PLL.
# Async reset sources terminate only at the reset synchronizer's asynchronous controls.
# Do not add a blanket reset or clock-domain exception to the game datapath.
# Inspect the inherited framework exceptions in the Stage C clock/constraint audit.
