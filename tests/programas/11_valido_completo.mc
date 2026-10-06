// Integracion: lee N y calcula suma 1..N, factorial y primera potencia de 2 >= N.

void main() {
    print("Introduce N: ");
    var int n;
    read(n);

    var int suma = 0;
    var int i = 1;
    while (i <= n) {
        suma = suma + i;
        i = i + 1;
    }
    print("Suma 1..", n, " = ", suma, "\n");

    var int fact = 1;
    var int k = n;
    if (n > 0) {
        do {
            fact = fact * k;
            k = k - 1;
        } while (k > 0);
    }
    print(n, "! = ", fact, "\n");

    var int p = 1;
    while (1) {
        if (p >= n) break;
        p = p * 2;
    }
    print("Primera potencia de 2 >= ", n, ": ", p, "\n");

    print("Fin\n");
}
