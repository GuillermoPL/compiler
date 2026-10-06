/* Analizador sintactico, semantico y generador de codigo MIPS para miniC */

/* Tipos visibles desde el .tab.h (los necesita el lexer) */
%code requires {
    #include "listaCodigo.h"

    /* Atributo de las expresiones: codigo + valor folded + flag de constancia */
    typedef struct {
        ListaC codigo;
        int    valor;
        int    es_const;
    } ExprInfo;
}

%{
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "listaSimbolos.h"
#include "listaCodigo.h"
#include "peephole.h"

extern int  yylex(void);
extern int  yylineno;
extern char *yytext;

void yyerror(const char *msg);

/* Estado del analisis semantico */
Lista tablaSimb;
int contCadenas = 0;
Tipo tipoActual;
int nivelBucle = 0;

int errores_lexicos     = 0;
int errores_sintacticos = 0;
int errores_semanticos  = 0;

/* Estado de la generacion de codigo */
int registros[10] = {0,0,0,0,0,0,0,0,0,0};
int contadorEtiquetas = 1;

#define MAX_BUCLES 100
char *pilaEtiqInicio[MAX_BUCLES];
char *pilaEtiquetasFin[MAX_BUCLES];
int   topeBucles = -1;

/* Prototipos cuyas firmas no usan ExprInfo */
int  perteneceTS(char *nombre);
Tipo obtenerTipoTS(char *nombre);
void insertarTS(char *nombre, Tipo tipo, int valor);
void imprimirTablaSimbolos(void);

char *nuevoRegistro(void);
void  liberarRegistro(char *reg);
void  resetearRegistros(void);
char *obtenerEtiqueta(void);
char *materializarExpr(ListaC *codigo, int *valor, int *es_const);

void emitirInstruccion(ListaC codigo, char *op, char *res, char *arg1, char *arg2);
void emitirLabel(ListaC codigo, char *etiq);
void emitirSyscall(ListaC codigo);
void concatenarYLiberar(ListaC destino, ListaC fuente);

void verificarVarAsignable(char *nombre);
void generarReadVar(ListaC codigo, char *nombre);
void generarPrintEntero(ListaC codigo, char *reg);
void generarPrintCadena(ListaC codigo, char *strLabel);

void iniciar_bucle(void);
void finalizar_bucle(void);
void imprimirCodigo(ListaC codigo);

void   comprobar_nombre_programa(char *nombre);
void   finalizar_programa(char *nombre, ListaC cuerpo);
ListaC concatenar(ListaC a, ListaC b);
void   iniciar_decl_var(void);
void   iniciar_decl_const(void);
ListaC declarar_id(char *nombre);
ListaC sentencia_break(void);
ListaC recuperar_error(void);
ListaC print_string(char *str);
ListaC leer_var(char *nombre);
ListaC leer_var_concat(ListaC prev, char *nombre);
%}

/* Prototipos cuyas firmas usan ExprInfo (definido en %code requires) */
%code {
    ExprInfo generarOpBinaria(ExprInfo izq, ExprInfo der, const char *mipsOp, int valorFold, int plegable);
    ListaC   generarAsignacion(ExprInfo expr, char *nombre);

    ListaC declarar_id_init(char *nombre, ExprInfo expr);
    ListaC asignar_id(char *nombre, ExprInfo expr);
    ListaC if_noelse(ExprInfo cond, ListaC cuerpo);
    ListaC if_else(ExprInfo cond, ListaC then_body, ListaC else_body);
    ListaC bucle_while(ExprInfo cond, ListaC cuerpo);
    ListaC bucle_do_while(ListaC cuerpo, ExprInfo cond);
    ListaC print_expr(ExprInfo expr);

    ExprInfo expr_suma(ExprInfo a, ExprInfo b);
    ExprInfo expr_resta(ExprInfo a, ExprInfo b);
    ExprInfo expr_mul(ExprInfo a, ExprInfo b);
    ExprInfo expr_div(ExprInfo a, ExprInfo b);
    ExprInfo expr_eq(ExprInfo a, ExprInfo b);
    ExprInfo expr_neq(ExprInfo a, ExprInfo b);
    ExprInfo expr_lt(ExprInfo a, ExprInfo b);
    ExprInfo expr_gt(ExprInfo a, ExprInfo b);
    ExprInfo expr_le(ExprInfo a, ExprInfo b);
    ExprInfo expr_ge(ExprInfo a, ExprInfo b);
    ExprInfo expr_neg(ExprInfo e);
    ExprInfo expr_id(char *nombre);
    ExprInfo expr_num(int n);
}

