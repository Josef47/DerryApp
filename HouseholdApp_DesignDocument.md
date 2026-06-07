# 🏠 Household App — Design Document
**Version 1.0 | Flutter Web Application**

---

## Document Overview

- This document defines the full product requirements for the Household App.
- Platform: Flutter Web App (PWA — installable on iOS & Android via browser).
- Target users: 6–8 housemates, 1 Housemaster with admin privileges.
- Core modules: Tasks, Book/Activity Tracking, Finance, Shopping List, Google Drive integration.
- Backend: Firebase (Firestore + Auth). Google Drive API for file & spreadsheet access.

---

## 1. Project Overview

The Household App is a shared, private web application for a group of 6–8 people living together. It centralises task management, activity tracking, shared finances, and shopping into a single tool that everyone can access from their phone — by using Flutter's PWA (Progressive Web App) capability.

### 1.1 Goals

- Replace scattered tools (WhatsApp, Bring!, Google Drive excel) with one cohesive app
- Give the Housemaster full visibility and control over house tasks and members
- Make daily and weekly recurring responsibilities clear and automatically reminded
- Track personal activities (books read, prayers) and sync results to a shared Drive spreadsheet
- Manage a shared house bank balance with expense logging
- Maintain a structured, archivable shopping list with loyalty card storage

### 1.2 Non-Goals (v1)

- Native iOS / Android App Store distribution — PWA covers this need
- Automatic bank API integration (planned for v2)
- Chat or messaging features — WhatsApp continues for that

---

## 2. Users & Roles

Users are fixed and pre-defined. There is no public registration. The Housemaster creates accounts by generating a one-time key for each member. A new member enters their key once, and the device stays permanently logged in (via local persistent storage).

| Role | Count | Capabilities |
|------|-------|--------------|
| Housemaster | 1 | Full admin: create/edit/delete tasks, manage users, view all progress, update bank balance, set notification times, create shopping categories, manage activity types. |
| Member | 5–7 | View own tasks, mark tasks as done, log activity data, add shopping items, view shared balance and drive files. |

### 2.1 Authentication — One-Time Key System

Since the app is private and small-scale, a lightweight key-based login is used instead of email/password flows:

1. Housemaster opens the app and navigates to User Management.
2. Housemaster creates a new user profile (name, role) — app generates a unique one-time key (e.g. `HM-X7K2-PLQR`).
3. Housemaster shares the key with the new housemate (e.g. via WhatsApp).
4. New member opens the app URL on their phone, enters the key — they are logged in as that user.
5. The key is marked as used and cannot be reused. The session persists in the browser's local storage indefinitely.

> **Tech:** Firebase Anonymous Auth + Firestore custom user records. Keys stored in Firestore with a `used: bool` flag.

---

## 3. Platform & Tech Stack

### 3.1 Why Flutter Web / PWA

Building a native app for both iOS and Android would require App Store / Play Store accounts, review processes, and two codebases. Flutter Web produces a single codebase that runs in any browser. Users on iOS can tap **Share → Add to Home Screen** to install it like an app. Users on Android can tap the browser install prompt. Both get a full-screen app experience with push notification support.

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | Flutter Web (Dart) | Cross-platform UI, PWA shell, local storage for session |
| Backend / DB | Firebase Firestore | Real-time NoSQL database for tasks, users, finance, shopping |
| Auth | Firebase Auth (Anonymous) | Lightweight auth tied to one-time keys |
| Notifications | Firebase Cloud Messaging (FCM) | Push notifications for task reminders |
| File Access | Google Drive API v3 | Browse meeting notes, read/write activity spreadsheet |
| Barcode Scanner | mobile_scanner (Flutter) | Camera-based barcode & QR scanning for loyalty card entry |
| Week Convention | ISO 8601, Monday start | Weeks labelled YYYY-Wnn, Monday = first day of week |
| State Mgmt | Riverpod (Flutter) | Reactive state, real-time Firestore stream subscriptions |
| Hosting | Firebase Hosting | HTTPS hosting, required for PWA service worker |

