// Patrones del peephole. Lee x por stdin para evitar el folding

void main() {
    var int x;
    print("Introduce x: ");
    read(x);

    var int a = x + 0;
    var int b = 0 + x;
    var int c = x - 0;
    var int d = x * 1;
    var int e = 1 * x;
    var int f = x * 0;
    var int g = x * 16;
    var int h = 8 * x;

    print(a, " ", b, " ", c, " ", d, " ", e, " ", f, " ", g, " ", h, "\n");
}
