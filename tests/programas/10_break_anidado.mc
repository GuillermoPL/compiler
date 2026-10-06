// Break en bucles anidados a 2 y 3 niveles

void main() {
    var int i = 0;
    var int j;
    var int m = 0;
    var int n;

    while (i < 3) {
        j = 0;
        do {
            if (j == 2) break;
            j = j + 1;
            print("i=", i, " j=", j, "\n");
        } while (1);
        print("  tras interno, i=", i, "\n");
        i = i + 1;
    }

    print("---\n");

    while (1) {
        n = 0;
        while (n < 10) {
            if (n == 5) break;
            n = n + 1;
        }
        print("n final = ", n, "\n");
        m = m + 1;
        if (m == 2) break;
    }

    print("Fin\n");
}
