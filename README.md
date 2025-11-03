# HabitFlow Demo

This quick Flutter build explores a lightweight habit dashboard that demonstrates a few frontend and data-layer fundamentals:

- **Material 3 styling & layout**: custom header, cards, horizontal lists, bottom sheets, and responsive slivers that adapt across desktop and web.
- **Theme toggle**: Settings screen switches between light, dark, and system themes using Material 3 controls.
- **Local persistence**: habits are stored in SQLite (`sqflite` on mobile, `sqflite_common_ffi` on desktop).
- **Stateful interactions**: add, complete, and now remove habits with optimistic UI updates.
- **Feature targeting**: works on Windows, Chrome, and mobile once an appropriate SDK is configured.

> The goal of this project is to showcase working knowledge of Flutter UI composition, async data handling, and platform considerations.

## Running the project

```bash
flutter pub get
flutter test                # runs widget specs, including add/delete flows
flutter run -d windows      # or chrome/android/ios with appropriate toolchains
```

Desktop builds require Visual Studio with the *Desktop development with C++* workload so that the Windows runner can compile native binaries.

## Project structure

```
lib/
 ├─ main.dart                  # app entry + theme + navigation shell
 ├─ models/habit.dart          # immutable habit model & mapping helpers
 └─ data/
    ├─ habit_store.dart        # storage interface for swap-able implementations
    └─ habit_repository.dart   # sqflite-backed repository (mobile/desktop)

test/
 └─ widget_test.dart          # widget tests with FakeHabitStore seeding
```

## Notable implementation details

- **Habit timeline interactions**
  - Tapping a checkbox toggles completion with optimistic updates.
  - Delete icon opens a confirmation dialog and persisently removes the habit.
  - “Curated routines” row opens a bottom sheet that can auto-create a new habit.
- **Appearance controls**
  - Theme selector in the Settings tab flips between light, dark, and system modes.
  - Time-saving defaults keep the UI responsive across window sizes.

- **SQLite on desktop**
  - `sqflite_common_ffi` is initialized in `main()` when the app runs on Windows, macOS, or Linux.
  - The repository relies on the injected `HabitStore` contract, making tests and alternative storage implementations straightforward.

- **Testing strategy**
  - Widget tests seed a fake in-memory store, scroll the UI, trigger modal interactions, and verify snackbars.
  - The deletion flow is covered so regressions around the new feature get caught quickly.

## Ideas for further polish

- Animate list insertions/removals with `AnimatedList` or `AnimatedSwitcher`.
- Extract shared state into `ChangeNotifier` or riverpod for additional architecture demonstrations.
- Add a “Stats” tab to show `FutureBuilder`/`StreamBuilder` usage and basic charting.

If you try the demo and want to chat about improvements or architecture, feel free to open an issue or reach out!
