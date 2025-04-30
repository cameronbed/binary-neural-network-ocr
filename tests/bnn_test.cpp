#include "Vbnn_top.h"
#include "verilated.h"
#include <vector>
#include <string>
#include <iostream>
#include <cassert>
#include <bitset>

void set_image(const std::vector<std::string> &digit, Vbnn_top *tb)
{
    std::cout << "[INFO] Setting image data...\n";
    // Flatten the digit into a single string
    std::string flat_digit;
    for (const auto &row : digit)
    {
        flat_digit += row;
    }

    // Convert the flattened string into a VlWide<29> array
    VlWide<29> img_data = {0}; // Initialize with zeros
    size_t bit_index = 0;

    for (size_t i = 0; i < flat_digit.size(); ++i)
    {
        if (flat_digit[i] == '1')
        {
            img_data[bit_index / 32] |= (1U << (bit_index % 32));
        }
        bit_index++;
    }

    // Assign the converted data to tb->img_in
    tb->img_in = img_data;
    std::cout << "[INFO] Image data set successfully.\n";
}

void tick_clk(Vbnn_top *tb, int cycles = 1)
{
    for (int i = 0; i < cycles; i++)
    {
        tb->clk = !tb->clk;
        tb->eval();
    }
}

void test_digit(const std::vector<std::string> &digit, const std::string &expected_result, Vbnn_top *tb)
{
    std::cout << "[INFO] Starting test for digit with expected result: " << expected_result << "\n";
    set_image(digit, tb);

    tb->bnn_enable = 1;
    tb->img_buffer_full = 1;
    tb->eval();
    std::cout << "[INFO] Waiting for result to be ready...\n";
    while (!tb->result_ready)
        tick_clk(tb, 1);
    tb->bnn_enable = 0;

    std::cout << "[INFO] Result ready. Checking output...\n";
    tick_clk(tb, 2); // Wait for 2 additional clock cycles to ensure result_out is stable
    std::cout << "[DEBUG] Raw result_out (binary): " << std::bitset<4>(tb->result_out) << "\n";
    if (tb->result_out == std::stoi(expected_result))
    {
        std::cout << "✅ Test passed for digit " << expected_result << "\n";
    }
    else
    {
        std::cerr << "❌ Test failed for digit " << expected_result
                  << ". Expected: " << expected_result << ", Got: " << tb->result_out << "\n";
        assert(tb->result_out == std::stoi(expected_result));
    }
}

int main()
{
    std::cout << "[INFO] Initializing testbench...\n";
    const char *argv[] = {""}; // Empty argument list
    Verilated::commandArgs(1, argv);
    Vbnn_top *tb = new Vbnn_top;

    tb->rst_n = 0;
    tb->clk = 0;
    tb->eval();
    tb->rst_n = 1;

    std::cout << "[INFO] Running test for digit '2'...\n";
    std::vector<std::string> digit_2 = {
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000011111111111110000000000",
        "000000111000000001111000000000",
        "000001100000000000111100000000",
        "000001000000000000011100000000",
        "000000000000000000011100000000",
        "000000000000000000111000000000",
        "000000000000000001110000000000",
        "000000000000000011100000000000",
        "000000000000000111000000000000",
        "000000000000001110000000000000",
        "000000000000111000000000000000",
        "000000000001110000000000000000",
        "000000000011100000000000000000",
        "000000001110000000000000000000",
        "000000011100000000000000000000",
        "000000111000000000000000000000",
        "000001110000000000000000000000",
        "000011111111111111111111110000",
        "000011111111111111111111110000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000",
        "000000000000000000000000000000"};

    test_digit(digit_2, "2", tb);

    std::cout << "[INFO] Cleaning up testbench...\n";
    delete tb;
    std::cout << "[INFO] Test completed.\n";
    return 0;
}