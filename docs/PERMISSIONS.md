---

# 🧠 The correct permission model

For your architecture:

### ✅ Required

* **Accessibility permission**

  * Needed for `CGEventTap`
  * Lets you observe global key events

### ❌ NOT required

* **Input Monitoring**

  * Only needed for *lower-level / raw HID access* (IOKit, keylogging-style access)

---

# 🔍 Why your current app is asking for Input Monitoring

From your table:

> `NSEvent.addGlobalMonitorForEvents` + IOKit usage

👉 That’s the key issue.

You’re likely:

* using **IOKit** (or something that triggers it indirectly)
* or accessing **HID devices directly**

That **forces macOS** to require:

* Input Monitoring permission

---

# ⚠️ Why you should remove Input Monitoring

### 1. 🚫 App Store risk

Apple is much stricter about Input Monitoring than Accessibility.

* Accessibility → acceptable for utilities
* Input Monitoring → **often flagged as keylogging**

---

### 2. 😬 User trust friction

Users see:

> “App wants to monitor your input from the keyboard”

👉 Much scarier than:

> “App needs accessibility access”

---

### 3. 🧩 You don’t need it

Everything you want:

* global key detection
* typing sounds

👉 Already works with:

* `CGEventTap` + Accessibility

---

# ⚖️ EventTap vs Global Monitor (important distinction)

### Your current approach:

```swift
NSEvent.addGlobalMonitorForEvents
```

* ❌ Higher latency
* ❌ Misses some events
* ❌ Can behave inconsistently
* ❌ Sometimes pushes you toward Input Monitoring

---

### Recommended approach:

```swift
CGEvent.tapCreate
```

* ✅ Lower-level (Quartz)
* ✅ More reliable
* ✅ Lower latency
* ✅ Only needs Accessibility

---

# 🧪 When Input Monitoring *would* be needed

Only if you:

* Read **raw HID events** via IOKit
* Capture input **before macOS processes it**
* Build:

  * keyloggers
  * advanced remappers (like Karabiner-level)

👉 That’s **not your use case**

---

# 🧠 What apps like Klack do

They almost certainly:

* use `CGEventTap`
* require **Accessibility only**
* avoid IOKit entirely

---

# ✅ What you should change

### 1. Replace:

```swift
NSEvent.addGlobalMonitorForEvents
```

👉 with:

```swift
CGEvent.tapCreate
```

---

### 2. Remove:

* Any **IOKit / HID usage**
* Any code triggering Input Monitoring

---

### 3. Keep:

* Accessibility permission prompt only

---

# 🔧 Quick sanity check

After refactor:

* App should appear in:

  * ✅ Accessibility list
* App should NOT appear in:

  * ❌ Input Monitoring list

---

# 🧠 Bottom line

* Input Monitoring = **overkill + risky**
* Accessibility + Event Tap = **correct architecture**
* Your GUIDANCE.md is right — your implementation drifted

---
