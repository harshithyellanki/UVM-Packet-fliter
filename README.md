# UVM-Packet-fliter


```markdown
# AXI4 Packet Filter Verification using UVM

## Project Overview

This project demonstrates the application of **Universal Verification Methodology (UVM)** to verify an AXI4-Stream–based packet filter hardware module. It consists of 3 parts:

1. Building and extending a UVM testbench to verify an AXI packet filter
2. Creating a directed debug test for waveform clarity
3. Extending the DUT to add checksum functionality and updating the testbench accordingly

All testbench components were built using UVM best practices and executed using **Questa**, while the final RTL implementation was synthesized in **Vivado** targeting a Xilinx FPGA.

---

## DUT: Packet Filter Module

The DUT is an AXI4-Stream packet filter that processes incoming data packets where each packet begins with a 16-bit header:

| Bits | Field Name    | Description                   |
|------|---------------|-------------------------------|
|15:12 | Message Type  | 4-bit identifier              |
|11:0  | Length        | Payload length in bytes       |

### Filter Logic
- Packets with supported message types `{0x0, 0xA, 0x5, 0x3}` are forwarded
- Others are dropped entirely
- AXI4-Stream protocol: `tvalid`, `tdata`, `tlast`, `tready`

---

## Part 1: UVM Testbench Completion & Coverage

### Goals
- Complete a partially implemented UVM environment
- Connect missing agents, scoreboard, and testbench logic
- Achieve **100% functional and code coverage**

### Key Tasks
- Completed `filter_env.svh` by instantiating and connecting the output agent and scoreboard
- Enhanced `filter_sequence.svh` to constrain `Packet` objects for broader message types and lengths
- Tuned testbench parameters (`NUM_PACKETS`, `MAX_LEN`) in `filter_tb.sv`

### Results
- Verified correctness of DUT with randomized sequences
- Achieved 100% functional and toggle coverage in Questa
- Screenshot and description included in `part1/part1.pdf`

---

## Part 2: Directed Debug Test Creation

### Goals
- Add a deterministic test with simple, predictable patterns
- Improve waveform readability and debug capability

### Key Tasks
- Created a new UVM sequence: `filter_debug_sequence` in `filter_sequence.svh`
  - Each packet increases in length (0, 1, 2, …)
  - Payload filled with fixed value `8'h55` for visual clarity
- Created a new UVM test: `filter_debug_test.svh`
- Updated `filter_tb_pkg.sv` and `Makefile` to integrate new test

### Results
- Visual confirmation in Questa waveform viewer
- Test clearly distinguishes valid payload bytes from padding
- Screenshot included in `part2/part2.pdf`

---

## Part 3: DUT Extension – Checksum Appending

### New DUT Feature
- Compute an **8-bit checksum** using XOR of all bytes in the packet (including the header)
- Append the checksum to the end of the output packet:
  - **Even-length payloads**: Add a new beat with only checksum
  - **Odd-length payloads**: Use remaining byte in final beat

### Challenges Addressed
- Valid byte tracking for AXI4-Stream `tdata[15:0]`
- Ensuring checksum is not calculated on invalid bytes
- Correctly aligning `tlast` and injecting final checksum beat

### Testbench Integration
- Updated DUT logic in `filter.sv`
- Used provided updated `packet.svh` and `filter_scoreboard.svh` from `part3/`
- Reused existing UVM tests to validate correctness

### Results
- Final simulation passed with 100% coverage
- Synthesized successfully in Vivado with no critical warnings
- Screenshots of both included in `part3/part3.pdf`

---

## Extra Credit Opportunities (Optional)

These were explored as design enhancements and are documented in `extra_credit/extra_credit.pdf`:

1. **No Input Backpressure**  
   Modified the DUT to always keep `s_axis_tready == 1`  
   Added assertion to confirm never deasserts

2. **Support for Variable AXI Interface Widths**  
   Extended DUT to work with `AXI_WIDTH = 8, 16, 32, 64`  
   Handled header parsing and packet alignment dynamically

3. **Different Input/Output Interface Widths**  
   Created version where `input` is 8-bit AXI and `output` is 32-bit  
   Required internal data realignment and beat re-packing

---

## Directory Structure



```bash
├── part1
│   ├── all testbench files (.sv and .svh)
|   ├── Makefile
|   ├── sources.txt
│   └── part1.pdf
├── part2
│   ├── all testbench files (.sv and .svh)
|   ├── Makefile
|   ├── sources.txt
│   └── part2.pdf
├── part3
│   ├── all testbench files (.sv and .svh)
|   ├── Makefile
|   ├── sources.txt
│   └── part3.pdf
├── extra_credit
│   ├── all corresponding files (use whatever directories you want)
│   └── extra_credit.pdf
└── README.md

---

## Key Takeaways

- Developed a complete **UVM-based verification environment**
- Extended testbench with **directed** and **constrained-random** sequences
- Implemented a checksum-based AXI4 filter with proper protocol alignment
- Synthesized and validated RTL in Vivado, following **best design practices**
- Explored backpressure-free and width-scalable AXI architectures

---

## Tools Used

- **Questa** (command-line & GUI) for UVM simulation, coverage, and waveform analysis
- **Vivado** for RTL synthesis and warnings/latch checking
- **SystemVerilog** for DUT, testbench, and reference model development
- **Makefile**-based flow for automation and repeatability

---

## License

This repository is a personal project built as part of a graduate-level course on digital verification and design. All code and documents are for educational and demonstration purposes.
```
