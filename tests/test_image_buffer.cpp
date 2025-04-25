#include "main_test.hpp"
#include <iostream>
#include <string>
#include <cstdlib>
#include <cassert>
#include <stdexcept> // For std::invalid_argument
#include <iomanip>   // Added for std::setw and std::setfill
#include <vector>

void test_image_buffer(Vsystem_controller *dut)
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

    std::vector<std::string> digit_3 = {
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000011111111111111000000000",
        "000001111000000000011110000000",
        "000011100000000000000111000000",
        "000111000000000000000011100000",
        "000110000000000000000011100000",
        "000000000000000000000111000000",
        "000000000000000000001110000000",
        "000000000000000001111000000000",
        "000000000111111111100000000000",
        "000000000111111111100000000000",
        "000000000000000000111000000000",
        "000000000000000000011100000000",
        "000000000000000000001110000000",
        "000000000000000000001110000000",
        "001100000000000000001110000000",
        "001110000000000000001100000000",
        "000111000000000000011100000000",
        "000011100000000000111000000000",
        "000001111000000001111000000000",
        "000000011111111111000000000000",
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
    std::cout << "[TB IMG] Enabling debug trigger before sending IMG_CMD...\n";
    debug(dut);
    tick(dut, 1); // Allow debug enable to propagate

    spi_send_byte(dut, IMG_CMD, 0, true, true);
    tick(dut, 4); // Keep original ticks, maybe spi_send_byte includes enough

    // Add more ticks to allow FSM state changes and signal propagation
    tick(dut, 10); // Add more delay before checking

    // Debug output to check FSM state and send_image_pin signal
    // debug(dut); // Keep commented, rely on debug_module
    // tick(dut, 2);

    std::cout << "[TB IMG] Checking assertion...\n";
    assert(dut->send_image_pin == 1 && "[TEST] send_image_pin should be asserted after IMG_CMD");
    std::cout << "[TB IMG] Assertion passed. Disabling debug trigger.\n";
    debug(dut);
    tick(dut, 1);

    // Send all rows of digit_3
    int total_bytes_sent = 0;
    std::string flat;
    for (auto &row : digit_3)
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
    std::cout << "\n"
              << "[RESULT]:" << dut->result_out << "\n";

    debug(dut);

    // Pad extra byte (four trailing zero bits) to reach 904 bits total
    spi_send_byte(dut, 0x00, 0, false, true);
    tick(dut, 2);
    total_bytes_sent++;
    std::cout << "[TEST] Sent padding byte = 0x00 (00000000) at cycle " << main_time << "\n";
    debug(dut);
    tick(dut, 2);

    std::cout << "[TEST] Total bytes sent: " << total_bytes_sent << "\n";
    // assert(total_bytes_sent == 113 && "[TEST] Total bytes sent must match IMG_BYTE_SIZE");

    debug(dut);
    tick(dut, 2);

    // Deassert CS_N
    dut->spi_cs_n = 1;
    tick(dut, 5);

    std::cout << "[TEST IMAGE BUFFER] All bytes write complete.\n";
}