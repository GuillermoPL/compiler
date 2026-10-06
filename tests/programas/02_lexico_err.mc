// Errores lexicos: overflow, id de mas de 32 caracteres, simbolos no reconocidos

void main() {
    var int limite = 2147483647;
    var int overflow = 2147483648;
    var int aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 1;
    var int panico = @#~;
    var int excl = !;
    print("Este programa no deberia generar MIPS.\n");
}
