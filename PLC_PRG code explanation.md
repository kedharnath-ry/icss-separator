# IEC 61131-3 Code Architecture Breakdown: Main Logic Engine (PLC_PRG)

While the GVL defines the memory and physical boundaries, the PLC_PRG (Programmable Logic Controller Program) is the active brain. Executing every 100 milliseconds, this engine evaluates physical inputs, calculates dynamic mathematics, enforces safety interlocks, and drives the process valves.

This document breaks down the Tier-1 engineering principles behind each section of the Structured Text code.

# Section 0: Black-Start & UPS Brownout Protection

When an industrial facility loses power, the PLC shuts down. When power is restored, the PLC wakes up "blind." This section ensures the facility recovers safely.

IF GVL.First_Scan_Init THEN
    GVL.Current_State := 0;
    GVL.Inlet_SDV := FALSE;
    GVL.Master_SIS_Trip := TRUE; 
    GVL.First_Scan_Init := FALSE;
END_IF;


The Physics: First_Scan_Init is TRUE for exactly one execution cycle after boot.

The Engineering: By forcing the Master Trip to TRUE and slamming the Inlet Shutdown Valve (SDV) to FALSE (Closed), we prevent an "Uncontrolled Startup." The plant locks itself down and waits for a human operator to verify the pipeline before introducing high-pressure gas.

IF GVL.UPS_Low_Batt_Warning THEN
    GVL.Master_SIS_Trip := TRUE; 
END_IF;


Brownout Failsafe: If the facility's Uninterruptible Power Supply (UPS) is dying, the PLC executes a controlled Emergency Shutdown (ESD) before the CPU loses power, ensuring the plant fails to a safe state.

# Section 1: NAMUR NE43 Validation & Dynamic Averaging

Raw 4-20mA signals from the field are volatile. This section filters broken hardware from true process data.

GVL.PT_A_Fault := (GVL.Raw_PT_A < GVL.RAW_FAULT_LOW) OR (GVL.Raw_PT_A > GVL.RAW_FAULT_HIGH);


Hardware Diagnostics: We do not blindly trust the sensor. If a backhoe cuts the underground cable, the signal drops below 4mA (< RAW_FAULT_LOW). If rain shorts the junction box, it spikes (> RAW_FAULT_HIGH). This line catches the electrical failure instantly.

IF NOT GVL.PT_A_Fault THEN 
    GVL.PT_A_Scaled := (INT_TO_REAL(GVL.Raw_PT_A) / GVL.RAW_MAX) * 100.0; 
END_IF;


Math Freeze: The mathematical scaling (translating 0-27648 to Bar/Percent) is only executed if the sensor is healthy. If the sensor dies, the math freezes, holding the last known good value to prevent wild PID spikes.

GVL.Healthy_PT_Count := 0; GVL.Sum_Pressure := 0.0;
IF NOT GVL.PT_A_Fault THEN GVL.Healthy_PT_Count := GVL.Healthy_PT_Count + 1; GVL.Sum_Pressure := GVL.Sum_Pressure + GVL.PT_A_Scaled; END_IF;
// ... (Repeated for B and C)
IF GVL.Healthy_PT_Count > 0 THEN GVL.Vessel_Pressure := GVL.Sum_Pressure / INT_TO_REAL(GVL.Healthy_PT_Count); ELSE GVL.Vessel_Pressure := 0.0; END_IF;


Dynamic Averaging Engine: Instead of hardcoding (A+B+C)/3, this logic dynamically counts how many sensors are alive. If Sensor C dies, Healthy_PT_Count drops to 2, and the math automatically adjusts to (A+B)/2. This guarantees perfectly stable pressure readings even during hardware casualties, preventing the PID loops from crashing.

# Section 2: Discrete Boolean Voting Generation

Translating continuous analog data into strict True/False digital decisions.

GVL.PT_A_High_Vote := NOT GVL.PT_A_Fault AND (GVL.PT_A_Scaled >= GVL.SYS_TRIP_PRESS);


