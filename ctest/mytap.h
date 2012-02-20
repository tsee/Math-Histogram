#ifndef mytap_h_
#define mytap_h_

static unsigned int ntests = 0;

unsigned int get_ntests() {
  return ntests;
}

void increment_ntests() {
  ntests++;
}

void done_testing() {
  printf("1..%u\n", ntests);
}

void plan(int expected_tests) {
  printf("1..%u\n", expected_tests);
}

void pass() {
  printf("ok %u\n", ++ntests);
}

void fail() {
  printf("not ok %u\n", ++ntests);
}

int ok(int i) {
  printf("%sok %u\n", (i ? "" : "not "), ++ntests);
  return i;
}

int ok_m(int i, char *msg) {
  printf("%sok %u - %s\n", (i ? "" : "not "), ++ntests, msg);
  return i;
}

int is_int(int a, int b) {
  return ok(a == b);
}

int is_int_m(int a, int b, char *msg) {
  return ok_m(a == b, msg);
}

#endif
