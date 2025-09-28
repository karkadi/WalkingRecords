# 🚶‍♂️ WalkingRecords

A personal walking & running tracker built with SwiftUI, featuring route tracking, statistics, and modern iOS technologies.

## 📸 Screenshots

<div align="center">
  <img src="./ScreenShoots/demo.gif" width="30%" />
  <img src="./ScreenShoots/dark.png" width="30%" />
  <img src="./ScreenShoots/light.png" width="30%" />
</div>

## ✨ Features

🚶‍♀️ Record walking, running, or cycling routes.

🗺 Display path on the map (MapKit).

📊 Calculate distance, average speed, and duration.

💾 Store workouts using SQLite or SwiftData.

📂 Export and import workouts as GPX files.

🎞 Smooth Metal-based walking animation during tracking.

🧪 Demo mode in Debug using an included Location.gpx.

🌗 Light and Dark mode.

## 🛠 Tech Stack

Swift 5.0+

SwiftUI (UI, animations, widgets)

The Composable Architecture (TCA) (modularity, testability)

Swift Concurrency (async/await)

MapKit (maps, routes)

Unit Tests

## 🏗 Project Structure
```bash
WalkingRecords/
 Sources/
 ├── App/
 ├── Core/
 │    ├── Models/        # Workout, RoutePoint, Stats
 │    ├── Services/      # LocationService, DataStore
 │    └── Utils/         # Helpers, Extensions
 │
 ├── Features/
 │    ├── Home/          # Start/stop workout, map
 │    └── Settings/      # Theme, preferences
 │
 ├── SharedUI/
 │    └── Components/    # Buttons, cards, charts
 │
 ├── Resources/
 │    ├── Assets.xcassets
 │    └── Location.gpx   # For demo mode in Debug
 │
 └── Tests/
      ├── UnitTests/
      └── UITests/
```
## 🚀 Installation

Clone the repository
```bash
git clone https://github.com/karkadi/WalkingRecords.git
cd WalkingRecords
```
Open in Xcode 16+.

Enable required Capabilities:

Background Modes → Location updates

## 📋 Roadmap

 HealthKit integration (steps, calories, heart rate).

 iCloud sync for workouts.

 Advanced charts with Swift Charts.

 Snapshot tests for UI consistency.

 GitHub Actions CI/CD pipeline.

 Apple Watch companion app.

 Achievements and gamification.

## 🤝 Contribution

Pull requests are welcome! For major changes, please open an issue first to discuss what you’d like to change.

## 📄 License

This project is licensed under the MIT License.
See [LICENSE](LICENSE) for details.
