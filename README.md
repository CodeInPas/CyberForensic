# CyberForensic: Live Volatility 🔍💻
![Lazarus Supported](https://img.shields.io/badge/Lazarus-Supported-blue.svg)
![FPC Supported](https://img.shields.io/badge/FPC-Supported-yellow.svg)
![BGRABitmap](https://img.shields.io/badge/Dependency-BGRABitmap-brightgreen.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)


**CyberForensic** is a real-time incident response and memory volatility simulator built entirely with Free Pascal and the Lazarus LCL. Step into the shoes of an elite cyber-forensic analyst dropped into a critical security breach. 

<img width="900" height="504" alt="image" src="https://github.com/user-attachments/assets/970d5125-4302-4f3b-9614-03163b1a4f91" />


Your mission is to monitor a live operating system environment, identify deceptive processes, and eradicate actively spreading malware (Root Infectors) before the threat actors successfully exfiltrate sensitive data. 

### ✨ Key Features
*   **Dynamic Process Migration:** Watch as malware actively spawns child processes and spreads across the system in real-time.
*   **Single-Page Dashboard:** A professional, unified interface featuring a Process Tree, live Hex Dump Viewer, and Threat Spectrum chart.
*   **Interactive Forensic Terminal:** Use built-in commands to scan for Indicators of Compromise (IoCs) via YARA rules/Regex, and execute `kill <PID>` commands to neutralize threats.
*   **Active Mitigation & Risks:** Make calculated decisions. Terminating the wrong system process will trigger a fatal Blue Screen of Death (BSOD).
*   **Procedural Anomalies:** Each gameplay session generates unique PID assignments, memory offsets, and malware behaviors for endless replayability.

### 🛠️ Built With
*   [Free Pascal](https://www.freepascal.org/) / [Lazarus IDE](https://www.lazarus-ide.org/)
*   Custom Off-Screen Rendering (BGRA)
