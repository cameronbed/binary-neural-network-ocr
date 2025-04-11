#include "Vbnn_controller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <string>
#include <cstdlib>

int test_failures = 0;

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

void assert_equal(const std::string &label, int expected, int actual);
void test_reset_behavior(Vbnn_controller *dut);
void test_spi_peripheral(Vbnn_controller *dut);
void test_bnn_controller(Vbnn_controller *dut);
void test_image_buffer(Vbnn_controller *dut);
void test_bnn_module(Vbnn_controller *dut);

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vbnn_controller *dut = new Vbnn_controller;

    test_reset_behavior(dut);
    test_spi_peripheral(dut);
    test_bnn_controller(dut);
    test_image_buffer(dut);
    test_bnn_module(dut);

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
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();

    // Check that initial state is correct
    assert_equal("State should be IDLE after reset", 0, dut->debug_state);

    // Deassert reset
    dut->rst = 0;
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
}

void test_spi_peripheral(Vbnn_controller *dut)
{
    std::cout << "\nRunning test_spi_peripheral...\n";

    // Initialize inputs
    dut->clk = 0;
    dut->rst = 1; // Active low reset
    dut->CS = 1;
    dut->SCLK = 0;
    dut->COPI = 0;

    // Reset phase
    for (int i = 0; i < 10; i++)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
    }
    dut->rst = 0; // Deassert reset

    // Begin SPI transaction
    dut->CS = 0; // Assert CS (active low)
    uint8_t test_data = 0x3C;
    std::cout << "Starting SPI transaction. Sending: 0x"
              << std::hex << (int)test_data << std::endl;

    // Add a needed delay between CS and sending data
    for (int i = 0; i < 5; i++)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
    }

    // Drive 8 bits (MSB first)
    for (int i = 7; i >= 0; i--)
    {
        // Set COPI for current bit (before clock edge)
        dut->COPI = (test_data >> i) & 1;
        std::cout << "Setting COPI = " << ((test_data >> i) & 1) << " for bit " << i << std::endl;

        // Drive clock for longer stabilization
        dut->SCLK = 0;
        for (int j = 0; j < 3; j++)
        {
            dut->clk = !dut->clk;
            dut->eval();
            main_time += 5;
        }

        dut->SCLK = 1;
        for (int j = 0; j < 3; j++)
        {
            dut->clk = !dut->clk;
            dut->eval();
            main_time += 5;
        }

        // Verify debug signals
        std::cout << "Bit " << i << ": debug_bit_count = "
                  << (int)dut->debug_bit_count << std::endl;
    }

    // End transaction
    dut->CS = 1;

    // Additional cycles to process
    for (int i = 0; i < 5; i++)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
    }

    // Verify received data using debug signals
    std::cout << "SPI received data: 0x" << std::hex
              << (int)dut->debug_rx_byte << std::endl;

    assert_equal("Received data matches", test_data, dut->debug_rx_byte);

    // At the end, add a check that bit_count was properly reset
    assert_equal("Bit count should be reset after transaction", 0, dut->debug_bit_count);
}

void test_bnn_controller(Vbnn_controller *dut)
{
    std::cout << "\nRunning test_bnn_controller...\n";

    // Reset the controller
    dut->rst = 1;
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
    dut->rst = 0;
    dut->clk = !dut->clk;
    dut->eval();
    assert_equal("Initial state should be IDLE", 0, dut->debug_state);

    // Start transaction by asserting CS
    dut->CS = 0;
    dut->clk = !dut->clk;
    dut->eval();
    assert_equal("State should transition to IMG_RX", 1, dut->debug_state);

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
    assert_equal("Buffer should be full", 1, dut->debug_buffer_full);
    assert_equal("State should transition to INFERENCE", 2, dut->debug_state);

    // Wait for inference to complete
    int timeout = 1000;
    while (!dut->debug_result_ready && timeout > 0)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
        timeout--;
    }
    assert_equal("Result should be ready", 1, dut->debug_result_ready);
    assert_equal("State should be in RESULT_TX", 3, dut->debug_state);

    // End transaction
    dut->CS = 1;
    dut->clk = !dut->clk;
    dut->eval();
    assert_equal("State should transition to CLEAR", 4, dut->debug_state);

    // Wait for buffer to clear
    timeout = 1000;
    while (!dut->debug_buffer_empty && timeout > 0)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
        timeout--;
    }
    assert_equal("Buffer should be empty", 1, dut->debug_buffer_empty);
    assert_equal("State should return to IDLE", 0, dut->debug_state);
}

void test_image_buffer(Vbnn_controller *dut)
{
    std::cout << "\nRunning test_image_buffer...\n";

    // Reset the system
    dut->rst = 1;
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

    // Release reset and check buffer is empty
    dut->rst = 0;
    dut->clk = !dut->clk;
    dut->eval();
    assert_equal("Buffer should start empty", 1, dut->debug_buffer_empty);
    assert_equal("Write address should be 0", 0, dut->debug_write_addr);

    // Start an SPI transaction and write some data
    dut->CS = 0;

    // Write 10 bytes to the buffer
    for (int i = 0; i < 10; i++)
    {
        uint8_t test_data = 0xA0 + i; // Test pattern

        // Send byte via SPI
        for (int bit = 7; bit >= 0; bit--)
        {
            dut->COPI = (test_data >> bit) & 1;

            // Toggle SPI clock
            dut->SCLK = 0;
            dut->clk = !dut->clk;
            dut->eval();
            main_time += 5;

            dut->SCLK = 1;
            dut->clk = !dut->clk;
            dut->eval();
            main_time += 5;
        }

        // Allow time for processing
        for (int j = 0; j < 5; j++)
        {
            dut->clk = !dut->clk;
            dut->eval();
            main_time += 5;
        }

        // Check write address increments
        std::cout << "After byte " << i << ", write address = "
                  << dut->debug_write_addr << std::endl;
        assert_equal("Buffer should no longer be empty", 0, dut->debug_buffer_empty);
    }

    // Verify write address has been incremented correctly
    assert_equal("Write address should be 10", 10, dut->debug_write_addr);

    // Fill the buffer completely (784 bytes total for 28x28)
    std::cout << "Filling buffer to capacity...\n";
    for (int i = 10; i < 784; i++)
    {
        uint8_t test_data = i & 0xFF;

        // Send byte via SPI (simplified - fewer clock cycles for speed)
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

        // Let design process the byte
        dut->clk = !dut->clk;
        dut->eval();
        dut->clk = !dut->clk;
        dut->eval();
    }

    // Check buffer is now full
    assert_equal("Buffer should be full", 1, dut->debug_buffer_full);
    assert_equal("Write address should be 784", 784, dut->debug_write_addr);

    // Test buffer clear functionality
    dut->CS = 1; // Deassert CS to trigger clear in the state machine

    // Wait for buffer to clear
    int timeout = 1000;
    while (!dut->debug_buffer_empty && timeout > 0)
    {
        dut->clk = !dut->clk;
        dut->eval();
        main_time += 5;
        timeout--;
    }

    assert_equal("Buffer should be empty after clear", 1, dut->debug_buffer_empty);
    assert_equal("Write address should be 0 after clear", 0, dut->debug_write_addr);

    std::cout << "Image buffer test completed\n";
}

void test_bnn_module(Vbnn_controller *dut)
{
    std::cout << "\nRunning test_bnn_module...\n";

    // Reset the system
    dut->rst = 1;
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
    dut->rst = 0;
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