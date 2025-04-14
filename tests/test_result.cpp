#include "bnn_controller_tb.hpp"
#include <iostream>
#include <string>
#include <cstdlib>

void test_result_tx_and_clear(Vbnn_controller *dut)
{
    std::cout << "\n[TEST] test_result_tx_and_clear...\n";
    int timestamp = 0;

    // Assume FSM is in RESULT_TX (mock result ready if needed)
    dut->rst_n = 1;
    dut->CS = 0;

    // Fill buffer & simulate result ready
    for (int i = 0; i < 98; ++i)                          // Send 98 bytes (784 bits)
        spi_send_byte(dut, 0x01, 0, nullptr, &timestamp); // Each byte contains 1 bit of data

    while (dut->debug_state != 3 && timestamp < 2000)
        tick(dut, nullptr, &timestamp, 1);

    assert(dut->debug_state == 3 && "FSM should be in RESULT_TX");
    std::cout << "[PASS] FSM is in RESULT_TX\n";

    // Simulate CS going high to trigger CLEAR
    dut->CS = 1;
    tick(dut, nullptr, &timestamp, 10);

    assert(dut->debug_state == 4 && "FSM should be in CLEAR");
    std::cout << "[PASS] FSM entered CLEAR after CS deasserted\n";
}