# Compilador miniC → MIPS

Práctica de la asignatura Compiladores (2025/2026), Universidad de Murcia.
Traduce un subconjunto de C llamado miniC a ensamblador de MIPS, ejecutable
en MARS o spim. La especificación completa, las decisiones de diseño y los
ejemplos de uso están en `docs/Memoria.pdf`.

Autores:

- Roberto Martínez Reina — roberto.m.r@um.es
- Guillermo Fulgencio Parra López — gf.parralopez@um.es

## Estructura

```
.
├── main.c, miniC.l, miniC.y     fuentes del compilador
├── Makefile
├── codigo_aulavirtual/
│   ├── LS/   listaSimbolos.{c,h}    (suministrado por el profesorado)
│   └── LC/   listaCodigo.{c,h}      (suministrado por el profesorado)
├── peephole/
│   └── peephole.{c,h}              optimizaciones peephole
├── ficheros_intermedios/            generada por make
│   ├── lex.yy.c                     analizador lexico generado por flex
│   ├── miniC.tab.{c,h}              parser generado por bison
│   ├── miniC.output                 informe de gramatica de bison
│   └── *.o                          objetos compilados
├── tests/
│   ├── Mars4_5.jar                  simulador para ejecutar el .s
│   ├── script_pruebas.sh            bateria de pruebas
│   ├── programas/                   11 ficheros .mc de prueba
│   └── salida/                      generada por el script
│       ├── ensamblador/             codigo MIPS generado (.s)
│       ├── error/                   stderr de cada compilacion (.err)
│       └── out/                     salida de MARS al ejecutar el .s (.out)
└── docs/
    └── Memoria.pdf                  memoria de la practica
```

El binario `minic` queda en la raíz; todo lo demás que produzca la compilación
va a `ficheros_intermedios/`.

## Compilación

Desde la raíz:

```sh
make
```

Requiere `gcc`, `flex` y `bison`. Genera el ejecutable `minic`.

## Uso

```sh
./minic programa.mc > programa.s
java -jar tests/Mars4_5.jar nc programa.s
```

El compilador escribe el código MIPS por stdout y los errores por stderr,
seguidos de un resumen con los contadores léxicos, sintácticos y semánticos.
Si alguno de los contadores no es cero, no se emite la sección `.data` ni
`.text` (solo el resumen).

Si prefieres `spim`:

```sh
spim -file programa.s
```

## Pruebas

```sh
make test
```

Compila si hace falta y lanza la batería sobre `tests/programas/`. Para cada
test se comparan los contadores de errores con los esperados y, si MARS está
disponible (`java` instalado y el jar en su sitio), se ejecuta el `.s` y se
verifica que la salida contiene una subcadena clave. Las salidas se reparten
en `tests/salida/`:

- `ensamblador/<nombre>.s` — código MIPS producido por el compilador.
- `error/<nombre>.err` — todo lo que el compilador escribió por stderr
  (avisos, errores y resumen final).
- `out/<nombre>.out` — salida de MARS al ejecutar el `.s` correspondiente.

El script también puede invocarse a mano:

```sh
sh tests/script_pruebas.sh
sh tests/script_pruebas.sh otro/directorio
```

Variables de entorno para personalizar:

- `COMPILER` — ruta al binario (por defecto `../minic` relativo al script).
- `MARS_JAR` — ruta al jar de MARS (por defecto `tests/Mars4_5.jar`).
- `OUT_DIR`  — directorio raíz de salidas (por defecto `tests/salida/`).

## Limpieza

```sh
make clean
```

Borra el binario, el directorio `ficheros_intermedios/` y los tres
subdirectorios de `tests/salida/`.
