# Vital-Care: An IoHT Multi-Parameter Health Monitoring System

[cite_start]Vital-Care is an integrated, low-cost Internet of Healthcare Things (IoHT) edge solution designed specifically to empower senior citizens with autonomous, at-home health monitoring and proactive medical oversight[cite: 59, 967]. [cite_start]Traditional remote patient tracking tools are often tailored around athletic fitness metrics or require complex, expensive, and intimidating clinical setups[cite: 73, 405]. [cite_start]Vital-Care bridges this gap by offering an affordable ($\text{INR } 4000$ per-unit cost) plug-and-play hardware system engineered around user-centered design paradigms[cite: 360, 365, 456].

[cite_start]By utilizing non-invasive optical and infrared sensor arrays managed by an ESP32-S3 microcontroller, the device continuously monitors primary clinical vitals: **Heart Rate (HR)**, **Blood Oxygen Saturation ($SpO_2$)**, and **Body Temperature**[cite: 60, 428, 612]. [cite_start]Instead of utilizing bulky, heavy internal batteries that require high-maintenance charging routines, the system powers natively via a universal USB Type-C interface directly from a phone, power bank, or laptop[cite: 612]. [cite_start]Vitals are instantly populated locally on a high-contrast OLED display in large, readable fonts and are processed entirely on-device to derive secondary parameters like Heart Rate Variability (HRV) and temperature trends before triggering wireless telemetry loops[cite: 63, 612, 613, 614].

---

## 🛠️ Repository Contents & Core Modules

This codebase serves as the repository for the physical engineering and local automation layers of the Vital-Care platform:

### 1. Device Firmware (`/firmware`)
[cite_start]A production-ready C++ embedded implementation built on the Arduino core and ESP-IDF abstraction layers[cite: 742]. It implements an execution timeline that handles tasks concurrently:
* [cite_start]**Sensor Orchestration:** Coordinates data streaming across a shared Fast-Mode ($400\text{ kHz}$) $\text{I}^2\text{C}$ bus structure connecting the MAX30102 and MLX90614 modules[cite: 612, 1063].
* **Digital Signal Processing (DSP):** Filters ambient lighting anomalies and high-frequency noise profiles using a local low-pass exponential moving average filter cascade[cite: 650, 871, 872].
* [cite_start]**Edge Analytics Engine:** Leverages the microcontroller's processing cores to analyze peak-to-peak morphology and parse normal-to-normal (NN) beat intervals for real-time HRV data mining without cloud dependency[cite: 614, 631, 902].
* [cite_start]**Telemetry Protocols:** Hosts a dual wireless communication engine capable of local data broadcast via JSON over WebSockets or structural notifications via custom BLE GATT services[cite: 613, 916, 1214, 1296].

### 2. Hardware Enclosure Engineering (`/hardware_casing`)
[cite_start]Contains precise dimensional 3D printing blueprints, structural CAD assemblies (`.step`/`.stl`), and production drawings generated inside Autodesk Fusion 360[cite: 809]:
* **Form Factor Optimization:** Combines all components (microcontroller, sensor boards, and OLED screen) into a compact $60\times40\text{ mm}$ ergonomic enclosure[cite: 612].
* [cite_start]**Optical Alignment Matrix:** Features an isolated, form-fitting finger cradle optimized for consistent tissue-to-sensor pressure to minimize active photoplethysmography (PPG) motion artifacts[cite: 281, 653].
* [cite_start]**Thermal Field of View (FOV) Shroud:** Integrates a physical column barrier conforming precisely to the MLX90614 sensor's $90^\circ$ field-of-view viewing angle, guaranteeing hygienic, contactless temperature metrics within an optimal distance[cite: 686, 705, 706].

---

## 📈 Mathematics, Digital Filtering, & Sensing Logic

To maintain diagnostic integrity, the firmware applies continuous digital signal processing logic directly to the raw sensor data streams:

