# IEC 61131-3 Architecture: Global Variable List (GVL) Deep Dive

In standard IEC 61131-3 programming, the Global Variable List (GVL) is the central nervous system of the PLC architecture. It dictates memory allocation for physical hardware I/O, mathematical calculations, and HMI SCADA communication tags.

A well-architected GVL ensures strict segregation between the Basic Process Control System (BPCS) and the Safety Instrumented System (SIS). Below is the comprehensive, term-by-term engineering breakdown of the GVL.st memory map used in this 3-Phase Separator project.

# Section 0: Engineering Parameters & Limits

VAR_GLOBAL CONSTANT locks these variables into the PLC's Read-Only Memory (ROM). The code can read them, but can never accidentally overwrite them. This eliminates "magic numbers" (hardcoding values like 55.0 into the logic), which is a major IEC 61511 compliance requirement.

VAR_GLOBAL CONSTANT
    SYS_TRIP_PRESS   : REAL := 55.0;  // High-High Pressure SIS Trip (PSHH)
    SYS_START_PRESS  : REAL := 45.0;  // Minimum pressure to enter RUN
    SYS_DROP_PRESS   : REAL := 40.0;  // Fallback to Pressurize mode
    SYS_PURGE_PRESS  : REAL := 5.0;   // Maximum pressure for Purge state


SYS_TRIP_PRESS: The absolute maximum physical pressure limit (Bar). Exceeding this triggers an Emergency Shutdown (ESD).

SYS_START_PRESS: The pressure boundary required for the ISA-106 state machine to transition from State 2 (Pressurizing) to State 3 (Running).

SYS_DROP_PRESS: If pressure falls below this in State 3, the plant safely downgrades back to State 2 rather than immediately tripping.

SYS_PURGE_PRESS: The safe atmospheric threshold. The system cannot enter State 2 until pressure drops below this limit.

    LIQ_TRIP_HIGH    : REAL := 85.0;  // High-High Level SIS Trip (LSHH)
    LIQ_TRIP_LOW     : REAL := 15.0;  // Low-Low Level SIS Trip (LSLL)


LIQ_TRIP_HIGH: The maximum liquid volume (%). Exceeding this risks catastrophic liquid carry-over into the gas flare stack.

LIQ_TRIP_LOW: The minimum liquid volume (%). Falling below this loses the "liquid seal," allowing high-pressure explosive gas to blow-by into the low-pressure water/oil downstream pipelines.

    RAW_MIN          : REAL := 0.0;     // 4mA Loop Baseline
    RAW_MAX          : REAL := 27648.0; // 20mA Loop Maximum
    RAW_FAULT_LOW    : INT  := -50;     // Broken Wire / Loss of Power threshold
    RAW_FAULT_HIGH   : INT  := 29030;   // Short-Circuit Threshold
END_VAR


RAW_MIN / RAW_MAX: The standard integer resolution for a standard 4-20mA analog hardware card (common in Siemens/CODESYS).

RAW_FAULT_LOW / RAW_FAULT_HIGH: NAMUR NE43 diagnostic limits. Used to mathematically detect if a physical wire has been cut (< 0) or short-circuited by water (> 29030).

# Section 1: System Security & Hardware I/O

This block handles the physical 4-20mA electrical signals coming into the PLC terminals and facility security.

    First_Scan_Init     : BOOL := TRUE;  
    Local_Panel_Key     : BOOL := FALSE; 
    UPS_Low_Batt_Warning: BOOL := FALSE; 


First_Scan_Init: A critical safety tag. TRUE only during the very first millisecond of PLC boot-up. Forces the plant into an isolated state to prevent dangerous uncontrolled startups after a power outage.

Local_Panel_Key: Represents a physical key switch on the PLC cabinet. If active, it locks out remote SCADA commands to protect technicians working on the physical machinery.

UPS_Low_Batt_Warning: Hardware diagnostic. Allows the PLC to initiate a controlled, safe shutdown before the computer loses backup battery power.

    Raw_PT_A : INT := 13824; Raw_PT_B : INT := 13824; Raw_PT_C : INT := 13824;
    Raw_LT_Tot_A : INT := 13824; Raw_LT_Tot_B : INT := 13824; Raw_LT_Tot_C : INT := 13824;
    Raw_LT_Inter : INT := 13824; 


