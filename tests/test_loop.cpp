#include "bnn_controller_tb.hpp"
#include <iostream>
#include <string>
#include <cstdlib>

void test_fsm_loop_end_to_end(Vbnn_controller *dut)
{
    std::cout << "\n[TEST] test_fsm_loop_end_to_end...\n";
    int timestamp = 0;

    dut->rst_n = 0;
    tick(dut, nullptr, &timestamp, 3);
    dut->rst_n = 1;
    tick(dut, nullptr, &timestamp, 3);

    dut->CS = 0;

    for (int i = 0; i < 98; ++i)                                 // Send 98 bytes (784 bits)
        spi_send_byte(dut, 0x01, 0, nullptr, &timestamp, false); // Each byte contains 1 bit of data

    int max_wait = 1000; // Timeout to prevent infinite loop
    while (dut->debug_state != 2 && timestamp < max_wait)
        tick(dut, nullptr, &timestamp, 1);

    if (dut->debug_state != 2)
    {
        std::cerr << "[FAIL] FSM did not reach INFERENCE within timeout\n";
        exit(1);
    }

    assert(dut->debug_state == 2 && "FSM should be in INFERENCE");
    std::cout << "[PASS] FSM reached INFERENCE\n";

    // Simulate inference completion
    max_wait = 2000; // Adjust timeout for next state
    while (dut->debug_state != 3 && timestamp < max_wait)
        tick(dut, nullptr, &timestamp, 1);

    if (dut->debug_state != 3)
    {
        std::cerr << "[FAIL] FSM did not reach RESULT_TX within timeout\n";
        exit(1);
    }

    assert(dut->debug_state == 3 && "FSM should be in RESULT_TX");
    std::cout << "[PASS] FSM reached RESULT_TX\n";

    // Simulate CS rising and clear
    dut->CS = 1;
    max_wait = 3000; // Adjust timeout for final state
    while (dut->debug_state != 0 && timestamp < max_wait)
        tick(dut, nullptr, &timestamp, 1);

    if (dut->debug_state != 0)
    {
        std::cerr << "[FAIL] FSM did not return to IDLE within timeout\n";
        exit(1);
    }

    assert(dut->debug_state == 0 && "FSM should return to IDLE");
    std::cout << "[PASS] FSM returned to IDLE — end-to-end complete\n";
}