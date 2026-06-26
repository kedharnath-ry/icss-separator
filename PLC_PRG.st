// =====================================================================
// SECTION 0: BLACK-START & UPS PROTECTION
// =====================================================================
IF GVL.First_Scan_Init THEN
    GVL.Current_State := 0;
    GVL.Inlet_SDV := FALSE;
    GVL.Master_SIS_Trip := TRUE; 
    GVL.First_Scan_Init := FALSE;
END_IF;

IF GVL.UPS_Low_Batt_Warning THEN
    GVL.Master_SIS_Trip := TRUE; 
END_IF;

// =====================================================================
// SECTION 1: NAMUR NE43 VALIDATION & DYNAMIC AVERAGING
// =====================================================================
GVL.PT_A_Fault := (GVL.Raw_PT_A < GVL.RAW_FAULT_LOW) OR (GVL.Raw_PT_A > GVL.RAW_FAULT_HIGH);
GVL.PT_B_Fault := (GVL.Raw_PT_B < GVL.RAW_FAULT_LOW) OR (GVL.Raw_PT_B > GVL.RAW_FAULT_HIGH);
GVL.PT_C_Fault := (GVL.Raw_PT_C < GVL.RAW_FAULT_LOW) OR (GVL.Raw_PT_C > GVL.RAW_FAULT_HIGH);

GVL.LT_A_Fault := (GVL.Raw_LT_Tot_A < GVL.RAW_FAULT_LOW) OR (GVL.Raw_LT_Tot_A > GVL.RAW_FAULT_HIGH);
GVL.LT_B_Fault := (GVL.Raw_LT_Tot_B < GVL.RAW_FAULT_LOW) OR (GVL.Raw_LT_Tot_B > GVL.RAW_FAULT_HIGH);
GVL.LT_C_Fault := (GVL.Raw_LT_Tot_C < GVL.RAW_FAULT_LOW) OR (GVL.Raw_LT_Tot_C > GVL.RAW_FAULT_HIGH);

IF NOT GVL.PT_A_Fault THEN GVL.PT_A_Scaled := (INT_TO_REAL(GVL.Raw_PT_A) / GVL.RAW_MAX) * 100.0; END_IF;
IF NOT GVL.PT_B_Fault THEN GVL.PT_B_Scaled := (INT_TO_REAL(GVL.Raw_PT_B) / GVL.RAW_MAX) * 100.0; END_IF;
IF NOT GVL.PT_C_Fault THEN GVL.PT_C_Scaled := (INT_TO_REAL(GVL.Raw_PT_C) / GVL.RAW_MAX) * 100.0; END_IF;

IF NOT GVL.LT_A_Fault THEN GVL.Tot_A_Pct := (INT_TO_REAL(GVL.Raw_LT_Tot_A) / GVL.RAW_MAX) * 100.0; END_IF;
IF NOT GVL.LT_B_Fault THEN GVL.Tot_B_Pct := (INT_TO_REAL(GVL.Raw_LT_Tot_B) / GVL.RAW_MAX) * 100.0; END_IF;
IF NOT GVL.LT_C_Fault THEN GVL.Tot_C_Pct := (INT_TO_REAL(GVL.Raw_LT_Tot_C) / GVL.RAW_MAX) * 100.0; END_IF;

// Dynamic Pressure Averaging
GVL.Healthy_PT_Count := 0; GVL.Sum_Pressure := 0.0;
IF NOT GVL.PT_A_Fault THEN GVL.Healthy_PT_Count := GVL.Healthy_PT_Count + 1; GVL.Sum_Pressure := GVL.Sum_Pressure + GVL.PT_A_Scaled; END_IF;
IF NOT GVL.PT_B_Fault THEN GVL.Healthy_PT_Count := GVL.Healthy_PT_Count + 1; GVL.Sum_Pressure := GVL.Sum_Pressure + GVL.PT_B_Scaled; END_IF;
IF NOT GVL.PT_C_Fault THEN GVL.Healthy_PT_Count := GVL.Healthy_PT_Count + 1; GVL.Sum_Pressure := GVL.Sum_Pressure + GVL.PT_C_Scaled; END_IF;

