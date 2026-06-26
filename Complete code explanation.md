# Comprehensive Architecture & Logic Breakdown

System: High-Pressure 3-Phase Separator ICSS

Languages: IEC 61131-3 Structured Text

Standards: IEC 61511 (SIS), ISA-106 (State Automation), ISA-18.2 (Alarms)

This document provides a complete, unomitted, line-by-line engineering explanation of the entire software architecture, covering the memory mapping (GVL.st) and the active logic engine (PLC_PRG.st).

# PART 1: GLOBAL VARIABLE LIST (GVL.st)

The GVL is the memory map of the PLC. It allocates exact memory registers for physical electrical wires, mathematical variables, and SCADA (HMI) communication tags.

# Section 0: Engineering Parameters & Limits

Defined as VAR_GLOBAL CONSTANT to lock them into Read-Only Memory (ROM). This prevents "magic numbers" in the code and ensures safety limits can never be accidentally overwritten by a stray calculation.

VAR_GLOBAL CONSTANT
    SYS_TRIP_PRESS   : REAL := 55.0;  // High-High Pressure SIS Trip (PSHH)
    SYS_START_PRESS  : REAL := 45.0;  // Minimum pressure to enter RUN
    SYS_DROP_PRESS   : REAL := 40.0;  // Fallback to Pressurize mode
    SYS_PURGE_PRESS  : REAL := 5.0;   // Maximum pressure for Purge state


SYS_TRIP_PRESS (55.0 Bar): The absolute physical limit of the vessel. Exceeding this triggers an Emergency Shutdown (ESD).

SYS_START_PRESS (45.0 Bar): The threshold pressure required to transition from startup pressurization (State 2) to steady-state running (State 3).

SYS_DROP_PRESS (40.0 Bar): If the plant is running but pressure falls below 40 Bar, it safely falls back to State 2 rather than immediately tripping offline.

SYS_PURGE_PRESS (5.0 Bar): The system cannot initiate a new startup sequence unless the pressure is safely vented below this atmospheric threshold.

    LIQ_TRIP_HIGH    : REAL := 85.0;  // High-High Level SIS Trip (LSHH)
    LIQ_TRIP_LOW     : REAL := 15.0;  // Low-Low Level SIS Trip (LSLL)


LIQ_TRIP_HIGH (85.0%): Maximum liquid level. Exceeding this causes liquids to carry over into the gas flare stack.

LIQ_TRIP_LOW (15.0%): Minimum liquid level. Falling below this causes a loss of the "liquid seal," allowing high-pressure explosive gas to blow-by into downstream liquid pipelines.

    RAW_MIN          : REAL := 0.0;     // 4mA Loop Baseline
    RAW_MAX          : REAL := 27648.0; // 20mA Loop Maximum
    RAW_FAULT_LOW    : INT  := 0;       // Broken Wire / Loss of Power threshold
    RAW_FAULT_HIGH   : INT  := 29030;   // Short-Circuit Threshold
END_VAR


RAW_MIN / RAW_MAX: Defines the 16-bit integer scale used by standard 4-20mA analog input hardware cards.

RAW_FAULT_LOW / RAW_FAULT_HIGH: NAMUR NE43 diagnostic limits. Used to mathematically diagnose physical hardware failures (e.g., cut wires or water-shorted terminals).

# Section 1: System Security & Hardware I/O

VAR_GLOBAL
    First_Scan_Init     : BOOL := TRUE;  
    Local_Panel_Key     : BOOL := FALSE; 
    UPS_Low_Batt_Warning: BOOL := FALSE; 


First_Scan_Init: TRUE only during the first millisecond of boot. Forces the plant into a safe lockdown after a total power failure.

Local_Panel_Key: Tied to a physical key on the PLC cabinet. Locks out remote SCADA commands to protect technicians.

UPS_Low_Batt_Warning: Allows the PLC to safely shut down the process before backup battery power dies.

    Raw_PT_A : INT := 13824; Raw_PT_B : INT := 13824; Raw_PT_C : INT := 13824;
    Raw_LT_Tot_A : INT := 13824; Raw_LT_Tot_B : INT := 13824; Raw_LT_Tot_C : INT := 13824;
    Raw_LT_Inter : INT := 13824; 


Raw_...: Memory registers for the raw electrical signals from the field transmitters. Initialized to 13824 (50% scale) to prevent the PLC from instantly tripping on "cut wire" alarms upon boot.

