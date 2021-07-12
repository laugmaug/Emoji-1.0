//+------------------------------------------------------------------+
//|                                                   VaalInvest.mq5 |
//|                                               Jabez Peter Radebe |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include<Trade\Trade.mqh>

/* ######################### Constant #######################
   ####################### Variables ######################
   ########################################################
*/

double Bid, Ask;
CTrade trade;

/* ######################### Class ########################
   ################### Entry Management ###################
   ########################################################
*/


class EntryManagement{
   //Entry managemment class to help calculate the perfect entry
   
   public : double KArray[], DArray[]; //stochastic arrays
   public : double rangeArr[]; //stochastic arrays 
   public : int StochDef, WPRDef;
   public : int trades;
   public : bool inTrade;
   public : string Trend;
   public : double ASK, BID;

   
   bool stochOverbought(){
      if((KArray[0] >= 80) || (DArray[0] >= 80)){
         return true;
      }
      return false;
   }
   
   bool stochOversold(){
      if((KArray[0] <= 20) || (DArray[0] <= 20)){
         return true;
      }
      return false;
   }
   
   bool rangeOverbought(){
      if(rangeArr[0] >= -2.5){
         return true;
      }
      return false;
   }
   
   bool rangeOversold(){
      if(rangeArr[0] <= -17.5){
         return true;
      }
      return false;
   }
   
   bool isBuy(){
      if(stochOversold() && rangeOversold())
         return true;
      return false;
   }
   
   bool isSell(){
      
      if(stochOverbought() && rangeOverbought())
         return true;
      
      return false;
   }
   
   bool openTradesExist()
   {
      Comment(PositionsTotal());
         if(PositionsTotal() > 0)
            return true;
         return false;
   }
   
   void getUpdateFromMarket(){
         //mARKETpRICE
         Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
         Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   
         //Stochastic Oscillator
         StochDef = iStochastic(_Symbol, PERIOD_M5,5, 3, 3, MODE_SMA, STO_LOWHIGH);
         
         CopyBuffer(StochDef, 0, 0, 5, Entries.KArray); 
         CopyBuffer(StochDef, 1, 0, 5, Entries.DArray);
         
         WPRDef =iWPR(_Symbol, PERIOD_M30, 14);
         CopyBuffer(WPRDef,0,0,5, Entries.rangeArr);
         
         
         ArraySetAsSeries(Entries.KArray, true);
         ArraySetAsSeries(Entries.DArray, true);
         ArraySetAsSeries(Entries.rangeArr, true);
   }
};



/* ######################### Class ########################
   ################### Risk Management ####################
   ########################################################
*/

class RiskManagement : EntryManagement {
   //Risk managemment class to help manage the risk the bot should take based on the account ballance
   
    double accBal;
    double lots;
    int tpt; //Trades per time
    int maxAllowedTrades;
          
    public : RiskManagement(double lots = 0.001, int maxOpenTrades = 1) {
        this.lots = lots;
        this.tpt = 1;
        this.accBal = AccountInfoDouble(ACCOUNT_BALANCE);
        this.maxAllowedTrades = maxOpenTrades;
            
        if(this.accBal >= 3){
            
            if(this.accBal < 19)
                this.tpt = 1;
            else{
                this.tpt = (int)(this.accBal/10);
            
                if(this.tpt > 0 && this.tpt < 1)
                     this.tpt = 1;
                 }
      
                 Comment("Risk Management Algorithm strated...");
              }
           else
              {        
                  Print("Account at risk!", "Account balance too low");
              }
    }
     
     public : void dynamicSL(bool trailing = false){
      if(trailing){
         for(int i=PositionsTotal(); i >= 0; i--){
            string symbol = PositionGetSymbol(i);         
               if(_Symbol == symbol){
                  ulong ticket = PositionGetInteger(POSITION_TICKET);
                  double newSL = PositionGetDouble(POSITION_PRICE_OPEN);
                  double currTP = PositionGetDouble(POSITION_TP);
                           
                           
                           
                  if(POSITION_TYPE_BUY == PositionGetInteger(POSITION_TYPE)){
                     if(PositionGetDouble(POSITION_PROFIT) > 3 && PositionGetDouble(POSITION_PROFIT) <= 5){
                        newSL += SYMBOL_SPREAD;
                        trade.PositionModify(ticket, newSL, currTP);
                     }
                     else if(PositionGetDouble(POSITION_PROFIT) <= 5){
                        //1000 pips == 1 USD
                        newSL = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) - 3000;
                        trade.PositionModify(ticket, newSL, currTP);
                     }
                  }
                             
                  else if(POSITION_TYPE_SELL == PositionGetInteger(POSITION_TYPE)){
                    if(PositionGetDouble(POSITION_PROFIT) > 3 && PositionGetDouble(POSITION_PROFIT) <= 5){
                       newSL -= SYMBOL_SPREAD;
                       trade.PositionModify(ticket, newSL, currTP);
                    }
                    else if(PositionGetDouble(POSITION_PROFIT) <= 5){
                        //1000 pips == 1 USD
                        newSL = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + 3000;
                        trade.PositionModify(ticket, newSL, currTP);
                    }
                  }
               }
         }
      }
      else{
           for(int i=PositionsTotal(); i >= 0; i--){
               string symbol = PositionGetSymbol(i);
               
               if(_Symbol == symbol){
                  ulong ticket = PositionGetInteger(POSITION_TICKET);
                  double newSL = PositionGetDouble(POSITION_PRICE_OPEN);
                  double currTP = PositionGetDouble(POSITION_TP);
                           
                  if(POSITION_TYPE_BUY == PositionGetInteger(POSITION_TYPE)){
                     newSL += SYMBOL_SPREAD;
                     trade.PositionModify(ticket, newSL, currTP);
                  }
                             
                  else if(POSITION_TYPE_SELL == PositionGetInteger(POSITION_TYPE)){
                     newSL -= SYMBOL_SPREAD;
                     trade.PositionModify(ticket, newSL, currTP);
                  }
               }
           }
      }
   }
   
   public : void huntEntries(){
         if(PositionsTotal() == 0)
         {   
               if(isBuy()){
                  for(int i=0; i<tpt; i++){
                        trade.Buy(this.lots, _Symbol, ASK, ASK-2000, ASK+10000);
                    }
               }else if(isSell()){
                    for(int i=0; i<tpt; i++){
                        trade.Sell(this.lots, _Symbol, ASK, ASK+2000, ASK-10000);
                    }
               }
               this.dynamicSL();
          }
    }
};



/* ######################### Global #######################
   ####################### Variables ######################
   ########################################################
*/

EntryManagement Entries = new EntryManagement;
RiskManagement RiskMan = new RiskManagement;



int OnInit()
{
   EventSetTimer(30);

   Entries = new EntryManagement;
   RiskMan = new RiskManagement;
   
   Comment("Bot Started");
     
   return(INIT_SUCCEEDED);
}


void OnTick()
{  
   
   //Entries.getUpdateFromMarket();
   //RiskMan.huntEntries();
   
}

 
void DeInit(){
   Comment("Bot Stopped");
}