IF GVL.Healthy_PT_Count > 0 THEN GVL.Vessel_Pressure := GVL.Sum_Pressure / INT_TO_REAL(GVL.Healthy_PT_Count); ELSE GVL.Vessel_Pressure := 0.0; END_IF;

// Dynamic Liquid Averaging
GVL.Healthy_LT_Count := 0; GVL.Sum_Liquid := 0.0;
IF NOT GVL.LT_A_Fault THEN GVL.Healthy_LT_Count := GVL.Healthy_LT_Count + 1; GVL.Sum_Liquid := GVL.Sum_Liquid + GVL.Tot_A_Pct; END_IF;
IF NOT GVL.LT_B_Fault THEN GVL.Healthy_LT_Count := GVL.Healthy_LT_Count + 1; GVL.Sum_Liquid := GVL.Sum_Liquid + GVL.Tot_B_Pct; END_IF;
IF NOT GVL.LT_C_Fault THEN GVL.Healthy_LT_Count := GVL.Healthy_LT_Count + 1; GVL.Sum_Liquid := GVL.Sum_Liquid + GVL.Tot_C_Pct; END_IF;

IF GVL.Healthy_LT_Count > 0 THEN GVL.Total_Liq_Pct := GVL.Sum_Liquid / INT_TO_REAL(GVL.Healthy_LT_Count); ELSE GVL.Total_Liq_Pct := 0.0; END_IF;

IF GVL.Raw_LT_Inter < 0 THEN GVL.Water_Int_Pct := 0.0; 
ELSE GVL.Water_Int_Pct := (INT_TO_REAL(GVL.Raw_LT_Inter) / GVL.RAW_MAX) * 100.0; END_IF;

// Physical Plausibility Clamp
IF GVL.Water_Int_Pct > GVL.Total_Liq_Pct THEN
    GVL.Water_Int_Pct := GVL.Total_Liq_Pct; 
END_IF;

// =====================================================================
// SECTION 2: DISCRETE BOOLEAN VOTING GENERATION
// =====================================================================
GVL.PT_A_High_Vote := NOT GVL.PT_A_Fault AND (GVL.PT_A_Scaled >= GVL.SYS_TRIP_PRESS);
GVL.PT_B_High_Vote := NOT GVL.PT_B_Fault AND (GVL.PT_B_Scaled >= GVL.SYS_TRIP_PRESS);
GVL.PT_C_High_Vote := NOT GVL.PT_C_Fault AND (GVL.PT_C_Scaled >= GVL.SYS_TRIP_PRESS);

GVL.LT_A_High_Vote := NOT GVL.LT_A_Fault AND (GVL.Tot_A_Pct >= GVL.LIQ_TRIP_HIGH);
GVL.LT_B_High_Vote := NOT GVL.LT_B_Fault AND (GVL.Tot_B_Pct >= GVL.LIQ_TRIP_HIGH);
GVL.LT_C_High_Vote := NOT GVL.LT_C_Fault AND (GVL.Tot_C_Pct >= GVL.LIQ_TRIP_HIGH);

GVL.LT_A_Low_Vote  := NOT GVL.LT_A_Fault AND (GVL.Tot_A_Pct <= GVL.LIQ_TRIP_LOW);
GVL.LT_B_Low_Vote  := NOT GVL.LT_B_Fault AND (GVL.Tot_B_Pct <= GVL.LIQ_TRIP_LOW);
GVL.LT_C_Low_Vote  := NOT GVL.LT_C_Fault AND (GVL.Tot_C_Pct <= GVL.LIQ_TRIP_LOW);

