# icss-separator
Enterprise IEC 61131-3 &amp; ISA-106 3-Phase Separator Logic Engine.
# Enterprise ICSS: High-Pressure 3-Phase Separator

## Project Overview
This repository contains a mathematically proven, enterprise-grade **Industrial Control and Safety System (ICSS)** logic engine and corresponding SCADA interface for a high-pressure 3-Phase Separator. 

This project demonstrates the strict decoupling of the **Basic Process Control System (BPCS)** from the **Safety Instrumented System (SIS)**, engineered to manage volatile physical processes including fluid separation, gas blow-by prevention, and dynamic safety interlocks.

### 🌐 Live Interactive Demonstration
A 1:1 JavaScript port of the PLC logic has been deployed alongside an ISA-101 compliant SCADA interface. 
👉 **[Run the Interactive Factory Acceptance Test (FAT) Here] https://kedharnath-ry.github.io/icss-separator/**

** Video Demonstration link - https://vimeo.com/1204951004?share=copy&fl=sv&fe=ci **

---

## 🏛️ International Engineering Standards Applied
This architecture strictly adheres to Tier-1 industrial automation standards:
* **IEC 61131-3:** Code architecture utilizing Structured Text (CODESYS) with standard `Util` libraries for true PID and Integral Windup Protection.
* **IEC 61511 (Functional Safety):** Implementation of Triple Modular Redundancy (TMR) and dynamic matrix degradation.
* **ISA-106 (Procedural Automation):** Deterministic, state-based startup and shutdown sequencing.
* **ISA-18.2 (Alarm Management):** Prioritized, non-intrusive diagnostic and system alarming.
* **ISA-101 (HMI Design):** High-performance graphics, muted color palettes, and strict situational awareness layouts.

---

## ⚙️ System Architecture & Logic Features

### 1. Safety Instrumented System (SIS)
* **Triple Modular Redundancy (2oo3):** Both Pressure (PT) and Level (LT) matrices utilize 2-out-of-3 voting logic to eliminate nuisance tripping while guaranteeing safety.
* **Dynamic Matrix Degradation:** If a field transmitter mechanically fails (Broken Wire `< 4mA` or Short Circuit `> 20mA`), the PLC drops the faulted sensor from the mathematical average and dynamically degrades the safety matrix to a highly sensitive **1oo2 architecture**.
* **Dynamic Bypass Veto:** Maintenance Override Switches (MOS) allow operators to bypass single sensors for calibration. However, if the active process reaches >90% of the trip threshold, the PLC mathematically revokes the human override to ensure full protective coverage.

### 2. Basic Process Control System (BPCS)
* **ISA-106 State Machine:** Enforces a rigid operational sequence: `0: ISOLATED ; 1: PURGING ; 2: PRESSURIZING ; 3: RUNNING 4: ESD TRIP .
* **Split-Range Pressure Control:** A single master PID dynamically splits its output between a primary **Sales Gas PCV** and an **Emergency Flare PCV** to seamlessly handle wellhead gas surges without tripping the facility.
* **Anti-Blow-By Clamps:** If the internal liquid seal drops below 5.0%, the PLC violently overrides the BPCS PID outputs, forcing the liquid drain valves to 0% (Closed) to prevent catastrophic high-pressure gas escape.
* **Integral Windup Protection:** PID controllers are explicitly commanded to `RESET := TRUE` during plant trips to prevent integral math accumulation, ensuring a perfectly bumpless transfer upon restart.

### 3. Asset Performance Management (APM)
* **Valve Transit Watchdogs:** Initiates a 15-second predictive maintenance timer when an SDV is commanded. Failure to read the mechanical limit switch (`ZSO` / `ZSC`) triggers a `STUCK VALVE` alarm and latches the SIS trip.
* **Stale Bypass Audit:** Timers track active MOS commands, alarming if a safety sensor is left bypassed for >8 hours.

---

## 📂 Repository Structure

| File | Description |
| :--- | :--- |
| `index.html` | The live SCADA HMI environment. Includes a full JavaScript port of the logic engine, custom vector graphics, and a 6-step interactive FAT Validation Guide. |
| `PLC_PRG.st` | The core IEC 61131-3 Structured Text logic engine. Contains NAMUR NE43 validation, boolean voting, ISA-106 states, and regulatory PID control. |
| `GVL.st` | The Global Variable List. Defines strictly typed memory allocation, engineering limits, and I/O tags. |

---

## 🛠️ How to Run & Compile (CODESYS)
To run the native logic engine on a local virtual PLC:
1. Open **CODESYS V3.5** and create a Standard Project.
2. Open the **Library Manager**, search for `Util`, and add it to the project (Required for the `PID` function blocks).
3. Copy the contents of `GVL.st` into your Global Variable List.
4. On top of plc_prg add - "PROGRAM PLC_PRG
VAR
END_VAR"
5. Copy the contents of `PLC_PRG.st` into your main program below the above code..
6. Press `F11` to build (0 Errors, 0 Warnings).
7. Click **Online -> Simulation**, then **Login (Alt+F8)**, and **Start (F5)**. You can now force variables directly in the GVL to test the ISA-106 transitions.

---
*Architected and developed as a comprehensive demonstration of enterprise process control capabilities.*
