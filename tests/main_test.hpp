#pragma once

#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// Declare shared variables
extern vluint64_t main_time;
extern int test_failures;

// Tests
void test_spi(Vtop *dut);
void test_fsm(Vtop *dut);
void test_image_buffer(Vtop *dut);

// Helpers
void tick(Vtop *dut, int cycles);
void spi_send_byte(Vtop *dut, uint8_t byte, int mode, bool verbose, bool keep_cs);
void do_reset(Vtop *dut, int cycles, bool verbose);
void debug(Vtop *dut);