/* Tipos de los simbolos de la gramatica */
%union {
    int      num;
    char    *str;
    ListaC   codigo;
    ExprInfo expr;
}

/* Palabras reservadas */
%token VOID  "void"
%token VAR   "var"
%token CONST "const"
%token INT   "int"
%token IF    "if"
%token ELSE  "else"
%token WHILE "while"
%token DO    "do"
%token PRINT "print"
%token READ  "read"
%token BREAK "break"

/* Puntuacion */
%token PYC    ";"
%token COMA   ","
%token LPAREN "("
%token RPAREN ")"
%token LBRACE "{"
%token RBRACE "}"

/* Operadores aritmeticos */
%token MAS    "+"
%token MENOS  "-"
%token POR    "*"
%token DIV    "/"

/* Operadores relacionales y asignacion */
%token EQ     "=="
%token NEQ    "!="
%token LE     "<="
%token GE     ">="
%token LT     "<"
%token GT     ">"
%token ASIG   "="

/* Tokens con valor semantico */
%token <str> ID     "id"
%token <str> STRING "string"
%token <num> NUM    "number"

/* No terminales (tipos) */
%type <expr>   expression
%type <codigo> statement statement_list
%type <codigo> body declaration id_list id_decl
%type <codigo> print_list print_item read_list

/* Liberacion de atributos al recuperar errores */
%destructor { free($$); }                 <str>
%destructor { if ($$ != NULL) liberaLC($$); } <codigo>

%define parse.error verbose

/* Asociatividad y precedencia */
%nonassoc "==" "!=" "<=" ">=" "<" ">"
%left     "+" "-"
%left     "*" "/"
%precedence SIGNO
%precedence NOELSE
%precedence ELSE

%%

program
    : { /* Inicializacion del estado global del compilador */
        tablaSimb           = creaLS();
        contCadenas         = 0;
        nivelBucle          = 0;
        errores_lexicos     = 0;
        errores_sintacticos = 0;
        errores_semanticos  = 0;
        contadorEtiquetas   = 1;
        topeBucles          = -1;
        resetearRegistros();
      }
      "void" ID                              { comprobar_nombre_programa($3); }
      "(" ")" "{" body "}"                  { finalizar_programa($3, $8); }
    ;

body
    : body declaration                              { $$ = concatenar($1, $2); }
    | body statement                                { $$ = concatenar($1, $2); }
    | %empty                                        { $$ = creaLC(); }
    ;

declaration
    : "var"   tipo { iniciar_decl_var();   } id_list ";"  { $$ = $4; }
    | "const" tipo { iniciar_decl_const(); } id_list ";"  { $$ = $4; }
    ;

tipo
    : "int"
    ;

id_list
    : id_decl                                       { $$ = $1; }
    | id_list "," id_decl                           { $$ = concatenar($1, $3); }
    ;

id_decl
    : ID                                            { $$ = declarar_id($1); }
    | ID "=" expression                             { $$ = declarar_id_init($1, $3); }
    ;

statement
    : ID "=" expression ";"                          { $$ = asignar_id($1, $3); }

    | "{" statement_list "}"                         { $$ = $2; }

    | "if" "(" expression ")" statement %prec NOELSE { $$ = if_noelse($3, $5); }

    | "if" "(" expression ")" statement
      "else" statement                               { $$ = if_else($3, $5, $7); }

    | "while" "(" expression ")"                     { iniciar_bucle(); }
      statement                                      { $$ = bucle_while($3, $6); finalizar_bucle(); }

    | "do"                                           { iniciar_bucle(); }
      statement
      "while" "(" expression ")" ";"                 { $$ = bucle_do_while($3, $6); finalizar_bucle(); }

    | "print" "(" print_list ")" ";"                 { $$ = $3; }

    | "read"  "(" read_list  ")" ";"                 { $$ = $3; }

    | "break" ";"                                    { $$ = sentencia_break(); }

    | error ";"                                      { yyerrok; $$ = recuperar_error(); }

    | error "}"                                      { yyerrok; $$ = recuperar_error(); }
    ;

