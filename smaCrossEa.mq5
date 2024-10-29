//+------------------------------------------------------------------+
//|                                                    smaCrossEa.mq5  |
//|                        Copyright 2024, MetaQuotes Software Corp.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window  // For RSI
#property indicator_buffers 9       // 4 indicators + 5 for colored candles
#property indicator_plots   5       // Keep 5 plots

// Plot properties for Fast SMA
#property indicator_label1  "Fast SMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

// Plot properties for Slow SMA
#property indicator_label2  "Slow SMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Plot properties for ATR
#property indicator_label3  "ATR"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

// Plot properties for RSI
#property indicator_label4  "RSI"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrPurple
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

// Modified ATR Bands properties
#property indicator_label5  "ATR Bands"
#property indicator_type5   DRAW_COLOR_CANDLES
#property indicator_color5  clrGray,clrLime,clrRed    // Colors for different states
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

// Input Parameters
input int FastSMA = 10;           // Fast SMA Period
input int SlowSMA = 21;           // Slow SMA Period
input int RSI_Period = 14;        // RSI Period
input double RiskPercent = 2.0;   // Risk Percent per trade

// ATR and Trading Parameters
input int ATR_Period = 14;        // ATR Period
input double SL_ATR_Multiplier = 1.5;  // Stop Loss ATR Multiplier
input double TP_ATR_Multiplier = 3.0;  // Take Profit ATR Multiplier
input bool UseTrailingStop = true;     // Use trailing stop
input double TrailingATR_Multiplier = 1.0; // Trailing Stop ATR Multiplier
input double TrailingStep_Multiplier = 0.3; // Trailing Step ATR Multiplier

// Global Variables
int handle_fast_sma;
int handle_slow_sma;
int handle_rsi;
int handle_atr;      // New ATR handle
double fast_sma_buffer[];
double slow_sma_buffer[];
double rsi_buffer[];
double atr_buffer[]; // New ATR buffer