The Safety Rule: A sensor is strictly forbidden from casting a trip vote if it is physically broken (NOT GVL.PT_A_Fault). This prevents an electrical short-circuit from triggering a multi-million-dollar phantom plant shutdown.

# Section 3: SIS Matrix Degradation & Algebra (IEC 61511)

The core of Functional Safety. This handles Triple Modular Redundancy (TMR).

GVL.Bypass_Veto_Active := (GVL.Vessel_Pressure >= (GVL.SYS_TRIP_PRESS * 0.90));
GVL.PT_A_Ignored := (GVL.HMI_PT_A_MOS AND NOT GVL.Bypass_Veto_Active) OR GVL.PT_A_Fault;


Dynamic Bypass Veto: Operators can bypass sensors for calibration using a Maintenance Override Switch (MOS). However, if actual tank pressure hits 90% of the explosive limit, the Veto activates, mathematically shredding the operator's bypass and forcing the sensor back online to protect the facility.

IF GVL.Ignore_Count = 0 THEN
    GVL.PSHH_Tripped := (GVL.PT_A_High_Vote AND GVL.PT_B_High_Vote) OR (GVL.PT_B_High_Vote AND GVL.PT_C_High_Vote) OR (GVL.PT_A_High_Vote AND GVL.PT_C_High_Vote);
ELSIF GVL.Ignore_Count = 1 THEN
    IF GVL.PT_A_Ignored THEN GVL.PSHH_Tripped := (GVL.PT_B_High_Vote OR GVL.PT_C_High_Vote); END_IF;
// ...
ELSE
    GVL.PSHH_Tripped := TRUE; 
END_IF;


1oo2 Matrix Degradation: * If 0 sensors are ignored, the system requires 2 out of 3 sensors to agree to trip.

If 1 sensor is broken or bypassed (Ignore_Count = 1), the matrix automatically downgrades to a highly sensitive 1oo2 architecture.

If 2 sensors are ignored, the system completely loses redundancy and mathematically fails-safe, tripping the plant (ELSE GVL.PSHH_Tripped := TRUE).

# Section 4: Cause & Effect Executive (Master Trips)

The final judge and executioner of the safety logic.

IF GVL.PSHH_Tripped OR GVL.LSHH_Tripped OR GVL.LSLL_Tripped OR GVL.PT_Matrix_Fault OR GVL.LT_Matrix_Fault OR GVL.Inlet_Transit_Err THEN
    GVL.Master_SIS_Trip := TRUE;
END_IF;


The Memory Latch: Notice there is no ELSE statement here. Once the Master_SIS_Trip evaluates to TRUE, it latches in memory. Even if the pressure safely drops seconds later, the plant remains locked down.

IF GVL.HMI_Reset_Cmd AND GVL.Master_SIS_Trip AND (GVL.Vessel_Pressure < GVL.SYS_TRIP_PRESS) AND GVL.Inlet_SDV_ZSC AND NOT GVL.PT_Matrix_Fault THEN 
    // Clear trip memory...
END_IF;


Secure Reset: To clear the Master Trip, the operator must press Reset, BUT the PLC mathematically demands proof that the hazard is gone (Pressure < Limit), the hardware matrix is healthy, and the massive shutdown valve is physically confirmed closed via limit switch (SDV_ZSC).

# Section 5: ISA-106 State Machine

Procedural automation replaces human error with strict mechanical sequencing.

