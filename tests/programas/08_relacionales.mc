// Operadores relacionales en condiciones ciertas, falsas y como condicion de while.

void main() {
    var int a = 5;
    var int b = 3;

    if (a == 5) print("a==5 OK\n");
    if (a != 3) print("a!=3 OK\n");
    if (a >  b) print("a>b  OK\n");
    if (b <  a) print("b<a  OK\n");
    if (a >= 5) print("a>=5 OK\n");
    if (b <= 3) print("b<=3 OK\n");

    if (a == 0) print("NO_1\n");
    if (a != 5) print("NO_2\n");
    if (a <  b) print("NO_3\n");
    if (a >  5) print("NO_4\n");
    if (a <= 0) print("NO_5\n");
    if (b >= 9) print("NO_6\n");

    var int i = 0;
    while (i < 3) {
        print(i, "\n");
        i = i + 1;
    }

    print("Fin\n");
}