// Indicator Buffers
double FastSMABuffer[];
double SlowSMABuffer[];
double ATRBuffer[];
double RSIBuffer[];
// ATR Bands buffers
double ATRBandsOpen[];
double ATRBandsHigh[];
double ATRBandsLow[];
double ATRBandsClose[];
double ATRBandsColors[];    // Color index buffer

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize indicator handles
    handle_fast_sma = iMA(_Symbol, PERIOD_CURRENT, FastSMA, 0, MODE_SMA, PRICE_CLOSE);
    handle_slow_sma = iMA(_Symbol, PERIOD_CURRENT, SlowSMA, 0, MODE_SMA, PRICE_CLOSE);
    handle_rsi = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    handle_atr = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
    
    // Set indicator buffers
    SetIndexBuffer(0, FastSMABuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SlowSMABuffer, INDICATOR_DATA);
    SetIndexBuffer(2, ATRBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, RSIBuffer, INDICATOR_DATA);
    // ATR Bands buffers (colored candles)
    SetIndexBuffer(4, ATRBandsOpen, INDICATOR_DATA);
    SetIndexBuffer(5, ATRBandsHigh, INDICATOR_DATA);
    SetIndexBuffer(6, ATRBandsLow, INDICATOR_DATA);
    SetIndexBuffer(7, ATRBandsClose, INDICATOR_DATA);
    SetIndexBuffer(8, ATRBandsColors, INDICATOR_COLOR_INDEX);
    
    // Set indicator labels
    PlotIndexSetString(0, PLOT_LABEL, "Fast SMA(" + IntegerToString(FastSMA) + ")");
    PlotIndexSetString(1, PLOT_LABEL, "Slow SMA(" + IntegerToString(SlowSMA) + ")");
    PlotIndexSetString(2, PLOT_LABEL, "ATR(" + IntegerToString(ATR_Period) + ")");
    PlotIndexSetString(3, PLOT_LABEL, "RSI(" + IntegerToString(RSI_Period) + ")");
    PlotIndexSetString(4, PLOT_LABEL, "ATR Bands");
    
    // Set indicator digits
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    // Allocate arrays
    ArraySetAsSeries(fast_sma_buffer, true);
    ArraySetAsSeries(slow_sma_buffer, true);
    ArraySetAsSeries(rsi_buffer, true);
    ArraySetAsSeries(atr_buffer, true);
    ArraySetAsSeries(FastSMABuffer, true);
    ArraySetAsSeries(SlowSMABuffer, true);
    ArraySetAsSeries(ATRBuffer, true);
    ArraySetAsSeries(RSIBuffer, true);
    ArraySetAsSeries(ATRBandsOpen, true);
    ArraySetAsSeries(ATRBandsHigh, true);
    ArraySetAsSeries(ATRBandsLow, true);
    ArraySetAsSeries(ATRBandsClose, true);
    ArraySetAsSeries(ATRBandsColors, true);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Copy indicator data to buffers
    CopyBuffer(handle_fast_sma, 0, 0, rates_total, FastSMABuffer);
    CopyBuffer(handle_slow_sma, 0, 0, rates_total, SlowSMABuffer);
    CopyBuffer(handle_rsi, 0, 0, rates_total, RSIBuffer);
    CopyBuffer(handle_atr, 0, 0, rates_total, ATRBuffer);
    
    // Calculate ATR Bands
    for(int i = 0; i < rates_total; i++)
    {
        double atr = ATRBuffer[i];
        
        // Set OHLC values
        ATRBandsOpen[i] = open[i];
        ATRBandsHigh[i] = high[i];
        ATRBandsLow[i] = low[i];
        ATRBandsClose[i] = close[i];
        
        // Set color based on price movement
        if(close[i] > open[i])
            ATRBandsColors[i] = 1;  // Bullish - lime
        else if(close[i] < open[i])
            ATRBandsColors[i] = 2;  // Bearish - red
        else
            ATRBandsColors[i] = 0;  // Neutral - gray
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(handle_fast_sma);
    IndicatorRelease(handle_slow_sma);
    IndicatorRelease(handle_rsi);
    IndicatorRelease(handle_atr);
    
    // Clear the chart
    ObjectsDeleteAll(0, "SmaCrossEA_");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update indicator buffers
    CopyBuffer(handle_fast_sma, 0, 0, 3, fast_sma_buffer);
    CopyBuffer(handle_slow_sma, 0, 0, 3, slow_sma_buffer);
    CopyBuffer(handle_rsi, 0, 0, 3, rsi_buffer);
    CopyBuffer(handle_atr, 0, 0, 3, atr_buffer);
    
    // Check if we have any open positions
    if(PositionsTotal() > 0)
    {
        if(UseTrailingStop) ManageTrailingStop();
        return;
    }
    
    // Trading logic
    if(IsNewBar())
    {
        // Bullish crossing
        if(fast_sma_buffer[1] > slow_sma_buffer[1] && 
           fast_sma_buffer[2] <= slow_sma_buffer[2] &&
           rsi_buffer[1] > 30)
        {
            OpenPosition(ORDER_TYPE_BUY);
        }
        
        // Bearish crossing
        if(fast_sma_buffer[1] < slow_sma_buffer[1] && 
           fast_sma_buffer[2] >= slow_sma_buffer[2] &&
           rsi_buffer[1] < 70)
        {
            OpenPosition(ORDER_TYPE_SELL);
        }
    }
}

//+------------------------------------------------------------------+
//| Check for new bar                                                 |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime last_time = 0;
    datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(last_time == current_time) return false;
    last_time = current_time;
    return true;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                   |
//+------------------------------------------------------------------+
double CalculatePositionSize(double sl_price, double entry_price)
{
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    double sl_points = MathAbs(entry_price - sl_price) / _Point;
    
    double risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100;
    double money_lot_step = (sl_points * tick_value * lot_step) / tick_size;
    double lots = MathFloor(risk_money / money_lot_step) * lot_step;
    
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    lots = MathMax(MathMin(lots, max_lot), min_lot);
    
    return lots;
}

