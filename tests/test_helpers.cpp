#include "main_test.hpp"

#include <iostream>
#include <string>
#include <string_view>
#include <cstdlib>
#include <cassert>
#include <stdexcept> // For std::invalid_argument
#include <iomanip>   // Added for std::setw and std::setfill

#include <format>

constexpr int HALF_PERIOD_NS = 5;

inline void tick(Vtop *dut, int cycles = 1)
{
    static_assert(std::is_same_v<vluint64_t, decltype(main_time)>,
                  "main_time must be vluint64_t");

    if (!dut || cycles <= 0)
        return;

    for (int i = 0; i < cycles * 2; ++i)
    {
        dut->clk = !dut->clk;
        dut->eval();
        if (dut->clk) // Increment main_time only on rising edge of clk
        {
            main_time += HALF_PERIOD_NS;
        }
    }
}

void spi_send_byte(Vtop *dut, uint8_t byte, int mode, bool verbose, bool keep_cs = false)
{

    if (!dut)
        return;
    if (mode < 0 || mode > 3)
        throw std::invalid_argument("SPI mode must be 0‑3");

    const bool CPOL = (mode & 0b10) >> 1;
    const bool CPHA = (mode & 0b01);

    auto set_sclk = [&](bool level)
    {
        dut->SCLK = level;
        tick(dut, 1);
        dut->eval(); // Ensure the signal propagates
    };

    // --- Prepare bus ---
    set_sclk(CPOL); // Set idle clock state before asserting spi_cs_n

    dut->spi_cs_n = 1; // ensure spi_cs_n idle high
    dut->eval();       // explicit settle
    tick(dut, 1);

    dut->spi_cs_n = 0; // start transaction
    dut->eval();       // explicit settle
    tick(dut, 2);      // settle before first bit

    // --- Bit transmission loop ---
    for (int i = 7; i >= 0; --i)
    {
        bool bit = (byte >> i) & 1;
        if (CPHA == 0)
        {
            dut->COPI = bit;
            dut->eval();
            set_sclk(!CPOL);
            tick(dut, 1);
            set_sclk(CPOL);
            tick(dut, 1);
        }
        else
        {
            set_sclk(!CPOL);
            tick(dut, 1);
            dut->COPI = bit;
            dut->eval();
            set_sclk(CPOL);
            tick(dut, 1);
        }

        // Debug output for each bit
        if (verbose)
        {
            std::cout << "[SPI TB] (" << std::dec << main_time / HALF_PERIOD_NS << "): bit=" << i
                      << " | COPI=" << bit
                      << " | SCLK=" << int(dut->SCLK)
                      << " | Byte=0x" << std::hex << std::setw(2) << std::setfill('0') << int(byte)
                      << "\n";
        }
    }

    // --- Post-transaction cleanup ---
    tick(dut, 2); // settle after last bit

    if (!keep_cs)
    {
        dut->spi_cs_n = 1; // release spi_cs_n
        dut->eval();
        tick(dut, 1);
    }
}

void do_reset(Vtop *dut, int cycles, bool verbose = false)
{
    if (!dut)
        return;

    dut->rst_n = 0; // Assert reset
    main_time = 0;  // Reset main_time
    tick(dut, cycles);
    dut->rst_n = 1; // Deassert reset
    tick(dut, cycles);
    tick(dut, 1); // extra settle cycle

    if (verbose)
    {
        std::cout << "[RST DEBUG]: Reset asserted for " << cycles << " cycles.\n";
        std::cout << "[RST DEBUG]: Current time: " << std::dec << main_time << "\n";
    }
}

void debug(Vtop *dut)
{
    if (!dut)
        return;

    dut->debug_trigger = 1; // Assert debug_trigger
    tick(dut, 1);

    // Debug output for debug trigger
    std::cout << "[DEBUG TRIGGER]: Trigger asserted at time " << main_time << "\n";

    dut->debug_trigger = 0; // Deassert debug_trigger
    tick(dut, 1);           // Allow signal to settle

    std::cout << "[DEBUG TRIGGER]: Trigger deasserted at time " << main_time << "\n";
}