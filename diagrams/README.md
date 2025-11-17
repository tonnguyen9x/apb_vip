# USB VIP Visualization Diagrams

This directory contains comprehensive visualizations of the USB 2.0 Verification IP transaction flow and architecture.

## Files

### 1. `../TRANSACTION_FLOW_VISUALIZATION.md`
The main visualization document containing:
- Transaction hierarchy diagrams
- Layered architecture overview
- Complete transaction flows (TX and RX)
- Component architecture details
- Transfer type flows (Control, Bulk, Interrupt, Isochronous, LPM)
- Sequence diagrams
- Data toggle synchronization
- Frame structure

**View:** Can be read directly in any markdown viewer or GitHub.

### 2. `architecture_diagrams.mmd`
Mermaid diagrams showing:
- Complete system architecture
- Transaction data flow (TX and RX)
- Sequencer interaction
- Protocol layer callback flow
- Transfer execution state machine
- Endpoint configuration structure
- Error handling flow
- Speed negotiation and chirp sequence
- Multi-endpoint transfer management

**View:** Use one of the following methods:
- **Mermaid Live Editor:** https://mermaid.live/ (paste the diagram code)
- **VS Code:** Install "Markdown Preview Mermaid Support" extension
- **GitHub:** Renders automatically in markdown files
- **Command line:** Use `mmdc` (Mermaid CLI) to generate PNG/SVG

### 3. `sequence_diagrams.mmd`
Detailed Mermaid sequence diagrams for:
- Control Transfer: GET_DESCRIPTOR
- Control Transfer: SET_ADDRESS
- Bulk OUT Transfer with PING
- Bulk IN Transfer with NAK retry
- Interrupt IN Transfer (periodic polling)
- Isochronous OUT Transfer (audio streaming)
- Split Transaction (HS Hub + FS Device)
- Error Recovery (Lost ACK scenario)
- Endpoint Stall and Clear Feature
- LPM (Link Power Management) Transaction

**View:** Same methods as architecture_diagrams.mmd

## How to View Mermaid Diagrams

### Option 1: Online (Quickest)
1. Go to https://mermaid.live/
2. Copy the content from `.mmd` files
3. Paste into the editor
4. View rendered diagram
5. Export as PNG/SVG if needed

### Option 2: VS Code
1. Install extension: "Markdown Preview Mermaid Support"
2. Create a markdown file (e.g., `view.md`)
3. Add mermaid code block:
   ````markdown
   ```mermaid
   [paste diagram code here]
   ```
   ````
4. Open preview (Ctrl+Shift+V or Cmd+Shift+V)

### Option 3: Command Line
```bash
# Install Mermaid CLI
npm install -g @mermaid-js/mermaid-cli

# Generate PNG from mermaid file
mmdc -i architecture_diagrams.mmd -o architecture.png

# Generate SVG
mmdc -i architecture_diagrams.mmd -o architecture.svg
```

### Option 4: GitHub
Push files to GitHub and view directly:
- Mermaid diagrams embedded in markdown render automatically
- Both `.mmd` files and inline mermaid blocks are supported

## Diagram Types

### System Architecture
Shows the complete hierarchy from test bench down to physical interface:
- Test Environment → USB Agent → Protocol Stack → Physical Interface → DUT
- All sequencer levels and their interactions
- Layering components (Transfer→Packet→Data conversion)
- Driver and Monitor components

### Transaction Flow
Illustrates how transactions flow through the system:
- **TX Flow:** Application layer transfer → Protocol packets → Link data → Physical signals
- **RX Flow:** Physical signals → Link data → Protocol packets → Application transfer
- Data transformations at each layer

### Sequence Diagrams
Step-by-step interaction for each transfer type:
- Shows timing and order of packets
- Illustrates handshake protocols
- Demonstrates error handling and retries
- Covers all USB 2.0 transfer types

### State Machines
Transfer execution states:
- INITIAL → RUNNING → ACCEPT/RETRY/ABORTED
- Error handling paths
- Retry logic

## Quick Reference

### Transaction Hierarchy (4 Layers)
```
brt_usb_transfer (Application)
    ↓
brt_usb_packet (Protocol)
    ↓
brt_usb_data (Link)
    ↓
Physical Signals (DP/DM or UTMI)
```

### Transfer Types
1. **Control** - Device enumeration and configuration
2. **Bulk IN/OUT** - Large data transfers, no timing guarantee
3. **Interrupt IN/OUT** - Small periodic transfers, guaranteed latency
4. **Isochronous IN/OUT** - Real-time streaming, no error recovery
5. **LPM** - Link Power Management for power saving

### Speed Modes
- **Low Speed (LS):** 1.5 Mbps
- **Full Speed (FS):** 12 Mbps
- **High Speed (HS):** 480 Mbps

### Key Components
- **Virtual Sequencer** - Coordinates all sequencers
- **Transfer Sequencer** - Generates high-level transfers
- **Packet Sequencer** - Decomposes to packets
- **Data Sequencer** - Encodes to physical format
- **Protocol Layer** - Packet routing and callbacks
- **Link Layer** - NRZI encoding and bit-stuffing
- **Physical Layer** - Interface driving

## Integration with Documentation

These visualizations complement the following documentation:
- `usb_vip/verify/RELEASE_DOC.TXT` - Verification environment usage
- `usb_vip/design/RELEASE_DOC.TXT` - Design VIP capabilities

## Extending the Visualizations

To add new diagrams:
1. Follow Mermaid syntax: https://mermaid.js.org/intro/
2. Keep consistent styling with existing diagrams
3. Add description to this README
4. Test rendering before committing

## Supported Mermaid Diagram Types

These files use the following Mermaid diagram types:
- `graph TB/LR` - Flowcharts and architecture diagrams
- `sequenceDiagram` - Sequence/timing diagrams
- `stateDiagram-v2` - State machine diagrams

## Tips for Best Viewing

1. **For presentations:** Export to PNG/SVG at high resolution
2. **For documentation:** Embed in markdown with GitHub rendering
3. **For analysis:** Use interactive Mermaid Live Editor to zoom and pan
4. **For printing:** Export to PDF via browser print from Mermaid Live

## Questions or Issues?

If you need:
- Additional diagram types
- More detailed views of specific components
- Custom visualizations for your use case

Please refer to the source code or contact the VIP maintainers.

---

**Created:** 2025-11-17
**USB VIP Version:** 2.0
**Format:** Mermaid v9.0+