//+------------------------------------------------------------------+
//| Open a new position                                               |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE order_type)
{
    double atr = atr_buffer[0];
    double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                                                 
    double sl = (order_type == ORDER_TYPE_BUY) ? price - (atr * SL_ATR_Multiplier)
                                               : price + (atr * SL_ATR_Multiplier);
                                               
    double tp = (order_type == ORDER_TYPE_BUY) ? price + (atr * TP_ATR_Multiplier)
                                               : price - (atr * TP_ATR_Multiplier);
                                               
    double lots = CalculatePositionSize(sl, price);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.type = order_type;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = 123456;
    request.comment = "SmaCross EA";
    request.type_filling = ORDER_FILLING_FOK;
    
    bool success = OrderSend(request, result);
    
    if(!success) 
    {
        Print("OrderSend failed with error: ", GetLastError());
        return false;
    }
    
    if(result.retcode != TRADE_RETCODE_DONE) 
    {
        Print("OrderSend failed with retcode: ", result.retcode);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                              |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    double atr = atr_buffer[0];
    double trailing_distance = atr * TrailingATR_Multiplier;
    double trailing_step = atr * TrailingStep_Multiplier;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        double position_sl = PositionGetDouble(POSITION_SL);
        double position_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
        ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        double new_sl = 0;
        
        if(position_type == POSITION_TYPE_BUY)
        {
            if(current_price - position_price > trailing_distance)
            {
                new_sl = current_price - trailing_distance;
                if(new_sl > position_sl + trailing_step)
                {
                    ModifyPosition(ticket, new_sl);
                }
            }
        }
        else if(position_type == POSITION_TYPE_SELL)
        {
            if(position_price - current_price > trailing_distance)
            {
                new_sl = current_price + trailing_distance;
                if(new_sl < position_sl - trailing_step || position_sl == 0)
                {
                    ModifyPosition(ticket, new_sl);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position's stop loss                                       |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double new_sl)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = new_sl;
    request.tp = PositionGetDouble(POSITION_TP);
    
    bool success = OrderSend(request, result);
    
    if(!success) 
    {
        Print("ModifyPosition failed with error: ", GetLastError());
        return false;
    }
    
    if(result.retcode != TRADE_RETCODE_DONE) 
    {
        Print("ModifyPosition failed with retcode: ", result.retcode);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Draw arrows for entry signals                                      |
//+------------------------------------------------------------------+
void DrawSignalArrow(bool isBuy, datetime time, double price)
{
    static int arrowIndex = 0;
    string arrowName = "SmaCrossEA_Arrow_" + IntegerToString(arrowIndex++);
    
    if(isBuy)
    {
        ObjectCreate(0, arrowName, OBJ_ARROW_BUY, 0, time, price);
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
    }
    else
    {
        ObjectCreate(0, arrowName, OBJ_ARROW_SELL, 0, time, price);
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
    }
    
    ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
}

//+------------------------------------------------------------------+
//| Draw ATR levels                                                    |
//+------------------------------------------------------------------+
void DrawATRLevels(double price, double atr)
{
    string slBuyName = "SmaCrossEA_SL_Buy";
    string tpBuyName = "SmaCrossEA_TP_Buy";
    string slSellName = "SmaCrossEA_SL_Sell";
    string tpSellName = "SmaCrossEA_TP_Sell";
    
    // Draw Buy levels
    ObjectCreate(0, slBuyName, OBJ_HLINE, 0, 0, price - (atr * SL_ATR_Multiplier));
    ObjectCreate(0, tpBuyName, OBJ_HLINE, 0, 0, price + (atr * TP_ATR_Multiplier));
    
    // Draw Sell levels
    ObjectCreate(0, slSellName, OBJ_HLINE, 0, 0, price + (atr * SL_ATR_Multiplier));
    ObjectCreate(0, tpSellName, OBJ_HLINE, 0, 0, price - (atr * TP_ATR_Multiplier));
    
    // Set properties
    ObjectSetInteger(0, slBuyName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, tpBuyName, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, slSellName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, tpSellName, OBJPROP_COLOR, clrGreen);
}
