all: compile run

run: compile
	./test

compile:
	gcc -g -O0 -Wall -Wextra -I.. test.c ../mh*.o -o test

