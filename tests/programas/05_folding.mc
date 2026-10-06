// Constant folding en expresiones aritmeticas y aviso de division por cero.

void main() {
    var int a = 2 * 8 + 5;
    var int b = 100 / 10 - 5;
    var int c = -10 + 20;
    var int d = 3 * 3 * 3;
    var int e = 3 - 5 * 2;
    var int div_cero = 100 / 0;

    print("a = ", a, "\n");
    print("b = ", b, "\n");
    print("c = ", c, "\n");
    print("d = ", d, "\n");
    print("e = ", e, "\n");
    print("div_cero = ", div_cero, "\n");
}