### 1. Digital Low-Pass Noise Filtering
[cite_start]Pulsatile blood flow changes dynamically alter the light absorption patterns captured by the MAX30102 photodiodes[cite: 649, 865, 866]. High-frequency noise is minimized using a local low-pass filtering algorithm applied directly to the Infrared ($\text{IR}$) and Red optical channels:

$$\text{ave}_{IR} = f_{rate} \cdot \text{ave}_{IR} + (1 - f_{rate}) \cdot \text{IR}_{sample}$$

$$\text{ave}_{Red} = f_{rate} \cdot \text{ave}_{Red} + (1 - f_{rate}) \cdot \text{Red}_{sample}$$

[cite_start]*(where the dynamic smoothing factor is controlled inside the runtime loop via $f_{rate} \approx 0.95$)*[cite: 876].

### 2. Oxygen Saturation ($SpO_2$) Extraction
[cite_start]The empirical calculation of oxygenated vs. deoxygenated hemoglobin levels requires isolation of the alternating current ($\text{AC}$) pulsatile variations away from the static, non-pulsatile background tissue absorption ($\text{DC}$)[cite: 655, 866, 890]. [cite_start]The root-mean-square ($\text{RMS}$) totals are evaluated over a moving window ($Num = 30$ samples) to determine the absolute optical absorption ratio ($R$)[cite: 890, 891, 892]:

$$R = \frac{\sqrt{\sum(AC_{IR})^2} / \text{ave}_{IR}}{\sqrt{\sum(AC_{Red})^2} / \text{ave}_{Red}}$$

This dynamic ratio maps directly to absolute blood oxygen levels using a linear calibration regression curve optimized for local node rendering:

$$SpO_2 = -23.3 \cdot (R - 0.4) + 120$$

---

## 📱 Full System Integration Architecture (Roadmap)

[cite_start]While this specific workspace acts as the master directory for the physical edge nodes and local firmware algorithms, Vital-Care is designed to work within a highly scalable, multi-tier telemetry infrastructure[cite: 620]:

### Tier A: Native Mobile Application (Android Studio UI)
* **Development Framework:** Built natively using Android Studio to minimize running resource allocation and ensure background service stability on budget target consumer hardware[cite: 617].
* **Low-Energy BLE Parsing:** Integrates a custom GATT configuration profile (`SERVICE_UUID: 6E400001-...`) that binds to local device descriptors[cite: 1219, 1220]. It converts raw notification packets straight into interactive visual vitals histories[cite: 932, 1279, 1281].
* **Elderly-Centric Accessibility:** Specifically customized with bold card-based UI metrics, color-coded threshold layouts, and integrated user-friendly configurations designed to eliminate software friction for senior citizen users[cite: 62, 299, 923].

### Tier B: Multi-User Cloud Synchronization (Firebase Infrastructure)
* **Asynchronous Serialization:** Local gateway endpoints serialize real-time parameter changes into lightweight, structured asynchronous JSON payloads[cite: 1317, 1324].
* **Firebase Realtime Database Prototyping:** Routes incoming telemetry streams directly into cloud document structures, providing instant synchronization across distant network segments without complex socket management workflows.
* **Remote Clinician Oversight:** Establishes an accessible, authenticated telemetry dataset layer, allowing medical providers and family caregivers to safely observe historical health trends anywhere in the world[cite: 61, 79, 449].

---

## 👥 Authors & Acknowledgments
* **Guruprakash A** (Mechatronics Engineering, Thiagarajar College of Engineering) [cite: 3, 9]
* **Manibalagan S** (Mechatronics Engineering, Thiagarajar College of Engineering) [cite: 4, 9]
* **Project Guide:** Mr. S. Parthasarthi (Assistant Professor, Department of Mechatronics Engineering) [cite: 7, 9]

*Special thanks to the engineering faculties of the Mechatronics Engineering Department at Thiagarajar College of Engineering (Madurai) for providing necessary hardware facilities and testing infrastructure[cite: 43, 44].*

---

## 📄 License
This project is released under the MIT License. Feel free to use, modify, and distribute the firmware and hardware components for educational or research purposes.
