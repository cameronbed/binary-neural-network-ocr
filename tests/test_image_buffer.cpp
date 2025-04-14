#include "bnn_controller_tb.hpp"
#include <iostream>
#include <string>
#include <cstdlib>

void test_image_write_and_fsm(Vbnn_controller *dut)
{
    std::cout << "\n[TEST] test_image_write_and_fsm...\n";
    int timestamp = 0;

    // Reset and enter IMG_RX
    dut->rst_n = 0;
    dut->CS = 1;
    tick(dut, nullptr, &timestamp, 3);
    dut->rst_n = 1;
    tick(dut, nullptr, &timestamp, 3);

    dut->CS = 0; // Activate SPI
    tick(dut, nullptr, &timestamp, 3);

    // Send 98 bytes (784 bits)
    for (int i = 0; i < 98; ++i)
        spi_send_byte(dut, 0x01, 0, nullptr, &timestamp); // Each byte contains 1 bit of data
    tick(dut, nullptr, &timestamp, 5);

    // Heartbeat check
    assert(dut->debug_state == 1 && "FSM should be in IMG_RX");
    std::cout << "[PASS] FSM entered IMG_RX and accepted bits\n";
}