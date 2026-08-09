# Product Requirements Document (PRD): Offline Dive Logbook

**Project Name:** DiveLogger  
**Version:** 1.1 (Updated based on stakeholder feedback)  
**Status:** Approved for Development  
**Target Platform:** iOS & Android (Flutter)  
**Core Mandate:** Offline-first, photo-driven dive logging without requiring cloud accounts.

---

## 1. Executive Summary
DiveLogger is a mobile application designed to streamline dive logging for recreational scuba divers. Unlike existing solutions (e.g., Subsurface—which is powerful but desktop/technical-heavy, and PADI—which is clean but requires constant internet and an account), DiveLogger combines **Subsurface's robust local data handling** with **PADI's intuitive UI**. 

Unique differentiators include:
- **Zero connectivity required** (no login, no cloud sync).
- **Automatic log creation** by analyzing photo gallery EXIF metadata.
- **Integrated Marine Life ID** for underwater naturalists.
- **One-tap social export** for Instagram posts.

> **Note:** Bluetooth/USB dive computer integration has been officially **scoped out** of this MVP and will not be considered for the initial build.

---

## 2. Objectives
1.  Provide a fast, offline CRUD (Create, Read, Update, Delete) interface for dive logs.
2.  Automatically calculate critical metrics like SAC (Surface Air Consumption) rate.
3.  Reduce manual entry time by leveraging smartphone photo libraries.
4.  Enhance the dive experience with marine life cataloging and social sharing.

---

## 3. Scope

