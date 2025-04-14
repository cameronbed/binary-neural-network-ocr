#include "bnn_controller_tb.hpp"
#include "test_globals.hpp" // Include shared header
#include <iostream>
#include <string>
#include <cstdlib>

void test_bnn_controller(Vbnn_controller *dut)
{
    std::cout << "\nTB: Running test_bnn_controller...\n";

    // Reset the controller
    dut->rst_n = 0;
    dut->clk = 0;
    dut->CS = 1;
    dut->eval();

    // Wait a few cycles in reset
    for (int i = 0; i < 5; i++)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
    }

    // Release reset and verify IDLE state
    dut->rst_n = 1;
    dut->clk = !dut->clk;
    dut->eval();
    assert_equal("TB: Initial state should be IDLE", 0, dut->debug_state);

    // Start transaction by asserting CS
    dut->CS = 0;
    dut->clk = !dut->clk;
    dut->eval();
    assert_equal("TB: State should transition to IMG_RX", 1, dut->debug_state);

    // Send image data until buffer is full
    for (int i = 0; i < 784; i++)
    {                          // 28x28 = 784 pixels
        dut->COPI = (i & 0x1); // Alternate between 0 and 1
        dut->SCLK = 0;
        dut->clk = !dut->clk;
        dut->eval();
        dut->SCLK = 1;
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 10;
    }

    // Verify buffer full and transition to INFERENCE
    assert_equal("TB: Buffer should be full", 1, dut->debug_buffer_full);
    assert_equal("TB: State should transition to INFERENCE", 2, dut->debug_state);

    // Wait for inference to complete
    int timeout = 1000;
    while (!dut->debug_result_ready && timeout > 0)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
        timeout--;
    }
    assert_equal("TB: Result should be ready", 1, dut->debug_result_ready);
    assert_equal("TB: State should be in RESULT_TX", 3, dut->debug_state);

    // End transaction
    dut->CS = 1;
    dut->clk = !dut->clk;
    dut->eval();
    assert_equal("TB: State should transition to CLEAR", 4, dut->debug_state);

    // Wait for buffer to clear
    timeout = 1000;
    while (!dut->debug_buffer_empty && timeout > 0)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
        timeout--;
    }
    assert_equal("TB: Buffer should be empty", 1, dut->debug_buffer_empty);
    assert_equal("TB: State should return to IDLE", 0, dut->debug_state);
}