Raw_...: The exact integer signals (0–27648) streaming from the field transmitters. They are initialized to 13824 (exactly 50% scale) so the PLC doesn't wake up thinking all wires are cut, preventing a cascade of false alarms during boot.

# Section 2: Scaled Process Variables & Dynamic Averaging

This section "Translates" dumb electrical integers into intelligent engineering math.

    PT_A_Scaled   : REAL; PT_B_Scaled : REAL; PT_C_Scaled   : REAL; 
    Tot_A_Pct     : REAL; Tot_B_Pct   : REAL; Tot_C_Pct     : REAL; 
    Vessel_Pressure : REAL; Total_Liq_Pct : REAL; Water_Int_Pct : REAL;


..._Scaled / ..._Pct: The floating-point mathematical conversions representing real-world Bar and Percentages.

Vessel_Pressure, Total_Liq_Pct, Water_Int_Pct: The "Golden" variables. These represent the final smoothed average values used by the regulatory PID controllers.

    Healthy_PT_Count  : INT; 
    Healthy_LT_Count  : INT;
    Sum_Pressure      : REAL;
    Sum_Liquid        : REAL;


The Dynamic Averaging Engine: Instead of hardcoding a divide-by-three (A+B+C)/3 (which is fatal if one sensor dies and reports 0), the system dynamically counts the Healthy sensors and calculates the Sum only using active units, ensuring perfect PID stability even during hardware failures.

# Section 3: SIS Discrete Votes & Diagnostics

This defines the Functional Safety (IEC 61511) architecture.

    PT_A_Fault : BOOL; PT_A_High_Vote : BOOL; 
    LT_A_Fault : BOOL; LT_A_High_Vote : BOOL; LT_A_Low_Vote : BOOL; 


..._Fault: Flag indicating the raw signal violates NAMUR limits (broken wire).

..._High_Vote / _Low_Vote: Boolean threshold flags. Translates an analog measurement into a strict True/False vote (e.g., "Has PT_A crossed 55.0 Bar?").

    HMI_PT_A_MOS : BOOL; 
    PT_A_Ignored : BOOL; 
    Ignore_Count : INT;


HMI_..._MOS: Maintenance Override Switch. A command from SCADA to bypass a sensor for calibration.

..._Ignored: The final diagnostic conclusion. A sensor is ignored if it is physically broken (Fault) OR explicitly bypassed (MOS).

Ignore_Count: A dynamic tally of blind sensors. Dictates automatic matrix degradation from 2oo3 to 1oo2.

    PT_Matrix_Fault    : BOOL; 
    LT_Matrix_Fault    : BOOL;
    Bypass_Veto_Active : BOOL; 
    Shift_MOS_Timer    : TON;  
    Stale_Bypass_Alarm : BOOL; 


..._Matrix_Fault: Becomes TRUE if Ignore_Count >= 2. Represents a total loss of redundancy and forces a facility trip.

Bypass_Veto_Active: The safety override. If the active process hits >90% of a trip limit, this turns TRUE and shreds all active MOS commands, forcing bypassed sensors back online to protect the plant.

Shift_MOS_Timer / Stale_Bypass_Alarm: Alerts the control room if a safety sensor is accidentally left bypassed for longer than an 8-hour shift.

# Section 4: Cause & Effect Executive (Trips)

These are the final "guillotine" flags that execute shutdowns.

    PSHH_Tripped      : BOOL; 
    LSHH_Tripped      : BOOL; 
    LSLL_Tripped      : BOOL; 
    Master_SIS_Trip   : BOOL; 
    PAH_Alarm         : BOOL; 
    LAL_Alarm         : BOOL; 


..._Tripped: The specific outputs of the 2oo3 safety voting matrices (Pressure High-High, Level High-High, Level Low-Low).

Master_SIS_Trip: The Global Kill Switch. If TRUE, all automation halts, safety valves slam closed, and the system is physically locked out until mechanically reset.

PAH_Alarm / LAL_Alarm: Process Alarms. These do not trip the plant; they are early-warning indicators presented to the operator.

# Section 5: ISA-106 State Machine & Regulatory Outputs

