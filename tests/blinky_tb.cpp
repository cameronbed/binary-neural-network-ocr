#include "Vblinky.h" // Generated from Verilator
#include "verilated.h"
#include <cassert>
#include <iostream>

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vblinky *dut = new Vblinky;

    dut->clk = 0;
    dut->eval();

    for (int i = 0; i < 100; ++i)
    {
        dut->clk = !dut->clk;
        dut->eval();
        printf("led = %d\n", dut->led);
    }

    delete dut;
    return 0;

    delete dut;
    return 0;
}
