# 04. Dark Neobrutalism Design System

## 1. Visual Philosophy

KanjiKi uses a **Dark Neobrutalism** design aesthetic designed to feel tactile, focused, and clean across both mobile devices and desktop web browsers.

### Key Principles:
* **Deep Dark Foundation:** Minimizes eye strain during long kanji study sessions (`#0C0D14`).
* **Solid Structural Geometry:** Sharp-yet-friendly `14px` border radii with solid `1.5px` to `2px` borders (`#2C3248`).
* **Offset Tactile Shadows:** Subtle hard-edge box shadows (`Offset(3, 3)`) on interactive components.
* **Vibrant Accent Roles:** Every color communicates explicit semantic state (Anki reviews, JLPT levels, stroke accuracies).

---

## 2. Color Palette & Semantic Roles

```
Background:        #0C0D14 (Pitch Dark Canvas)
Elevated Surface:  #151722 (Card Background)
Inner Surface:     #1E2130 (Input / Inner Card)
Border Default:    #2C3248 (Solid Component Border)
Border Active:     #7A68FF (Active Highlight Border)

Primary Brand:     #705DF2 (Electric Violet)
Cyan / Info:       #06B6D4 (JLPT & Stroke Badges)
Green / Good:      #10B981 (Review / Passed / Synced)
Amber / Hard:      #F59E0B (Readings / Warning / Offline)
Red / Again:       #EF4444 (Failed / Again / Delete)
Pink / Sakura:     #EC4899 (Mnemonics / Radicals)
```

---

## 3. Component Architecture

### 1. Tactile Cards (`AppStyles.neoCardDecoration`)
Used across Deck Cards, Dictionary search results, Profile statistics, and Card Editor:
```dart
BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: AppColors.border, width: 1.5),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.8),
      offset: Offset(3, 3),
      blurRadius: 0,
    )
  ],
)
```

### 2. Anki Pill Counters (New / Learn / Due)
Three distinct status badges displayed on every deck card:
* **🔵 New:** Blue container with new card count.
* **🔴 Learn:** Red container with relearning card count.
* **🟢 Due:** Green container with graduated cards due today.

### 3. Interactive Privacy-Masked Email
* In the Profile Screen and Drawer header, the user's email is masked by default (`d************@gmail.com`).
* Tapping the email field or the eye icon reveals the full unmasked email address.

---

## 4. Screen-by-Screen Breakdown

| Screen | Core UI Elements |
| :--- | :--- |
| **`home.dart`** | Clean dashboard, deck list with SRS counter pills, floating add deck modal, and JLPT preset drawer. |
| **`profile_screen.dart`** | Masked email badge, study stats overview (Decks, Total Cards, Offline Ready), and account sign-out/sign-in controls. |
| **`review_screen.dart`** | Top remaining count pill, flashcard prompt, mnemonic component chips, interactive canvas, bottom SRS buttons, and sticky Undo button. |
| **`practice.dart`** | Freeform canvas practice mode, stroke order guide toggle, readings, meanings, and radical breakdowns. |
| **`dictionary.dart`** | High-contrast search input, horizontal JLPT filter pills (`All`, `N5`–`N1`), kanji items with radical preview, and multi-selection "+ Add to Deck" mode. |
| **`deck_browser.dart`** | Tabular card list with kanji, readings, meanings, reps count, and SRS due status badges. |
| **`deck_options.dart`** | Segmented card front display selectors (Both, Kanji Front, Meaning Front) and daily quota inputs. |
| **`card_editor.dart`** | Kanji stroke preview canvas with high-contrast editable meaning and reading fields. |
| **`auth_screen.dart`** | Neobrutalist card with segmented Sign In / Sign Up tab switcher, email/password inputs, and offline guest mode button. |
