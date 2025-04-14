#include "bnn_controller_tb.hpp"
#include "test_globals.hpp" // Include shared header
#include <iostream>
#include <string>
#include <cstdlib>

// Define shared variables
vluint64_t main_time = 0;
int test_failures = 0;

double sc_time_stamp() { return main_time; }

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vbnn_controller *dut = new Vbnn_controller;

    // test_reset_behavior(dut);
    // test_spi_peripheral(dut);
    // test_bnn_controller(dut);
    test_image_buffer(dut);
    // test_bnn_module(dut);

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
    std::cout << "\nTB: Running test_reset_behavior...\n";

    // Apply reset
    dut->rst_n = 0;
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();

    // Check that initial state is correct
    assert_equal("TB: State should be IDLE after reset", 0, dut->debug_state);

    // Deassert reset
    dut->rst_n = 1;
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

void tick(Vbnn_controller *dut)
{
    dut->clk = !dut->clk;
    dut->eval();
    main_time += 5;
}

void spi_send_byte(Vbnn_controller *dut, uint8_t data)
{
    for (int i = 7; i >= 0; i--)
    {
        // Pull SCLK low (idle state)
        dut->SCLK = 0;
        tick(dut);
        tick(dut); // Wait for synchronizer to catch it

        // Set bit on COPI
        dut->COPI = (data >> i) & 0x1;
        tick(dut);
        tick(dut); // Allow data to settle

        // Toggle SCLK high — should generate a rising edge detectable by the SPI module
        dut->SCLK = 1;
        tick(dut);
        tick(dut); // Must last enough system clocks for edge detection

        // Bring SCLK back low
        dut->SCLK = 0;
        tick(dut);
        tick(dut); // Complete the cycle
    }
}