# Section 2: Scaled Process Variables & Dynamic Averaging

    PT_A_Scaled   : REAL; PT_B_Scaled : REAL; PT_C_Scaled   : REAL; 
    Tot_A_Pct     : REAL; Tot_B_Pct   : REAL; Tot_C_Pct     : REAL; 
    Vessel_Pressure : REAL; Total_Liq_Pct : REAL; Water_Int_Pct : REAL;


..._Scaled / ..._Pct: The floating-point numbers representing actual Bar and Percentages after math scaling.

Vessel_Pressure, Total_Liq_Pct, Water_Int_Pct: The highly stable, dynamically averaged values used by the control loops.

    Healthy_PT_Count  : INT; Healthy_LT_Count  : INT;
    Sum_Pressure      : REAL; Sum_Liquid        : REAL;


Dynamic Averaging Variables: Tracks how many sensors are physically healthy and sums their values. This ensures the calculated averages remain perfectly stable even if one sensor is physically destroyed.

# Section 3: SIS Discrete Votes & Diagnostics

    PT_A_Fault : BOOL; PT_B_Fault : BOOL; PT_C_Fault : BOOL;
    LT_A_Fault : BOOL; LT_B_Fault : BOOL; LT_C_Fault : BOOL;


..._Fault: TRUE if the raw signal violates NAMUR NE43 bounds (hardware failure).

    PT_A_High_Vote : BOOL; PT_B_High_Vote : BOOL; PT_C_High_Vote : BOOL;
    LT_A_High_Vote : BOOL; LT_B_High_Vote : BOOL; LT_C_High_Vote : BOOL;
    LT_A_Low_Vote  : BOOL; LT_B_Low_Vote  : BOOL; LT_C_Low_Vote  : BOOL;


..._Vote: Discrete boolean flags indicating if a specific, healthy sensor has crossed a physical trip limit.

    HMI_PT_A_MOS : BOOL; HMI_PT_B_MOS : BOOL; HMI_PT_C_MOS : BOOL;
    PT_A_Ignored : BOOL; PT_B_Ignored : BOOL; PT_C_Ignored : BOOL;
    Ignore_Count : INT;
    HMI_LT_A_MOS : BOOL; HMI_LT_B_MOS : BOOL; HMI_LT_C_MOS : BOOL;
    LT_A_Ignored : BOOL; LT_B_Ignored : BOOL; LT_C_Ignored : BOOL;
    LT_Ignore_Count : INT;


HMI_..._MOS: Maintenance Override Switch requests from the SCADA screen.

..._Ignored: The final diagnostic state. TRUE if the sensor is mechanically broken (Fault) OR explicitly bypassed by the operator (MOS).

Ignore_Count: Tallies the number of blind sensors, driving the mathematical shift from 2oo3 to 1oo2 matrix degradation.

    PT_Matrix_Fault    : BOOL; LT_Matrix_Fault    : BOOL;
    Bypass_Veto_Active : BOOL; 
    Shift_MOS_Timer    : TON; Stale_Bypass_Alarm : BOOL; 


..._Matrix_Fault: TRUE if Ignore_Count >= 2, representing a fatal loss of safety redundancy.

Bypass_Veto_Active: Dynamic Kamikaze safeguard. Activates if the process reaches >90% of danger, forcefully shredding human MOS bypasses.

Shift_MOS_Timer / Stale_Bypass_Alarm: Tracks active bypasses and triggers an alarm if left active for >8 hours.

# Section 4: Cause & Effect Executive (Trips)

    PSHH_Tripped      : BOOL; LSHH_Tripped      : BOOL; LSLL_Tripped      : BOOL; 
    Master_SIS_Trip   : BOOL; 
    PAH_Alarm         : BOOL; LAL_Alarm         : BOOL; 


..._Tripped: The exact output flags from the safety voting matrices.

Master_SIS_Trip: The Global Interlock. If TRUE, the plant drops to State 4 and closes all shutdown valves.

PAH_Alarm / LAL_Alarm: Early-warning operator process alarms that do not automatically trip the plant.

# Section 5: ISA-106 State Machine & Regulatory Outputs

    Current_State     : INT := 0; 
    Startup_Grace_Timer: TON; State2_Timer      : TON;      
    Inlet_SDV         : BOOL; 
    PCV_Sales_Output  : REAL; PCV_Flare_Output  : REAL; 
    LCV_Oil_Output    : REAL; LCV_Water_Output  : REAL; 


