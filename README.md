
# UVM Packet Filter Verification

## Objective

The objective of this project is to implement a **Universal Verification Methodology (UVM)** testbench to verify an AXI4-Stream packet filter design. The project is divided into three parts:

1. Completing the UVM testbench and achieving 100% coverage
2. Creating a directed test for waveform clarity
3. Extending the DUT to include checksum logic and adapting the testbench accordingly

All verification tasks were completed using **Questa**, and RTL synthesis was performed in **Vivado** targeting a Xilinx FPGA device.

---

## DUT: AXI4-Stream Packet Filter

The DUT is a packet filter that receives AXI4-Stream input packets. Each packet begins with a 16-bit header:

| Bits  | Field Name   | Description             |
| ----- | ------------ | ----------------------- |
| 15:12 | Message Type | 4-bit identifier        |
| 11:0  | Length       | Payload length in bytes |

### Filtering Behavior

* Forwards packets with message types: `0x0`, `0xA`, `0x5`, `0x3`
* Drops packets with all other message types
* Operates on standard AXI4-Stream signals: `tvalid`, `tdata`, `tready`, and `tlast`

---

## Part 1: UVM Testbench Completion & Coverage

### Goals

* Finalize a partially implemented UVM environment
* Instantiate and connect missing components
* Achieve 100% functional and code coverage

### Implementation Highlights

* Completed `filter_env.svh` by instantiating the output agent and scoreboard
* Enhanced `filter_sequence.svh` to generate diverse `Packet` types with varying lengths
* Adjusted test parameters (`NUM_PACKETS`, `MAX_LEN`) in `filter_tb.sv` for broad coverage

### Results

* Functional correctness verified through randomized testing
* Achieved 100% toggle and functional coverage using Questa
* Results documented in `part1/part1.pdf`

---

## Part 2: Directed Debug Test

### Goals

* Create a deterministic test for waveform clarity
* Improve debug visibility in simulation

### Implementation Highlights

* Implemented `filter_debug_sequence`:

  * Packet lengths increment from 0, 1, 2, ...
  * All payload bytes set to `8'h55` for easy visual recognition
* Added a new UVM test: `filter_debug_test.svh`
* Integrated test into `filter_tb_pkg.sv` and `Makefile`

### Results

* Waveform clearly shows structure of valid payloads and padding
* Easy visual confirmation of packet forwarding behavior
* Included in `part2/part2.pdf`

---

## Part 3: DUT Extension – Checksum Functionality

### New Feature

* Appends an **8-bit checksum** to each valid output packet
* Checksum is computed as XOR of all bytes in the packet, including header

### Edge Case Handling

* Even payload length → checksum sent in an extra beat
* Odd payload length → checksum fits within the final beat

### Implementation Highlights

* Updated DUT logic in `filter.sv`
* Integrated new `packet.svh` and `filter_scoreboard.svh` from `part3/`
* Reused UVM tests to validate checksum functionality

### Results

* Simulation passed with 100% coverage
* DUT synthesized successfully in Vivado with no critical warnings
* Documentation provided in `part3/part3.pdf`

---

## Extra Credit Features (Optional)

Additional enhancements implemented and documented in `extra_credit/extra_credit.pdf`:

1. **No Input Backpressure**

   * Modified DUT to keep `s_axis_tready` asserted at all times
   * Added assertion to verify constant readiness

2. **Variable AXI Interface Widths**

   * Extended DUT to support `AXI_WIDTH = 8, 16, 32, 64`
   * Adjusted logic to handle variable-width header parsing and payload alignment

3. **Asymmetric Interface Widths**

   * Implemented version with 8-bit input AXI and 32-bit output AXI
   * Realigned and packed data internally across interface widths

---

## Directory Structure

```bash
├── part1
│   ├── [testbench files]
│   ├── Makefile
│   ├── sources.txt
│   └── part1.pdf
├── part2
│   ├── [testbench files]
│   ├── Makefile
│   ├── sources.txt
│   └── part2.pdf
├── part3
│   ├── [testbench files]
│   ├── Makefile
│   ├── sources.txt
│   └── part3.pdf
├── extra_credit
│   ├── [optional files]
│   └── extra_credit.pdf
└── README.md
```

---

## Summary & Key Takeaways

* Completed a modular, reusable **UVM testbench** for AXI4-Stream interfaces
* Used both **directed** and **constrained-random** sequences for thorough validation
* Extended the RTL to include checksum logic while maintaining AXI protocol compliance
* Explored additional AXI configurations for improved robustness
* Verified simulation correctness and successful Vivado synthesis

---

## Tools Used

* **Questa**: UVM simulation, waveform analysis, and coverage
* **Vivado**: RTL synthesis and timing/resource evaluation
* **SystemVerilog**: DUT and testbench development
* **Makefiles**: Automation of build, simulation, and regression flows

---

## License

This project was developed as part of a graduate-level digital design and verification course. All source files and documents are for educational use only.

---