CASE GVL.Current_State OF
    // ...
    2: // PRESSURIZING
        GVL.Inlet_SDV := TRUE; 
        GVL.State2_Timer(IN := (GVL.Current_State = 2), PT := T#5m); 
        
        IF GVL.Inlet_SDV_ZSO AND (GVL.Vessel_Pressure >= GVL.SYS_START_PRESS) THEN 
            GVL.Current_State := 3; 
        ELSIF GVL.State2_Timer.Q THEN
            GVL.Master_SIS_Trip := TRUE; 
        END_IF;


State 2 (Pressurizing) Example: The PLC commands the inlet valve open. It then waits for pressure to reach 45 Bar.

The Watchdog: If 5 minutes pass (State2_Timer) and the pressure still hasn't reached 45 Bar, the PLC deduces there is a massive pipeline rupture leaking gas into the environment. It aborts the startup and trips the plant.

# Section 6: Regulatory Control Loops & Bumpless Transfer

The Basic Process Control System (BPCS) modulates valves to make profit.

IF GVL.Current_State = 3 THEN
    // --- Sales Gas Split-Range (45.0 to 52.0 Bar) ---
    IF GVL.Vessel_Pressure <= 45.0 THEN GVL.PCV_Sales_Output := 0.0;
    ELSIF GVL.Vessel_Pressure >= 52.0 THEN GVL.PCV_Sales_Output := 100.0;
    ELSE GVL.PCV_Sales_Output := ((GVL.Vessel_Pressure - 45.0) / 7.0) * 100.0;
    END_IF;


Split-Range Pressure Control:

Under normal conditions (45-52 Bar), the Sales PCV opens to export gas for profit.

If pressure surges past 52 Bar, the Sales valve maxes out, and the Emergency Flare PCV (handled in the next block) dynamically ramps open to vent the excess pressure, preventing the vessel from hitting the 55 Bar SIS trip.

    IF GVL.HMI_LCV_Oil_Manual_Mode THEN
        GVL.LCV_Oil_Output := GVL.HMI_LCV_Oil_Manual_Value; 
    ELSE
        GVL.LCV_Oil_Output := GVL.Total_Liq_Pct; 
    END_IF;


Bumpless Transfer: Allows the operator to hijack the valve from the math engine and manually stroke it. Because it switches smoothly based on an IF/ELSE state, it prevents the valve from violently snapping (which causes hydraulic shock or "Water Hammer").

IF GVL.LCV_Oil_Output > 100.0 THEN GVL.LCV_Oil_Output := 100.0; ELSIF GVL.LCV_Oil_Output < 0.0 THEN GVL.LCV_Oil_Output := 0.0; END_IF;


Hardware Output Clamps: Analog output cards require a signal between 0 and 100%. If manual input or broken math sends -10% to a hardware card, the PLC processor can hard-fault and crash. These clamps act as an absolute mathematical firewall.

# Section 7: APM Watchdogs & ISA-18.2 Alarm Management

Asset Performance Management predicts failures before they cause downtime.

GVL.Inlet_Watchdog(IN := (GVL.Inlet_SDV AND NOT GVL.Inlet_SDV_ZSO) OR (NOT GVL.Inlet_SDV AND NOT GVL.Inlet_SDV_ZSC), PT := T#5s);
IF GVL.Inlet_Watchdog.Q THEN GVL.Inlet_Transit_Err := TRUE; END_IF;


Bi-Directional Mechanical Watchdog: If the PLC removes power to close a safety valve, but the valve is jammed by a rock, the closed limit switch (ZSC) will never click. The watchdog counts to 5 seconds. If no physical switch is engaged, it deduces the valve is stuck (Transit_Err) and immediately trips the facility.

GVL.Shift_MOS_Timer(IN := (GVL.Ignore_Count > 0) OR (GVL.LT_Ignore_Count > 0), PT := T#8h);
IF GVL.Shift_MOS_Timer.Q THEN GVL.Stale_Bypass_Alarm := TRUE; END_IF;


Safety Auditing: The biggest danger in a plant is an operator bypassing a safety sensor to clean it, and forgetting to turn the bypass off. This logic triggers an un-ignorable alarm if any sensor in the facility is left bypassed for more than an 8-hour shift.

IF (GVL.Current_State = 0) OR (GVL.Current_State = 4) THEN
    GVL.LAL_Alarm := FALSE; 
ELSE
    GVL.LAL_Alarm := (GVL.Total_Liq_Pct <= 30.0);
END_IF;


ISA-18.2 Alarm Suppression (Muting): When an entire facility trips (State 4), the tank naturally empties out. Without this code, the Low-Level alarm (LAL) would trigger. In a large plant, a shutdown causes hundreds of these nuisance alarms, blinding the operator. This logic intentionally suppresses the low-level alarm when the plant is offline, keeping the SCADA screen clean and actionable.
