%{
/* Analizador lexico para miniC */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <errno.h>
#include "miniC.tab.h"

/* Linea donde comienza una estructura multilinea (comentario o cadena) */
int inicio_estructura = 0;

/* Contador de errores definido en miniC.y */
extern int errores_lexicos;
%}

/* Opciones de flex */
%option yylineno

/* Macros */
DIGITO      [0-9]
LETRA       [a-zA-Z_]
IDENT       {LETRA}({LETRA}|{DIGITO})*
ENTERO      {DIGITO}+
PANICO      [^ \t\n\ra-zA-Z0-9_"=;,+\-*/(){}<>]+

/* Contextos exclusivos, diferentes automatas */
%x COMENTARIO
%x CADENA

%%

 /* Blancos y comentarios */
[ \t\r\n]+          { /* ignorar */ }
"//".*              { /* comentario de linea */ }
"/*"                { BEGIN(COMENTARIO); inicio_estructura = yylineno; }

<COMENTARIO>"*/"    { BEGIN(INITIAL); }
<COMENTARIO>(.|\n)  { /* consumir cuerpo */ }
<COMENTARIO><<EOF>> {
    fprintf(stderr, "Error lexico en linea %d: comentario iniciado en linea %d no cerrado.\n",
            yylineno, inicio_estructura);
    errores_lexicos++;
    return 0;
}

 /* Cadenas de caracteres */
\"                  { BEGIN(CADENA); yymore(); inicio_estructura = yylineno; }

<CADENA>\"          {
    BEGIN(INITIAL);
    yylval.str = strdup(yytext);
    return STRING;
}
<CADENA>\\\"        { yymore(); }
<CADENA>\\\\        { yymore(); }
<CADENA>\\n         { yymore(); }
<CADENA>\\t         { yymore(); }
<CADENA>\\r         { yymore(); }
<CADENA>\n          {
    fprintf(stderr, "Error lexico en linea %d: cadena no cerrada (salto de linea inesperado).\n",
            yylineno);
    errores_lexicos++;
    BEGIN(INITIAL);
}
<CADENA>.           { yymore(); }
<CADENA><<EOF>>     {
    fprintf(stderr, "Error lexico en linea %d: cadena iniciada en linea %d no cerrada.\n",
            yylineno, inicio_estructura);
    errores_lexicos++;
    return 0;
}

 /* Palabras reservadas (antes que el patron de identificadores) */
"void"              { return VOID;  }
"var"               { return VAR;   }
"const"             { return CONST; }
"if"                { return IF;    }
"else"              { return ELSE;  }
"while"             { return WHILE; }
"print"             { return PRINT; }
"read"              { return READ;  }
"int"               { return INT;   }
"do"                { return DO;    }
"break"             { return BREAK; }

 /* Caracteres especiales y operadores aritmeticos */
";"                 { return PYC;    }
","                 { return COMA;   }
"("                 { return LPAREN; }
")"                 { return RPAREN; }
"{"                 { return LBRACE; }
"}"                 { return RBRACE; }
"+"                 { return MAS;    }
"-"                 { return MENOS;  }
"*"                 { return POR;    }
"/"                 { return DIV;    }

 /* Relacionales de dos caracteres (antes que los de uno) */
"=="                { return EQ;   }
"!="                { return NEQ;  }
"<="                { return LE;   }
">="                { return GE;   }

 /* Operadores de un caracter */
"="                 { return ASIG; }
"<"                 { return LT; }
">"                 { return GT; }

 /* Identificadores (maximo 32 caracteres) */
{IDENT}             {
    if (yyleng > 32) {
        fprintf(stderr, "Error lexico en linea %d: identificador '%s' excede 32 caracteres.\n",
                yylineno, yytext);
        errores_lexicos++;
        yytext[32] = '\0';
    }
    yylval.str = strdup(yytext);
    return ID;
}

 /* Numeros enteros (0..2^31) */
{ENTERO} {
    errno = 0;
    long val = strtol(yytext, NULL, 10);
    if (errno == ERANGE || val > 2147483647L) {
        fprintf(stderr, "Error lexico en linea %d: constante '%s' fuera de rango.\n",
                yylineno, yytext);
        errores_lexicos++;
        yylval.num = 0;
    } else {
        yylval.num = (int)val;
    }
    return NUM;
}

 /* Modo panico: cualquier secuencia de simbolos no reconocidos */
{PANICO}            {
    fprintf(stderr, "Error lexico en linea %d: simbolo(s) no reconocido(s) '%s'\n",
            yylineno, yytext);
    errores_lexicos++;
}

%%
