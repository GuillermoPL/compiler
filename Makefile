CC       = gcc
LEX      = flex
YACC     = bison

LS_DIR    = codigo_aulavirtual/LS
LC_DIR    = codigo_aulavirtual/LC
PEEP_DIR  = peephole
TESTS_DIR = tests/programas
INT_DIR   = ficheros_intermedios

CFLAGS = -Wall -g -I. -I$(INT_DIR) -I$(LS_DIR) -I$(LC_DIR) -I$(PEEP_DIR)

OBJS = $(INT_DIR)/lex.yy.o \
       $(INT_DIR)/miniC.tab.o \
       $(INT_DIR)/main.o \
       $(INT_DIR)/listaSimbolos.o \
       $(INT_DIR)/listaCodigo.o \
       $(INT_DIR)/peephole.o

.PHONY: all clean test

all: minic

$(INT_DIR):
	mkdir -p $(INT_DIR)

minic: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) -lfl

$(INT_DIR)/miniC.tab.c $(INT_DIR)/miniC.tab.h: miniC.y | $(INT_DIR)
	$(YACC) -d -v -o $(INT_DIR)/miniC.tab.c miniC.y

$(INT_DIR)/lex.yy.c: miniC.l $(INT_DIR)/miniC.tab.h | $(INT_DIR)
	$(LEX) -o $(INT_DIR)/lex.yy.c miniC.l

$(INT_DIR)/lex.yy.o: $(INT_DIR)/lex.yy.c
	$(CC) $(CFLAGS) -c $< -o $@

$(INT_DIR)/miniC.tab.o: $(INT_DIR)/miniC.tab.c
	$(CC) $(CFLAGS) -c $< -o $@

$(INT_DIR)/main.o: main.c | $(INT_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(INT_DIR)/listaSimbolos.o: $(LS_DIR)/listaSimbolos.c $(LS_DIR)/listaSimbolos.h | $(INT_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(INT_DIR)/listaCodigo.o: $(LC_DIR)/listaCodigo.c $(LC_DIR)/listaCodigo.h | $(INT_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(INT_DIR)/peephole.o: $(PEEP_DIR)/peephole.c $(PEEP_DIR)/peephole.h $(LC_DIR)/listaCodigo.h | $(INT_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

test: minic
	sh tests/script_pruebas.sh $(TESTS_DIR)

clean:
	rm -f minic
	rm -rf $(INT_DIR)
	rm -rf tests/salida/ensamblador tests/salida/error tests/salida/out