// =====================================================================
// SECTION 3: SIS MATRIX DEGRADATION & ALGEBRA (IEC 61511)
// =====================================================================
GVL.Bypass_Veto_Active := (GVL.Vessel_Pressure >= (GVL.SYS_TRIP_PRESS * 0.90)) OR (GVL.Total_Liq_Pct >= (GVL.LIQ_TRIP_HIGH * 0.90));

GVL.PT_A_Ignored := (GVL.HMI_PT_A_MOS AND NOT GVL.Bypass_Veto_Active) OR GVL.PT_A_Fault;
GVL.PT_B_Ignored := (GVL.HMI_PT_B_MOS AND NOT GVL.Bypass_Veto_Active) OR GVL.PT_B_Fault;
GVL.PT_C_Ignored := (GVL.HMI_PT_C_MOS AND NOT GVL.Bypass_Veto_Active) OR GVL.PT_C_Fault;
GVL.LT_A_Ignored := (GVL.HMI_LT_A_MOS AND NOT GVL.Bypass_Veto_Active) OR GVL.LT_A_Fault;
GVL.LT_B_Ignored := (GVL.HMI_LT_B_MOS AND NOT GVL.Bypass_Veto_Active) OR GVL.LT_B_Fault;
GVL.LT_C_Ignored := (GVL.HMI_LT_C_MOS AND NOT GVL.Bypass_Veto_Active) OR GVL.LT_C_Fault;

GVL.Ignore_Count := 0;
IF GVL.PT_A_Ignored THEN GVL.Ignore_Count := GVL.Ignore_Count + 1; END_IF;
IF GVL.PT_B_Ignored THEN GVL.Ignore_Count := GVL.Ignore_Count + 1; END_IF;
IF GVL.PT_C_Ignored THEN GVL.Ignore_Count := GVL.Ignore_Count + 1; END_IF;

GVL.LT_Ignore_Count := 0;
IF GVL.LT_A_Ignored THEN GVL.LT_Ignore_Count := GVL.LT_Ignore_Count + 1; END_IF;
IF GVL.LT_B_Ignored THEN GVL.LT_Ignore_Count := GVL.LT_Ignore_Count + 1; END_IF;
IF GVL.LT_C_Ignored THEN GVL.LT_Ignore_Count := GVL.LT_Ignore_Count + 1; END_IF;

IF GVL.Ignore_Count = 0 THEN
    GVL.PSHH_Tripped := (GVL.PT_A_High_Vote AND GVL.PT_B_High_Vote) OR (GVL.PT_B_High_Vote AND GVL.PT_C_High_Vote) OR (GVL.PT_A_High_Vote AND GVL.PT_C_High_Vote);
ELSIF GVL.Ignore_Count = 1 THEN
    IF GVL.PT_A_Ignored THEN GVL.PSHH_Tripped := (GVL.PT_B_High_Vote OR GVL.PT_C_High_Vote); END_IF;
    IF GVL.PT_B_Ignored THEN GVL.PSHH_Tripped := (GVL.PT_A_High_Vote OR GVL.PT_C_High_Vote); END_IF;
    IF GVL.PT_C_Ignored THEN GVL.PSHH_Tripped := (GVL.PT_A_High_Vote OR GVL.PT_B_High_Vote); END_IF;
ELSE
    GVL.PSHH_Tripped := TRUE; 
END_IF;

IF GVL.LT_Ignore_Count = 0 THEN
    GVL.LSHH_Tripped := (GVL.LT_A_High_Vote AND GVL.LT_B_High_Vote) OR (GVL.LT_B_High_Vote AND GVL.LT_C_High_Vote) OR (GVL.LT_A_High_Vote AND GVL.LT_C_High_Vote);
