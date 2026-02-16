CC_FLAGS := -Wall
CC_FLAGS += -std=c++23 -lstdc++
CC_FLAGS += -O0 
CC_FLGAS += -g

main.o: main.cpp
	cc $(CC_FLAGS) -o main.o main.cpp -c

build: main.o
	cc $(CC_FLAGS) -o main.elf main.o 

asm: main.o
	objdump -D main.o

clean: 
	rm -f *.o
	rm -f main.elf
