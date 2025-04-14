#include "bnn_controller_tb.hpp"
#include <iostream>
#include <string>
#include <cstdlib>

void test_inference_trigger(Vbnn_controller *dut)
{
    std::cout << "\n[TEST] test_inference_trigger...\n";
    int timestamp = 0;

    // Reset and prepare the DUT
    dut->rst_n = 0;
    tick(dut, nullptr, &timestamp, 5);
    dut->rst_n = 1;
    tick(dut, nullptr, &timestamp, 5);

    // Activate SPI and fill the buffer
    dut->CS = 0;
    for (int i = 0; i < 98; ++i)                                 // Send 98 bytes (784 bits)
        spi_send_byte(dut, 0x01, 0, nullptr, &timestamp, false); // Each byte contains 1 bit of data

    // Debug output for buffer_full
    std::cout << "[DEBUG] buffer_full: " << dut->debug_buffer_full << "\n";

    // Wait for FSM to transition to INFERENCE
    int max_wait = 1000; // Timeout to prevent infinite loop
    while (dut->debug_state != 2 && timestamp < max_wait)
        tick(dut, nullptr, &timestamp, 1);

    if (dut->debug_state != 2)
    {
        std::cerr << "[FAIL] FSM did not transition to INFERENCE within timeout\n";
        exit(1);
    }

    // Assert FSM transitioned to INFERENCE
    assert(dut->debug_state == 2 && "FSM should have transitioned to INFERENCE");
    std::cout << "[PASS] FSM transitioned to INFERENCE\n";
}