This governs the Basic Process Control System (BPCS) and automated valve outputs.

    Current_State      : INT := 0; 
    Startup_Grace_Timer: TON;     
    State2_Timer       : TON;     


Current_State: Integer enforcing the operational sequence (0=Isolated, 1=Purging, 2=Pressurizing, 3=Running, 4=ESD Trip).

Startup_Grace_Timer: Disables the Low-Level (LSLL) trip for 15 seconds during start-up, giving the empty tank time to fill with fluid without instantly tripping.

State2_Timer: A watchdog that trips the plant if it takes longer than 5 minutes to pressurize (indicating a massive pipeline leak).

    Inlet_SDV          : BOOL; 
    PCV_Sales_Output   : REAL; 
    PCV_Flare_Output   : REAL; 
    LCV_Oil_Output     : REAL; 
    LCV_Water_Output   : REAL; 


Inlet_SDV: Boolean discrete output to the physical solenoid holding the main Shutdown Valve open.

PCV_ / LCV_: Floating-point analog outputs (0.0 to 100.0%) sent to output cards to modulate physical control valves in the field.

# Section 6: APM & HMI Commands

Asset Performance Management (APM) and SCADA interaction tags.

    Inlet_SDV_ZSO     : BOOL; 
    Inlet_SDV_ZSC     : BOOL; 
    Inlet_Watchdog    : TON;  
    Inlet_Transit_Err : BOOL; 
    Inlet_Stroke_Timer: TON;  
    Measured_Stroke_Time: REAL; 
    Valve_Degrad_Alert: BOOL; 


..._ZSO / ..._ZSC: Physical limit switches (Position Switch Open / Closed) mounted on the valve to confirm mechanical movement.

Inlet_Watchdog / Transit_Err: Trips the plant if the valve is commanded to move but fails to trigger its limit switch within 5 seconds (Stuck Valve).

Inlet_Stroke_Timer / Measured_Stroke_Time: Millisecond APM profiling. Measures the exact physical stroke velocity of the valve.

Valve_Degrad_Alert: Predictive maintenance alarm triggered if the measured stroke time slows down, allowing mechanics to grease the valve weeks before it fully seizes.

    HMI_Start_Cmd : BOOL; HMI_Stop_Cmd : BOOL; HMI_Reset_Cmd : BOOL;
    HMI_LCV_Oil_Manual_Mode : BOOL; 
    HMI_LCV_Oil_Manual_Value: REAL;


HMI_..._Cmd: Momentary pushbuttons from the SCADA screen.

Manual_Mode / Manual_Value: Tags that allow an operator to disconnect a valve from the mathematical PID engine and force it open/closed manually.

# Section 7: Regulatory PID Controllers

This block instantiates the advanced math blocks required for stable process control.

    PID_Pressure  : PID; 
    PID_Level_Oil : PID;
    PID_Level_Wat : PID;
    SP_Pressure   : REAL := 45.0; 
    SP_Level_Oil  : REAL := 50.0; 
    SP_Level_Wat  : REAL := 25.0; 


PID_...: Calling the standard PID mathematical block from the CODESYS Util library.

SP_...: Setpoints. The target limits the PID logic attempts to automatically achieve and maintain.

    Kp_Press : REAL := -2.0;   
    Tn_Press : REAL := 15.0;  
    Kp_Level : REAL := -1.5; 
    Tn_Level : REAL := 30.0;  


Kp (Proportional Gains - NEGATIVE): Crucial Engineering detail. Because these PIDs control drain and vent valves, they require Direct-Acting control (if the level/pressure goes UP, the valve must open). By supplying a negative gain, a negative error (SP - PV) results in a positive output command to open the valve.

Tn (Integral Time): Determines how aggressively the PID eliminates steady-state offset. Liquid loops (Tn = 30s) are intentionally tuned slower than Gas (Tn = 15s) to prevent sudden valve snaps and mechanical water-hammering in the pipes.

    Oil_PID_Manual_Cmd : BOOL;
    Oil_PID_Manual_Val : REAL;
    Wat_PID_Manual_Cmd : BOOL;


Dynamic Manual Injections: Allows the Anti-Blow-By safety logic to systematically hijack the PID block and force it into Manual mode (0.0). This effectively "freezes" the internal PID math, completely preventing Integral Windup while the valve is mechanically clamped closed.