statement_list
    : statement_list statement                      { $$ = concatenar($1, $2); }
    | %empty                                        { $$ = creaLC(); }
    ;

print_list
    : print_item                                    { $$ = $1; }
    | print_list "," print_item                     { $$ = concatenar($1, $3); }
    ;

print_item
    : expression                                    { $$ = print_expr($1); }
    | STRING                                        { $$ = print_string($1); }
    ;

read_list
    : ID                                            { $$ = leer_var($1); }
    | read_list "," ID                              { $$ = leer_var_concat($1, $3); }
    ;

expression
    : expression "+"  expression                    { $$ = expr_suma($1, $3);  }
    | expression "-"  expression                    { $$ = expr_resta($1, $3); }
    | expression "*"  expression                    { $$ = expr_mul($1, $3);   }
    | expression "/"  expression                    { $$ = expr_div($1, $3);   }
    | expression "==" expression                    { $$ = expr_eq($1, $3);    }
    | expression "!=" expression                    { $$ = expr_neq($1, $3);   }
    | expression "<"  expression                    { $$ = expr_lt($1, $3);    }
    | expression ">"  expression                    { $$ = expr_gt($1, $3);    }
    | expression "<=" expression                    { $$ = expr_le($1, $3);    }
    | expression ">=" expression                    { $$ = expr_ge($1, $3);    }
    | "-" expression %prec SIGNO                    { $$ = expr_neg($2); }
    | "(" expression ")"                            { $$ = $2; }
    | ID                                            { $$ = expr_id($1); }
    | NUM                                           { $$ = expr_num($1); }
    ;

%%

/* Reporta un error sintactico y aumenta el contador */
void yyerror(const char *msg) {
    fprintf(stderr, "Error sintactico en linea %d: %s\n", yylineno, msg);
    errores_sintacticos++;
}

// TABLA DE SIMBOLOS

/* Devuelve 1 si nombre esta declarado en la tabla */
int perteneceTS(char *nombre) {
    PosicionLista p = buscaLS(tablaSimb, nombre);
    return (p != finalLS(tablaSimb));
}

/* Devuelve el tipo asociado a nombre (asume que existe) */
Tipo obtenerTipoTS(char *nombre) {
    PosicionLista p = buscaLS(tablaSimb, nombre);
    if (p == finalLS(tablaSimb)) {
        return VARIABLE;
    }
    Simbolo s = recuperaLS(tablaSimb, p);
    return s.tipo;
}

/* Inserta un simbolo nuevo al final de la tabla */
void insertarTS(char *nombre, Tipo tipo, int valor) {
    Simbolo s;
    s.nombre = nombre;
    s.tipo   = tipo;
    s.valor  = valor;
    insertaLS(tablaSimb, finalLS(tablaSimb), s);
}

/* Vuelca la tabla de simbolos como seccion .data en la salida */
void imprimirTablaSimbolos(void) {
    PosicionLista p;
    Simbolo s;

    printf("##################\n");
    printf("# Seccion de datos\n");
    printf("\t.data\n\n");

    /* Primero las cadenas */
    p = inicioLS(tablaSimb);
    while (p != finalLS(tablaSimb)) {
        s = recuperaLS(tablaSimb, p);
        if (s.tipo == CADENA) {
            printf("$str%d:\n", s.valor);
            printf("\t.asciiz %s\n", s.nombre);
        }
        p = siguienteLS(tablaSimb, p);
    }

    /* Despues variables y constantes */
    p = inicioLS(tablaSimb);
    while (p != finalLS(tablaSimb)) {
        s = recuperaLS(tablaSimb, p);
        if (s.tipo == VARIABLE || s.tipo == CONSTANTE) {
            printf("_%s:\n", s.nombre);
            printf("\t.word 0\n");
        }
        p = siguienteLS(tablaSimb, p);
    }
}

// REGISTROS Y ETIQUETAS

static const char *nombres_registros[10] = {
    "$t0", "$t1", "$t2", "$t3", "$t4", "$t5", "$t6", "$t7", "$t8", "$t9"
};

/* Reserva el primer registro $ti libre */
char *nuevoRegistro(void) {
    int i;
    for (i = 0; i < 10; i++) {
        if (!registros[i]) {
            registros[i] = 1;
            return (char *)nombres_registros[i];
        }
    }
    fprintf(stderr, "Error interno: no hay registros temporales disponibles\n");
    return (char *)nombres_registros[0];
}