### 3.2 Notification Strategy

Flutter Web supports push notifications via the Web Push API + FCM when the app is installed as a PWA. Each device registers an FCM token on login. Firebase Cloud Functions trigger daily at the configured reminder time and send push notifications to users with incomplete tasks.

- If a task is completed (ticked) before the reminder time — no notification is sent for that task.
- The Housemaster can set the global reminder time (e.g. 08:00 AM) in Settings.
- If a task deadline passes without completion, the notification appears the next morning.

---

## 4. Firestore Data Model

### 4.1 Collections Overview

| Collection | Document Key | Key Fields |
|-----------|-------------|-----------|
| `users` | userId | name, role, isHousemaster, fcmToken, createdAt |
| `oneTimeKeys` | key string | userId, used: bool, createdAt |
| `tasks` | taskId | title, type (recurring\|one-time), recurrence, deadline, assignedTo[], reminderEnabled |
| `completions` | auto-id | taskId, userId, completedAt, weekLabel (YYYY-Wnn) |
| `activityTypes` | auto-id | name, unit (e.g. 'pages'), createdBy (HM only), active: bool |
| `activityLogs` | auto-id | userId, activityTypeId, value, weekLabel, note, syncedToDrive |
| `financeEntries` | auto-id | userId, amount, description, receiptImageUrl, createdAt, deletedBy |
| `financeBalance` | singleton | currentBalance, lastUpdatedBy, lastUpdatedAt |
| `shoppingItems` | auto-id | title, category, description, urgency, deadline, expectedPrice, imageUrl, addedBy, boughtBy, boughtAt, archived |
| `shoppingCategories` | auto-id | name, createdBy |
| `loyaltyCards` | auto-id | storeName, cardImageUrl, barcodeValue, barcodeType, addedBy |
| `driveLinks` | auto-id | label, url, type (folder\|file), addedBy |
| `settings` | singleton | reminderTime, timezone, houseName, driveSheetId, googleRefreshToken |

### 4.2 Recurrence Schema (tasks)

The `recurrence` field on a task document:

```json
{
  "type": "none | daily | weekly | custom",
  "daysOfWeek": [1, 4],
  "interval": 1,
  "nextDeadline": "<Timestamp>",
  "endDate": "<Timestamp | null>"
}
```

- `daysOfWeek`: array of integers (0 = Sunday, 1 = Monday … 6 = Saturday). Used when type = `custom`.
- `interval`: e.g. `2` for every 2 weeks.
- `nextDeadline`: auto-updated whenever a completion is recorded.
- `endDate`: optional end for the recurrence series.

---

## 5. Feature Modules

### 5.1 Task Management

#### 5.1.1 Task Types

| Type | Description | Example |
|------|-------------|---------|
| Recurring — Daily | Resets every day. Deadline is end of today. | Cleaning the kitchen counter |
| Recurring — Weekly | Resets every week on a set day. Deadline auto-advances. | Cleaning the bathrooms (every Monday) |
| Recurring — Custom | User picks specific weekdays (like Google Calendar). Interval configurable. | Every Monday & Thursday |
| One-Time | Single deadline. Marked done and archived. | Buy new dish soap before Friday |

#### 5.1.2 Task Fields

- Title (required)
- Description (optional)
- Assigned to: one or multiple members (multi-select)
- Type: Recurring or One-Time
- Recurrence: Daily / Weekly / Custom (day picker UI like Google Calendar)
- Deadline: date-time picker
- Reminder enabled: toggle
- Created by (auto, Housemaster only can create tasks)

#### 5.1.3 Completing a Task

1. Member taps the task checkbox in their task list.
2. A completion record is written to Firestore with `userId`, `taskId`, `completedAt`.
3. The task card shows as completed (green checkmark).
4. If a reminder was scheduled for this task and it is now completed — the scheduled notification is cancelled.
5. For recurring tasks: the `nextDeadline` field is auto-advanced to the next recurrence.

