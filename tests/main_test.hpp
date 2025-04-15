#pragma once

#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// Declare shared variables
extern vluint64_t main_time;
extern int test_failures;

// Tests
void test_spi(Vtop *dut);

// Helpers
void tick(Vtop *dut, VerilatedVcdC *tfp, int *timestamp, int n);
void tick(Vtop *dut, int n);
void spi_send_byte(Vtop *dut, uint8_t byte, int mode, VerilatedVcdC *tfp, int *timestamp, bool verbose = false);
void debug(Vtop *dut);

// Helpers Tests
void test_tick_and_spi_send(Vtop *dut);