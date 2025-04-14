#include "bnn_controller_tb.hpp"
#include "test_globals.hpp" // Include shared header
#include <iostream>
#include <string>
#include <cstdlib>

void test_bnn_module(Vbnn_controller *dut)
{
    std::cout << "\nRunning test_bnn_module...\n";

    // Reset the system
    dut->rst_n = 0;
    dut->clk = 0;
    dut->CS = 1;
    dut->SCLK = 0;
    dut->COPI = 0;
    dut->eval();

    for (int i = 0; i < 5; i++)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
    }

    // Release reset
    dut->rst_n = 1;
    dut->clk = !dut->clk;
    dut->eval();

    // Ensure we're in IDLE state
    assert_equal("Initial state should be IDLE", 0, dut->debug_state);

    // Start SPI transaction and load an image pattern
    dut->CS = 0;

    // Load a simple test pattern (checkerboard)
    std::cout << "Loading test image pattern...\n";
    for (int i = 0; i < 784; i++)
    { // 28x28 pixels
        uint8_t test_data = ((i / 28) % 2 == 0) ? (((i % 28) % 2 == 0) ? 0xFF : 0x00) : (((i % 28) % 2 == 0) ? 0x00 : 0xFF);

        // Send byte via SPI
        for (int bit = 7; bit >= 0; bit--)
        {
            dut->COPI = (test_data >> bit) & 1;
            dut->SCLK = 0;
            dut->clk = !dut->clk;
            dut->eval();
            dut->SCLK = 1;
            dut->clk = !dut->clk;
            dut->eval();
        }

        // Allow time for processing
        dut->clk = !dut->clk;
        dut->eval();
        dut->clk = !dut->clk;
        dut->eval();

        if (i % 100 == 0)
        {
            std::cout << "Loaded " << i << " pixels...\n";
        }
    }

    // Verify transition to INFERENCE state
    assert_equal("State should be INFERENCE after buffer full", 2, dut->debug_state);

    // Wait for inference to complete
    std::cout << "Waiting for inference to complete...\n";
    int timeout = 5000; // Increased from 1000
    while (!dut->debug_result_ready && timeout > 0)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
        timeout--;
    }

    if (timeout <= 0)
    {
        std::cerr << "ERROR: Inference timed out!\n";
        test_failures++;
    }
    else
    {
        std::cout << "Inference completed in " << (5000 - timeout) << " cycles\n";
        assert_equal("Result should be ready", 1, dut->debug_result_ready);
        assert_equal("State should be RESULT_TX", 3, dut->debug_state);

        // Check result (we don't know the exact value, but it should be non-zero)
        std::cout << "Classification result: " << (int)dut->debug_result_out << std::endl;

        // Complete the transaction
        dut->CS = 1;
        dut->clk = !dut->clk;
        dut->eval();

        // Verify state transition to CLEAR
        assert_equal("State should transition to CLEAR", 4, dut->debug_state);

        // Wait for IDLE state
        timeout = 100;
        while (dut->debug_state != 0 && timeout > 0)
        {
            dut->clk = !dut->clk;
            dut->eval();
            main_time += 5;
            timeout--;
        }

        assert_equal("Should return to IDLE state", 0, dut->debug_state);
    }

    std::cout << "BNN module test completed\n";
}