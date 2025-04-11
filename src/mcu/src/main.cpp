// main.cpp
#include "mbed.h"
#include "TS_DISCO_F429ZI.h"
#include "LCD_DISCO_F429ZI.h"

// --- LCD and Touchscreen Initialization ---
LCD_DISCO_F429ZI lcd; // object to handle LCD display functionalities
TS_DISCO_F429ZI ts;   // object to handle touchscreen functionalities

// ----- Function Prototypes -----                                                            // sets up application environment
static void setup_screen();                                           // initializes the screen
static void draw_screen();                                            // ui elements on the LCD
static void display_touch(uint16_t x, uint16_t y);                    // displays touchscreen coordinates on the screen
pair<uint16_t, uint16_t> read_touchscreen(TS_StateTypeDef &TS_State); // reads touchscreen input and returns coordinates
static void display_count(uint8_t count);                             // displays the current sample count during recording/unlocking
static void clearButtons();                                           // resets the button on the screen

int main()
{

    TS_StateTypeDef TS_State; // object to store touchscreen data
}

void setup_screen()
{
    uint8_t status;

    BSP_LCD_SetFont(&Font20); // set font for display text

    lcd.DisplayStringAt(0, LINE(5), (uint8_t *)"TOUCHSCREEN DEMO", CENTER_MODE); // display initialization message
    thread_sleep_for(1);

    status = ts.Init(lcd.GetXSize(), lcd.GetYSize()); // initialize touchscreen

    if (status != TS_OK) // check initialization status
    {
        lcd.Clear(LCD_COLOR_RED); // red for failure
        lcd.SetBackColor(LCD_COLOR_RED);
        lcd.SetTextColor(LCD_COLOR_WHITE);
        lcd.DisplayStringAt(0, LINE(5), (uint8_t *)"TOUCHSCREEN INIT FAIL", CENTER_MODE);
    }
    else
    {
        lcd.Clear(LCD_COLOR_GREEN); // green for success
        lcd.SetBackColor(LCD_COLOR_GREEN);
        lcd.SetTextColor(LCD_COLOR_WHITE);
        lcd.DisplayStringAt(0, LINE(5), (uint8_t *)"TOUCHSCREEN INIT OK", CENTER_MODE);
    }

    thread_sleep_for(1);
    lcd.Clear(LCD_COLOR_BLUE); // default blue background
    lcd.SetBackColor(LCD_COLOR_BLUE);
    lcd.SetTextColor(LCD_COLOR_WHITE);
}

pair<uint16_t, uint16_t> read_touchscreen(TS_StateTypeDef &TS_State)
{
    uint16_t x = 0;
    uint16_t y = 0;
    ts.GetState(&TS_State);     // read touchscreen state
    if (TS_State.TouchDetected) // get touchscreen coordinates
    {
        x = TS_State.X;
        y = TS_State.Y;
    }

    return pair<uint16_t, uint16_t>(x, y);
}

void display_touch(uint16_t x, uint16_t y)
{
    lcd.SetFont(&Font16);
    uint8_t text[30];
    sprintf((char *)text, "x=%d y=%d    ", x, y);
    lcd.ClearStringLine(9);
    lcd.DisplayStringAtLine(9, (uint8_t *)&text);
    lcd.SetFont(&Font20);
}

void display_xyz(float x_dps, float y_dps, float z_dps, int16_t x_raw, int16_t y_raw, int16_t z_raw)
{
    lcd.SetFont(&Font20);

    lcd.SetTextColor(LCD_COLOR_BLUE);
    lcd.FillRect(97, 4, 135, 133);
    thread_sleep_for(10);
    lcd.SetTextColor(LCD_COLOR_WHITE);

    lcd.DisplayStringAt(235, 10, (uint8_t *)x_dps_text, RIGHT_MODE);
    lcd.DisplayStringAt(235, 30, (uint8_t *)y_dps_text, RIGHT_MODE);
    lcd.DisplayStringAt(235, 50, (uint8_t *)z_dps_text, RIGHT_MODE);

    lcd.DisplayStringAt(230, 70, (uint8_t *)x_raw_text, RIGHT_MODE);
    lcd.DisplayStringAt(230, 90, (uint8_t *)y_raw_text, RIGHT_MODE);
    lcd.DisplayStringAt(230, 110, (uint8_t *)z_raw_text, RIGHT_MODE);
}

void draw_screen()
{
    // 1200x600
    // Draw Box for labels
    lcd.DrawRect(2, 2, 90, 135);
    // Draw box for values
    lcd.DrawRect(95, 2, 140, 135);

    // Draw Buttons
    lcd.DrawRect(10, 250, 100, 50);
    lcd.DisplayStringAt(60, 220, (uint8_t *)"Record", CENTER_MODE);
    lcd.DrawRect(130, 250, 100, 50);
    lcd.DisplayStringAt(180, 220, (uint8_t *)"Unlock", CENTER_MODE);

    // Draw Text
    lcd.DisplayStringAt(5, 10, (uint8_t *)"X.dps:", LEFT_MODE);
    lcd.DisplayStringAt(5, 30, (uint8_t *)"Y.dps:", LEFT_MODE);
    lcd.DisplayStringAt(5, 50, (uint8_t *)"Z.dps:", LEFT_MODE);

    lcd.DisplayStringAt(5, 70, (uint8_t *)"X.raw:", LEFT_MODE);
    lcd.DisplayStringAt(5, 90, (uint8_t *)"Y.raw:", LEFT_MODE);
    lcd.DisplayStringAt(5, 110, (uint8_t *)"Z.raw:", LEFT_MODE);
}

void clearButtons()
{
    lcd.SetBackColor(LCD_COLOR_BLUE);
    lcd.SetTextColor(LCD_COLOR_BLUE);
    lcd.FillRect(132, 252, 98, 48);
    lcd.FillRect(12, 252, 98, 48);
    lcd.SetTextColor(LCD_COLOR_WHITE);
}

void display_count(uint8_t count)
{
    lcd.SetBackColor(LCD_COLOR_BLUE);
    lcd.SetTextColor(LCD_COLOR_WHITE);
    char countStr[10];
    sprintf(countStr, "%d", count);
    lcd.SetFont(&Font20);
    lcd.ClearStringLine(10);
    lcd.DisplayStringAtLine(10, (uint8_t *)countStr);
    lcd.SetFont(&Font16);
}