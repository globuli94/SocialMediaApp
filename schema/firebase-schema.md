# Firebase Schema

This document is the single source of truth for all Firestore collections and
fields used in the social network app.

**Owner:** Firebase Agent
**Consumers:** Flutter Developer Agent, QA Agent, Board

> This file is generated at project initialization and updated by the Firebase
> Agent only. No other agent may add, rename, or remove collections or fields.

---

## users

Stores public profile data for each registered user.

| Field | Type | Required | Description |
|---|---|---|---|
| uid | string | yes | Firebase Auth UID — matches the document ID |
| displayName | string | yes | Publicly visible username |
| bio | string | no | Short user biography |
| avatarUrl | string | no | URL to profile picture in Firebase Storage |
| createdAt | timestamp | yes | Account creation time |
| postCount | number | no | Cached count of the user's posts — default 0 |

---

## posts

Stores posts created by users and displayed in the feed.

| Field | Type | Required | Description |
|---|---|---|---|
| id | string | yes | Auto-generated document ID |
| authorUid | string | yes | UID of the user who created the post — references users/{uid} |
| content | string | yes | Text body of the post |
| createdAt | timestamp | yes | Time the post was published |
| likeCount | number | yes | Cached count of likes — default 0 |

---

> *Additional collections will be defined here as features are added.
> All changes require a ticket assigned to the Firebase Agent.*
