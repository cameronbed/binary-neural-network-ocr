#pragma once

#include "Vbnn_controller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

void assert_equal(const std::string &label, int expected, int actual);
void test_reset_behavior(Vbnn_controller *dut);
void test_bnn_controller(Vbnn_controller *dut);
void test_image_buffer(Vbnn_controller *dut);
void test_bnn_module(Vbnn_controller *dut);
void test_spi_peripheral(Vbnn_controller *dut);
void tick(Vbnn_controller *dut);
void spi_send_byte(Vbnn_controller *dut, uint8_t byte);