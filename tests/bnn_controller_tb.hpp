#pragma once

#include "Vbnn_controller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// Declare shared variables
extern vluint64_t main_time;
extern int test_failures;

// Helpers
void tick(Vbnn_controller *dut, VerilatedVcdC *tfp, int *timestamp, int n);
void spi_send_byte(Vbnn_controller *dut, uint8_t byte, int mode, VerilatedVcdC *tfp, int *timestamp, bool verbose = false);

// Helpers Tests
void test_tick_and_spi_send(Vbnn_controller *dut);

// Tests
void test_reset_and_startup(Vbnn_controller *dut);
void test_image_write_and_fsm(Vbnn_controller *dut);
void test_inference_trigger(Vbnn_controller *dut);
void test_result_tx_and_clear(Vbnn_controller *dut);
void test_fsm_loop_end_to_end(Vbnn_controller *dut);