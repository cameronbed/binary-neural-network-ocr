#include "bnn_controller_tb.hpp"
#include <iostream>
#include <string>
#include <cstdlib>

// Define shared variables
vluint64_t main_time = 0;
int test_failures = 0;

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vbnn_controller *dut = new Vbnn_controller;

    // Initialize DUT signals
    dut->clk = 0;
    dut->rst_n = 1;
    dut->CS = 1;

    test_reset_and_startup(dut);
    test_image_write_and_fsm(dut);
    test_inference_trigger(dut);
    test_result_tx_and_clear(dut);
    test_fsm_loop_end_to_end(dut);
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