#include <stdio.h>

long long fib(long long n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    long long res = fib(30);
    printf("%lld\n", res);
    return 0;
}
