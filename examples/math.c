#include <stdio.h>

// Simple arithmetic functions
int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}

// Factorial function
int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

int main() {
    int x = 5, y = 3;
    
    printf("Addition: %d + %d = %d\n", x, y, add(x, y));
    printf("Multiplication: %d * %d = %d\n", x, y, multiply(x, y));
    printf("Factorial of %d = %d\n", x, factorial(x));
    
    return 0;
}