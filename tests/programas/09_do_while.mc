// Sentencia do-while estandar, do-while(0) y do-while(1) con break.

void main() {
    var int i = 0;
    do {
        print("una vuelta i=", i, "\n");
        i = i + 1;
    } while (i < 3);

    var int j = 0;
    do {
        j = j + 1;
        print("j = ", j, "\n");
    } while (0);

    var int k = 0;
    do {
        print("k antes = ", k, "\n");
        break;
        k = 999;
    } while (1);
    print("k final = ", k, "\n");

    print("Fin\n");
}
