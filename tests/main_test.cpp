#include "main_test.hpp"
#include <iostream>
#include <string>
#include <cstdlib>

// Define the VERBOSE variable
int VERBOSE = 0;

vluint64_t main_clk_ticks = 0;
vluint64_t sclk_ticks = 0;

// Modular Test Functions
void test_reset(Vsystem_controller *dut);
void test_spi_command_send(Vsystem_controller *dut);
void test_buffer_write(Vsystem_controller *dut);
void test_bnn_inference(Vsystem_controller *dut);
void test_image_buffer_module(Vsystem_controller *dut);
void test_clk(Vsystem_controller *dut);

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vsystem_controller *dut = new Vsystem_controller;
    std::cout << "Starting test..." << std::endl;

    // Example: Set VERBOSE to 1
    VERBOSE = 0;

    if (VERBOSE)
    {
        std::cout << "Verbose mode enabled." << std::endl;
    }

    test_reset(dut);
    test_spi_command_send(dut);
    test_buffer_write(dut);
    test_bnn_inference(dut);
    test_image_buffer_module(dut);
    test_image_buffer(dut);
    ;

    // Reset VERBOSE if needed
    VERBOSE = 0;

    delete dut;
    return 0;
}

void test_reset(Vsystem_controller *dut)
{
    std::cout << "[TEST] RESET\n";

    do_reset(dut);

    assert(dut->status_code_reg == STATUS_IDLE); // STATUS_IDLE = 0
    std::cout << "[PASS] Reset brings system_controller to IDLE state.\n";
}

void test_spi_command_send(Vsystem_controller *dut)
{
    std::cout << "[TEST] SPI COMMAND SEND\n";
    spi_send_byte(dut, 0xFE);
    tick_main_clk(dut, 5);

    tick_main_clk(dut, 2);

    // Step 2: Check we are in WAIT_IMAGE (STATUS_RX_IMG_RDY)
    if (dut->status_code_reg != STATUS_RX_IMG_RDY)
    {
        std::cerr << "❌ Expected STATUS_RX_IMG_RDY (" << (int)STATUS_RX_IMG_RDY
                  << "), but got " << (int)dut->status_code_reg << "\n";
        assert(dut->status_code_reg == STATUS_RX_IMG_RDY);
    }
    std::cout << "✅ [PASS] FSM moved to STATUS_RX_IMG_RDY\n";

    // Step 3: Now send dummy byte to trigger image receiving
    spi_send_byte(dut, 0x00); // First image data byte
    tick_main_clk(dut, 5);

    tick_main_clk(dut, 2);

    if (dut->status_code_reg == STATUS_RX_IMG)
    {
        std::cout << "✅ [PASS] FSM moved to STATUS_RX_IMG\n";
    }
    else
    {
        std::cerr << "❌ Expected STATUS_RX_IMG (" << (int)STATUS_RX_IMG
                  << "), but got " << (int)dut->status_code_reg << "\n";
        assert(dut->status_code_reg == STATUS_RX_IMG);
    }
}

void test_buffer_write(Vsystem_controller *dut)
{
    std::cout << "[TEST] BUFFER WRITE\n";

    // Step 1: Reset the DUT
    do_reset(dut);

    // Step 2: Send the CMD_IMG_SEND_REQUEST command to transition to S_WAIT_IMAGE
    spi_send_byte(dut, 0xFE); // CMD_IMG_SEND_REQUEST
    tick_main_clk(dut, 5);

    assert(dut->status_code_reg == STATUS_RX_IMG_RDY);
    std::cout << "✅ [PASS] FSM moved to STATUS_RX_IMG_RDY\n";

    // Step 3: Send image data bytes and verify buffer writes
    for (int i = 0; i < 5; i++) // Test with 5 bytes
    {
        uint8_t test_byte = 0xFF; // Example data: 0x10, 0x11, 0x12, ...
        spi_send_byte(dut, test_byte);
        tick_main_clk(dut, 5);
    }

    // debug(dut);

    // Step 4: Verify FSM transitions to S_WAIT_FOR_BNN after the last byte
    for (int i = 5; i < 113; i++) // Fill the rest of the buffer
    {
        spi_send_byte(dut, 0xFF);
        tick_main_clk(dut, 5);
    }

    tick_main_clk(dut, 10);

    // debug(dut);

    check_fsm_state(dut, STATUS_BNN_BUSY, "STATUS_BNN_BUSY");
}

void test_bnn_inference(Vsystem_controller *dut)
{
    std::cout << "[TEST] BNN Inference Start/Result/Clear\n";
}

void test_image_buffer_module(Vsystem_controller *dut)
{
    std::cout << "[TEST] IMAGE BUFFER MODULE\n";

    // --- Reset ---
    do_reset(dut);

    // After reset: Check status_code_reg is STATUS_IDLE
    assert(dut->status_code_reg == STATUS_IDLE);
    std::cout << "[PASS] Reset ⇒ STATUS_IDLE\n";

    // --- Send CMD_IMG_SEND_REQUEST to transition to S_WAIT_IMAGE ---
    spi_send_byte(dut, 0xFE); // CMD_IMG_SEND_REQUEST
    tick_main_clk(dut, 5);

    // Check FSM state is STATUS_RX_IMG_RDY
    assert(dut->status_code_reg == STATUS_RX_IMG_RDY);
    std::cout << "[PASS] FSM moved to STATUS_RX_IMG_RDY\n";

    // --- Write 3 bytes ---
    uint8_t seq1[3] = {0x12, 0x34, 0x56};
    for (int i = 0; i < 3; i++)
    {
        spi_send_byte(dut, seq1[i]);
        tick_main_clk(dut, 5);

        // Check FSM state is STATUS_RX_IMG
        assert(dut->status_code_reg == STATUS_RX_IMG);
        std::cout << "[PASS] FSM in STATUS_RX_IMG after sending byte " << i << "\n";
    }

    // --- Clear the buffer ---
    spi_send_byte(dut, 0xFD); // CMD_CLEAR
    tick_main_clk(dut, 5);

    // debug(dut);

    for (int i = 0; i < 2; i++) // Allow 2 cycles for buffer_empty to propagate
    {
        tick_main_clk(dut, 1);
        if (dut->status_code_reg == STATUS_IDLE)
        {
            std::cout << "[PASS] FSM moved to STATUS_IDLE after clear\n";
            break;
        }
    }

    // Wait for buffer_empty to assert
    tick_main_clk(dut, 10);

    // debug(dut);

    // Check FSM state is STATUS_IDLE
    check_fsm_state(dut, STATUS_IDLE, "STATUS_IDLE");

    spi_send_byte(dut, 0xFE); // CMD_IMG_SEND_REQUEST
    tick_main_clk(dut, 5);

    // debug(dut);

    // --- Write 113 bytes to fill the buffer ---
    for (int i = 0; i < 113; i++)
    {
        spi_send_byte(dut, 0xFF); // Write 0xFF
        tick_main_clk(dut, 5);
    }

    tick_main_clk(dut, 5); // Allow time for FSM to transition

    // debug(dut);

    // Check FSM state transitions to STATUS_BNN_BUSY after buffer is full
    check_fsm_state(dut, STATUS_BNN_BUSY, "STATUS_BNN_BUSY");

    std::cout << "[TEST COMPLETE] IMAGE BUFFER MODULE\n";
}