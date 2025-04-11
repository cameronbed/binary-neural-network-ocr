#include "TS_DISCO_F429ZI.h"
#include "LCD_DISCO_F429ZI.h"

void clearScreen();
void displayTouchCoords(uint16_t x, uint16_t y);
pair<uint16_t, uint16_t> read_touchscreen(TS_StateTypeDef &TS_State);

class F429ZI_Screen
{
    F429ZI_Screen() {}
    LCD_DISCO_F429ZI lcd;             // object to handle LCD display functionalities
    TS_DISCO_F429ZI ts;               // object to handle touchscreen functionalities
    bool display_touchscreen = false; // flag to indicate if touchscreen coordinates should be displayed
};