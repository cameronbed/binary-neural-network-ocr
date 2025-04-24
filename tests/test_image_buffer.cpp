#include "main_test.hpp"
#include <iostream>
#include <string>
#include <cstdlib>
#include <cassert>
#include <stdexcept> // For std::invalid_argument
#include <iomanip>   // Added for std::setw and std::setfill
#include <vector>

void test_image_buffer(Vtop *dut)
{
    std::cout << "\n[TB IMG] test_image_write_and_fsm... [Clock cycles: " << main_time << "]\n";

    std::vector<std::string> digit_0 = {
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000011111111111111000000000",
        "000001111000000000011110000000",
        "000011100000000000000111000000",
        "000111000000000000000011100000",
        "000110000000000000000001100000",
        "001110000000000000000011100000",
        "001100000000000000000001100000",
        "001100000000000000000001100000",
        "001100000000000000000001100000",
        "001100000000000000000001100000",
        "001100000000000000000001100000",
        "001100000000000000000001100000",
        "001100000000000000000001100000",
        "001100000000000000000001100000",
        "001110000000000000000011100000",
        "000110000000000000000001100000",
        "000111000000000000000011100000",
        "000011100000000000000111000000",
        "000001111000000000011110000000",
        "000000011111111111111000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000"};

    constexpr uint8_t IMG_CMD = 0xBF;

    do_reset(dut, 2, true);
    tick(dut, 2); // FSM enters S_RX_CMD

    // Step 1: Send command to begin image reception
    spi_send_byte(dut, IMG_CMD, 0, true, true);
    tick(dut, 4);

    // Debug output to check FSM state and send_image_pin signal
    debug(dut);
    tick(dut, 2);

    assert(dut->send_image_pin == 1 && "[TEST] send_image_pin should be asserted after IMG_CMD");

    // Send all rows of digit_0
    int total_bytes_sent = 0;
    std::string flat;
    for (auto &row : digit_0)
        flat += row; // 900 characters
    for (size_t k = 0; k < flat.size(); k += 8)
    {
        uint8_t b = 0;
        for (int j = 0; j < 8 && k + j < flat.size(); ++j)
        {
            if (flat[k + j] == '1')
                b |= (1 << j); // LSB‑first!
            if (k + j >= flat.size())
                break;
        }
        spi_send_byte(dut, b, 0, false, true);
        tick(dut, 2);
    }

    debug(dut);

    // Pad extra byte (four trailing zero bits) to reach 904 bits total
    spi_send_byte(dut, 0x00, 0, false, true);
    tick(dut, 2);
    total_bytes_sent++;
    std::cout << "[TEST] Sent padding byte = 0x00 (00000000) at cycle " << main_time << "\n";
    debug(dut);
    tick(dut, 2);

    std::cout << "[TEST] Total bytes sent: " << total_bytes_sent << "\n";
    assert(total_bytes_sent == 113 && "[TEST] Total bytes sent must match IMG_BYTE_SIZE");

    debug(dut);
    tick(dut, 2);

    // Deassert CS_N
    dut->spi_cs_n = 1;
    tick(dut, 5);

    std::cout << "[TEST IMAGE BUFFER] All bytes write complete.\n";
}