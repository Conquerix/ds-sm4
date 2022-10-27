crypto_sim: crypto utils_pkg rnd_pkg axi_memory axi_memory_optimized
crypto: axi_pkg key_expansion master_axi_ctrl slave_axi_ctrl round_function_engine xor_engine
key_expansion: sm4_pkg counter
master_axi_ctrl: sm4_pkg counter
slave_axi_ctrl: sm4_pkg
round_function_engine: sm4_pkg
xor_engine: sm4_pkg
