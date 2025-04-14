#include "bnn_controller_tb.hpp"
#include "test_globals.hpp" // Include shared header
#include <iostream>
#include <string>
#include <cstdlib>

void test_spi_peripheral(Vbnn_controller *dut)
{
    std::cout << "\nTB: Running test_spi_peripheral...\n";

    // Initialize inputs
    dut->clk = 0;
    dut->rst_n = 0; // Assert reset (active low)
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
    dut->rst_n = 1; // Deassert reset (inactive high)

    std::cout << "\nTB: Reset complete. Starting exhaustive SPI transaction testing...\n";

    // Iterate through all possible uint8_t values
    for (uint16_t loop_counter = 0; loop_counter < 256; loop_counter++)
    {
        uint8_t test_data = static_cast<uint8_t>(loop_counter);
        std::cout << "TB: Loop " << loop_counter + 1 << " of 256\n";

        // Begin SPI transaction
        dut->CS = 0; // Assert CS (active low)

        // Add delay between CS and sending data
        for (int i = 0; i < 5; i++)
        {
            dut->clk = !dut->clk;
            dut->eval();
            main_time += 5;
        }

        // Drive 8 bits (MSB first_n)
        for (int i = 7; i >= 0; i--)
        {
            // Set COPI for current bit
            dut->COPI = (test_data >> i) & 1;

            // Toggle SCLK for bit transfer
            for (int j = 0; j < 2; j++)
            {
                dut->SCLK = j;              // 0 -> 1 or 1 -> 0
                for (int k = 0; k < 2; k++) // Ensure enough clk cycles per SCLK edge
                {
                    dut->clk = !dut->clk;
                    dut->eval();
                    main_time += 5;
                }
            }
        }

        // End transaction
        dut->CS = 1;

        // Additional cycles to process (increased delay to ensure FSM updates)
        for (int i = 0; i < 6; i++) // increased from 5 to 10 cycles
        {
            dut->clk = !dut->clk;
            dut->eval();
            main_time += 5;
        }

        // Collect debugging outputs at the end of the loop
        std::cout << "TB: Sent data: 0x" << std::hex << (int)test_data
                  << ", Received data: 0x" << (int)dut->debug_rx_byte
                  << ", Bit count: " << (int)dut->debug_bit_count << std::endl;

        // Verify received data using debug signals
        assert_equal("TB: Received data matches", test_data, dut->debug_rx_byte);
        assert_equal("TB: Bit count should be reset after transaction", 0, dut->debug_bit_count);
    }

    std::cout << "\nTB: Exhaustive SPI transaction testing complete.\n";
}