ELSIF GVL.LT_Ignore_Count = 1 THEN
    IF GVL.LT_A_Ignored THEN GVL.LSHH_Tripped := (GVL.LT_B_High_Vote OR GVL.LT_C_High_Vote); END_IF;
    IF GVL.LT_B_Ignored THEN GVL.LSHH_Tripped := (GVL.LT_A_High_Vote OR GVL.LT_C_High_Vote); END_IF;
    IF GVL.LT_C_Ignored THEN GVL.LSHH_Tripped := (GVL.LT_A_High_Vote OR GVL.LT_B_High_Vote); END_IF;
ELSE
    GVL.LSHH_Tripped := TRUE;
END_IF;

GVL.Startup_Grace_Timer(IN := (GVL.Current_State = 2 OR GVL.Current_State = 3), PT := T#15s);

IF GVL.LT_Ignore_Count = 0 THEN
    GVL.LSLL_Tripped := GVL.Startup_Grace_Timer.Q AND ((GVL.LT_A_Low_Vote AND GVL.LT_B_Low_Vote) OR (GVL.LT_B_Low_Vote AND GVL.LT_C_Low_Vote) OR (GVL.LT_A_Low_Vote AND GVL.LT_C_Low_Vote));
ELSIF GVL.LT_Ignore_Count = 1 THEN
    IF GVL.LT_A_Ignored THEN GVL.LSLL_Tripped := GVL.Startup_Grace_Timer.Q AND (GVL.LT_B_Low_Vote OR GVL.LT_C_Low_Vote); END_IF;
    IF GVL.LT_B_Ignored THEN GVL.LSLL_Tripped := GVL.Startup_Grace_Timer.Q AND (GVL.LT_A_Low_Vote OR GVL.LT_C_Low_Vote); END_IF;
    IF GVL.LT_C_Ignored THEN GVL.LSLL_Tripped := GVL.Startup_Grace_Timer.Q AND (GVL.LT_A_Low_Vote OR GVL.LT_B_Low_Vote); END_IF;
ELSE
    GVL.LSLL_Tripped := GVL.Startup_Grace_Timer.Q AND TRUE; 
END_IF;

GVL.PT_Matrix_Fault := (GVL.Ignore_Count >= 2);
GVL.LT_Matrix_Fault := (GVL.LT_Ignore_Count >= 2);

// =====================================================================
// SECTION 4: CAUSE & EFFECT EXECUTIVE (MASTER TRIPS & RESET)
// =====================================================================
IF GVL.PSHH_Tripped OR GVL.LSHH_Tripped OR GVL.LSLL_Tripped OR GVL.PT_Matrix_Fault OR GVL.LT_Matrix_Fault OR GVL.Inlet_Transit_Err THEN
    GVL.Master_SIS_Trip := TRUE;
END_IF;

IF GVL.HMI_Reset_Cmd AND GVL.Master_SIS_Trip AND (GVL.Vessel_Pressure < GVL.SYS_TRIP_PRESS) AND (GVL.Total_Liq_Pct < GVL.LIQ_TRIP_HIGH) AND GVL.Inlet_SDV_ZSC AND NOT GVL.PT_Matrix_Fault AND NOT GVL.LT_Matrix_Fault THEN 
    GVL.PSHH_Tripped      := FALSE;
    GVL.LSHH_Tripped      := FALSE;
    GVL.LSLL_Tripped      := FALSE;
    GVL.Inlet_Transit_Err := FALSE;
    GVL.Master_SIS_Trip   := FALSE; 
    GVL.Current_State     := 0;     
END_IF;

// =====================================================================
// SECTION 5: ISA-106 STATE MACHINE 
// =====================================================================
CASE GVL.Current_State OF
    0: // ISOLATED
        GVL.Inlet_SDV := FALSE;
        IF GVL.HMI_Start_Cmd AND NOT GVL.Master_SIS_Trip AND NOT GVL.Local_Panel_Key THEN GVL.Current_State := 1; END_IF;
    1: // PURGING
        IF GVL.Vessel_Pressure <= GVL.SYS_PURGE_PRESS THEN GVL.Current_State := 2; END_IF;
    2: // PRESSURIZING
        GVL.Inlet_SDV := TRUE; 
        GVL.State2_Timer(IN := (GVL.Current_State = 2), PT := T#5m); 
        
        IF GVL.Inlet_SDV_ZSO AND (GVL.Vessel_Pressure >= GVL.SYS_START_PRESS) THEN 
            GVL.Current_State := 3; 
        ELSIF GVL.State2_Timer.Q THEN
            GVL.Master_SIS_Trip := TRUE; 
        END_IF;
    3: // RUNNING (BPCS ACTIVE)
        GVL.Inlet_SDV := TRUE;
        IF GVL.Master_SIS_Trip OR GVL.HMI_Stop_Cmd THEN 
            GVL.Current_State := 4; 
        ELSIF GVL.Vessel_Pressure < GVL.SYS_DROP_PRESS THEN
            GVL.Current_State := 2; 
        END_IF;
    4: // EMERGENCY SHUTDOWN (ESD)
        GVL.Inlet_SDV := FALSE; 
END_CASE;

// =====================================================================
// SECTION 6: REGULATORY CONTROL LOOPS (TRUE PID CONTROL)
// =====================================================================
IF GVL.Current_State = 3 THEN
    
    // --- 1. Master Pressure PID (Split-Range Architecture) ---
    GVL.PID_Pressure(
        ACTUAL    := GVL.Vessel_Pressure,
        SET_POINT := GVL.SP_Pressure,
        KP        := GVL.Kp_Press,
        TN        := GVL.Tn_Press,
        TV        := 0.0, 
        Y_MANUAL  := 0.0,
        Y_OFFSET  := 0.0, 
        Y_MIN     := 0.0,
        Y_MAX     := 100.0,
        MANUAL    := FALSE,
        RESET     := FALSE
    );

    IF GVL.PID_Pressure.Y <= 50.0 THEN
        GVL.PCV_Sales_Output := GVL.PID_Pressure.Y * 2.0;
        GVL.PCV_Flare_Output := 0.0;
    ELSE
        GVL.PCV_Sales_Output := 100.0;
        GVL.PCV_Flare_Output := (GVL.PID_Pressure.Y - 50.0) * 2.0;
    END_IF;

    // --- 2. Oil Level PID (With Anti-Blow-By Manual Override) ---
    GVL.Oil_PID_Manual_Cmd := GVL.HMI_LCV_Oil_Manual_Mode OR (GVL.Total_Liq_Pct < 5.0);
    IF GVL.Total_Liq_Pct < 5.0 THEN
        GVL.Oil_PID_Manual_Val := 0.0; // Override blocks integral windup
    ELSE
        GVL.Oil_PID_Manual_Val := GVL.HMI_LCV_Oil_Manual_Value; 
    END_IF;

    GVL.PID_Level_Oil(
        ACTUAL    := GVL.Total_Liq_Pct,
        SET_POINT := GVL.SP_Level_Oil,
        KP        := GVL.Kp_Level,
        TN        := GVL.Tn_Level,
        TV        := 0.0,
        Y_MANUAL  := GVL.Oil_PID_Manual_Val,
        Y_OFFSET  := 0.0,
        Y_MIN     := 0.0,
        Y_MAX     := 100.0,
        MANUAL    := GVL.Oil_PID_Manual_Cmd, 
        RESET     := FALSE
    );
    GVL.LCV_Oil_Output := GVL.PID_Level_Oil.Y;

    // --- 3. Water Level PID (With Anti-Blow-By Manual Override) ---
    GVL.Wat_PID_Manual_Cmd := (GVL.Water_Int_Pct < 5.0);
    
    GVL.PID_Level_Wat(
        ACTUAL    := GVL.Water_Int_Pct,
        SET_POINT := GVL.SP_Level_Wat,
        KP        := GVL.Kp_Level,
        TN        := GVL.Tn_Level,
        TV        := 0.0,
        Y_MANUAL  := 0.0,
        Y_OFFSET  := 0.0,
        Y_MIN     := 0.0,
        Y_MAX     := 100.0,
        MANUAL    := GVL.Wat_PID_Manual_Cmd,
        RESET     := FALSE
    );
    GVL.LCV_Water_Output := GVL.PID_Level_Wat.Y;

ELSE
    // INTEGRAL WINDUP PROTECTION (OFFLINE STATE)
    GVL.PID_Pressure(ACTUAL := GVL.Vessel_Pressure, SET_POINT := GVL.SP_Pressure, RESET := TRUE, Y_OFFSET := 0.0);
    GVL.PID_Level_Oil(ACTUAL := GVL.Total_Liq_Pct, SET_POINT := GVL.SP_Level_Oil, RESET := TRUE, Y_OFFSET := 0.0);
    GVL.PID_Level_Wat(ACTUAL := GVL.Water_Int_Pct, SET_POINT := GVL.SP_Level_Wat, RESET := TRUE, Y_OFFSET := 0.0);
    
    GVL.PCV_Sales_Output := 0.0; 
    IF GVL.Current_State = 2 THEN GVL.PCV_Flare_Output := 0.0; ELSE GVL.PCV_Flare_Output := 100.0; END_IF;
    GVL.LCV_Oil_Output := 0.0; 
    GVL.LCV_Water_Output := 0.0;
END_IF;

IF GVL.LCV_Oil_Output > 100.0 THEN GVL.LCV_Oil_Output := 100.0; ELSIF GVL.LCV_Oil_Output < 0.0 THEN GVL.LCV_Oil_Output := 0.0; END_IF;
IF GVL.LCV_Water_Output > 100.0 THEN GVL.LCV_Water_Output := 100.0; ELSIF GVL.LCV_Water_Output < 0.0 THEN GVL.LCV_Water_Output := 0.0; END_IF;

// =====================================================================
// SECTION 7: APM WATCHDOGS & ISA-18.2 ALARM MANAGEMENT
// =====================================================================
GVL.Inlet_Stroke_Timer(IN := (GVL.Inlet_SDV AND NOT GVL.Inlet_SDV_ZSO), PT := T#10s);
IF GVL.Inlet_SDV_ZSO AND NOT GVL.Valve_Degrad_Alert THEN
    GVL.Measured_Stroke_Time := TIME_TO_REAL(GVL.Inlet_Stroke_Timer.ET) / 1000.0;
    IF (GVL.Measured_Stroke_Time > 2.4) THEN GVL.Valve_Degrad_Alert := TRUE; END_IF; 
END_IF;
IF NOT GVL.Inlet_SDV THEN GVL.Inlet_Stroke_Timer(IN := FALSE); END_IF;

GVL.Inlet_Watchdog(IN := (GVL.Inlet_SDV AND NOT GVL.Inlet_SDV_ZSO) OR (NOT GVL.Inlet_SDV AND NOT GVL.Inlet_SDV_ZSC), PT := T#15s);
IF GVL.Inlet_Watchdog.Q THEN GVL.Inlet_Transit_Err := TRUE; END_IF;

GVL.Shift_MOS_Timer(IN := (GVL.Ignore_Count > 0) OR (GVL.LT_Ignore_Count > 0), PT := T#8h);
IF GVL.Shift_MOS_Timer.Q THEN GVL.Stale_Bypass_Alarm := TRUE; END_IF;

GVL.PAH_Alarm := (GVL.Vessel_Pressure >= (GVL.SYS_TRIP_PRESS * 0.90)); 
IF (GVL.Current_State = 0) OR (GVL.Current_State = 4) THEN GVL.LAL_Alarm := FALSE; ELSE GVL.LAL_Alarm := (GVL.Total_Liq_Pct <= 30.0); 
END_IF;
