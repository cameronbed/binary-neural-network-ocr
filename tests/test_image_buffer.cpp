#include "bnn_controller_tb.hpp"
#include "test_globals.hpp" // Include shared header
#include <iostream>
#include <string>
#include <cstdlib>

void test_image_buffer(Vbnn_controller *dut)
{
    std::cout << "\nRunning test_image_buffer...\n";

    // Reset the system
    dut->rst_n = 0;
    dut->clk = 0;
    dut->CS = 1;
    dut->SCLK = 0;
    dut->COPI = 0;
    dut->eval();

    // Apply reset
    for (int i = 0; i < 5; i++)
    {
        tick(dut);
    }

    // Release reset
    dut->rst_n = 1;
    for (int i = 0; i < 5; i++)
    {
        tick(dut);
    }

    // Check buffer is empty after reset
    assert_equal("Buffer should start empty", 1, dut->debug_buffer_empty);
    assert_equal("Write address should be 0", 0, dut->debug_write_addr);

    // Start an SPI transaction and write some data
    dut->CS = 0;

    // Write 10 bytes to the buffer
    for (int i = 0; i < 10; i++)
    {
        uint8_t test_data = 0xA0 + i; // Test pattern
        spi_send_byte(dut, test_data);

        // Wait for the write address to update
        int timeout = 1000;
        while (dut->debug_write_addr != (i + 1) && timeout > 0)
        {
            tick(dut);
            timeout--;
        }

        if (timeout == 0)
        {
            std::cerr << "[FAIL] Timeout waiting for write address to increment after byte " << i << "\n";
            test_failures++;
            break;
        }

        for (int j = 0; j < 5; j++)
        {
            tick(dut);
            // Debug printing
            std::cout << "Tick " << j
                      << ": debug_write_addr=" << dut->debug_write_addr
                      << ", debug_write_enable=" << dut->debug_write_enable
                      << ", debug_byte_valid=" << dut->debug_byte_valid
                      << std::endl;
        }

        // Verify that write_enable is asserted
        assert_equal("Write enable should be asserted", 1, dut->debug_write_enable);

        // Verify that byte_valid is asserted after each byte
        assert_equal("Byte valid should be asserted", 1, dut->debug_byte_valid);

        assert_equal("Buffer should no longer be empty", 0, dut->debug_buffer_empty);
    }

    // Verify write address has been incremented correctly
    assert_equal("Write address should be 10", 10, dut->debug_write_addr);

    // Fill the buffer completely (784 bytes total for 28x28)
    std::cout << "Filling buffer to capacity...\n";
    for (int i = 10; i < 784; i++)
    {
        uint8_t test_data = i & 0xFF;

        // Send byte via SPI with clearer timing
        for (int bit = 7; bit >= 0; bit--)
        {
            dut->SCLK = 0;
            dut->eval();
            main_time += 1;

            dut->COPI = (test_data >> bit) & 1;
            dut->eval();
            main_time += 1;

            dut->SCLK = 1;
            dut->eval();
            main_time += 1;

            dut->SCLK = 0;
            dut->eval();
            main_time += 1;
        }

        // Let design process the byte
        tick(dut);
    }

    // Check buffer is now full
    assert_equal("Buffer should be full", 1, dut->debug_buffer_full);
    assert_equal("Write address should be 784", 784, dut->debug_write_addr);

    // Test buffer clear functionality
    // Deassert CS to trigger image read or buffer reset logic in FSM
    dut->CS = 1;

    // Wait for buffer to clear
    int timeout = 1000;
    while (!dut->debug_buffer_empty && timeout > 0)
    {
        tick(dut);
        timeout--;
        if (timeout == 0)
        {
            std::cerr << "[ERROR] Timeout waiting for buffer to clear\n";
            exit(EXIT_FAILURE); // or return false, depending on your test framework
        }
    }

    assert_equal("Buffer should be empty after clear", 1, dut->debug_buffer_empty);
    assert_equal("Write address should be 0 after clear", 0, dut->debug_write_addr);

    std::cout << "Image buffer test completed\n";
}
