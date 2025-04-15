#include "main_test.hpp"
#include <iostream>
#include <string>
#include <cstdlib>

// Define shared variables
vluint64_t main_time = 0; // Initialize main_time to 0
int test_failures = 0;    // Initialize test_failures to 0

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vtop *dut = new Vtop;

    test_tick_and_spi_send(dut);
    delete dut;

    if (test_failures == 0)
    {
        std::cout << "\n✅ ALL TESTS PASSED ✅\n";
        return 0;
    }
    else
    {
        std::cerr << "\n❌ " << test_failures << " TEST(S) FAILED ❌\n";
        return 1;
    }
}