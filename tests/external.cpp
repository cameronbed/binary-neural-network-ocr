#include "verilated.h"
#include "svdpi.h"
#include "handles.h"
#include <iostream>
#include <cstdlib>

// Vtb *dut = nullptr;

// ------------------------------------------------------------------
// Simple SPI‐master state machine
// ------------------------------------------------------------------
enum SpiState
{
    ASSERT_CS,
    SEND_BITS,
    DEASSERT_CS,
    DONE
};

extern "C" void c_external(const svBit is_posedge)
{
    // Grab the current TB scope (the one `tb` instance)
    // dut = (Vtb *)Verilated::dpiScope();
    assert(::dut && "dut not set!");

    static SpiState state = ASSERT_CS;
    static int bytes_sent = 0, bit_idx = 7;
    static uint8_t cur_byte = 0x55;

    switch (state)
    {
    case ASSERT_CS:
        dut->spi_cs_n = 0;
        bit_idx = 7;
        bytes_sent = 0;
        cur_byte = 0x55;
        state = SEND_BITS;
        break;

    case SEND_BITS:
        // Drive SCLK = is_posedge
        std::cout << "[C++] Status code: " << (int)dut->status_code_reg << "\n";
        dut->SCLK = is_posedge;
        if (!is_posedge)
        {
            // falling edge: set next COPI bit
            dut->COPI = (cur_byte >> bit_idx) & 1;
        }
        else
        {
            // rising edge: advance bit counter
            if (--bit_idx < 0)
            {
                bit_idx = 7;
                if (++bytes_sent < 113)
                {
                    cur_byte = 0x55;
                }
                else if (bytes_sent == 113)
                {
                    cur_byte = 0xFF; // “process” command
                }
                else
                {
                    state = DEASSERT_CS;
                }
            }
        }
        break;

    case DEASSERT_CS:
        dut->spi_cs_n = 1;
        dut->SCLK = 0;
        std::cout << "[C++] All bytes sent, deasserting CS\n";
        std::cout << "[C++] Bytes sent: " << bytes_sent << "\n";
        std::cout << "[C++] Segment: " << (int)dut->seg << "\n";
        std::cout << "[C++] Status code: " << (int)dut->status_code_reg << "\n";
        state = DONE;
        break;

    case DONE:
        std::cout << "[C++] DONE reached, exiting simulation\n";
        std::exit(0);
        break;
    }

    // Must propagate our SPI pin changes *immediately*
    dut->eval();
}