#### 5.1.4 Housemaster View

The Housemaster has a dedicated dashboard tab showing all members and all tasks in a matrix view. Each cell shows: ✅ Done, ⏳ Pending, ❌ Overdue. The Housemaster can filter by date range, member, or task type.

---

### 5.2 Activity & Book Tracking

Members track personal activities weekly — such as pages of a book read, or number of daily prayers performed. These are stored in Firestore and immediately synced to a designated Google Drive spreadsheet.

#### 5.2.1 Activity Types (Housemaster-managed)

The Housemaster manages the list of activity types from Settings:
- Each type has a **name** (e.g. "Book: Pages Read", "Prayers") and a **unit label** (e.g. "pages", "times").
- Types can be added, renamed, or deactivated at any time.
- Members see only active types when logging.

#### 5.2.2 Activity Log Entry Fields

- Activity type: selected from the active list
- Value: numeric input (e.g. 45 pages, 21 prayers)
- Week label: auto-set to current ISO week (YYYY-Wnn), Monday = week start
- Optional note (e.g. book title, chapter name)

#### 5.2.3 Google Drive Spreadsheet Sync

The Drive spreadsheet has a fixed structure: rows = members, columns = weeks. When an activity log is submitted:

1. App calls a Firebase Cloud Function.
2. Cloud Function uses the house Google account credentials (stored as refresh token in Firestore `settings`) to call Sheets API v4.
3. It finds or creates the column for the current ISO week.
4. It finds the row for the current user.
5. It writes (or adds to) the cell value **immediately**.
6. The `syncedToDrive` flag on the Firestore record is set to `true`.

> If the sync fails (offline or error), it retries on next app open. Firestore is the source of truth.

---

### 5.3 Shared Finance

#### 5.3.1 Balance View

- All members can see the current shared house balance.
- The Housemaster can manually set the actual bank balance at any time (e.g. after checking the bank app).
- A log of all manual balance updates is kept.

> **v2 idea:** Bank API integration (e.g. Bunq, ING) to auto-fetch the balance.

#### 5.3.2 Expense Submission

1. Member taps **+ Add Expense**.
2. They enter: amount, description, and optionally take/upload a photo of the receipt.
3. Expense is saved to Firestore and the amount is **immediately subtracted** from the current balance.
4. All members can see the full expense log.
5. The Housemaster can **directly edit or delete** any entry — including those submitted by other members.

> No approval step needed. HM is the final authority on corrections.

---

### 5.4 Shopping List

#### 5.4.1 Items

| Field | Required | Notes |
|-------|----------|-------|
| Title | ✅ Yes | |
| Category | ✅ Yes | From Housemaster-defined list |
| Description | No | |
| Deadline | No | |
| Urgency | No | Low / Medium / High |
| Picture | No | Photo upload |
| Expected Price | No | |

- Any member can add an item.
- When bought: member ticks the checkbox — item moves to **archive** with `boughtBy` and `boughtAt` recorded.
- Archive is permanently accessible and searchable.

#### 5.4.2 Categories

- Created and managed by the Housemaster only.
- Examples: Kitchen, Bathroom, Cleaning, Other.
- Shopping list view groups items by category with collapsible sections.

#### 5.4.3 Loyalty Cards & Coupons Tab

Separate tab within the Shopping section.

- Any member can add a store card via two methods:
  1. **Photo** — take or upload a picture of the physical card.
  2. **Camera scan** — scan the barcode or QR code live using the device camera (`mobile_scanner` package). Format is auto-detected.
- Each card entry: store name, card image, barcode value, barcode type.
- Supported formats: EAN-13, QR Code, Code 128.
- Card displayed **full-screen** with barcode rendered for easy scanning at checkout.
- Stores: Albert Heijn, Lidl, Jumbo, and any custom store name.

---

### 5.5 Google Drive Integration

