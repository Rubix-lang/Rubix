#include <stdio.h>

int main(void) {
  long long s = 0;
  long long i;
  for (i = 0; i < 50000000; i++) {
    s += (i * 3) >> 1;
    s += i & 7;
    s -= i % 17;
  }
  printf("%lld\n", s & 255);
  return 0;
}
