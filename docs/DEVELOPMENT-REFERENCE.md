# Flutter & Dart Development Reference for AI Agents

This document provides a curated reference of essential Flutter/Dart development skills, official documentation, and existing skills/rules that an AI agent can use to assist with Flutter/Dart projects.

---

## 1. Essential Flutter/Dart Development Skills

### Core Development
- **Flutter CLI Operations**
  - Creating new projects with templates (`flutter create`)
  - Running apps on devices/emulators (`flutter run`)
  - Building release APK/AAB/IPA files (`flutter build apk`, `flutter build appbundle`, `flutter build ios`)
  - Executing `flutter analyze` for linting
  - Running `flutter doctor` for environment diagnostics

- **Dart Language Features**
  - Writing null-safe Dart code
  - Implementing `async`/`await` patterns with `Future`s
  - Creating classes with factory constructors
  - Using extension methods effectively
  - Implementing sealed classes with pattern matching

- **Widget Development**
  - Creating custom `StatelessWidget` and `StatefulWidget` classes
  - Implementing `InheritedWidget` for dependency injection
  - Building custom graphics with `CustomPainter`
  - Creating responsive layouts with `LayoutBuilder`
  - Implementing animations with `AnimationController`

### State Management
- **BLoC Pattern** – Generate BLoC classes with events and states, configure `flutter_bloc` with `BlocProvider`, use `Cubit` for simpler management, set up `BlocObserver` for debugging, handle state persistence with `hydrated_bloc`.
- **Provider Pattern** – Configure `ChangeNotifierProvider`, implement `Consumer` and `Selector` widgets, set up `MultiProvider` for multiple states, use `ProxyProvider` for dependent providers.
- **Riverpod** – Configure `ProviderScope` and `ProviderContainer`, implement `StateNotifier` and `StateNotifierProvider`, create `AsyncNotifier` for async operations, use Riverpod code generation.
- **Built-in approaches** – `setState` for widget-specific ephemeral state, `ValueNotifier` and `InheritedNotifier` using only Flutter-provided APIs, `InheritedWidget`/`InheritedModel` for ancestor-child communication.

### Navigation
- **GoRouter** – Declarative routing, deep linking with path parameters, redirect guards for authentication, nested navigation with `ShellRoute`, type‑safe routing with code generation.
- **AutoRoute** – Route configurations, nested routers, route guards, handling path parameters and query strings.

### Code Generation
- **Build Runner** – Configure Freezed for immutable classes, JsonSerializable for JSON parsing, Hive type adapters, Mockito for mocks, and `built_value` for value types.

### Testing
- **Unit tests** – Test single functions, methods, or classes with mocked dependencies.
- **Widget tests** – Test single widgets to verify UI appearance and interaction.
- **Integration tests** – Test complete apps or large parts on real devices/emulators using the `integration_test` package.
- **Golden tests** – Verify UI against reference images.

### Performance Optimization
- Using `const` constructors
- Using `RepaintBoundary` effectively
- Controlling `build()` cost by splitting large widgets
- Using `StringBuffer` for efficient string building
- Using `saveLayer()` sparingly

---

## 2. Official Documentation & Guides

