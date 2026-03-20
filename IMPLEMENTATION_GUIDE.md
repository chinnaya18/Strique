# Strique Cross-Device Communication & Notification System - Implementation Guide

## Overview
This document outlines all the features implemented for real-time cross-device synchronization, friend request management, and streak tracking in Strique.

## Implemented Features

### 1. **Cross-Device Real-Time Sync** ✅
- **Service**: `CrossDeviceSyncService` 
- **What it does**: 
  - Initializes Firebase Messaging for push notifications
  - Sets up local notification handling
  - Manages real-time notification sync across devices
  - Created centralized notification system (in `notification_model.dart`)

### 2. **Friend Request Flow** ✅
**Before**: Friends were auto-added to the list
**After**: Proper request → Notification → Acceptance → Visibility

**Changes Made**:
- Updated `FriendshipService`:
  - `addFriend()` - now sends friend request (status: pending) + sends notification
  - `acceptFriendRequest()` - accepts request and sends notification to sender
  - `rejectFriendRequest()` - new method to reject requests
  - `getAcceptedFriendships()` - new method to get only accepted friendships
  - `getPendingFriendRequests()` - new method to get pending requests

- Updated `add_friend_screen.dart`:
  - Success message now shows "Friend request sent successfully!"

- Updated `friends_screen.dart`:
  - Now has 3 tabs: Friends, Requests, Leaderboard
  - "Friends" tab shows only accepted friendships
  - "Requests" tab shows pending friend requests with Accept/Reject buttons
  - Leaderboard shows only accepted friendships sorted by streak

### 3. **Real-Time Completion Sync** ✅
- **Service**: `CompletionSyncService`
- **What it does**:
  - Listens to friend's daily completions in real-time
  - Syncs completion status across devices
  - Automatically increments friendship streak when both complete
  - Sends real-time notifications

**Key Methods**:
- `listenToFriendCompletions()` - Monitors friend's completion status
- `_updateFriendshipStreakIfBothCompleted()` - Updates streak when both users complete
- `checkAndResetStreaksIfNeeded()` - Resets streaks if 24 hours passed without completion
- `sendIncompleteReminders()` - Sends warning if friend hasn't completed
- `getFriendshipSyncStatus()` - Real-time sync status stream

### 4. **Friendship Streak Management** ✅
**Logic**:
- When BOTH users complete their habits for the day → Streak Increments
- If ONE doesn't complete within 24 hours → Streak Resets to 0
- Both users get notifications about streak changes

**Implementation**:
- Automatic check every hour (in `main.dart`)
- Check happens at midnight for previous day's completion
- Notifications sent to both users when streak changes
- Leaderboard updates in real-time

### 5. **24-Hour Streak Reset Cycle** ✅
**Implementation** (in `main.dart`):
- `_initializeStreakManagement()` - Initializes background tasks
- `_scheduleStreakCheck()` - Checks every hour if 24 hours have passed
- `_scheduleIncompleteReminders()` - Sends warnings at 8 PM

**Cycle Logic**:
- Completion window: Full 24 hours (midnight to midnight)
- At midnight: System checks if both users completed previous day
- If yes → Streak increments
- If no → Streak resets to 0

### 6. **Notification System** ✅
- **Model**: `NotificationModel` with types:
  - `friendRequest` - New friend request received
  - `friendRequestAccepted` - Request was accepted
  - `streakReminder` - Time to complete tasks
  - `friendStreakWarning` - Friend hasn't completed, 6 hours left
  - `friendCompletedTask` - Friend just completed their work
  - `friendshipStreakIncrement` - Friendship streak increased!
  - `streakResetWarning` - Streak reset due to missed day

- **Storage**: Firestore `notificationsCollection`
- **Features**:
  - Mark as read
  - Delete
  - Real-time stream
  - Unread count badge
  - Auto-cleanup old notifications (>30 days)

### 7. **Notification Center Screen** ✅
- **File**: `notification_center_screen.dart`
- **Features**:
  - Display all notifications with icons/colors by type
  - Mark individual notifications as read
  - Mark all as read button
  - Delete individual notifications (long-press)
  - Shows time relative to now (e.g., "2 hours ago")
  - Unread badge count

### 8. **Header Notification Icon** ✅
- **Location**: `home_screen.dart` AppBar
- **Features**:
  - Bell icon in AppBar
  - Red badge showing unread count
  - Taps to open Notification Center
  - Real-time badge update via Stream

### 9. **Providers for State Management** ✅
- **NotificationProvider** (`notification_provider.dart`):
  - Manages notifications stream
  - Tracks unread count
  - Methods: markAsRead(), deleteNotification()

- **FriendshipProvider** (`friendship_provider.dart`):
  - Manages friends list
  - Manages pending requests
  - Manages leaderboard
  - Methods: addFriend(), acceptFriendRequest(), rejectFriendRequest(), removeFriend()

## Integration Steps Completed

### 1. Core Services Initialized (main.dart)
```dart
✅ CrossDeviceSyncService().initialize()
✅ Background streak checks every hour
✅ Incomplete reminders at 8 PM
✅ New Providers added to MultiProvider
```

### 2. Firebase Setup Requirements

Make sure in your Firebase project:
1. **Firestore Security Rules**: Allow read/write to notifications, friendships, completions
2. **Firebase Cloud Messaging**: Enabled for push notifications
3. **Collections Created**:
   - `notifications` - Stores all notifications
   - `friendships` - Already exists, stores friendships & streaks
   - `completions` - Already exists, stores daily task completions

### 3. Android Implementation (Required)

Add to `android/app/build.gradle`:
```gradle
dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.0.0'
}
```

