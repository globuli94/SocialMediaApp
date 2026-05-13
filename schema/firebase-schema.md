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
| followingCount | number | no | Cached count of users this user follows — default 0; absent on existing docs until first follow action |
| followerCount | number | no | Cached count of users following this user — default 0; absent on existing docs until first follow action |

### Subcollection: users/{userId}/following

Tracks the users that `userId` is following. Written atomically alongside `followerCount`/`followingCount` increments via a Firestore batch write.

| Field | Type | Required | Description |
|---|---|---|---|
| followeeId | string | yes | UID of the user being followed — matches the document ID |
| createdAt | timestamp | yes | Time the follow relationship was created |

### Subcollection: users/{userId}/followers

Tracks the users who follow `userId`. Written atomically alongside `followerCount`/`followingCount` increments via a Firestore batch write.

| Field | Type | Required | Description |
|---|---|---|---|
| followerId | string | yes | UID of the user who is following — matches the document ID |
| createdAt | timestamp | yes | Time the follow relationship was created |

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
| imageUrl | string | no | URL to post image in Firebase Storage; null/absent if text-only post |

---

> *Additional collections will be defined here as features are added.
> All changes require a ticket assigned to the Firebase Agent.*