Current_State: Controls automation phases (0=Isolated, 1=Purging, 2=Pressurizing, 3=Running, 4=ESD Trip).

Startup_Grace_Timer: Suppresses the Low-Level trip for 15s during startup to allow liquid to build up.

State2_Timer: Watchdog that aborts pressurization if it takes >5 minutes.

Inlet_SDV: Digital command to open the Main Shutdown Valve.

PCV_ / LCV_: Analog floating-point outputs (0-100%) to the control valves.

# Section 6: APM & HMI Commands

    Inlet_SDV_ZSO     : BOOL; Inlet_SDV_ZSC     : BOOL; 
    Inlet_Watchdog    : TON; Inlet_Transit_Err : BOOL; 
    Inlet_Stroke_Timer: TON; Measured_Stroke_Time: REAL; Valve_Degrad_Alert: BOOL; 


..._ZSO / ..._ZSC: Limit switches physically mounted on the valve.

Inlet_Watchdog / Transit_Err: Alarms if the valve takes >5s to change state.

Inlet_Stroke_Timer / Measured_Stroke_Time: APM profiling capturing exact millisecond stroke speeds.

Valve_Degrad_Alert: Warns maintenance if the stroke time slows down.

    HMI_Start_Cmd : BOOL; HMI_Stop_Cmd : BOOL; HMI_Reset_Cmd : BOOL;
    HMI_LCV_Oil_Manual_Mode : BOOL; HMI_LCV_Oil_Manual_Value: REAL;


HMI_...: UI commands from the SCADA interface, including the manual bypass logic for bumpless valve transfer.

# Section 7: Regulatory PID Controllers

    PID_Pressure  : PID; PID_Level_Oil : PID; PID_Level_Wat : PID;
    SP_Pressure   : REAL := 45.0; SP_Level_Oil  : REAL := 50.0; SP_Level_Wat  : REAL := 25.0; 


PID_...: Core mathematical function blocks (Requires CODESYS 'Util' Library).

SP_...: Target control Setpoints.

    Kp_Press : REAL := -2.0; Tn_Press : REAL := 15.0;  
    Kp_Level : REAL := -1.5; Tn_Level : REAL := 30.0;  


Kp (Proportional Gains): Negative values establish Direct-Acting control (valves open to vent rising pressure/level).

Tn (Integral Time): Liquid loops (30s) are tuned slower than gas (15s) to prevent hydraulic shock.

    Oil_PID_Manual_Cmd : BOOL; Oil_PID_Manual_Val : REAL; Wat_PID_Manual_Cmd : BOOL;
END_VAR


Manual Override Pins: Utilized by Anti-Blow-By logic to instantly hijack the PID math and force the valve to 0% while preventing Integral Windup.

# PART 2: MAIN LOGIC ENGINE (PLC_PRG.st)

This engine executes every 100 milliseconds, applying physics, matrices, and state control to the memory map.

# Section 0: Black-Start & UPS Brownout Protection

IF GVL.First_Scan_Init THEN
    GVL.Current_State := 0;
    GVL.Inlet_SDV := FALSE;
    GVL.Master_SIS_Trip := TRUE; 
    GVL.First_Scan_Init := FALSE;
END_IF;

IF GVL.UPS_Low_Batt_Warning THEN
    GVL.Master_SIS_Trip := TRUE; 
END_IF;


First Scan Trap: Guarantees the plant wakes up in a safe, fully locked-down state after a power outage.

UPS Failsafe: Executes a controlled shutdown if backup power drops to critical levels.

# Section 1: NAMUR NE43 Validation & Dynamic Averaging

GVL.PT_A_Fault := (GVL.Raw_PT_A < GVL.RAW_FAULT_LOW) OR (GVL.Raw_PT_A > GVL.RAW_FAULT_HIGH);
// ... Repeated for PT_B, PT_C, LT_A, LT_B, LT_C


Identifies hardware failures (broken wires or short circuits) instantly based on electrical bounds.

IF NOT GVL.PT_A_Fault THEN GVL.PT_A_Scaled := (INT_TO_REAL(GVL.Raw_PT_A) / GVL.RAW_MAX) * 100.0; END_IF;
// ... Repeated for PT_B, PT_C, LT_A, LT_B, LT_C