The house holds weekly meetings and stores notes in a shared Google Drive folder. The app provides a read-only browser for those files, and write access for the activity spreadsheet.

- A **single shared house Google account** is configured once by the Housemaster in Settings (OAuth2 refresh token stored securely in Firestore, used server-side via Cloud Functions).
- No individual Google sign-in is required from members. All Drive access is proxied through Firebase Cloud Functions.
- Housemaster adds Drive folder/file links to the app by pasting a Drive share URL.
- Members can browse the linked files and open them in the Drive viewer within the app.
- The activity tracking spreadsheet is a separately linked file — the app reads and writes it via Sheets API v4.

---

## 6. UX & Navigation Structure

| Tab / Screen | Accessible by | Description |
|-------------|--------------|-------------|
| Home / Dashboard | All members | Today's tasks, quick stats, upcoming deadlines |
| Tasks | All members | Personal task list; Housemaster sees all-members matrix view |
| Activities | All members | Log book pages / prayers; view weekly history |
| Finance | All members | See balance; submit expense. HM can edit/delete entries & set balance |
| Shopping | All members | Item list by category + Loyalty Cards tab |
| Drive | All members | Linked Drive files browser |
| Settings | Housemaster only | Reminder time, user management, activity types, task categories, Google account |

---

## 7. Notification Logic

### 7.1 Reminder Flow

| Step | Action | Detail |
|------|--------|--------|
| 1 | Daily Firebase Cloud Function runs | Triggered at the Housemaster-configured time (e.g. 08:00 CET) |
| 2 | Function queries overdue/pending tasks | Finds all tasks where `nextDeadline < now` AND no completion exists for today |
| 3 | Sends FCM push notification | Per user, per overdue task — batched into one notification if multiple |
| 4 | User opens app and ticks task | Completion recorded; notification not repeated |
| 5 | Task done before trigger fires | Cloud Function skips it — no notification sent |

---

## 8. Design Decisions (All Resolved)

| Decision | Resolution |
|----------|-----------|
| Google Drive auth | Single shared house Google account, configured once by HM in Settings. No per-user Google login. |
| Activity types | Housemaster-managed list. Add / rename / remove from Settings. Each type has a name and unit label. |
| Expense approval | No approval flow. Amount subtracted immediately. HM can directly edit or delete any entry. |
| Sheets sync | Immediate — every activity log entry is written to Drive in real time. Offline: retry on next app open. |
| Week start day | Monday (ISO 8601). Week labels formatted as YYYY-Wnn throughout. |
| Loyalty card entry | Two methods: photo of the physical card, or live camera barcode/QR scan (mobile_scanner). Format auto-detected. |

---

## 9. Suggested Development Phases

| Phase | Scope | Est. Effort |
|-------|-------|------------|
| Phase 1 — Foundation | Firebase setup, Auth + one-time key login, user management, persistent session | ~1 week |
| Phase 2 — Tasks | Task CRUD, recurrence engine, completion tracking, HM matrix view | ~1.5 weeks |
| Phase 3 — Notifications | FCM token registration, Cloud Functions for daily trigger, reminder logic | ~1 week |
| Phase 4 — Finance | Balance view, expense submission, receipt photo upload, HM edit/delete | ~1 week |
| Phase 5 — Shopping | Shopping list, categories, archive, loyalty cards + camera scan tab | ~1 week |
| Phase 6 — Drive & Activities | Google OAuth2 (house account), Drive file browser, Sheets API read/write, activity log UI | ~1.5 weeks |
| Phase 7 — Polish | PWA manifest, offline support, responsive design, error handling, testing | ~1 week |

---

## 10. v2 Roadmap

- Bank API integration (e.g. Bunq, ING) to auto-fetch shared account balance
- Housemaster can export a weekly PDF summary (tasks, finance, activities)
- Per-user push notification preferences (opt-out of specific task reminders)
- Dark mode

---

*Household App — Design Document v1.0 — All decisions finalised.*
