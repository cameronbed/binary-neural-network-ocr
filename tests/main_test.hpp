#pragma once

#include "Vsystem_controller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <memory>
#include <vector>
#include <iostream>
#include <stdexcept>
#include <string>

// Declare shared variables
extern vluint64_t main_clk_ticks;
extern vluint64_t sclk_ticks;

// SPI Commands
constexpr uint8_t CMD_IMG_SEND_REQUEST = 0xFE; // 11111110
constexpr uint8_t CMD_CLEAR = 0xFD;            // 11111101

// Status Codes
constexpr uint8_t STATUS_IDLE = 0;       // FPGA idle, ready
constexpr uint8_t STATUS_RX_IMG_RDY = 1; // Receiving image bytes
constexpr uint8_t STATUS_RX_IMG = 2;     // SPI bytes sent are being put in the buffer
constexpr uint8_t STATUS_BNN_BUSY = 4;   // Image received, BNN running
constexpr uint8_t STATUS_RESULT_RDY = 8; // BNN result ready
constexpr uint8_t STATUS_ERROR = 14;     // Error occurred
constexpr uint8_t STATUS_UNKNOWN = 15;   // Busy / unknown

#define SPI_CLK_PERIOD 10
#define MAIN_CLK_PERIOD 5

// Replace the macro with a global variable
extern int VERBOSE;

// Tests
void test_spi(Vsystem_controller *dut);
void test_fsm(Vsystem_controller *dut);
void test_image_buffer(Vsystem_controller *dut);

// Helpers
void tick_main_clk(Vsystem_controller *dut, int cycles);
void sclk_rise(Vsystem_controller *dut);
void sclk_fall(Vsystem_controller *dut);
void check_fsm_state(Vsystem_controller *dut, int expected_state, const std::string &state_name);
void spi_send_bytes(Vsystem_controller *dut, const std::vector<uint8_t> &bytes);
void spi_send_byte(Vsystem_controller *dut, const uint8_t byte_val);

void do_reset(Vsystem_controller *dut);
void debug(Vsystem_controller *dut);

class DUT
{
public:
    std::unique_ptr<Vsystem_controller> dut;
    std::unique_ptr<VerilatedVcdC> tfp;
    vluint64_t main_time = 0;
    vluint64_t sclk_time = 0;
    int verbose = 0;

    DUT()
    {
        Verilated::traceEverOn(true);
        dut = std::make_unique<Vsystem_controller>();
        tfp = std::make_unique<VerilatedVcdC>();
        dut->trace(tfp.get(), 99); // trace 99 levels of hierarchy
        tfp->open("waveform.vcd");
    }

    ~DUT()
    {
        tfp->close();
    }

    void tick_main_clk(int cycles = 1)
    {
        for (int i = 0; i < cycles; ++i)
        {
            dut->clk = 0;
            dut->eval();
            tfp->dump(main_time);
            main_time += MAIN_CLK_PERIOD / 2;

            dut->clk = 1;
            dut->eval();
            tfp->dump(main_time);
            main_time += MAIN_CLK_PERIOD / 2;
        }
    }

    void sclk_rise(int cycles = 1)
    {
        dut->SCLK = 1;
        dut->eval();
        tick_main_clk(cycles);
    }

    void sclk_fall(int cycles = 1)
    {
        dut->SCLK = 0;
        dut->eval();
        sclk_time++;
        tick_main_clk(cycles);
    }

    void spi_send_byte(uint8_t byte_val)
    {
        if (!dut)
            throw std::invalid_argument("spi_send_byte: DUT pointer is null!");

        dut->spi_cs_n = 0; // Start transaction
        dut->eval();
        tick_main_clk(2); // Setup time after CS_N falling

        if (verbose)
        {
            debug();
            std::cout << "[SPI] Sending byte: 0x" << std::hex << (int)byte_val << "\n";
        }

        for (int i = 7; i >= 0; --i)
        {
            bool bit_val = (byte_val >> i) & 0x1;
            dut->COPI = bit_val;
            dut->eval();
            tick_main_clk(2); // Setup before SCLK rising

            sclk_rise();
            sclk_fall();

            if (verbose)
                debug();
        }

        dut->spi_cs_n = 1; // End transaction
        dut->eval();
        tick_main_clk(10); // Hold time after transaction end

        if (verbose)
        {
            debug();
            std::cout << "[SPI] Byte sent: 0x" << std::hex << (int)byte_val << "\n";
        }
    }

    void spi_send_bytes(const std::vector<uint8_t> &bytes)
    {
        for (auto byte : bytes)
        {
            spi_send_byte(byte);
        }
    }

    void do_reset()
    {
        if (!dut)
            throw std::invalid_argument("do_reset: DUT pointer is null!");

        int cycles = 1;

        dut->rst_n_pin = 0;
        tick_main_clk(cycles);

        dut->rst_n_pin = 1;
        tick_main_clk(cycles);

        tick_main_clk(cycles);

        main_time = 0; // reset simulation time counter if you want

        if (verbose)
        {
            std::cout << "[RST DEBUG]: Reset completed over " << 3 * cycles << " cycles.\n";
        }
    }

    void debug()
    {
        if (!dut)
            return;

        dut->debug_trigger = 1;
        tick_main_clk(2);

        std::cout << "[DEBUG TRIGGER]: Trigger asserted at time " << main_time << "\n";

        dut->debug_trigger = 0;
        tick_main_clk(2);

        std::cout << "[DEBUG TRIGGER]: Trigger deasserted at time " << main_time << "\n";
    }

    void check_fsm_state(int expected_state, const std::string &state_name)
    {
        if (dut->status_code_reg != expected_state)
        {
            std::cerr << "❌ Expected " << state_name << " (" << expected_state
                      << "), but got " << (int)dut->status_code_reg << "\n";
            assert(dut->status_code_reg == expected_state);
        }
        std::cout << "✅ [PASS] FSM moved to " << state_name << "\n";
    }
};