Math scaling is strictly bypassed if a fault exists, holding the last known good value to prevent math errors.

GVL.Water_Int_Pct := (INT_TO_REAL(GVL.Raw_LT_Inter) / GVL.RAW_MAX) * 100.0;


Scales the standalone water interface level.

GVL.Healthy_PT_Count := 0; GVL.Sum_Pressure := 0.0;
IF NOT GVL.PT_A_Fault THEN GVL.Healthy_PT_Count := GVL.Healthy_PT_Count + 1; GVL.Sum_Pressure := GVL.Sum_Pressure + GVL.PT_A_Scaled; END_IF;
// ... Repeated for PT_B and PT_C ...
IF GVL.Healthy_PT_Count > 0 THEN GVL.Vessel_Pressure := GVL.Sum_Pressure / INT_TO_REAL(GVL.Healthy_PT_Count); ELSE GVL.Vessel_Pressure := 0.0; END_IF;


Dynamic Averaging Engine: Calculates the exact number of healthy sensors. Bypasses division by zero (Count > 0), then divides the sum of only the healthy sensors, guaranteeing extreme PID stability during hardware casualties.

# Section 2: Discrete Boolean Voting Generation

GVL.PT_A_High_Vote := NOT GVL.PT_A_Fault AND (GVL.PT_A_Scaled >= GVL.SYS_TRIP_PRESS);
// ... Repeated for High/Low votes across all matrices


Converts analog levels into definitive digital "Votes". A sensor is strictly forbidden from casting a trip vote if it is physically broken (NOT Fault).

# Section 3: SIS Matrix Degradation & Algebra

GVL.Bypass_Veto_Active := (GVL.Vessel_Pressure >= (GVL.SYS_TRIP_PRESS * 0.90)) OR (GVL.Total_Liq_Pct >= (GVL.LIQ_TRIP_HIGH * 0.90));


Dynamic Veto: If pressure/level hits 90% of the trip limit, human overrides are mathematically shredded.

GVL.PT_A_Ignored := (GVL.HMI_PT_A_MOS AND NOT GVL.Bypass_Veto_Active) OR GVL.PT_A_Fault;
// ... Repeated for all sensors


A sensor is explicitly ignored from the safety matrix if it is faulty or manually bypassed by an operator (assuming Veto is inactive).

GVL.Ignore_Count := 0;
IF GVL.PT_A_Ignored THEN GVL.Ignore_Count := GVL.Ignore_Count + 1; END_IF;
// ... Repeated for B and C


Tallies the number of blind sensors to drive logic degradation.

IF GVL.Ignore_Count = 0 THEN
    GVL.PSHH_Tripped := (GVL.PT_A_High_Vote AND GVL.PT_B_High_Vote) OR (GVL.PT_B_High_Vote AND GVL.PT_C_High_Vote) OR (GVL.PT_A_High_Vote AND GVL.PT_C_High_Vote);
ELSIF GVL.Ignore_Count = 1 THEN
    IF GVL.PT_A_Ignored THEN GVL.PSHH_Tripped := (GVL.PT_B_High_Vote OR GVL.PT_C_High_Vote); END_IF;
    IF GVL.PT_B_Ignored THEN GVL.PSHH_Tripped := (GVL.PT_A_High_Vote OR GVL.PT_C_High_Vote); END_IF;
    IF GVL.PT_C_Ignored THEN GVL.PSHH_Tripped := (GVL.PT_A_High_Vote OR GVL.PT_B_High_Vote); END_IF;
ELSE
    GVL.PSHH_Tripped := TRUE; 
END_IF;
// ... Repeated exactly for LSHH_Tripped


Matrix Logic: 0 Ignored = 2oo3 Voting. 1 Ignored = Downgrades to highly sensitive 1oo2 Voting. 2 Ignored = Failsafe Trip due to total loss of redundancy.