/* Marca un registro $ti como libre */
void liberarRegistro(char *reg) {
    if (reg != NULL && strlen(reg) == 3 && reg[0] == '$' && reg[1] == 't' && reg[2] >= '0' && reg[2] <= '9')
    {
        registros[reg[2] - '0'] = 0;
    }
}

/* Marca todos los registros $ti como libres */
void resetearRegistros(void) {
    int i;
    for (i = 0; i < 10; i++) {
        registros[i] = 0;
    }
}

/* Genera y devuelve una nueva etiqueta */
char *obtenerEtiqueta(void) {
    char *aux;
    asprintf(&aux, "$l%d", contadorEtiquetas++);
    return aux;
}

/* Si la expresion es una constante diferida, emite ahora un li y devuelve el registro */
char *materializarExpr(ListaC *codigo, int *valor, int *es_const) {
    if (*es_const) {
        char *reg = nuevoRegistro();
        char *val;
        asprintf(&val, "%d", *valor);
        Operacion o;
        o.op = "li"; o.res = reg; o.arg1 = val; o.arg2 = NULL;
        insertaLC(*codigo, finalLC(*codigo), o);
        guardaResLC(*codigo, reg);
        *es_const = 0;
        return reg;
    }
    return recuperaResLC(*codigo);
}

// EMISION DE CUADRUPLAS

/* Crea una cuadrupla (op,res,arg1,arg2) y la inserta al final de la lista */
void emitirInstruccion(ListaC codigo, char *op, char *res, char *arg1, char *arg2)
{
    Operacion o;
    o.op = op; o.res = res; o.arg1 = arg1; o.arg2 = arg2;
    insertaLC(codigo, finalLC(codigo), o);
}

/* Emite una etiqueta de salto */
void emitirLabel(ListaC codigo, char *etiq) {
    emitirInstruccion(codigo, "label", etiq, NULL, NULL);
}

/* Emite una llamada al sistema */
void emitirSyscall(ListaC codigo) {
    emitirInstruccion(codigo, "syscall", NULL, NULL, NULL);
}

/* Concatena dos listas y libera la fuente */
void concatenarYLiberar(ListaC destino, ListaC fuente) {
    if (fuente != NULL) {
        concatenaLC(destino, fuente);
        liberaLC(fuente);
    }
}

// AYUDAS SEMANTICAS

/* Comprueba que un identificador sea variable declarada (no constante) */
void verificarVarAsignable(char *nombre) {
    if (!perteneceTS(nombre)) {
        fprintf(stderr, "Error semantico en linea %d: %s no declarada\n", yylineno, nombre);
        errores_semanticos++;
    } else if (obtenerTipoTS(nombre) == CONSTANTE) {
        fprintf(stderr, "Error semantico en linea %d: %s es constante\n", yylineno, nombre);
        errores_semanticos++;
    }
}

/* Genera el syscall 5 (read int) y lo guarda en _nombre */
void generarReadVar(ListaC codigo, char *nombre) {
    emitirInstruccion(codigo, "li", "$v0", "5", NULL);
    emitirSyscall(codigo);
    char *varname;
    asprintf(&varname, "_%s", nombre);
    emitirInstruccion(codigo, "sw", "$v0", varname, NULL);
}

/* Genera el syscall 1 (print int) sobre un registro */
void generarPrintEntero(ListaC codigo, char *reg) {
    emitirInstruccion(codigo, "move", "$a0", reg, NULL);
    emitirInstruccion(codigo, "li", "$v0", "1", NULL);
    emitirSyscall(codigo);
}

/* Genera el syscall 4 (print string) sobre una etiqueta de cadena */
void generarPrintCadena(ListaC codigo, char *strLabel) {
    emitirInstruccion(codigo, "la", "$a0", strLabel, NULL);
    emitirInstruccion(codigo, "li", "$v0", "4", NULL);
    emitirSyscall(codigo);
}

// GESTION DE BUCLES

