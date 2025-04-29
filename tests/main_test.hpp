#pragma once

#include "Vsystem_controller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// Declare shared variables
extern vluint64_t main_clk_ticks;
extern vluint64_t sclk_ticks;

// SPI Commands
constexpr uint8_t CMD_IMG_SEND_REQUEST = 0xFE; // 11111110
constexpr uint8_t CMD_CLEAR = 0xFD;            // 11111101

// Status Codes
constexpr uint8_t STATUS_IDLE = 0;       // FPGA idle, ready
constexpr uint8_t STATUS_RX_IMG_RDY = 1; // Receiving image bytes
constexpr uint8_t STATUS_RX_IMG = 2;     // SPI bytes sent are being put in the buffer
constexpr uint8_t STATUS_BNN_BUSY = 4;   // Image received, BNN running
constexpr uint8_t STATUS_RESULT_RDY = 8; // BNN result ready
constexpr uint8_t STATUS_ERROR = 14;     // Error occurred
constexpr uint8_t STATUS_UNKNOWN = 15;   // Busy / unknown

#define SPI_CLK_PERIOD 10
#define MAIN_CLK_PERIOD 5

// Replace the macro with a global variable
extern int VERBOSE;

// Tests
void test_spi(Vsystem_controller *dut);
void test_fsm(Vsystem_controller *dut);
void test_image_buffer(Vsystem_controller *dut);

// Helpers
void tick_main_clk(Vsystem_controller *dut, int cycles);
void sclk_rise(Vsystem_controller *dut);
void sclk_fall(Vsystem_controller *dut);
void check_fsm_state(Vsystem_controller *dut, int expected_state, const std::string &state_name);
void spi_send_bytes(Vsystem_controller *dut, const std::vector<uint8_t> &bytes);
void spi_send_byte(Vsystem_controller *dut, const uint8_t byte_val);

void do_reset(Vsystem_controller *dut);
void debug(Vsystem_controller *dut);
