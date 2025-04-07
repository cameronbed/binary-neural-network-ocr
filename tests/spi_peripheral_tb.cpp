#include "Vspi_peripheral.h"
#include "verilated.h"
#include <iostream>
#include <cstdlib>

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vspi_peripheral *top = new Vspi_peripheral;

    // Initialize inputs
    top->clk = 0;
    top->rst_n = 0;
    top->CS = 1;
    top->SCLK = 0;
    top->SDI = 0;

    // Reset phase
    for (int i = 0; i < 10; i++)
    {
        top->clk = !top->clk;
        top->eval();
        main_time += 5;
    }
    top->rst_n = 1;

    // Begin SPI transaction: assert CS (active low)
    top->CS = 0;
    uint8_t master_data = 0x3C; // Data to send
    std::cout << "Starting SPI transaction. Master sending: 0x"
              << std::hex << (int)master_data << std::endl;

    // Drive 8 SPI clock cycles (MSB first)
    for (int i = 7; i >= 0; i--)
    {
        // Set SDI for the current bit
        top->SDI = (master_data >> i) & 1;

        // Generate rising edge of SPI clock
        top->SCLK = 0;
        top->clk = !top->clk;
        top->eval();
        main_time += 5;
        top->SCLK = 1;
        top->clk = !top->clk;
        top->eval();
        main_time += 5;

        // Generate falling edge of SPI clock
        top->SCLK = 0;
        top->clk = !top->clk;
        top->eval();
        main_time += 5;
    }

    // End SPI transaction: deassert CS
    top->CS = 1;

    // Let the design process the final bit
    for (int i = 0; i < 10; i++)
    {
        top->clk = !top->clk;
        top->eval();
        main_time += 5;
    }

    std::cout << "SPI peripheral received data: 0x" << std::hex
              << (int)top->rx_data << std::endl;

    top->final();
    delete top;
    return 0;
}