### 3.1 In-Scope (MVP)
- Local SQLite database for all data persistence.
- Dive log entry form with technical metrics (including gas, salinity, tank size, and altitude).
- SAC rate calculation engine.
- Full device gallery scanning to group photos into dive events.
- Per-dive marine life sighting list (Name + Local Photo attached from the dive's photos).
- Share sheet generation to push an image card to Instagram.
- Digital Certification Library (organized by Scuba Org, with photo storage).
- Master Equipment List (managed inventory of user's gear) with per-dive gear selection.

### 3.2 Out-of-Scope (Explicitly Excluded)
- Cloud backup, sync, or account creation.
- Reading data via Bluetooth/Wi-Fi/USB from physical dive computers.
- Social network feeds or commenting.
- Web dashboard or desktop companion app.

---

## 4. User Personas
- **The Photo Enthusiast**: Takes 50+ photos per dive. Wants to log *which* dive the photos belong to without typing the date/time manually.
- **The Air-Conscious Diver**: Strictly tracks tank pressure to optimize breathing efficiency.
- **The Marine Biologist/Spotter**: Cares about cataloging specific fish/coral species per location.
- **The Social Diver**: Wants to flex their latest deep dive or whale sighting on Instagram immediately after surfacing.
- **The Gear Geek**: Owns multiple wetsuits/BCD setups and needs to track exactly which configuration was used for buoyancy calculations.

---

## 5. Functional Requirements

### 5.1 Core Dive Logbook (Baseline)
The app must maintain a list of `DiveLog` entities with the following fields (all locally stored):

**Basic / Temporal**:
- **Date & Time** (Start of dive).
- **Location** (Free text, e.g., "Great Barrier Reef, QLD").
- **Altitude** (e.g., "Sea Level", "Lake at 2000m" - free text or numeric).

**Depth & Duration**:
- **Max Depth** (meters).
- **Average Depth** (meters).
- **Duration** (minutes).

**Tank & Gas**:
- **Gas Type** (Dropdown: Air, Nitrox, Other). If "Other", allow free text.
- **Tank Size** (e.g., "12L", "80 cu ft" - free text to support metric/imperial).
- **Start Tank Pressure** (Bar).
- **End Tank Pressure** (Bar).

**Environmental**:
- **Water Temperature** (Celcius).
- **Salinity** (Dropdown: Fresh Water, Ocean, Other).
- **Visibility** (meters - optional).

**Gear & Selection**:
- **Gear Used**: Multi-select from the Master Equipment List (see 5.6). *Why: Different wetsuit thicknesses or BCD sizes affect buoyancy and trim, so tracking which specific gear was worn is critical.*

**Personal**:
- **Weight Used** (kilograms).
- **Personal Notes** (Free text).

**UI Requirements**:
- List view sorted by most recent dive date.
- Detail view showing all fields clearly. Primary stats (Depth, Duration, SAC) should be prominent; secondary stats (Tank size, Salinity, Altitude) can be in an expandable section to keep the UI clean.

### 5.2 SAC Rate Calculation (Critical)
- The app **must** automatically compute and display the SAC rate for every saved dive (computed dynamically, never stored).
- **Surface pressure rate**: `P_rate = (Start_Pressure - End_Pressure) / (Duration_min × ((Avg_Depth_m / 10) + 1))` → bar/min at surface.
- **Tank volume**: parsed from the Tank Size field — `"12L"` → 12 L; `"80 cu ft"` → `80 × 28.3168 / 207 ≈ 10.9 L` (assumes 3000 psi / 207 bar service pressure). Missing/unparseable → tank volume unknown.
- **SAC (industry-standard RMV)**: `SAC = P_rate × Tank_Volume_L` → **L/min at surface**.
- *Units*: Primary display **L/min** (metric). Expanded details also show **bar/min**, plus imperial conversions (**psi/min**, **cu ft/min** = L/min × 0.0353147).
- If tank volume is unknown, fall back to displaying the pressure rate (bar/min) only.
- Guard rails: if `Duration_min ≤ 0` or `End_Pressure ≥ Start_Pressure`, no SAC is displayed.
- Display prominently on the dive detail screen.

### 5.3 Auto-Log Creation from Photos (The "Killer" Feature)
The app must provide a "Scan Gallery" button.

1.  **Access**: Request system gallery permissions (handling iOS Privacy/PHPhotoLibrary restrictions).
2.  **EXIF Parsing**: Read `DateTimeOriginal` and `DateTimeDigitized` EXIF tags from images/videos.
3.  **Grouping Algorithm (Stakeholder Decision)**:
    - **Max time between photos within a single dive**: Cap at **90 minutes**.
    - **Min time between separate dives**: **60 minutes**.
    - *Logic*: The first photo in a selection is automatically tagged as the first picture of a dive. The system looks for the *last* photo of the dive based on the 90-minute cap. If the gap between the last photo and the next photo exceeds 60 minutes, a new dive cluster starts.
4.  **Draft Creation**: For each cluster, automatically generate a draft `DiveLog` where:
    - `Start_Time` = Timestamp of the first photo in the cluster.
    - `End_Time` = Timestamp of the last photo in the cluster.
    - Attach all grouped photos to the draft.
5.  **User Flow**: Present drafts to the user so they can fill in missing details (Depth, Pressure, etc.) before saving permanently.

### 5.4 Marine Life ID Section
Each `DiveLog` must have a sub-section to manage a list of sighted marine life.

- **Data Structure**: Each sighting consists of `Common Name` (Text) and an `Image` (Local File Path).
- **Photo Source**: The user selects photos **from the dive's already attached photos** (i.e., you cannot pick a brand new photo from the gallery just for marine life; it must be one of the dive photos). This keeps photo storage contained and prevents gallery overload.
- **CRUD**: Users can add, edit, or delete sightings within a specific dive.
- **Visuals**: Display thumbnails of the marine life photos within the dive detail view.

### 5.5 Export to Instagram (Social Sharing)
The app must generate an Instagram-ready post from a dive log.

- **Content**: A generated **Image Card** (PNG/JPEG) containing:
  - Dive Site Name, Date, and Duration.
  - Max Depth & SAC Rate (key stats).
  - A mini-grid of up to 4 attached photos from the dive.
  - List of Marine Life spotted (text only, max 5 items).
- **Action**: Trigger the native share sheet (`share_plus`) to allow the user to post to Instagram Stories/Feed (saving to camera roll fallback).

---

### 5.6 Extra Utilities (PADI-Inspired)
#### A. Digital Certification Library
- A separate tab/list to store certifications.
- **Fields**: 
  - Scuba Organization (e.g., PADI, SSI, BSAC - dropdown or free text).
  - Level (e.g., Open Water, Advanced, Rescue).
  - Issue Date (optional, as certs generally don't expire).
  - Photo of physical card / screenshot of digital card.
- **View**: Organized primarily by Scuba Org for easy browsing.
- **Note**: No expiry reminders are required for MVP; just passive storage.

#### B. Master Equipment List (Replaces generic checklist)
This is a **managed inventory** of the exact gear the user owns.

- **CRUD**: Users can add, edit, or delete equipment items.
- **Fields per item**: 
  - Name (e.g., "Aqualung Core BCD").
  - Type/Notes (e.g., "7mm Wetsuit", "HP Steel 100").
- **Per-Dive Selection**:
  - On the dive log form (Section 5.1), the user must be able to select **which items** from their master list were used on that specific dive.
  - *Why it matters*: The exact wetsuit thickness or BCD size used affects buoyancy and weighting. Storing this per dive allows the user to look back and see what configuration worked best.

---

## 6. Non-Functional Requirements (NFRs)

1.  **Offline-First**: The app must function 100% without an internet connection. All assets, logic, and databases must be local.
2.  **Performance**: Scanning a gallery of 1,000 photos must complete in under 3 seconds on a mid-range device.
3.  **Storage**: Photos attached to dives should be copied into the app's private directory to prevent accidental deletion from the system gallery.
4.  **Platform**: Must run on Android (minimum API 23) and iOS (minimum 14).
5.  **UX/UI**: Mimic the clean, card-based, high-contrast UI found in the PADI app. Primary units: **Metric**. Imperial conversions displayed only within the expanded details screen (to avoid clutter).

---

## 7. Technical Stack Recommendations
- **Framework**: Flutter (Dart).
- **State Management**: Riverpod or Bloc (simple provider is sufficient for MVP).
- **Local Database**: `sqflite` (SQLite) with a join table for `DiveLog_Gear` (many-to-many) to handle gear selection.
- **Gallery/EXIF**: `photo_manager` + `exif` (or `image_picker` combined with `exif`).
- **File Management**: `path_provider` for local storage.
- **Sharing**: `share_plus`.
- **Image Generation**: `dart_image` or `screenshot` + `image_gallery_saver`.

---

## 8. Resolved Decisions & Clarifications (Stakeholder Approved)
> *The following items were previously open questions and have been finalized by the stakeholder.*

1.  **Photo Grouping Threshold**:
    - **Max time between photos within a single dive**: 90 minutes.
    - **Min time between separate dives**: 60 minutes.
    - Logic: First photo starts a dive; scan forward to find the last photo within 90 mins; if next photo gap > 60 mins, start new dive.
2.  **SAC Rate Units** (formula corrected to industry-standard RMV, see 5.2):
    - **Primary**: Metric — **L/min at surface**.
    - **Imperial (cu ft/min, plus psi/min)**: Visible only in the **expanded details** section of the dive view.
3.  **Marine Life Photo Source**:
    - Users select photos **from the dive's existing attached photos**, not from the general gallery.
4.  **Instagram Export Format**:
    - **Image Card** (PNG/JPEG). Not plain text.
5.  **Certification Expiry & Org**:
    - Certifications do not have expiry notifications; they are stored passively.
    - Must include a photo field for the cert card.
    - Certifications must be **organized by Scuba Org** (e.g., PADI, SSI, BSAC) in the UI.
6.  **Gear Checklist Scope**:
    - It is a **Master Inventory List** of all gear the user owns.
    - Selection is **per-dive**: the user picks exactly which items from the master list were used on that specific dive.

---

## 9. Success Metrics (How to "Win")
- **Time-to-Log**: Reduce average manual input time from 5 minutes to 1 minute using the Photo Scan feature.
- **Zero Crash Rate**: No crashes during gallery scanning or heavy file I/O.
- **User Retention**: User feels compelled to log the dive immediately after surfacing due to the ease of the process.
- **Gear Accuracy**: User can reliably look back at previous dives to see which wetsuit/BCD setup they used for specific conditions.