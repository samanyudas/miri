---
status: accepted
---

# Limit system access

Miri requires Accessibility permission only, keeps System Integrity Protection (SIP) enabled, and does not capture the screen.
Features that require additional permissions or SIP changes do not meet these boundaries.
Undocumented macOS APIs require individual evaluation of their compatibility risks and fallback behavior before adoption.
This permits evaluating undocumented APIs without treating them as approved dependencies.
