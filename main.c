/* Punto de entrada: abre el fichero y arranca el parser */

#include <stdio.h>

extern FILE *yyin;
extern int   yyparse(void);

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Uso: %s <fichero_entrada.mc>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        fprintf(stderr, "Error: no se puede abrir el fichero '%s'\n", argv[1]);
        return 2;
    }

    int resultado = yyparse();

    fclose(yyin);
    return resultado;
}
