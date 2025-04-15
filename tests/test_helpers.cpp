#include "main_test.hpp"

#include <iostream>
#include <string>
#include <cstdlib>
#include <cassert>
#include <stdexcept> // For std::invalid_argument
#include <iomanip>   // Added for std::setw and std::setfill

void tick(Vtop *dut, VerilatedVcdC *tfp = nullptr, int *timestamp = nullptr, int n = 1)
{
    if (!dut)
        return;

    for (int i = 0; i < n; ++i)
    {
        for (int edge = 0; edge < 2; ++edge) // One full clock cycle
        {
            dut->clk = !dut->clk;
            dut->eval();

            if (tfp && timestamp)
            {
                tfp->dump(*timestamp);
                *timestamp += 5; // 5ns per edge (10ns full cycle)
            }

            main_time += 5; // Increment main_time for each edge
        }
    }
}

void tick(Vtop *dut, int n)
{
    if (!dut)
        return;

    for (int i = 0; i < n; ++i)
    {
        for (int edge = 0; edge < 2; ++edge) // One full clock cycle
        {
            dut->clk = !dut->clk;
            dut->eval();

            main_time += 5; // Increment main_time for each edge
        }
    }
}

void spi_send_byte(Vtop *dut, uint8_t byte, int mode,
                   VerilatedVcdC *tfp, int *timestamp, bool verbose)
{
    if (!dut)
        return;
    if (mode < 0 || mode > 3)
        throw std::invalid_argument("Invalid SPI mode: must be 0-3");

    bool cpol = (mode & 0b10) >> 1;
    bool cpha = (mode & 0b01);

    // Set clock to idle state
    dut->SCLK = cpol;
    dut->eval();
    tick(dut, tfp, timestamp, 1);

    for (int i = 7; i >= 0; --i)
    {
        uint8_t bit = (byte >> i) & 1;

        if (cpha == 0)
        {
            // Set data before active edge
            dut->COPI = bit;
            dut->eval();
            tick(dut, tfp, timestamp, 1);

            // Toggle clock (active edge)
            dut->SCLK = !cpol;
            dut->eval();
            tick(dut, tfp, timestamp, 1);

            // Return to idle
            dut->SCLK = cpol;
            dut->eval();
            tick(dut, tfp, timestamp, 1);
        }
        else
        {
            // Idle clock first
            dut->SCLK = cpol;
            dut->eval();
            tick(dut, tfp, timestamp, 1);

            // First edge
            dut->SCLK = !cpol;
            dut->eval();
            tick(dut, tfp, timestamp, 1);

            // Set data
            dut->COPI = bit;
            dut->eval();
            tick(dut, tfp, timestamp, 1);

            // Second edge
            dut->SCLK = cpol;
            dut->eval();
            tick(dut, tfp, timestamp, 1);
        }

        if (verbose)
        {
            std::cout << "[SPI] Bit " << i
                      << " | COPI=" << (int)bit
                      << " SCLK=" << (int)dut->SCLK
                      << " CPOL=" << cpol
                      << " CPHA=" << cpha
                      << std::endl;
        }
    }

    // Let signals settle
    tick(dut, tfp, timestamp, 2);
}

void test_tick_and_spi_send(Vtop *dut)
{
    std::cout << "\n[TEST] test_tick_and_spi_send...\n";

    int timestamp = 0;
    VerilatedVcdC *tfp = nullptr; // Add your VCD pointer if needed

    // --- Tick Test ---
    uint64_t start_time = main_time;
    tick(dut, tfp, &timestamp, 1);
    assert(main_time - start_time == 10 && "tick() failed to increment time by 10ns");

    tick(dut, tfp, &timestamp, 3);
    assert(main_time - start_time == 40 && "tick() failed to increment time by expected amount");

    std::cout << "[PASS] tick() timing checks passed\n";

    // --- SPI Send Tests ---
    dut->rst_n = 1;
    dut->CS = 0; // Activate SPI

    for (int mode = 0; mode < 4; ++mode)
    {
        std::cout << "\n[MODE " << mode << "]\n";
        for (int val = 0; val <= 0xFF; ++val)
        {
            uint8_t byte = static_cast<uint8_t>(val);
            std::cout << "[SEND] Byte: 0x" << std::hex << std::setw(2) << std::setfill('0') << (int)byte << std::dec << "\n";

            if(val == 0xf9) debug(dut);
            if(val == 0xfa) debug(dut);
            if(val == 0xfb) debug(dut);

            spi_send_byte(dut, byte, mode, tfp, &timestamp, false); // Explicitly pass verbose

            // Confirm SCLK returns to idle (CPOL)
            int expected_sclk = (mode & 0b10) >> 1;
            assert(dut->SCLK == expected_sclk && "SCLK did not return to idle after SPI byte");

            // Optional: confirm COPI ends on LSB (for CPHA=0 only)
            if ((mode & 0b01) == 0)
                assert(dut->COPI == (byte & 0x1) && "COPI did not end on expected value");
        }
    }

    dut->CS = 1; // End SPI
    tick(dut, tfp, &timestamp, 2);

    std::cout << "[TEST] test_tick_and_spi_send PASSED ✅\n";
}

void debug(Vtop *dut)
{
    tick(dut, 1);
    dut->debug_trigger = 1;
    dut->eval();
    tick(dut, 1);
    dut->debug_trigger = 0;
    dut->eval();
    tick(dut, 1);
}