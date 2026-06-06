# Vital-Care: An IoHT Multi-Parameter Health Monitoring System

Vital-Care is an integrated, low-cost Internet of Healthcare Things (IoHT) edge solution designed specifically to empower senior citizens with autonomous, at-home health monitoring and proactive medical oversight. Traditional remote patient tracking tools are often tailored around athletic fitness metrics or require complex, expensive, and intimidating clinical setups. Vital-Care bridges this gap by offering an affordable ($\text{INR } 4000$ per-unit cost) plug-and-play hardware system engineered around user-centered design paradigms.

By utilizing non-invasive optical and infrared sensor arrays managed by an ESP32-S3 microcontroller, the device continuously monitors primary clinical vitals: **Heart Rate (HR)**, **Blood Oxygen Saturation ($SpO_2$)**, and **Body Temperature**. Instead of utilizing bulky, heavy internal batteries that require high-maintenance charging routines, the system powers natively via a universal USB Type-C interface directly from a phone, power bank, or laptop. Vitals are instantly populated locally on a high-contrast OLED display in large, readable fonts and are processed entirely on-device to derive secondary parameters like Heart Rate Variability (HRV) and temperature trends before triggering wireless telemetry loops.

---

## 🛠️ Repository Contents & Core Modules

This codebase serves as the repository for the physical engineering and local automation layers of the Vital-Care platform:

### 1. Device Firmware (`/firmware`)
A production-ready C++ embedded implementation built on the Arduino core and ESP-IDF abstraction layers. It implements an execution timeline that handles tasks concurrently:
* **Sensor Orchestration:** Coordinates data streaming across a shared Fast-Mode ($400\text{ kHz}$) $\text{I}^2\text{C}$ bus structure connecting the MAX30102 and MLX90614 modules.
* **Digital Signal Processing (DSP):** Filters ambient lighting anomalies and high-frequency noise profiles using a local low-pass exponential moving average filter cascade.
* **Edge Analytics Engine:** Leverages the microcontroller's processing cores to analyze peak-to-peak morphology and parse normal-to-normal (NN) beat intervals for real-time HRV data mining without cloud dependency.
* **Telemetry Protocols:** Hosts a dual wireless communication engine capable of local data broadcast via JSON over WebSockets or structural notifications via custom BLE GATT services.


### 2. Hardware Enclosure Engineering (`/hardware_casing`)
Contains precise dimensional 3D printing blueprints, structural CAD assemblies (`.step`/`.stl`), and production drawings generated inside Autodesk Fusion 360:
* **Form Factor Optimization:** Combines all components (microcontroller, sensor boards, and OLED screen) into a compact $60\times40\text{ mm}$ ergonomic enclosure.
* **Optical Alignment Matrix:** Features an isolated, form-fitting finger cradle optimized for consistent tissue-to-sensor pressure to minimize active photoplethysmography (PPG) motion artifacts.
* **Thermal Field of View (FOV) Shroud:** Integrates a physical column barrier conforming precisely to the MLX90614 sensor's $90^\circ$ field-of-view viewing angle, guaranteeing hygienic, contactless temperature metrics within an optimal distance.

---

## 📈 Mathematics, Digital Filtering, & Sensing Logic

To maintain diagnostic integrity, the firmware applies continuous digital signal processing logic directly to the raw sensor data streams:

### 1. Digital Low-Pass Noise Filtering
Pulsatile blood flow changes dynamically alter the light absorption patterns captured by the MAX30102 photodiodes. High-frequency noise is minimized using a local low-pass filtering algorithm applied directly to the Infrared ($\text{IR}$) and Red optical channels:

$$\text{ave}_{IR} = f_{rate} \cdot \text{ave}_{IR} + (1 - f_{rate}) \cdot \text{IR}_{sample}$$

$$\text{ave}_{Red} = f_{rate} \cdot \text{ave}_{Red} + (1 - f_{rate}) \cdot \text{Red}_{sample}$$

*(where the dynamic smoothing factor is controlled inside the runtime loop via $f_{rate} \approx 0.95$)*.

### 2. Oxygen Saturation ($SpO_2$) Extraction
The empirical calculation of oxygenated vs. deoxygenated hemoglobin levels requires isolation of the alternating current ($\text{AC}$) pulsatile variations away from the static, non-pulsatile background tissue absorption ($\text{DC}$). The root-mean-square ($\text{RMS}$) totals are evaluated over a moving window ($Num = 30$ samples) to determine the absolute optical absorption ratio ($R$):

$$R = \frac{\sqrt{\sum(AC_{IR})^2} / \text{ave}_{IR}}{\sqrt{\sum(AC_{Red})^2} / \text{ave}_{Red}}$$

This dynamic ratio maps directly to absolute blood oxygen levels using a linear calibration regression curve optimized for local node rendering:

$$SpO_2 = -23.3 \cdot (R - 0.4) + 120$$

---

## 📱 Full System Integration Architecture (Roadmap)

While this specific workspace acts as the master directory for the physical edge nodes and local firmware algorithms, Vital-Care is designed to work within a highly scalable, multi-tier telemetry infrastructure:

### Tier A: Native Mobile Application (Android Studio UI)
* **Development Framework:** Built natively using Android Studio to minimize running resource allocation and ensure background service stability on budget target consumer hardware.
* **Low-Energy BLE Parsing:** Integrates a custom GATT configuration profile (`SERVICE_UUID: 6E400001-...`) that binds to local device descriptors. It converts raw notification packets straight into interactive visual vitals histories.
* **Elderly-Centric Accessibility:** Specifically customized with bold card-based UI metrics, color-coded threshold layouts, and integrated user-friendly configurations designed to eliminate software friction for senior citizen users.

### Tier B: Multi-User Cloud Synchronization (Firebase Infrastructure)
* **Asynchronous Serialization:** Local gateway endpoints serialize real-time parameter changes into lightweight, structured asynchronous JSON payloads.
* **Firebase Realtime Database Prototyping:** Routes incoming telemetry streams directly into cloud document structures, providing instant synchronization across distant network segments without complex socket management workflows.
* **Remote Clinician Oversight:** Establishes an accessible, authenticated telemetry dataset layer, allowing medical providers and family caregivers to safely observe historical health trends anywhere in the world.

---

## 👥 Authors & Acknowledgments
* **Guruprakash A** (Mechatronics Engineering, Thiagarajar College of Engineering)
* **Manibalagan S** (Mechatronics Engineering, Thiagarajar College of Engineering)
* **Project Guide:** Mr. S. Parthasarthi (Assistant Professor, Department of Mechatronics Engineering)

*Special thanks to the engineering faculties of the Mechatronics Engineering Department at Thiagarajar College of Engineering (Madurai) for providing necessary hardware facilities and testing infrastructure.*

---

## 📄 License
This project is released under the MIT License. Feel free to use, modify, and distribute the firmware and hardware components for educational or research purposes.