GVL.Startup_Grace_Timer(IN := (GVL.Current_State = 2 OR GVL.Current_State = 3), PT := T#10m);
// ... LSLL_Tripped matrix uses GVL.Startup_Grace_Timer.Q AND (Voting Logic)


Applies a 10-minute grace period during startup to prevent the empty tank from instantly triggering a Low-Level trip.

GVL.PT_Matrix_Fault := (GVL.Ignore_Count >= 2);
GVL.LT_Matrix_Fault := (GVL.LT_Ignore_Count >= 2);


Legacy mapping for Master Trip routines.

# Section 4: Cause & Effect Executive (Master Trips)

IF GVL.PSHH_Tripped OR GVL.LSHH_Tripped OR GVL.LSLL_Tripped OR GVL.PT_Matrix_Fault OR GVL.LT_Matrix_Fault OR GVL.Inlet_Transit_Err THEN
    GVL.Master_SIS_Trip := TRUE;
END_IF;


Memory Latch: The lack of an ELSE statement ensures the Master Trip stays locked TRUE even after the physical hazard subsides.

IF GVL.HMI_Reset_Cmd AND GVL.Master_SIS_Trip AND (GVL.Vessel_Pressure < GVL.SYS_TRIP_PRESS) AND (GVL.Total_Liq_Pct < GVL.LIQ_TRIP_HIGH) AND GVL.Inlet_SDV_ZSC AND NOT GVL.PT_Matrix_Fault AND NOT GVL.LT_Matrix_Fault THEN 
    GVL.PSHH_Tripped := FALSE; GVL.LSHH_Tripped := FALSE; GVL.LSLL_Tripped := FALSE; 
    GVL.Inlet_Transit_Err := FALSE; GVL.Master_SIS_Trip := FALSE; GVL.Current_State := 0;     
END_IF;


Secure Reset: The operator's reset button is completely ignored unless process pressure/level are safe, the valve limit switch is confirmed closed (ZSC), and the voting matrices are healthy.

# Section 5: ISA-106 State Machine

CASE GVL.Current_State OF
    0: // ISOLATED
        GVL.Inlet_SDV := FALSE;
        IF GVL.HMI_Start_Cmd AND NOT GVL.Master_SIS_Trip AND NOT GVL.Local_Panel_Key THEN GVL.Current_State := 1; END_IF;
    1: // PURGING
        IF GVL.Vessel_Pressure <= GVL.SYS_PURGE_PRESS THEN GVL.Current_State := 2; END_IF;
    2: // PRESSURIZING
        GVL.Inlet_SDV := TRUE; 
        GVL.State2_Timer(IN := (GVL.Current_State = 2), PT := T#5m); 
        IF GVL.Inlet_SDV_ZSO AND (GVL.Vessel_Pressure >= GVL.SYS_START_PRESS) THEN GVL.Current_State := 3; 
        ELSIF GVL.State2_Timer.Q THEN GVL.Master_SIS_Trip := TRUE; END_IF;
    3: // RUNNING (BPCS ACTIVE)
        GVL.Inlet_SDV := TRUE;
        IF GVL.Master_SIS_Trip OR GVL.HMI_Stop_Cmd THEN GVL.Current_State := 4; 
        ELSIF GVL.Vessel_Pressure < GVL.SYS_DROP_PRESS THEN GVL.Current_State := 2; END_IF;
    4: // EMERGENCY SHUTDOWN (ESD)
        GVL.Inlet_SDV := FALSE; 
END_CASE;


Enforces strict, step-by-step procedural automation. Note the State 2 Watchdog (State2_Timer.Q), which actively trips the plant if pressurization fails after 5 minutes (indicating a pipeline rupture).

# Section 6: Regulatory Control Loops & Bounding

IF GVL.Current_State = 3 THEN


Ensures Basic Process Control System (BPCS) valves only modulate during steady-state Running operations.

    // --- 1. Sales Gas Split-Range (45.0 to 52.0 Bar) ---
    IF GVL.Vessel_Pressure <= 45.0 THEN GVL.PCV_Sales_Output := 0.0;
    ELSIF GVL.Vessel_Pressure >= 52.0 THEN GVL.PCV_Sales_Output := 100.0;
    ELSE GVL.PCV_Sales_Output := ((GVL.Vessel_Pressure - 45.0) / 7.0) * 100.0; END_IF;

    // --- 2. Emergency Flare Split-Range (52.0 to 55.0 Bar) ---
    IF GVL.Vessel_Pressure <= 52.0 THEN GVL.PCV_Flare_Output := 0.0;
    ELSIF GVL.Vessel_Pressure >= 55.0 THEN GVL.PCV_Flare_Output := 100.0;
    ELSE GVL.PCV_Flare_Output := ((GVL.Vessel_Pressure - 52.0) / 3.0) * 100.0; END_IF;


Split-Range Control: Prioritizes Sales Gas to maximize profit. Dynamically ramps the Flare valve open only if pressure hits 52.0 Bar, catching pressure surges before they trigger the 55.0 Bar facility trip.

    IF GVL.HMI_LCV_Oil_Manual_Mode THEN GVL.LCV_Oil_Output := GVL.HMI_LCV_Oil_Manual_Value; 
    ELSE GVL.LCV_Oil_Output := GVL.Total_Liq_Pct; END_IF;
    
    GVL.LCV_Water_Output := GVL.Water_Int_Pct;


Bumpless Transfer: Allows the operator to inject manual values to the Oil drain without snapping the valve abruptly.

ELSE
    GVL.PCV_Sales_Output := 0.0; 
    IF GVL.Current_State = 2 THEN GVL.PCV_Flare_Output := 0.0; 
    ELSE GVL.PCV_Flare_Output := 100.0; END_IF;
    GVL.LCV_Oil_Output := 0.0; GVL.LCV_Water_Output := 0.0;
END_IF;


Emergency Blowdown: When the plant trips, the Flare Valve defaults to 100% open to safely depressurize the vessel, except in State 2 where it must remain closed to build startup pressure.

IF GVL.LCV_Oil_Output > 100.0 THEN GVL.LCV_Oil_Output := 100.0; ELSIF GVL.LCV_Oil_Output < 0.0 THEN GVL.LCV_Oil_Output := 0.0; END_IF;
IF GVL.LCV_Water_Output > 100.0 THEN GVL.LCV_Water_Output := 100.0; ELSIF GVL.LCV_Water_Output < 0.0 THEN GVL.LCV_Water_Output := 0.0; END_IF;


Absolute Bounds: Mathematical clamps ensuring faulty logic or manual operator typos (e.g. "900%") can never send invalid electrical signals out to the hardware cards.

# Section 7: APM Watchdogs & Alarm Management

GVL.Inlet_Stroke_Timer(IN := (GVL.Inlet_SDV AND NOT GVL.Inlet_SDV_ZSO), PT := T#10s);
IF GVL.Inlet_SDV_ZSO AND NOT GVL.Valve_Degrad_Alert THEN
    GVL.Measured_Stroke_Time := TIME_TO_REAL(GVL.Inlet_Stroke_Timer.ET) / 1000.0;
    IF (GVL.Measured_Stroke_Time > 2.4) THEN GVL.Valve_Degrad_Alert := TRUE; END_IF; 
END_IF;
IF NOT GVL.Inlet_SDV THEN GVL.Inlet_Stroke_Timer(IN := FALSE); END_IF;


Valve Stroke Profiling: Extracts the exact Elapsed Time (.ET) of the mechanical valve movement. Warns mechanics if the valve begins moving sluggishly (> 2.4s) weeks before it actually breaks.

GVL.Inlet_Watchdog(IN := (GVL.Inlet_SDV AND NOT GVL.Inlet_SDV_ZSO) OR (NOT GVL.Inlet_SDV AND NOT GVL.Inlet_SDV_ZSC), PT := T#5s);
IF GVL.Inlet_Watchdog.Q THEN GVL.Inlet_Transit_Err := TRUE; END_IF;


Bi-Directional Failure Trap: If the PLC commands the valve Open or Closed, and the physical limit switch (ZSO/ZSC) doesn't click within 5 seconds, it immediately trips the plant for a "Stuck Valve" error.

GVL.Shift_MOS_Timer(IN := (GVL.Ignore_Count > 0) OR (GVL.LT_Ignore_Count > 0), PT := T#8h);
IF GVL.Shift_MOS_Timer.Q THEN GVL.Stale_Bypass_Alarm := TRUE; END_IF;


Safety Audit: Triggers an alarm if an operator forgets to remove a sensor bypass at the end of an 8-hour shift.

GVL.PAH_Alarm := (GVL.Vessel_Pressure >= (GVL.SYS_TRIP_PRESS * 0.90)); 
IF (GVL.Current_State = 0) OR (GVL.Current_State = 4) THEN GVL.LAL_Alarm := FALSE; 
ELSE GVL.LAL_Alarm := (GVL.Total_Liq_Pct <= 30.0); END_IF;


ISA-18.2 State-Based Muting: Explicitly suppresses the "Low Level Alarm" (LAL) when the plant is offline or tripped, preventing a flood of nuisance alarms from blinding the operator during an emergency shutdown.
