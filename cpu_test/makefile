CC_FLAGS := -Wall
CC_FLAGS += -std=c++23 -lstdc++ -lm
CC_FLAGS += -O0 
CC_FLGAS += -g

.PHONY: asm run clean

main.o: main.cpp
	cc $(CC_FLAGS) -o main.o main.cpp -c

main.elf: main.o
	cc $(CC_FLAGS) -o main.elf main.o 

build: main.elf

run: build
	./main.elf

asm: main.o
	objdump -D main.o

clean: 
	rm -f *.o
	rm -f main.elf
