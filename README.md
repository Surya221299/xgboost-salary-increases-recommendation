# Salary Increases Recommendation

Aplikasi desktop macOS berbasis SwiftUI untuk memprediksi rekomendasi persentase kenaikan gaji karyawan secara offline menggunakan model Machine Learning on-device (Core ML).

## Fitur Utama

- **Keyboard-Navigable Table**: Input data interaktif bergaya spreadsheet dengan dukungan navigasi tombol panah, dropdown popup, dan inline editing.
- **Bulk CSV Import & Template**: Fitur unduh template CSV serta import data batch dengan validasi dan normalisasi otomatis.
- **On-Device Core ML Inference**: Prediksi kenaikan gaji dihitung secara lokal tanpa ketergantungan koneksi internet.
- **End-to-End ML Pipeline**: Dokumentasi dan script pelatihan model menggunakan Python (XGBoost, hyperparameter tuning Optuna, dan konversi ke Core ML).

## Tech Stack

| Komponen | Teknologi |
| :--- | :--- |
| **Aplikasi Desktop** | macOS, SwiftUI, Combine, AppKit |
| **Model On-Device** | Apple Core ML (`salary_hike_v2.mlmodel`) |
| **Pipeline ML** | Python 3, XGBoost, Optuna, Scikit-Learn, Coremltools |

## Parameter Input Model

| Parameter | Tipe Data | Keterangan / Nilai |
| :--- | :--- | :--- |
| `Monthly Rupiah` | Numeric | Gaji pokok per bulan (IDR) |
| `Performance` | Categorical | `Low` (1), `Medium` (2), `High` (3), `VeryHigh` (4) |
| `Position Level` | Categorical | `Junior` (1), `Middle` (2), `Senior` (3), `Manager` (4), `Executive` (5) |
| `Years At Company` | Numeric | Masa kerja dalam tahun (0 - 40) |
| `Works Overtime` | Binary | `Yes` (1), `No` (0) |
| **Target Output** | Numeric | Rekomendasi persentase kenaikan gaji (%) |

## Panduan Menjalankan

### Menjalankan Aplikasi macOS
1. Buka project menggunakan Xcode:
   ```bash
   open SalaryIncreasesRecommendation.xcodeproj
   ```
2. Pilih skema target `SalaryIncreasesRecommendation` dengan destination **My Mac**.
3. Jalankan aplikasi dengan menekan `Cmd + R`.

### Melatih Ulang Model ML (Opsional)
1. Install dependensi Python:
   ```bash
   pip install -r requirements.txt
   ```
2. Buka dan jalankan Jupyter Notebook:
   ```bash
   jupyter notebook machine-learning-pipeline/employee-compensation-optimation.ipynb
   ```

## Struktur Direktori

```text
.
├── SalaryIncreasesRecommendation.xcodeproj
├── requirements.txt
├── machine-learning-pipeline/
│   ├── employee-compensation-optimation.ipynb
│   ├── dataset/
│   └── *.json
└── SalaryIncreasesRecommendation/
    ├── Model/
    ├── View/
    ├── ViewModel/
    └── salary_hike_v2.mlmodel
```