/* Apila las etiquetas de inicio y fin del bucle que empieza */
void iniciar_bucle(void) {
    nivelBucle++;
    topeBucles++;
    if (topeBucles >= MAX_BUCLES) {
        fprintf(stderr, "Error interno: Limite maximo de bucles anidados excedido (%d)\n", MAX_BUCLES);
        exit(3);
    }
    pilaEtiqInicio[topeBucles]   = obtenerEtiqueta();
    pilaEtiquetasFin[topeBucles] = obtenerEtiqueta();
}

/* Desapila las etiquetas del bucle que se cierra */
void finalizar_bucle(void) {
    nivelBucle--;
    topeBucles--;
}

/* Vuelca la lista de cuadruplas como ensamblador en la salida */
void imprimirCodigo(ListaC codigo) {
    PosicionListaC p = inicioLC(codigo);
    while (p != finalLC(codigo)) {
        Operacion o = recuperaLC(codigo, p);
        if (o.op != NULL && strcmp(o.op, "#nop") == 0) {
            p = siguienteLC(codigo, p);
            continue;
        }
        if (o.op != NULL && strcmp(o.op, "label") == 0) {
            printf("%s:\n", o.res);
        } else if (o.op != NULL) {
            printf("\t%s", o.op);
            if (o.res != NULL) {
                printf(" %s", o.res);
                if (o.arg1 != NULL) {
                    printf(", %s", o.arg1);
                    if (o.arg2 != NULL) {
                        printf(", %s", o.arg2);
                    }
                }
            }
            printf("\n");
        }
        p = siguienteLC(codigo, p);
    }
}

// NUCLEO DE OPERACIONES BINARIAS Y ASIGNACIONES

/* Operacion binaria con constant folding: si los dos operandos son constantes
 * propaga el valor sin emitir codigo; si no, materializa y emite mipsOp */
ExprInfo generarOpBinaria(ExprInfo izq, ExprInfo der, const char *mipsOp, int valorFold, int plegable)
{
    ExprInfo res;
    if (plegable) {
        res.codigo   = creaLC();
        res.valor    = valorFold;
        res.es_const = 1;
        liberaLC(izq.codigo);
        liberaLC(der.codigo);
    } else {
        if (izq.es_const){
            materializarExpr(&izq.codigo, &izq.valor, &izq.es_const);
        }
        if (der.es_const)
        {
            materializarExpr(&der.codigo, &der.valor, &der.es_const);
        }   
        res.codigo = izq.codigo;
        concatenaLC(res.codigo, der.codigo);
        char *reg1   = recuperaResLC(izq.codigo);
        char *reg2   = recuperaResLC(der.codigo);
        char *regRes = nuevoRegistro();
        Operacion o;
        o.op  = (char *)mipsOp; o.res = regRes;
        o.arg1 = reg1;          o.arg2 = reg2;
        insertaLC(res.codigo, finalLC(res.codigo), o);
        liberarRegistro(reg1);
        liberarRegistro(reg2);
        guardaResLC(res.codigo, regRes);
        liberaLC(der.codigo);
        res.es_const = 0;
        res.valor    = 0;
    }
    return res;
}

/* Materializa la expresion (si es const) y emite el sw a _nombre */
ListaC generarAsignacion(ExprInfo expr, char *nombre) {
    if (expr.es_const) {
        materializarExpr(&expr.codigo, &expr.valor, &expr.es_const);
    }
    ListaC codigo = expr.codigo;
    char *reg = recuperaResLC(expr.codigo);
    char *varname;
    asprintf(&varname, "_%s", nombre);
    emitirInstruccion(codigo, "sw", reg, varname, NULL);
    liberarRegistro(reg);
    guardaResLC(codigo, NULL);
    return codigo;
}

// ACCIONES SEMANTICAS DEL PROGRAMA

/* Comprueba que el identificador del programa es 'main' */
void comprobar_nombre_programa(char *nombre) {
    if (strcmp(nombre, "main") != 0) {
        fprintf(stderr, "Error semantico en linea %d: id de programa incorrecto\n", yylineno);
        errores_semanticos++;
    }
}

