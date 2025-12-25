vlib work
vlog RAM.v cache.v controller.v CacheSystem_top.v tb.v
vsim -voptargs=+acc work.tb
add wave *
add wave -position insertpoint  \
sim:/tb/dut/cache_ctrl/cs \
sim:/tb/dut/cache_ctrl/ns
add wave -position insertpoint  \
sim:/tb/dut/cache_ctrl/cache_mod/way0 \
sim:/tb/dut/cache_ctrl/cache_mod/way1 \
sim:/tb/dut/cache_ctrl/cache_mod/way2 \
sim:/tb/dut/cache_ctrl/cache_mod/way3 \
sim:/tb/dut/cache_ctrl/cache_mod/line_way0 \
sim:/tb/dut/cache_ctrl/cache_mod/line_way1 \
sim:/tb/dut/cache_ctrl/cache_mod/line_way2 \
sim:/tb/dut/cache_ctrl/cache_mod/line_way3 \
sim:/tb/dut/main_memory/mem \
sim:/tb/dut/cache_ctrl/hit
run -all