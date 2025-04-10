#include "Vbnn_controller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <string>

int test_failures = 0;

void assert_equal(const std::string &label, int expected, int actual);
void test_reset_behavior(Vbnn_controller *dut);

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vbnn_controller *dut = new Vbnn_controller;

    test_reset_behavior(dut);
    // Add more tests here

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

void test_reset_behavior(Vbnn_controller *dut)
{
    std::cout << "\nRunning test_reset_behavior...\n";

    // Apply reset
    dut->rst = 1;
    dut->start = 0;
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();

    // Check that 'done' is low
    assert_equal("done should be 0 after reset", 0, dut->done);

    // Deassert reset
    dut->rst = 0;
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
}

void assert_equal(const std::string &label, int expected, int actual)
{
    if (expected != actual)
    {
        std::cerr << "[FAIL] " << label << ": expected " << expected << ", got " << actual << "\n";
        test_failures++;
    }
    else
    {
        std::cout << "[PASS] " << label << "\n";
    }
}