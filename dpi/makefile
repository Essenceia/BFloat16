CC_FLAGS := -Wall -std=c++23 
DPI_HEADER_DIR := ../obj_dir
VERILATOR_FLAGS := -I/usr/local/share/verilator/include 
VERILATOR_FLAGS += -I/usr/local/share/verilator/include/vltstd
VERILATOR_FLAGS += -I$(DPI_HEADER_DIR)/.

Vbf16_add_tb__Dpi.o : Vbf16_add_tb__Dpi.cpp 
	g++ $(CC_FLAGS) $(VERILATOR_FLAGS) -o $@ $? -c	

