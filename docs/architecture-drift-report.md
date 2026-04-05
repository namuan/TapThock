# Architecture Drift Report

**Source:** Comparison of `docs/GUIDANCE.md` vs TapThock implementation

| Aspect | GUIDANCE.md | Implementation | Status |
|--------|-------------|----------------|--------|
| Event Capture | `CGEventTap` | `NSEvent.addGlobalMonitorForEvents` | Different |
| Audio Engine | `AVAudioEngine` + buffer | `AVAudioPlayer` pool | Different |
| Key Filtering | Filter modifiers | Not implemented | Missing |
| Key Repeat | Handle autorepeat | Not implemented | Missing |
| Permissions | Accessibility only | Accessibility + Input Monitoring | More |

**Key Differences:**
- Event monitoring uses AppKit's higher-level API vs C-level CGEventTap
- Audio uses player pool instead of preloaded PCM buffer
- Missing filter for modifier keys and autorepeat handling
- Requires Input Monitoring permission beyond Accessibility

**Recommendation:** Consider implementing key filtering and repeat handling per GUIDANCE.md.