### Flutter Official Docs
- **[Flutter Documentation](https://docs.flutter.dev/)** – Main entry point with widgets, examples, updates, and API docs.
- **[Learn Flutter](https://docs.flutter.dev/learn)** – Recommended starting point with tutorials covering setup, Dart code, app architecture, network data fetching, and best practices.
- **[Architecting Flutter Apps](https://docs.flutter.dev/app-architecture)** – Comprehensive guide on MVVM architecture, state management, dependency injection, and design patterns.
- **[Architecture Recommendations](https://docs.flutter.dev/app-architecture/recommendations)** – Specific best practices including separation of concerns (UI + data layers), repository pattern, MVVM, unidirectional data flow, and Commands for handling user events.
- **[Flutter for React Native Developers](https://docs.flutter.dev/flutter-for/react-native-devs)** – Cookbook-style guide for RN developers transitioning to Flutter.
- **[Developing Packages & Plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages)** – Instructions for writing Dart packages and Flutter plugins.
- **[Using Packages](https://docs.flutter.dev/packages-and-plugins/using-packages)** – How to use shared packages from pub.dev, including Flutter Favorites.

### Dart Official Docs
- **[Dart Overview](https://dart.dev/overview)** – Introduction to Dart as a client-optimized language for multi-platform development.
- **[Introduction to Dart](https://dart.dev/language)** – Brief introduction to Dart programs and important concepts.
- **[Functions](https://dart.dev/language/functions)** – Everything about functions, including treating functions as objects.
- **[Classes](https://dart.dev/language/classes)** – Comprehensive summary of classes, instances, and members with mixin-based inheritance.
- **[Learn Dart](https://dart.dev/learn)** – Learning resources including building an interactive CLI app.
- **[Dart Language Evolution](https://dart.dev/language/evolution)** – Notable changes and additions to the Dart language.

### Specialized Guides
- **[Dive into Dart's Patterns and Records](https://codelabs.developers.google.com/codelabs/dart-patterns-records)** – Google Codelab for using Dart 3's new features.
- **[Tools & Techniques](https://docs.flutter.dev/tools)** – Guides for developing Flutter apps in Android Studio, IntelliJ, and other IDEs.
- **[Flutter Learning Pathway](https://docs.flutter.dev/learn/pathway)** – Step‑by‑step pathway covering environment setup, Dart coding, and building three small Flutter apps.

---

## 3. Existing Skills & AI Rules

### Flutter/Dart Development Skill File
A comprehensive skill already exists at **[babysitter/library/specializations/mobile-development/skills/flutter-dart/SKILL.md](https://github.com/a5c-ai/babysitter/blob/main/library/specializations/mobile-development/skills/flutter-dart/SKILL.md)**. This skill includes:

- **Allowed Tools**: `bash` (Flutter CLI, Dart commands, pub operations), `read` (project files, widgets), `write` (Dart code, Flutter configurations), `edit` (widgets, configurations), `glob` (Dart files, assets), `grep` (pattern searching)
- **Capabilities**: Core development, state management (BLoC, Provider, Riverpod), navigation (GoRouter, AutoRoute), code generation, testing, and performance optimization

### Flutter/Dart Code Review Skill
Another existing skill at **[ECC/skills/flutter-dart-code-review/SKILL.md](https://github.com/affaan-m/ECC/blob/main/skills/flutter-dart-code-review/SKILL.md)** covers widget best practices, state management patterns (BLoC, Signals), Dart idioms, performance, accessibility, security, and clean architecture.

### Official AI Rules Files from Flutter
The Flutter team provides official **AI rules files** for customizing AI behavior:
- **[rules.md](https://raw.githubusercontent.com/flutter/flutter/refs/heads/main/docs/rules/rules.md)** – Comprehensive master rule set
- **[rules_10k.md](https://raw.githubusercontent.com/flutter/flutter/refs/heads/main/docs/rules/rules_10k.md)** – Condensed version (<10k chars)
- **[rules_4k.md](https://raw.githubusercontent.com/flutter/flutter/refs/heads/main/docs/rules/rules_4k.md)** – Highly concise (<4k chars)
- **[rules_1k.md](https://raw.githubusercontent.com/flutter/flutter/refs/heads/main/docs/rules/rules_1k.md)** – Ultra‑compact (<1k chars)

These rules can be adapted for AI coding assistants such as Antigravity (`.agent/rules/`), Claude Code (`CLAUDE.md`), Cursor (`AGENTS.md`), Gemini CLI (`GEMINI.md`), GitHub Copilot (`.github/copilot-instructions.md`), JetBrains AI (`.junie/guidelines.md`), and VS Code (`.instructions.md`).

### Dart Code Quality Lints
- **[dart_code_quality](https://pub.dev/packages/dart_code_quality)** – Provides analyzer rules for style and team consistency.
- **[clean_code_lints](https://pub.dev/packages/clean_code_lints)** – Opinionated lint rules for clean architecture and clean code.

---

## 4. Summary for the Agent

When assisting with Flutter/Dart development, the agent should:

1. **Reference official documentation** for authoritative guidance (Flutter and Dart docs links above).
2. **Leverage existing skill files** (from babysitter and ECC repositories) for common tasks, state management, navigation, code generation, testing, and performance.
3. **Apply the official AI rules** from the Flutter team to align behavior with Flutter best practices.
4. **Use the provided architecture guides** (especially the app‑architecture docs) to design scalable and maintainable applications.
5. **Consult the Dart language docs** for language‑specific features and idioms.
6. **When no direct example exists**, use the linked official guides to create new skills or relevant `.md` files, adapting from the patterns in existing skills and rules.

This reference should be used as a starting point for any Flutter/Dart task, ensuring that the agent's suggestions and code are up‑to‑date, idiomatic, and aligned with official recommendations.