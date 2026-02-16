CC_FLAGS := -Wall
CC_FLAGS += -std=c++23 -O0 -g

main.o: main.cpp
	cc $(CC_FLAGS) -o main.o main.cpp -c

build: main.o
	cc -o main.elf main.o -g 

asm: main.o
	objdump -D main.o

clean: 
	rm -f *.o
	rm -f main.elf