/* Si no hubo errores, vuelca .data, codigo optimizado y exit; siempre imprime el resumen */
void finalizar_programa(char *nombre, ListaC cuerpo) {
    free(nombre);

    if (errores_lexicos == 0 && errores_sintacticos == 0 && errores_semanticos == 0)
    {
        imprimirTablaSimbolos();

        printf("\n###################\n");
        printf("# Seccion de codigo\n");
        printf("\t.text\n");
        printf("\t.globl main\n");
        printf("main:\n");
        if (cuerpo != NULL) {
            peephole_optimize(cuerpo);
            imprimirCodigo(cuerpo);
        }

        printf("\n##############\n");
        printf("# Fin\n");
        printf("\tli $v0, 10\n");
        printf("\tsyscall\n");
    }

    fprintf(stderr, "\nErrores lexicos: %d\n",   errores_lexicos);
    fprintf(stderr, "Errores sintacticos: %d\n", errores_sintacticos);
    fprintf(stderr, "Errores semanticos: %d\n",  errores_semanticos);

    if (cuerpo != NULL){
        liberaLC(cuerpo);
    } 
    liberaLS(tablaSimb);
}

/* Concatena el codigo de dos no terminales y devuelve el resultado */
ListaC concatenar(ListaC a, ListaC b) {
    concatenarYLiberar(a, b);
    return a;
}

// ACCIONES SEMANTICAS DE DECLARACIONES

void iniciar_decl_var(void)   { tipoActual = VARIABLE; }
void iniciar_decl_const(void) { tipoActual = CONSTANTE; }

/* Declara un identificador (sin inicializar). Detecta redeclaraciones y constantes sin valor */
ListaC declarar_id(char *nombre) {
    if (tipoActual == CONSTANTE) {
        fprintf(stderr, "Error semantico en linea %d: constante '%s' sin inicializar\n", yylineno, nombre);
        errores_semanticos++;
        free(nombre);
    } else if (perteneceTS(nombre)) {
        fprintf(stderr, "Error semantico en linea %d: %s ya declarada\n", yylineno, nombre);
        errores_semanticos++;
        free(nombre);
    } else {
        insertarTS(nombre, tipoActual, 0);
    }
    return creaLC();
}
/* Declara un identificador con valor inicial y emite la asignacion */
ListaC declarar_id_init(char *nombre, ExprInfo expr) {
    if (perteneceTS(nombre)) {
        fprintf(stderr, "Error semantico en linea %d: %s ya declarada\n", yylineno, nombre);
        errores_semanticos++;
        liberaLC(expr.codigo);
        free(nombre);
        return creaLC();
    }
    ListaC res = generarAsignacion(expr, nombre);
    insertarTS(nombre, tipoActual, 0);
    return res;
}

// ACCIONES SEMANTICAS DE SENTENCIAS

/* Asignacion: comprueba que el id sea variable y emite el sw */
ListaC asignar_id(char *nombre, ExprInfo expr) {
    verificarVarAsignable(nombre);
    ListaC res = generarAsignacion(expr, nombre);
    free(nombre);
    return res;
}

/* if sin else. Si la condicion es constante, descarta cuerpo o emite directamente */
ListaC if_noelse(ExprInfo cond, ListaC cuerpo) {
    if (cond.es_const && cond.valor == 0) {
        liberaLC(cond.codigo);
        if (cuerpo != NULL){
            liberaLC(cuerpo);
        } 
        return creaLC();
    }
    if (cond.es_const && cond.valor != 0) {
        liberaLC(cond.codigo);
        return (cuerpo != NULL) ? cuerpo : creaLC();
    }

    char *etiqFin = obtenerEtiqueta();
    ListaC res = cond.codigo;
    char *reg = recuperaResLC(cond.codigo);
    emitirInstruccion(res, "beqz", reg, etiqFin, NULL);
    liberarRegistro(reg);

    concatenarYLiberar(res, cuerpo);
    emitirLabel(res, etiqFin);
    guardaResLC(res, NULL);
    return res;
}

/* if-else. Si la condicion es constante, se queda solo con la rama viva */
ListaC if_else(ExprInfo cond, ListaC then_body, ListaC else_body) {
    if (cond.es_const && cond.valor == 0) {
        liberaLC(cond.codigo);
        if (then_body != NULL){
            liberaLC(then_body);
        } 
        return (else_body != NULL) ? else_body : creaLC();
    }
    if (cond.es_const && cond.valor != 0) {
        liberaLC(cond.codigo);
        if (else_body != NULL){
            liberaLC(else_body);
        } 
        return (then_body != NULL) ? then_body : creaLC();
    }

    char *etiqElse = obtenerEtiqueta();
    char *etiqFin  = obtenerEtiqueta();

    ListaC res = cond.codigo;
    char *reg = recuperaResLC(cond.codigo);
    emitirInstruccion(res, "beqz", reg, etiqElse, NULL);
    liberarRegistro(reg);

    concatenarYLiberar(res, then_body);
    emitirInstruccion(res, "b", etiqFin, NULL, NULL);
    emitirLabel(res, etiqElse);
    concatenarYLiberar(res, else_body);
    emitirLabel(res, etiqFin);
    guardaResLC(res, NULL);
    return res;
}

