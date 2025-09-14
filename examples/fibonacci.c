#include <stdio.h>

// Fibonacci function
int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

int main() {
    int n = 10;
    
    printf("Fibonacci sequence up to %d:\n", n);
    for (int i = 0; i <= n; i++) {
        printf("fib(%d) = %d\n", i, fibonacci(i));
    }
    
    return 0;
}