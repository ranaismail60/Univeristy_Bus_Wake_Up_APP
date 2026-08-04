# 🚌 FAST-NUCES CFD - Offline Bus Wake-Up & P2P Radar App

A 100% free, zero-server-cost offline application designed for university students to receive high-priority wake-up alarms before reaching their bus stop, register locally, and share real-time location with peers on the same bus route using offline Peer-to-Peer (Wi-Fi Direct / Local Hotspot / BLE) mesh networking.

---

## 🛠️ Core Capabilities

1. **Zero Internet & Zero API Cost**:
   - Uses smartphone satellite GPS hardware (which operates without cellular data or SIM card).
   - Preloaded JSON matrix for **FAST-NUCES CFD Bus Routes 01 to 15** with stop coordinates, times, and driver phone numbers.

2. **Haversine Distance Wake-Up Alarm**:
   - Continuously calculates satellite distance to student's chosen stop.
   - Activates a high-volume alarm & vibration when student enters the pre-set radius ($\le 500\text{ meters}$).

3. **Offline Route-Scoped Peer Radar & Bus Detection**:
   - Uses local Wi-Fi Direct & Bluetooth LE broadcasting to share location between students on the **same Route Number**.
   - **Cluster & Speed Algorithm**: If 2+ students on the same route are moving together at speeds $> 15\text{ km/h}$, the app automatically identifies and marks the **"IN BUS"** cluster location for waiting students.

---

## 📱 How Students Use & Download the App (.apk)

### Option A: Testing the Web App Prototype (Instant Browser Test)
Double-click `index.html` inside your browser to test:
- Offline registration (Name, Route 01-15, Target Stop).
- Interactive GPS Haversine distance alarm synthesizer (with loud Web Audio API alert sound).
- Offline P2P Route Peer mesh simulator.

### Option B: Building & Installing the Android `.apk` File

#### Step 1: Build APK (On your computer)
Open terminal in the project folder and run:
```bash
flutter pub get
flutter build apk --release
```
The output APK file will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

#### Step 2: Free Distribution to University Students
Upload `app-release.apk` to:
1. **Google Drive / OneDrive Link**: Share the download link on university WhatsApp groups / Student Portal.
2. **Offline Bluetooth / Nearby Share**: Students on campus can transfer the `.apk` directly to each other without using any internet data!
3. **GitHub Releases**: Host the `.apk` file directly on GitHub under "Releases" for free permanent downloads.

---

## 📊 Embedded Routes Dataset (Routes 01 to 15)

Extracted directly from FAST-NUCES Chiniot-Faisalabad Campus Schedule:
- **Route 01**: Chenab Garden to Campus (Driver: Mr. Waqas `0307-7912548`)
- **Route 02**: Chowki Bazzar to Campus (Driver: Mr. Hanif Shakir `0300-2388900`)
- **Route 03**: Millat Town to Campus (Driver: Mr. Zahid `0333-6565326`)
- **Route 04**: 4 Season to Campus (Driver: Mr. Ateeq `0322-6303059`)
- **Route 05**: Marzi Pura to Campus (Driver: Mr. Khalid `0336-7788662`)
- **Route 06**: Shiffa Hospital to Campus (Driver: Mr. Javaid `0342-8791644`)
- **Route 07**: Manawala to Campus (Driver: Mr. Sadiq `0302-7130536`)
- **Route 08**: Chiniot - Chenab Nagar (Desk: `0312-9103000`)
- **Route 09**: Punjab Housing to Campus (Driver: Mr. Ali `0310-7418089`)
- **Route 10**: Suzuki Showroom to Campus (Driver: Mr. Awais `0344-6832248`)
- **Route 11**: Air Port Chowk to Campus (Driver: Mr. Akhtar `0306-9091701`)
- **Route 12**: Manawala via NTU to Campus (Driver: Mr. Moeen `0309-7348386`)
- **Route 13**: Chiniot City to Campus (Driver: Mr. Zafar `0312-9103000`)
- **Route 14**: Nadeem Cafe to Campus (Driver: Mr. Usman `0300-9669887`)
- **Route 15**: Jamia Chishtia to Campus (Driver: Mr. Hanif Shakir `0300-2388900`)

---

## 🧮 Math: Haversine Geofence Formula

Distance calculation implemented inside the app:
$$\text{Distance} = 2r \cdot \arcsin\left(\sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)}\right)$$
where $r = 6371000\text{ meters}$, $\phi$ is latitude, and $\lambda$ is longitude.
