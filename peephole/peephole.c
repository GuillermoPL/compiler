/* Optimizaciones peephole sobre la lista de codigo MIPS */

#include "peephole.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// AUXILIARES

/* Devuelve el exponente si val > 0 es potencia de 2, o -1 en otro caso */
static int es_potencia_de_2(int val) {
    if (val <= 0) return -1;
    int exp = 0;
    while (val > 1) {
        if (val % 2 != 0) return -1;
        val /= 2;
        exp++;
    }
    return exp;
}

/* Comprueba si la operacion es "li REG, NUMERO" y, si lo es, escribe el numero en *valor */
static int es_li_con_valor(Operacion o, int *valor) {
    if (o.op == NULL || strcmp(o.op, "li") != 0)
        return 0;
    if (o.arg1 == NULL || o.res == NULL)
        return 0;

    char *endptr;
    long v = strtol(o.arg1, &endptr, 10);
    if (*endptr == '\0') {
        *valor = (int)v;
        return 1;
    }
    return 0;
}

/* Busca el ultimo "li reg, val" antes de 'hasta' que no haya sido sobreescrito */
static int buscar_ultimo_li(ListaC codigo, PosicionListaC hasta,
                            const char *reg, int *valor)
{
    int encontrado = 0;
    int val_tmp = 0;

    PosicionListaC scan = inicioLC(codigo);
    while (scan != hasta && scan != finalLC(codigo)) {
        Operacion os = recuperaLC(codigo, scan);

        // Una etiqueta rompe el bloque basico, asi que invalidamos
        if (os.op != NULL && strcmp(os.op, "label") == 0) {
            encontrado = 0;
        }
        // li sobre el registro buscado: guardamos el valor
        else if (os.op != NULL && strcmp(os.op, "li") == 0 &&
                 os.res != NULL && strcmp(os.res, reg) == 0)
        {
            if (es_li_con_valor(os, &val_tmp)) {
                encontrado = 1;
            }
        }
        // Cualquier otra escritura sobre el registro lo invalida (excepto #nop)
        else if (os.res != NULL && strcmp(os.res, reg) == 0 &&
                 os.op != NULL && strcmp(os.op, "#nop") != 0)
        {
            encontrado = 0;
        }

        scan = siguienteLC(codigo, scan);
    }

    if (encontrado) {
        *valor = val_tmp;
    }
    return encontrado;
}

// OPTIMIZACION

void peephole_optimize(ListaC codigo) {
    if (codigo == NULL) return;
    if (inicioLC(codigo) == finalLC(codigo)) return;

    PosicionListaC p = inicioLC(codigo);

    while (p != finalLC(codigo)) {
        Operacion o = recuperaLC(codigo, p);

        /* Saltar operaciones nulas, etiquetas y nops */
        if (o.op == NULL || strcmp(o.op, "label") == 0 ||
            strcmp(o.op, "#nop") == 0)
        {
            p = siguienteLC(codigo, p);
            continue;
        }

        /* move $r, $r -> #nop */
        if (strcmp(o.op, "move") == 0 &&
            o.res != NULL && o.arg1 != NULL &&
            strcmp(o.res, o.arg1) == 0)
        {
            Operacion nop;
            nop.op = "#nop"; nop.res = NULL;
            nop.arg1 = NULL; nop.arg2 = NULL;
            asignaLC(codigo, p, nop);
            p = siguienteLC(codigo, p);
            continue;
        }

        /* Operaciones aritmeticas en las que algun operando es una constante conocida */
        if (strcmp(o.op, "add") == 0 ||
            strcmp(o.op, "sub") == 0 ||
            strcmp(o.op, "mul") == 0)
        {
            int val1 = 0, val2 = 0;
            int found1 = 0, found2 = 0;

            if (o.arg1 != NULL) {
                found1 = buscar_ultimo_li(codigo, p, o.arg1, &val1);
            }
            if (o.arg2 != NULL) {
                found2 = buscar_ultimo_li(codigo, p, o.arg2, &val2);
            }

            if (strcmp(o.op, "add") == 0) {
                /* x + 0 -> move res, x */
                if (found2 && val2 == 0) {
                    Operacion nuevo;
                    nuevo.op = "move"; nuevo.res = o.res;
                    nuevo.arg1 = o.arg1; nuevo.arg2 = NULL;
                    asignaLC(codigo, p, nuevo);
                }
                /* 0 + x -> move res, x */
                else if (found1 && val1 == 0) {
                    Operacion nuevo;
                    nuevo.op = "move"; nuevo.res = o.res;
                    nuevo.arg1 = o.arg2; nuevo.arg2 = NULL;
                    asignaLC(codigo, p, nuevo);
                }
            }

            else if (strcmp(o.op, "sub") == 0) {
                /* x - 0 -> move res, x */
                if (found2 && val2 == 0) {
                    Operacion nuevo;
                    nuevo.op = "move"; nuevo.res = o.res;
                    nuevo.arg1 = o.arg1; nuevo.arg2 = NULL;
                    asignaLC(codigo, p, nuevo);
                }
            }

            else if (strcmp(o.op, "mul") == 0) {
                /* x * 1 -> move res, x */
                if (found2 && val2 == 1) {
                    Operacion nuevo;
                    nuevo.op = "move"; nuevo.res = o.res;
                    nuevo.arg1 = o.arg1; nuevo.arg2 = NULL;
                    asignaLC(codigo, p, nuevo);
                }
                /* 1 * x -> move res, x */
                else if (found1 && val1 == 1) {
                    Operacion nuevo;
                    nuevo.op = "move"; nuevo.res = o.res;
                    nuevo.arg1 = o.arg2; nuevo.arg2 = NULL;
                    asignaLC(codigo, p, nuevo);
                }
                /* x * 0 o 0 * x -> li res, 0 */
                else if ((found2 && val2 == 0) || (found1 && val1 == 0)) {
                    Operacion nuevo;
                    nuevo.op = "li"; nuevo.res = o.res;
                    nuevo.arg1 = "0"; nuevo.arg2 = NULL;
                    asignaLC(codigo, p, nuevo);
                }
                /* x * 2^k -> sll res, x, k */
                else if (found2) {
                    int exp = es_potencia_de_2(val2);
                    if (exp > 0) {
                        char *shift;
                        asprintf(&shift, "%d", exp);
                        Operacion nuevo;
                        nuevo.op = "sll"; nuevo.res = o.res;
                        nuevo.arg1 = o.arg1; nuevo.arg2 = shift;
                        asignaLC(codigo, p, nuevo);
                    }
                }
                /* 2^k * x -> sll res, x, k */
                else if (found1) {
                    int exp = es_potencia_de_2(val1);
                    if (exp > 0) {
                        char *shift;
                        asprintf(&shift, "%d", exp);
                        Operacion nuevo;
                        nuevo.op = "sll"; nuevo.res = o.res;
                        nuevo.arg1 = o.arg2; nuevo.arg2 = shift;
                        asignaLC(codigo, p, nuevo);
                    }
                }
            }
        }

        p = siguienteLC(codigo, p);
    }
}
