// Eliminacion de codigo muerto en if y while con condicion constante.

void main() {
    var int x = 5;

    if (0) {
        print("NUNCA_1\n");
    }

    while (0) {
        x = x + 1000;
    }

    if (1) {
        print("siempre\n");
    }

    if (3 > 2) {
        print("3>2 cierto\n");
    } else {
        print("NUNCA_2\n");
    }

    if (3 < 2) {
        print("NUNCA_3\n");
    } else {
        print("3<2 falso\n");
    }

    print("x = ", x, "\n");
}
