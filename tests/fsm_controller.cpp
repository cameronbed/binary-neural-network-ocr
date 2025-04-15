#include "main_test.hpp"

#include <iostream>
#include <string>
#include <cstdlib>
#include <cassert>
#include <stdexcept> // For std::invalid_argument
#include <iomanip>   // Added for std::setw and std::setfill

void fsm_controller(Vtop *dut, VerilatedVcdC *tfp, int *timestamp, int n)
{
    if (!dut)
        return;

    for (int i = 0; i < n; ++i)
    {
        // Set the clock to high
        dut->clk = 1;
        dut->eval();
        if (tfp && timestamp)
        {
            tfp->dump(*timestamp);
            *timestamp += 5; // 5ns per edge (10ns full cycle)
        }
        main_time += 5; // Increment main_time for each edge

        // Set the clock to low
        dut->clk = 0;
        dut->eval();
        if (tfp && timestamp)
        {
            tfp->dump(*timestamp);
            *timestamp += 5; // 5ns per edge (10ns full cycle)
        }
        main_time += 5; // Increment main_time for each edge
    }
}