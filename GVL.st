VAR_GLOBAL CONSTANT
    // =====================================================================
    // 0. ENGINEERING PARAMETERS & LIMITS
    // =====================================================================
    SYS_TRIP_PRESS   : REAL := 55.0;  // High-High Pressure SIS Trip (PSHH)
    SYS_START_PRESS  : REAL := 45.0;  // Minimum pressure to enter RUN
    SYS_DROP_PRESS   : REAL := 40.0;  // Fallback to Pressurize mode
    SYS_PURGE_PRESS  : REAL := 5.0;   // Maximum pressure for Purge state
    
    LIQ_TRIP_HIGH    : REAL := 85.0;  // High-High Level SIS Trip (LSHH)
    LIQ_TRIP_LOW     : REAL := 15.0;  // Low-Low Level SIS Trip (LSLL)
    
    RAW_MIN          : REAL := 0.0;     // 4mA Loop Baseline
    RAW_MAX          : REAL := 27648.0; // 20mA Loop Maximum
    RAW_FAULT_LOW    : INT  := -50;     // Broken Wire (Calibrated floor)
    RAW_FAULT_HIGH   : INT  := 29030;   // Short-Circuit Threshold
END_VAR

VAR_GLOBAL
    // =====================================================================
    // 1. SYSTEM SECURITY & HARDWARE I/O
    // =====================================================================
    First_Scan_Init     : BOOL := TRUE;  
    Local_Panel_Key     : BOOL := FALSE; 
    UPS_Low_Batt_Warning: BOOL := FALSE; 

    Raw_PT_A : INT := 13824; Raw_PT_B : INT := 13824; Raw_PT_C : INT := 13824;
    Raw_LT_Tot_A : INT := 13824; Raw_LT_Tot_B : INT := 13824; Raw_LT_Tot_C : INT := 13824;
    Raw_LT_Inter : INT := 13824; 
    
    // =====================================================================
    // 2. SCALED PROCESS VARIABLES & DYNAMIC AVERAGING
    // =====================================================================
    PT_A_Scaled   : REAL; PT_B_Scaled : REAL; PT_C_Scaled   : REAL; 
    Tot_A_Pct     : REAL; Tot_B_Pct   : REAL; Tot_C_Pct     : REAL; 
    Vessel_Pressure : REAL; Total_Liq_Pct : REAL; Water_Int_Pct : REAL;

    Healthy_PT_Count  : INT; 
    Healthy_LT_Count  : INT;
    Sum_Pressure      : REAL;
    Sum_Liquid        : REAL;

    // =====================================================================
    // 3. SIS DISCRETE VOTES & DIAGNOSTICS
    // =====================================================================
    PT_A_Fault : BOOL; PT_B_Fault : BOOL; PT_C_Fault : BOOL;
    LT_A_Fault : BOOL; LT_B_Fault : BOOL; LT_C_Fault : BOOL;

    PT_A_High_Vote : BOOL; PT_B_High_Vote : BOOL; PT_C_High_Vote : BOOL;
    LT_A_High_Vote : BOOL; LT_B_High_Vote : BOOL; LT_C_High_Vote : BOOL;
    LT_A_Low_Vote  : BOOL; LT_B_Low_Vote  : BOOL; LT_C_Low_Vote  : BOOL;

    HMI_PT_A_MOS : BOOL; HMI_PT_B_MOS : BOOL; HMI_PT_C_MOS : BOOL;
    PT_A_Ignored : BOOL; PT_B_Ignored : BOOL; PT_C_Ignored : BOOL;
    Ignore_Count : INT;

    HMI_LT_A_MOS : BOOL; HMI_LT_B_MOS : BOOL; HMI_LT_C_MOS : BOOL;
    LT_A_Ignored : BOOL; LT_B_Ignored : BOOL; LT_C_Ignored : BOOL;
    LT_Ignore_Count : INT;

    PT_Matrix_Fault    : BOOL; 
    LT_Matrix_Fault    : BOOL;
    Bypass_Veto_Active : BOOL; 
    Shift_MOS_Timer    : TON;  
    Stale_Bypass_Alarm : BOOL; 

    // =====================================================================
    // 4. CAUSE & EFFECT EXECUTIVE (TRIPS)
    // =====================================================================
    PSHH_Tripped      : BOOL; 
    LSHH_Tripped      : BOOL; 
    LSLL_Tripped      : BOOL; 
    Master_SIS_Trip   : BOOL; 
    PAH_Alarm         : BOOL; 
    LAL_Alarm         : BOOL; 

    // =====================================================================
    // 5. ISA-106 STATE MACHINE & REGULATORY OUTPUTS
    // =====================================================================
    Current_State      : INT := 0; 
    Startup_Grace_Timer: TON;     
    State2_Timer       : TON;     
    
    Inlet_SDV          : BOOL; 
    PCV_Sales_Output   : REAL; 
    PCV_Flare_Output   : REAL; 
    LCV_Oil_Output     : REAL; 
    LCV_Water_Output   : REAL; 

    // =====================================================================
    // 6. APM & HMI COMMANDS
    // =====================================================================
    Inlet_SDV_ZSO     : BOOL; 
    Inlet_SDV_ZSC     : BOOL; 
    Inlet_Watchdog    : TON;  
    Inlet_Transit_Err : BOOL; 
    Inlet_Stroke_Timer: TON;  
    Measured_Stroke_Time: REAL; 
    Valve_Degrad_Alert: BOOL; 

    HMI_Start_Cmd : BOOL; HMI_Stop_Cmd : BOOL; HMI_Reset_Cmd : BOOL;
    HMI_LCV_Oil_Manual_Mode : BOOL; 
    HMI_LCV_Oil_Manual_Value: REAL;

    // =====================================================================
    // 7. REGULATORY PID CONTROLLERS (REQUIRES CODESYS 'UTIL' LIBRARY)
    // =====================================================================
    PID_Pressure  : PID; 
    PID_Level_Oil : PID;
    PID_Level_Wat : PID;

    SP_Pressure   : REAL := 45.0; 
    SP_Level_Oil  : REAL := 50.0; 
    SP_Level_Wat  : REAL := 25.0; 

    // ** NEGATIVE GAINS REQUIRED FOR DIRECT-ACTING DRAIN/VENT CONTROL **
    Kp_Press : REAL := -2.0;   
    Tn_Press : REAL := 15.0;  
    
    Kp_Level : REAL := -1.5; 
    Tn_Level : REAL := 30.0;  

    // Dynamic PID Overrides
    Oil_PID_Manual_Cmd : BOOL;
    Oil_PID_Manual_Val : REAL;
    Wat_PID_Manual_Cmd : BOOL;
END_VAR
