# Doseday widgets — source

These files become the **DosedayWidgets** widget extension. They live here
until the target exists in Xcode (they are not part of the app target).

- `DosedayWidgets.swift` — the widget bundle: Today's doses (Home + Lock Screen), Mood, Supply
- `Intents.swift` — interactive buttons: tick a dose, log a mood
- `SharedData.swift` — reads/writes the app's data through the App Group `group.com.doseday.ios`
- `DoseFrequency.swift` — copy of the app's schedule type; keep in sync
- `Assets.xcassets` — mood faces and accent colour
