#pragma once

#include "Vsystem_controller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// Declare shared variables
extern vluint64_t main_time;
extern int test_failures;

// Tests
void test_spi(Vsystem_controller *dut);
void test_fsm(Vsystem_controller *dut);
void test_image_buffer(Vsystem_controller *dut);

// Helpers
void tick(Vsystem_controller *dut, int cycles);
void spi_send_byte(Vsystem_controller *dut, uint8_t byte, int mode, bool verbose, bool keep_cs);
void do_reset(Vsystem_controller *dut, int cycles, bool verbose);
void debug(Vsystem_controller *dut);
