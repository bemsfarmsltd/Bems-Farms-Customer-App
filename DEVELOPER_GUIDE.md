# BeemFarms Developer Guide

This document provides a comprehensive overview of the BeemFarms Flutter application. It serves as a guide for any developer who needs to understand the project's architecture, maintain the codebase, or add new features. 

**Note: This document should be updated as the project evolves.**

---

## 1. Project Overview

**BeemFarms** is an e-commerce mobile application for farm produce and agricultural products. It enables users to browse fresh products, deals, and recipes, add items to their cart, and complete orders through a secure checkout process. 

**Technology Stack:**
- **Framework:** Flutter (Dart)
- **State Management:** Riverpod (`flutter_riverpod`)
- **Networking:** HTTP (`http`) targeting a REST API hosted at `https://bemsfarms-api.onrender.com/api`
- **Local Storage:** `flutter_secure_storage` (for JWTs) and `shared_preferences` (for app settings/onboarding state).
- **Design System:** Material Design with customized `AppTheme`.

---

## 2. Project Structure & Architecture

The app uses a **Feature-Driven Architecture** (sometimes referred to as Clean Architecture by feature). This means that all code related to a specific feature (like authentication or cart) is encapsulated in its own folder.

```text
lib/
├── core/             # App-wide constants, theming, and routing logic
├── features/         # Individual app features (Auth, Cart, Home, etc.)
├── shared/           # Reusable UI widgets and common models
└── main.dart         # App entry point & initialization
```

### 2.1 `core/`
Contains the structural configurations of the app:
- **`theme/`**: Configures the Material UI theme, standard colors, and font styles.
- **`constants/`**: Holds string literals, API base URLs, or global keys.
- **`routing/`**: Manages screen navigation (if centralized).

### 2.2 `features/`
This is where the business logic and user interface live. The project is split into the following features:
- **`auth/`**: Login, registration, token storage, and the splash screen.
- **`cart/`**: Managing the user's shopping cart state.
- **`checkout/`**: Processing cart items into an order, entering shipping details.
- **`home/`**: The main dashboard the user sees after logging in.
- **`onboarding/`**: Welcome screens for first-time users.
- **`orders/`**: Viewing past and current orders.
- **`product/`**: Fetching and displaying individual products.
- **`profile/`**: Managing user details and settings.
- **`recipes/`**: Agricultural/food recipes for users.
- **`shop/`**: Browsing categories and searching for items.

**Inside each feature folder**, you will typically find:
- **`data/`**: Repositories for fetching data (e.g., `ProductRepository`), making HTTP requests, and communicating with the API.
- **`models/`**: Dart classes that map JSON responses to objects (e.g., `ProductModel`).
- **`presentation/`**: 
  - **`pages/`** or **`screens/`**: The main UI files (e.g., `deals_page.dart`).
  - **`widgets/`**: Smaller UI components specific to the feature.
  - **`providers/`**: Riverpod providers that manage the state for this feature.

### 2.3 `shared/`
Contains code that is used across multiple features to avoid duplication.
- **`widgets/`**: Common buttons, text fields, loaders, and error dialogs.
- **`models/`**: Data classes that multiple features need to reference.

---

## 3. State Management (Riverpod)

The app relies heavily on **Riverpod** for state management. 
- Global state such as user authentication status or the current shopping cart is managed via Providers (e.g., `StateNotifierProvider` or `FutureProvider`).
- **How to read state:** In your UI, extend `ConsumerWidget` instead of `StatelessWidget`, and use `ref.watch(providerName)` to listen for changes.
- **How to modify state:** Use `ref.read(providerName.notifier).methodName()` to trigger updates without listening.

---

## 4. Networking & API Integration

All external API communication is handled through Repository classes located in the `data/repositories` folder of their respective features.

- **Base URL:** `https://bemsfarms-api.onrender.com/api`
- **Authentication:** Most endpoints require a JWT token. This is handled by retrieving the token via `TokenStorage` (using `flutter_secure_storage`) and attaching it to the `Authorization: Bearer <token>` header.
- **Error Handling:** Repositories intercept HTTP status codes. A `401 Unauthorized` will trigger a session expiration flow, while `4xx` and `5xx` throw standard exceptions that the UI should catch and display.

Example Repository structure:
```dart
Future<Product> getProductById(String id) async {
  final token = await _tokenStorage.getToken();
  final response = await _client.get(
    Uri.parse('$_baseUrl/products/$id'),
    headers: { 'Authorization': 'Bearer $token' },
  );
  // Parse response and handle errors
}
```

---

## 5. Adding a New Feature

When the company needs a new feature, follow this checklist to maintain the architecture:
1. Create a new folder under `lib/features/` (e.g., `lib/features/payments/`).
2. Inside it, create `data/`, `models/`, and `presentation/` folders.
3. Build the UI in `presentation/pages/`.
4. Create the necessary `StateNotifier` or Riverpod providers to manage the feature's logic.
5. Create a repository in `data/` if the feature needs to talk to the backend.

---

## 6. Development & Deployment

### Running the App
1. Ensure you have Flutter installed and an emulator running (or a physical device connected).
2. Fetch dependencies: `flutter pub get`
3. Run the app: `flutter run`

### Environment Setup
- The app requires standard Flutter SDK `^3.0.0`.
- No complex environment files (`.env`) are currently tracked, as the API URL is hardcoded in the repositories. If you move to staging/production servers, consider adding `flutter_dotenv`.

---
*End of Developer Guide*
