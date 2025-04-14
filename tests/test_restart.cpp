#include "bnn_controller_tb.hpp"
#include <iostream>
#include <string>
#include <cstdlib>

void test_reset_and_startup(Vbnn_controller *dut)
{
    std::cout << "\n[TEST] test_reset_and_startup...\n";
    int timestamp = 0;

    // Apply reset
    dut->rst_n = 0;
    tick(dut, nullptr, &timestamp, 5);
    dut->rst_n = 1;
    tick(dut, nullptr, &timestamp, 5);

    // Debug output for FSM state
    std::cout << "[DEBUG] FSM state after reset: " << (int)dut->debug_state << "\n";

    // Heartbeat checks
    std::cout << "[DEBUG] FSM state after reset: " << dut->debug_state << "\n";
    assert(dut->debug_state == 0 && "FSM should be IDLE after reset");
    std::cout << "[PASS] FSM is in IDLE after reset\n";
}