# 📱 Papyrus Mobile

Papyrus is a powerful, flexible business management suite designed for small shop owners. It simplifies inventory tracking, sales management, and employee oversight into a clean, mobile-first experience.

![App Icon](assets/images/app_icon.png)

## ✨ Core Features

### 🏢 Shop & Team Management
- **Multi-Shop Support**: Manage multiple business locations from a single account.
- **Role-Based Access (RBAC)**: Secure permissions for Owners, Managers, and Employees.
- **Live Activity Logs**: Audit trails for every transaction and inventory change.

### 📦 Inventory & Sales
- **Kena Beca**: Efficient buying and selling module.
- **Stock Tracking**: Real-time alerts for low stock and inventory valuation.
- **Reporting**: Daily sales, expense tracking, and performance analytics.

### 🔄 Dynamic Update System
- **Architecture Aware**: Automatically detects your phone's CPU (ARM64, v7a, x86) and downloads the most optimized build.
- **In-App Prompts**: Integrated soft/force update logic powered by the [Papyrus Web Hub](https://github.com/arnobx86/PapyrusWebsite).

## 🛠️ Technical Specifications
- **Framework**: [Flutter](https://flutter.dev/)
- **Backend/Auth**: [Supabase](https://supabase.com/)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Storage**: [Shared Preferences](https://pub.dev/packages/shared_preferences)
- **Error Tracking**: [Sentry](https://sentry.io/)

## 🚀 Getting Started

1. **Clone the repo**:
   ```bash
   git clone https://github.com/arnobx86/Papyrus.git
   ```

2. **Environment Setup**:
   Create a `.env` file in the root:
   ```env
   SUPABASE_URL=your_url
   SUPABASE_ANON_KEY=your_key
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Build for Release**:
   To generate optimized, architecture-specific APKs:
   ```bash
   flutter build apk --release --split-per-abi
   ```

## 🏗️ Project Structure
- `lib/core`: Service layers, configuration, and app-wide logic.
- `lib/screens`: All UI components partitioned by module (Shop, Employee, Settings).
- `lib/models`: Supabase data transformers.
- `lib/providers`: State management logic.

## 📄 License
Copyright © 2026 Papyrus Team. All rights reserved.
