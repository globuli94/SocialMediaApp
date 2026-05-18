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

### Subcollection: posts/{postId}/likes

Tracks which users have liked a post. Written atomically alongside the `likeCount` increment/decrement on the parent post document via a Firestore batch write. Document ID equals the liker's UID.

| Field | Type | Required | Description |
|---|---|---|---|
| userId | string | yes | UID of the user who liked the post — matches the document ID |
| createdAt | timestamp | yes | Time the like was recorded |

---

---

## conversations

Stores 1-to-1 conversations between two users.

| Field | Type | Required | Description |
|---|---|---|---|
| id | string | yes | Auto-generated document ID |
| participantUids | array\<string\> | yes | Exactly 2 UIDs; used for array-contains queries |
| lastMessageText | string | yes | Preview text of the most recent message |
| lastMessageAt | timestamp | yes | Timestamp of the most recent message; used for sort |
| lastMessageSenderUid | string | yes | UID of the sender of the last message |
| unreadCounts | map\<string, number\> | yes | Keyed by UID — e.g. `{"uid1": 0, "uid2": 2}` |
| createdAt | timestamp | yes | When the conversation was created |

### Subcollection: conversations/{conversationId}/messages

Each document is one message in the conversation thread.

| Field | Type | Required | Description |
|---|---|---|---|
| id | string | yes | Auto-generated document ID |
| senderUid | string | yes | UID of the sender |
| text | string | yes | Message body |
| createdAt | timestamp | yes | When the message was sent |

---

> *Additional collections will be defined here as features are added.
> All changes require a ticket assigned to the Firebase Agent.*