### 4. iOS Implementation (Required)

In `ios/Podfile`, ensure:
```
pod 'Firebase/Messaging'
pod 'Firebase/Core'
```

## Testing Checklist

### Test 1: Friend Request Flow
1. User A searches for User B using Friend ID
2. ✅ User B receives notification (check Notifications tab)
3. ✅ Request appears in User B's "Requests" tab
4. User B taps Accept
5. ✅ User A receives "Request Accepted" notification
6. ✅ User B appears in User A's "Friends" tab
7. ✅ Both see friendship streak counter

### Test 2: Streak Increment
1. Both User A and User B complete ALL their habits
2. ✅ Both receive "Friendship Streak Fire!" notification
3. ✅ Streak counter increments by 1
4. ✅ Updates visible on Leaderboard

### Test 3: 24-Hour Reset
1. User A completes workout, User B doesn't
2. Wait for system check (happens every hour at the hour mark)
3. ✅ Both receive streak reset warning
4. ✅ Streak counter resets to 0

### Test 4: Cross-Device Sync
1. On Device A: Complete a habit
2. ✅ Device B instantly shows "Friend completed their task!" notification
3. ✅ Friendship streak updates on Device B immediately
4. ✅ Leaderboard reflects changes in real-time

### Test 5: Incomplete Reminder
1. One friend hasn't completed by 8 PM
2. ✅ Other friend receives "Help Your Friend!" notification
3. ✅ Warning shows hours remaining (e.g., "6 hours remaining")

### Test 6: Notification Center
1. Make sure you have multiple notifications
2. ✅ All notifications appear in Notification Center
3. ✅ Unread count badge shows correctly
4. ✅ Mark all as read works
5. ✅ Individual delete works (long-press)
6. ✅ Times display correctly

## Database Schema

### Notifications Collection
```json
{
  "userId": "string",          // Recipient
  "senderId": "string",        // Sender (optional)
  "senderName": "string",      // Sender display name
  "type": "friendRequest",     // NotificationType
  "title": "Friend Request",   // Display title
  "body": "John sent...",      // Display body
  "data": "friendshipId",      // Additional data
  "createdAt": "timestamp",
  "isRead": false,
  "readAt": "timestamp"        // When marked as read
}
```

### Friendships Collection (Updated)
```json
{
  "user1Id": "string",
  "user2Id": "string",
  "user1Name": "string",
  "user2Name": "string",
  "status": "accepted",        // "pending" or "accepted"
  "friendshipStreak": 5,
  "maxFriendshipStreak": 10,
  "createdAt": "timestamp",
  "lastBothCompletedDate": "timestamp"
}
```

## Common Issues & Solutions

### Issue: Notifications not appearing
**Solution**: 
1. Check Firebase Cloud Messaging is enabled
2. Check app has notification permissions (iOS/Android)
3. Check user is logged in
4. Check notification timestamps are recent

### Issue: Streak not syncing between devices
**Solution**:
1. Check both users have completed ALL active habits
2. Check firestore rules allow read/write on completions
3. Check device times are synced (not hours off)
4. Manually trigger sync by waiting for hourly check

### Issue: Friend request not showing
**Solution**:
1. Verify Friend ID is correct (case-insensitive)
2. Check user exists in database
3. Verify friendship doesn't already exist (pending or accepted)
4. Check notifications stream is properly initialized

## Performance Considerations

1. **Notification Cleanup**: Old notifications (>30 days) are auto-cleaned
2. **Stream Limits**: Notifications limited to 50 most recent
3. **Hourly Checks**: Streak checks happen every hour (not too frequent)
4. **Batch Writes**: Streak resets use batch operations for efficiency
5. **Listeners**: Remove listeners on screen dispose to prevent memory leaks

## Future Enhancements

1. **SMS Notifications**: Use Twilio for SMS delivery
2. **Email Notifications**: Send email on streak reset
3. **Push Notifications**: Firebase Cloud Messaging backend setup
4. **Notification Preferences**: User can choose notification types
5. **Notification History**: Archive old notifications
6. **Scheduled Notifications**: Workmanager for persistent iOS reminders
7. **Rich Notifications**: Images/GIFs in notifications

## Security Notes

1. Firestore rules should ensure:
   - Users can only read their own notifications
   - Users can only modify their own notifications
   - Friendships are visible to both users only

2. Backend validation needed for:
   - Friendship status changes (only receiver can accept)
   - Streak calculations (verify both users actually completed)
   - Notification creation (validate sender exists)

## Files Modified/Created

### Created:
- `lib/models/notification_model.dart`
- `lib/services/cross_device_sync_service.dart`
- `lib/services/completion_sync_service.dart`
- `lib/providers/notification_provider.dart`
- `lib/providers/friendship_provider.dart`
- `lib/screens/notifications/notification_center_screen.dart`

### Modified:
- `lib/main.dart` - Added sync services initialization
- `lib/services/friendship_service.dart` - Added notification sending + request flow
- `lib/providers/habit_provider.dart` - Added streak sync on completion
- `lib/screens/home/home_screen.dart` - Added notification icon in header
- `lib/screens/friends/add_friend_screen.dart` - Updated success message
- `lib/screens/friends/friends_screen.dart` - Added requests tab + filters

## Next Steps

1. **Test the full flow** with multiple devices
2. **Set up Firebase Cloud Messaging** for production push notifications
3. **Configure Firestore Security Rules** properly
4. **Add SMS service** (optional) via Twilio
5. **Monitor performance** and adjust check intervals as needed
6. **Get user feedback** on notification timing and frequency