/* while. Si la condicion es constante 0, descarta el bucle entero */
ListaC bucle_while(ExprInfo cond, ListaC cuerpo) {
    char *etiqInicio = pilaEtiqInicio[topeBucles];
    char *etiqFin    = pilaEtiquetasFin[topeBucles];

    if (cond.es_const && cond.valor == 0) {
        liberaLC(cond.codigo);
        if (cuerpo != NULL){
            liberaLC(cuerpo);
        } 
        return creaLC();
    }

    ListaC res = creaLC();
    emitirLabel(res, etiqInicio);

    if (!cond.es_const) {
        concatenaLC(res, cond.codigo);
        char *reg = recuperaResLC(cond.codigo);
        emitirInstruccion(res, "beqz", reg, etiqFin, NULL);
        liberarRegistro(reg);
    }
    liberaLC(cond.codigo);

    concatenarYLiberar(res, cuerpo);
    emitirInstruccion(res, "b", etiqInicio, NULL, NULL);
    emitirLabel(res, etiqFin);
    guardaResLC(res, NULL);
    return res;
}

/* do-while. Si la condicion es constante 0 ejecuta una vez sin saltar */
ListaC bucle_do_while(ListaC cuerpo, ExprInfo cond) {
    char *etiqInicio = pilaEtiqInicio[topeBucles];
    char *etiqFin    = pilaEtiquetasFin[topeBucles];

    ListaC res = creaLC();
    emitirLabel(res, etiqInicio);
    concatenarYLiberar(res, cuerpo);

    if (cond.es_const && cond.valor == 0) {
        liberaLC(cond.codigo);
    } else if (cond.es_const && cond.valor != 0) {
        liberaLC(cond.codigo);
        emitirInstruccion(res, "b", etiqInicio, NULL, NULL);
    } else {
        concatenaLC(res, cond.codigo);
        char *reg = recuperaResLC(cond.codigo);
        emitirInstruccion(res, "bnez", reg, etiqInicio, NULL);
        liberarRegistro(reg);
        liberaLC(cond.codigo);
    }

    emitirLabel(res, etiqFin);
    guardaResLC(res, NULL);
    return res;
}

/* break: salta a la etiqueta de fin del bucle mas interno */
ListaC sentencia_break(void) {
    if (nivelBucle == 0) {
        fprintf(stderr, "Error semantico en linea %d: break fuera de bucle\n", yylineno);
        errores_semanticos++;
        return creaLC();
    }
    ListaC res = creaLC();
    emitirInstruccion(res, "b", pilaEtiquetasFin[topeBucles], NULL, NULL);
    return res;
}

/* Reseteo de estado tras error sintactico (yyerrok queda en la accion de la regla) */
ListaC recuperar_error(void) {
    resetearRegistros();
    return creaLC();
}

// ACCIONES SEMANTICAS DE PRINT

/* Imprime una expresion como entero (syscall 1) */
ListaC print_expr(ExprInfo expr) {
    if (expr.es_const) {
        materializarExpr(&expr.codigo, &expr.valor, &expr.es_const);
    }
    ListaC res = expr.codigo;
    char *reg = recuperaResLC(expr.codigo);
    generarPrintEntero(res, reg);
    liberarRegistro(reg);
    guardaResLC(res, NULL);
    return res;
}

/* Imprime una cadena (syscall 4); reutiliza la entrada en TS si ya existe */
ListaC print_string(char *str) {
    int idCadena;
    PosicionLista p = buscaLS(tablaSimb, str);

    if (p != finalLS(tablaSimb)) {
        Simbolo s = recuperaLS(tablaSimb, p);
        idCadena = s.valor;
        free(str);
    } else {
        contCadenas++;
        insertarTS(str, CADENA, contCadenas);
        idCadena = contCadenas;
    }

    ListaC res = creaLC();
    char *strLabel;
    asprintf(&strLabel, "$str%d", idCadena);
    generarPrintCadena(res, strLabel);
    return res;
}

