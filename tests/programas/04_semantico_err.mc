// Errores semanticos: id de programa, redeclaracion, asignacion a constante, uso sin declarar, read sobre constante y break fuera de bucle

void programa_principal() {
    var int x = 1;
    var int x = 2;
    const int PI = 3;
    PI = 4;
    y = 5;
    read(PI);
    break;
}
