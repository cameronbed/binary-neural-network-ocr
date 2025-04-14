#ifndef TEST_GLOBALS_HPP
#define TEST_GLOBALS_HPP

#include <verilated.h>

// Declare shared variables
extern vluint64_t main_time;
extern int test_failures;

// Declare utility functions
void assert_equal(const std::string &label, int expected, int actual);

#endif // TEST_GLOBALS_HPP
