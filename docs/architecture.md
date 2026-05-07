# AXI4-Lite Peripheral Subsystem

## 1. Purpose
MMIO peripherals for UART, GPIO, and a DDS component, accessible via AXI4-Lite interconnect from an FPGA-to-HPS bridge.

Provides UART serial comms with FIFO buffer; GPIO with interrupt capability; DDS wavefrom generator. HPS is to be used as AXI master, handling route transactions from these peripherals. Designed for intergration, but not limited to, a Cyclone V with HPS via AXI bridge.

## 2. External Interface 

Signal list provided for AXI4-Lite protocol from AMBA AXI and ACE Protocol
Specification, Chapter B.3.

## 3. Current File Structure
Under the AXI Peripheral Subsystem, the project includes a comprehensive workflow with HAS for RTL, TB structure with UVM integration, formal verif., drivers, and various scripts for tests and regressions. The following base structure is as follows:

1. RTL modules:
    - AXI Top level
    - AXI interface for M/S
    - AXI Crossbar/fabric 
    - UART
    - GPIO
    - DDS
2. Testbench Structure:
    - Interfaces
        - AXI wrapper
        - UART wrapper
        - GPIO wrapper
        - DDS wrapper
    - Common TB
        - BFM tasks
        - AXI package
        - CLK/RST generator
    - UVM for AXI
        - Sequence items
        - Driver
        - Monitor
        - Agent
        - Coverage
        - UVM package
    - UART, GPIO, DDS
        - Directed tests
        - Top module TB
        - Environment
        - Scoreboard
        - Reg. models
        - Sequences
        - Test config. and stimulus generation
    - Integration
        - Icarus/Verilator/IDE integration check
        - UVM Top level integration
        - Top Environment
        - Virtual Sequencer
    - Further testing though Verilator with C++
        - Simulation main
        - AXI BFM source and header files
        - CMake
3. Formal Verification:
    - UART, GPIO, DDS props
    - Symbiyosys files
4. Scripting:
    - Register Generation
        - YAML for register map
        - Python RAL gen
        - Python C header gen
        - Python Sine LUT
    - Mutagen
        - YAML for mutations
        - Python Mutagen
        - Python Mutagen Run files
    - Bench & Tools
        - Python for Connect
        - PyDDS Characterisation
    - Regressions with Python
5. Software Intrgration:
    - Drivers
        - AXI-UART/GPIO/DDS source and headers
        - generated:
            - peripheral registers (from Python C header gen)
            - DDS Sine LUT (from Python Sine LUT)
    - demo 
        - main C entry point
6. FPGA:
    - Cyclone/Altera/Intel Integration
    - Nexys/Xilinx/AMD Integration
7. DOCS:
    - Architecture (HAS)
    - Verification Report
    - Register Map (HAS)
    - Figures, misc., and supplementary material
8. CI/CD workflow with YAML
9. Makefile build & compilation
10. Git misc.
11. README


