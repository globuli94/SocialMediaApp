# Approved Packages

**Owner:** CTO
**Consumers:** Flutter Developer, QA Agent, Firebase Agent

This file is the single source of truth for all approved packages and
technologies in the project. It is maintained by the CTO and updated
only after board approval of a package proposal.

> No agent may add a package to `pubspec.yaml` that is not listed here.

---

## Dependencies

| Layer | Technology | Package | Version |
|---|---|---|---|
| UI framework | Flutter (Dart) | `sdk: flutter` | stable |
| State management | BLoC | `flutter_bloc` | latest |
| Authentication | Firebase Auth | `firebase_auth` | latest |
| Database | Cloud Firestore | `cloud_firestore` | latest |
| File storage | Firebase Storage | `firebase_storage` | latest |
| Navigation | go_router | `go_router` | latest |
| Fonts | Google Fonts | `google_fonts` | latest |
| Social auth | Google Sign-In | `google_sign_in` | latest |

## Dev Dependencies

| Purpose | Package | Version |
|---|---|---|
| Testing framework | `flutter_test` | sdk |
| BLoC testing | `bloc_test` | ^10.0.0 |
| Linting | `flutter_lints` | latest |
| Mocking | `mocktail` | latest |
| Firestore testing | `fake_cloud_firestore` | ^3.0.0 |
| App icon generation | `flutter_launcher_icons` | latest |

---

## Changelog

| Date | Change | Approved by |
|---|---|---|
| 2026-05-09 | Initial package set defined | Board |
| 2026-05-10 | Add flutter_launcher_icons (dev) for APP-003 | Board |
| 2026-05-12 | Add fake_cloud_firestore (dev) for SOCAA-75 data layer tests | CTO |

---

> Additional packages require a `PACKAGE PROPOSAL` comment on the relevant
> ticket, followed by board approval. The CTO updates this file once approved.