// ACCIONES SEMANTICAS DE READ

/* read sobre un solo identificador */
ListaC leer_var(char *nombre) {
    verificarVarAsignable(nombre);
    ListaC res = creaLC();
    generarReadVar(res, nombre);
    free(nombre);
    return res;
}

/* read encadenado: anyade el read al final de la lista anterior */
ListaC leer_var_concat(ListaC prev, char *nombre) {
    verificarVarAsignable(nombre);
    generarReadVar(prev, nombre);
    free(nombre);
    return prev;
}

// ACCIONES SEMANTICAS DE EXPRESIONES (con constant folding)

ExprInfo expr_suma(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "add", a.valor + b.valor, a.es_const && b.es_const);
}

ExprInfo expr_resta(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "sub", a.valor - b.valor, a.es_const && b.es_const);
}

ExprInfo expr_mul(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "mul", a.valor * b.valor, a.es_const && b.es_const);
}

/* Division: si el divisor constante es cero, avisa y pliega el resultado a 0. */
ExprInfo expr_div(ExprInfo a, ExprInfo b) {
    int es_div_cero = (b.es_const && b.valor == 0);
    if (es_div_cero){
        fprintf(stderr, "Aviso en linea %d: division por cero en expresion constante.\n", yylineno);
    } 
    return generarOpBinaria(a, b, "div", (a.es_const && b.es_const && !es_div_cero) ? a.valor / b.valor : 0, (a.es_const && b.es_const) || es_div_cero);
}

ExprInfo expr_eq(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "seq", (a.valor == b.valor) ? 1 : 0, a.es_const && b.es_const);
}

ExprInfo expr_neq(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "sne", (a.valor != b.valor) ? 1 : 0, a.es_const && b.es_const);
}

ExprInfo expr_lt(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "slt", (a.valor < b.valor) ? 1 : 0, a.es_const && b.es_const);
}

ExprInfo expr_gt(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "sgt", (a.valor > b.valor) ? 1 : 0, a.es_const && b.es_const);
}

ExprInfo expr_le(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "sle", (a.valor <= b.valor) ? 1 : 0, a.es_const && b.es_const);
}

ExprInfo expr_ge(ExprInfo a, ExprInfo b) {
    return generarOpBinaria(a, b, "sge", (a.valor >= b.valor) ? 1 : 0, a.es_const && b.es_const);
}

/* Menos unario. Pliega si el operando es constante */
ExprInfo expr_neg(ExprInfo e) {
    ExprInfo res;
    if (e.es_const) {
        res.codigo   = creaLC();
        res.valor    = -e.valor;
        res.es_const = 1;
        liberaLC(e.codigo);
        return res;
    }
    res.codigo = e.codigo;
    char *regExpr = recuperaResLC(e.codigo);
    char *regRes  = nuevoRegistro();
    emitirInstruccion(res.codigo, "neg", regRes, regExpr, NULL);
    liberarRegistro(regExpr);
    guardaResLC(res.codigo, regRes);
    res.es_const = 0;
    res.valor    = 0;
    return res;
}

/* Lectura de un identificador. Si no esta declarado emite li 0 para no romper */
ExprInfo expr_id(char *nombre) {
    ExprInfo res;
    res.codigo = creaLC();
    res.es_const = 0;
    res.valor = 0;
    char *reg = nuevoRegistro();

    if (!perteneceTS(nombre)) {
        fprintf(stderr, "Error semantico en linea %d: %s no declarada\n", yylineno, nombre);
        errores_semanticos++;
        emitirInstruccion(res.codigo, "li", reg, "0", NULL);
    } else {
        char *varname;
        asprintf(&varname, "_%s", nombre);
        emitirInstruccion(res.codigo, "lw", reg, varname, NULL);
    }

    guardaResLC(res.codigo, reg);
    free(nombre);
    return res;
}

/* Numero literal: no emite codigo, queda como constante diferida */
ExprInfo expr_num(int n) {
    ExprInfo res;
    res.codigo = creaLC();
    res.valor = n;
    res.es_const = 1;
    return res;
}
