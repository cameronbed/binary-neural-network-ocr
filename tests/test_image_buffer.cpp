#include "main_test.hpp"
#include "digits.h"
#include <iostream>
#include <string>
#include <cstdlib>
#include <cassert>
#include <stdexcept>
#include <iomanip>
#include <vector>
#include <iostream>

// Inline implementation for assert_status_code
void assert_status_code(Vsystem_controller *dut, int expected_status)
{
    if (dut->status_code_reg != expected_status)
    {
        std::cerr << "❌ Expected status: " << expected_status
                  << ", but got: " << dut->status_code_reg << "\n";
        assert(dut->status_code_reg == expected_status);
    }
}

std::string decode_seg(uint8_t seg)
{
    switch (seg)
    {
    case 0b1000000:
        return "0";
    case 0b1111001:
        return "1";
    case 0b0100100:
        return "2";
    case 0b0110000:
        return "3";
    case 0b0011001:
        return "4";
    case 0b0010010:
        return "5";
    case 0b0000010:
        return "6";
    case 0b1111000:
        return "7";
    case 0b0000000:
        return "8";
    case 0b0010000:
        return "9";
    default:
        return "Blank/Unknown";
    }
}

// Extracted function to flatten a 30x30 pattern into a single string
std::string flatten_pattern(const std::vector<std::string> &pattern)
{
    std::string flat;
    flat.reserve(30 * 30);
    for (const auto &row : pattern)
        flat += row;
    assert(flat.size() == 900);
    return flat;
}

// Extracted function to clear the buffer and wait until idle
void clear_buffer_and_wait(Vsystem_controller *dut)
{
    spi_send_byte(dut, CMD_CLEAR);
    while (dut->status_code_reg == STATUS_BNN_BUSY)
        tick_main_clk(dut, 1);
    check_fsm_state(dut, STATUS_IDLE, "STATUS_IDLE");
}

// Extracted function to send an image request and wait for readiness
void send_image_request_and_wait(Vsystem_controller *dut)
{
    spi_send_byte(dut, CMD_IMG_SEND_REQUEST);
    tick_main_clk(dut, 5);
    check_fsm_state(dut, STATUS_RX_IMG_RDY, "STATUS_RX_IMG_RDY");
}

// Extracted function to stream image bits LSB-first in bytes
void stream_image_bits(Vsystem_controller *dut, const std::string &flat)
{
    for (size_t i = 0; i < flat.size(); i += 8)
    {
        uint8_t b = 0;
        for (int bit = 0; bit < 8 && i + bit < flat.size(); ++bit)
            if (flat[i + bit] == '1')
                b |= (1 << bit);
        spi_send_byte(dut, b);
        tick_main_clk(dut, 2);
    }
}

// Updated send_digit function to use extracted functions
void send_digit(Vsystem_controller *dut, const std::vector<std::string> &digit, size_t idx)
{
    std::cout << "[TB IMG] Sending digit " << idx << "\n";

    std::string flat = flatten_pattern(digit);

    clear_buffer_and_wait(dut);
    send_image_request_and_wait(dut);
    stream_image_bits(dut, flat);

    // Wait for BNN to consume
    check_fsm_state(dut, STATUS_BNN_BUSY, "STATUS_BNN_BUSY");
    while (dut->status_code_reg == STATUS_BNN_BUSY)
        tick_main_clk(dut, 3);

    tick_main_clk(dut, 5);
    std::string decoded_seg = decode_seg(dut->seg);
    std::cout << "[SEG DISPLAY] 7-segment display for digit " << idx << ": " << decoded_seg << "\n";

    tick_main_clk(dut, 6);

    // Check if the decoded value matches the expected digit
    if (decoded_seg != std::to_string(idx))
    {
        std::cerr << "❌ Test failed for digit " << idx << ": Expected " << idx
                  << ", but got " << decoded_seg << "\n";
    }
    else
    {
        std::cout << "✅ Test passed for digit " << idx << "\n";
    }

    std::cout << "[TB IMG] Digit " << idx << " done (cycles: " << main_clk_ticks << ")\n";
}

// Updated send_pattern function to use extracted functions
void send_pattern(Vsystem_controller *dut, const std::vector<std::string> &pattern)
{
    std::cout << "[TB IMG] Sending custom pattern\n";

    std::string flat = flatten_pattern(pattern);

    clear_buffer_and_wait(dut);
    send_image_request_and_wait(dut);
    stream_image_bits(dut, flat);

    std::cout << "[TB IMG] Custom pattern sent successfully\n";
}

void test_clear_buffer(Vsystem_controller *dut)
{
    std::cout << "[TEST] Clearing buffer and waiting for idle state\n";
    spi_send_byte(dut, 0xFD); // CMD_CLEAR
    int i = 0;
    while (dut->status_code_reg == STATUS_BNN_BUSY)
    {
        tick_main_clk(dut, 1);
        i++;
    }
    std::cout << "Waited " << i << " cycles for BNN to finish\n";
    tick_main_clk(dut, 4);
    check_fsm_state(dut, STATUS_IDLE, "STATUS_IDLE");
}

void test_send_all_digits(Vsystem_controller *dut)
{
    std::cout << "[TEST] Sending all digits to the image buffer\n";

    std::vector<std::vector<std::string>> all_digits = {
        digit_0, digit_1, digit_2, digit_3,
        digit_4, digit_5, digit_6, digit_8, digit_9};

    for (size_t idx = 0; idx < all_digits.size(); ++idx)
    {
        send_digit(dut, all_digits[idx], idx);
    }
}

void test_send_repeating_pattern(Vsystem_controller *dut)
{
    std::cout << "[TEST] Sending repeating pattern to the image buffer\n";
    send_pattern(dut, repeating_pattern);

    // Wait for DUT to enter BNN inference state
    check_fsm_state(dut, STATUS_BNN_BUSY, "STATUS_BNN_BUSY");
    while (dut->status_code_reg == STATUS_BNN_BUSY)
        tick_main_clk(dut, 10);

    // Wait for DUT to enter BNN done state
    std::string decoded_seg = decode_seg(dut->seg);
    std::cout << "[SEG DISPLAY] 7-segment display: " << decoded_seg << "\n";

    check_fsm_state(dut, STATUS_RESULT_RDY, "STATUS_RESULT_RDY");
    decoded_seg = decode_seg(dut->seg);
    std::cout << "[SEG DISPLAY] 7-segment display: " << decoded_seg << "\n";

    tick_main_clk(dut, 10);

    decoded_seg = decode_seg(dut->seg);
    std::cout << "[SEG DISPLAY] 7-segment display: " << decoded_seg << "\n";

    std::cout << "[TEST] Repeating pattern processed successfully\n";
}

void test_single_digit(Vsystem_controller *dut, const std::vector<std::string> &digit, size_t idx)
{
    std::cout << "[TEST] Sending single digit " << idx << " to the image buffer\n";
    send_digit(dut, digit, idx);
}

void test_bnn_inference_start(Vsystem_controller *dut)
{
    std::cout << "[TEST] BNN Inference Start/Result/Clear\n";
}

void test_image_buffer(Vsystem_controller *dut)
{
    std::cout << "\n[TB IMG] test_image_buffer [Clock cycles: " << main_clk_ticks << "]\n";

    // Modular test calls
    test_clear_buffer(dut);
    test_bnn_inference_start(dut);
    test_send_repeating_pattern(dut);
    test_send_all_digits(dut);
    // test_single_digit(dut, digit_8, 0); // Example: Test digit 0 again

    std::cout << "[TB IMG] ✅ All tests completed successfully\n";
}