#include "main_test.hpp"

#include <iostream>
#include <string>
#include <string_view>
#include <cstdlib>
#include <cassert>
#include <stdexcept>
#include <iomanip>
#include <format>

constexpr int HALF_PERIOD_NS = 5;

void sclk_rise(Vsystem_controller *dut)
{
    dut->SCLK = 1;
    dut->eval();
    tick_main_clk(dut, 2); // Hold SCLK high for setup/sample
}

void sclk_fall(Vsystem_controller *dut)
{
    dut->SCLK = 0;
    dut->eval();
    tick_main_clk(dut, 2); // Hold SCLK low after sample
}

void tick_main_clk(Vsystem_controller *dut, int cycles)
{
    for (int i = 0; i < cycles; i++)
    {
        dut->clk = !dut->clk;
        dut->eval();

        if (dut->clk)
            main_clk_ticks++;
    }
}

void spi_send_byte(Vsystem_controller *dut, uint8_t byte_val)
{
    if (!dut)
        throw std::invalid_argument("spi_send_byte: DUT pointer is null!");

    dut->spi_cs_n = 0; // Start transaction
    dut->eval();
    tick_main_clk(dut, 2); // Setup time after CS_N falling

    if (VERBOSE)
    {
        debug(dut);
        std::cout << "[SPI] Sending byte: 0x" << std::hex << (int)byte_val << "\n";
    }

    for (int i = 7; i >= 0; i--)
    {
        bool bit_val = (byte_val >> i) & 0x1;

        dut->COPI = bit_val;
        dut->eval();
        tick_main_clk(dut, 2); // Setup time before SCLK rising

        sclk_rise(dut); // Rising edge
        sclk_fall(dut); // Falling edge

        if (VERBOSE)
            debug(dut);
    }

    dut->spi_cs_n = 1; // End transaction
    dut->eval();
    tick_main_clk(dut, 10); // Wait after CS_N goes high

    if (VERBOSE)
    {
        debug(dut);
        std::cout << "[SPI] Byte sent: 0x" << std::hex << (int)byte_val << "\n";
    }
}

void spi_send_bytes(Vsystem_controller *dut, const std::vector<uint8_t> &bytes)
{
    for (auto byte : bytes)
    {
        spi_send_byte(dut, byte);
    }
}

void do_reset(Vsystem_controller *dut)
{
    if (!dut)
        throw std::invalid_argument("do_reset: DUT pointer is null!");

    int cycles = 1;

    dut->rst_n_pin = 0;         // Assert reset
    tick_main_clk(dut, cycles); // Tick system clock during reset

    dut->rst_n_pin = 1;         // Deassert reset
    tick_main_clk(dut, cycles); // Tick system clock after reset

    tick_main_clk(dut, cycles); // extra settle cycle

    main_clk_ticks = 0;

    if (VERBOSE)
    {
        std::cout << "[RST DEBUG]: Reset completed over " << 3 * cycles << " cycles.\n";
    }
}

void debug(Vsystem_controller *dut)
{
    if (!dut)
        return;

    dut->debug_trigger = 1; // Assert debug_trigger
    tick_main_clk(dut, 2);

    // Debug output for debug trigger
    std::cout << "[DEBUG TRIGGER]: Trigger asserted at time " << main_clk_ticks << "\n";

    dut->debug_trigger = 0; // Deassert debug_trigger
    tick_main_clk(dut, 2);  // Allow signal to settle

    std::cout << "[DEBUG TRIGGER]: Trigger deasserted at time " << main_clk_ticks << "\n";
}

void check_fsm_state(Vsystem_controller *dut, int expected_state, const std::string &state_name)
{
    if (dut->status_code_reg != expected_state)
    {
        std::cerr << "❌ Expected " << state_name << " (" << expected_state
                  << "), but got " << (int)dut->status_code_reg << "\n";
        assert(dut->status_code_reg == expected_state);
    }
    std::cout << "✅ [PASS] FSM moved to " << state_name << "\n";
}