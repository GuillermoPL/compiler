#!/bin/sh
# Ejecuta la bateria de pruebas del compilador miniC.
# Comprueba contadores de errores y, si MARS esta disponible, valida la salida
# de los tests sin errores buscando una subcadena clave.
#
# Salidas (todas dentro de OUT_DIR):
#   ensamblador/  ficheros .s generados
#   error/        stderr capturado de cada compilacion
#   out/          salida de MARS al ejecutar el .s
#
# Uso:
#   sh script_pruebas.sh [directorio_pruebas]
#
# Variables (todas opcionales):
#   COMPILER  ruta del ejecutable (por defecto ../minic relativo al script)
#   MARS_JAR  ruta al jar de MARS (por defecto Mars4_5.jar junto al script)
#   OUT_DIR   directorio de salidas (por defecto salida/ junto al script)

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

COMPILER="${COMPILER:-$SCRIPT_DIR/../minic}"
TEST_DIR="${1:-$SCRIPT_DIR/programas}"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/salida}"
MARS_JAR="${MARS_JAR:-$SCRIPT_DIR/Mars4_5.jar}"

ASM_DIR="$OUT_DIR/ensamblador"
ERR_DIR="$OUT_DIR/error"
RUN_DIR="$OUT_DIR/out"

PASS=0
FAIL=0
HAS_MARS=0

if [ ! -x "$COMPILER" ]; then
    echo "Error: compilador no encontrado en '$COMPILER'." >&2
    echo "       Ejecuta 'make' en la raiz o exporta COMPILER=/ruta/al/binario." >&2
    exit 2
fi

if [ ! -d "$TEST_DIR" ]; then
    echo "Error: directorio de pruebas '$TEST_DIR' no existe." >&2
    exit 2
fi

mkdir -p "$ASM_DIR" "$ERR_DIR" "$RUN_DIR"

if [ -f "$MARS_JAR" ] && command -v java >/dev/null 2>&1; then
    HAS_MARS=1
fi

extract_count() {
    grep -E "Errores $2:" "$1" 2>/dev/null | tail -1 | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/'
}

run_test() {
    src="$TEST_DIR/$1"
    exp_lex=$2
    exp_sint=$3
    exp_sem=$4
    stdin_data=$5
    expected_substr=$6

    base=$(basename "$1" .mc)
    s_out="$ASM_DIR/${base}.s"
    err_out="$ERR_DIR/${base}.err"
    mars_out="$RUN_DIR/${base}.out"

    if [ ! -f "$src" ]; then
        printf '%-24s SKIP  (no existe)\n' "$base"
        return
    fi

    "$COMPILER" "$src" > "$s_out" 2> "$err_out" || true

    lex=$(extract_count "$err_out" lexicos)
    sint=$(extract_count "$err_out" sintacticos)
    sem=$(extract_count "$err_out" semanticos)
    lex=${lex:-0}
    sint=${sint:-0}
    sem=${sem:-0}

    ok=1
    detail=""
    if [ "$lex" != "$exp_lex" ]; then
        ok=0
        detail="$detail lex=$lex/esp$exp_lex"
    fi
    if [ "$sint" != "$exp_sint" ]; then
        ok=0
        detail="$detail sint=$sint/esp$exp_sint"
    fi
    if [ "$sem" != "$exp_sem" ]; then
        ok=0
        detail="$detail sem=$sem/esp$exp_sem"
    fi

    total=$((exp_lex + exp_sint + exp_sem))
    mars_tag=""

    if [ "$ok" = "1" ] && [ "$total" = "0" ] && [ "$HAS_MARS" = "1" ]; then
        if [ -n "$stdin_data" ]; then
            printf '%s\n' "$stdin_data" | java -jar "$MARS_JAR" nc "$s_out" \
                > "$mars_out" 2>&1 || true
        else
            java -jar "$MARS_JAR" nc "$s_out" > "$mars_out" 2>&1 || true
        fi

        if [ -n "$expected_substr" ]; then
            if grep -qF "$expected_substr" "$mars_out"; then
                mars_tag=" [MARS ok]"
            else
                ok=0
                mars_tag=" [MARS no contiene '$expected_substr']"
            fi
        else
            mars_tag=" [MARS run]"
        fi
    elif [ "$total" = "0" ] && [ "$HAS_MARS" = "0" ]; then
        mars_tag=" [MARS skip]"
    fi

    if [ "$ok" = "1" ]; then
        printf '%-24s PASS  lex=%s sint=%s sem=%s%s\n' \
            "$base" "$lex" "$sint" "$sem" "$mars_tag"
        PASS=$((PASS + 1))
    else
        printf '%-24s FAIL %s%s\n' "$base" "$detail" "$mars_tag"
        FAIL=$((FAIL + 1))
    fi
}

echo "Bateria de pruebas miniC"
echo "  compilador: $COMPILER"
echo "  pruebas:    $TEST_DIR"
echo "  salidas:    $OUT_DIR (ensamblador/, error/, out/)"
if [ "$HAS_MARS" = "1" ]; then
    echo "  MARS:       $MARS_JAR"
else
    echo "  MARS:       no disponible (solo se comprobaran errores)"
fi
echo

#        fichero                 lex sint sem  stdin  substring esperada en MARS
run_test 01_enunciado.mc          0   0   0   ""     "Inicio del programa"
run_test 02_lexico_err.mc         4   2   0   ""     ""
run_test 03_sintactico_err.mc     0   4   1   ""     ""
run_test 04_semantico_err.mc      0   0   6   ""     ""
run_test 05_folding.mc            0   0   0   ""     "div_cero = 0"
run_test 06_dead_code.mc          0   0   0   ""     "x = 5"
run_test 07_peephole.mc           0   0   0   "2"    "2 2 2 2 2 0 32 16"
run_test 08_relacionales.mc       0   0   0   ""     "Fin"
run_test 09_do_while.mc           0   0   0   ""     "k final = 0"
run_test 10_break_anidado.mc      0   0   0   ""     "n final = 5"
run_test 11_valido_completo.mc    0   0   0   "5"    "Suma 1..5 = 15"

echo
echo "Resultados: $PASS PASS, $FAIL FAIL"
[ "$FAIL" = "0" ]
