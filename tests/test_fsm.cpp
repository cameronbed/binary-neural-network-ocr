#include "main_test.hpp"

#include <iostream>
#include <string>
#include <cstdlib>
#include <cassert>
#include <stdexcept> // For std::invalid_argument
#include <iomanip>   // Added for std::setw and std::setfill

void test_fsm(Vtop *dut)
{
    std::cout << "[Test FSM] Running FSM test..." << std::endl;
    assert(dut && "DUT must not be null");

    constexpr uint8_t STATUS_CMD = 0xFE;
    constexpr uint8_t IMG_CMD = 0xBF;
    constexpr uint8_t UNKNOWN_CMD = 0xAA;
    constexpr uint8_t TEST_IMG_BYTE = 0x55;

    // ---------- [1] RESET + DEBUG ----------
    do_reset(dut, 2, true);
    debug(dut);

    // ---------- [2] STATUS_CMD TEST ----------
    std::cout << "[DEBUG] Testing STATUS_CMD..." << std::endl;
    spi_send_byte(dut, STATUS_CMD, 0, true, true);
    tick(dut, 3);
    dut->spi_cs_n = 1;
    tick(dut, 5);
    std::cout << "[DEBUG] status_ready = " << int(dut->status_ready) << "\n";
    assert(dut->status_ready == 1 && "[TEST FSM] Expected status_ready = 1");

    // ---------- [3] IMG_CMD TEST ----------
    std::cout << "[DEBUG] Testing IMG_CMD..." << std::endl;
    spi_send_byte(dut, IMG_CMD, 0, true, true);
    tick(dut, 3);
    dut->spi_cs_n = 1;
    tick(dut, 3);
    std::cout << "[DEBUG] send_image = " << int(dut->send_image) << "\n";
    assert(dut->send_image == 1 && "[TEST FSM] Expected send_image = 1");

    // ---------- [4] IMAGE BYTE WRITE TEST ----------
    std::cout << "[DEBUG] Sending one image data byte (0x55)..." << std::endl;
    spi_send_byte(dut, TEST_IMG_BYTE, 0, true, true);
    tick(dut, 3);
    dut->spi_cs_n = 1;
    tick(dut, 1);

    // Debug bytes_received during image reception
    //     std::cout << "[DEBUG] bytes_received = " << int(dut->bytes_received) << "\n";

    // Expect FSM to still be in image receive mode
    std::cout << "[DEBUG] send_image = " << int(dut->send_image) << "\n";
    assert(dut->send_image == 1 && "[TEST FSM] send_image should remain high during image RX");

    // ---------- [5] send_image SHOULD RESET ----------
    tick(dut, 10); // Allow FSM to return to IDLE
    assert(dut->send_image == 0 && "[TEST FSM] send_image not cleared after return to S_IDLE");

    // ---------- [6] UNKNOWN CMD TEST ----------
    std::cout << "[DEBUG] Testing unknown command (0xAA)..." << std::endl;
    do_reset(dut, 2, true);
    tick(dut, 2);
    spi_send_byte(dut, UNKNOWN_CMD, 0, true, true);
    tick(dut, 3);
    dut->spi_cs_n = 1;
    tick(dut, 5);
    assert(dut->status_ready == 0 && "[TEST FSM] Unexpected status_ready for unknown cmd");
    assert(dut->send_image == 0 && "[TEST FSM] Unexpected send_image for unknown cmd");

    // ---------- [7] RX_CMD TIMEOUT TEST (functional) ----------
    std::cout << "[DEBUG] Simulating RX_CMD timeout (no byte sent)..." << std::endl;
    do_reset(dut, 2, true);
    tick(dut, 2);
    tick(dut, 100005); // TIMEOUT_LIMIT + slack
    assert(dut->status_ready == 0);
    assert(dut->send_image == 0);

    // ---------- [END] ----------
    std::cout << "[TEST FSM] ALL TESTS PASSED ✅" << std::endl;
    debug(dut);
}