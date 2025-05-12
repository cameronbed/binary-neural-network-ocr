#include "verilated.h"
#include "Vtb.h"
#include "handles.h"
#include <iostream>

Vtb *dut = nullptr;

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    auto ctx = new VerilatedContext;

    dut = new Vtb{ctx, "tb"};

    dut->rst_n_pin = 0;
    dut->eval();
    ctx->timeInc(20);
    dut->rst_n_pin = 1;
    dut->eval();

    while (!ctx->gotFinish())
    {
        ctx->timeInc(1);
        dut->eval();
    }

    delete dut;
    delete ctx;

    return 0;
}
