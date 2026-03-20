# TESTING GUIDE - Strique Cross-Device Sync

## Quick Start Testing (5 min each scenario)

### Scenario 1: Friend Request & Acceptance
**Devices**: Phone A, Phone B (same Firebase project)

1. **On Phone A**:
   - Open Strique
   - Go to Friends → Add Friend
   - Enter Phone B's Friend ID
   - Tap "Add Friend"
   - ✓ See: "Friend request sent successfully! 👋"

2. **On Phone B**:
   - Get notification: "👥 Friend Request - [Name] sent you a friend request!"
   - Open Notifications (bell icon in header)
   - Swipe notification or go to Friends → Requests tab
   - Tap "Accept"
   - ✓ See: Friend now appears in Friends tab

3. **On Phone A**:
   - Get notification: "✅ Request Accepted - [Name] accepted your friend request!"
   - ✓ Friend appears in Friends tab
   - ✓ Streak counter shows "0" for this friend

---

### Scenario 2: Friendship Streak Increment
**Setup**: Both are friends (from Scenario 1)

1. **On Phone A**:
   - Go to Habits
   - Complete ALL active habits for today
   - Go to Home
   - ✓ See: "🔥 Friendship Streak Fire! You and [Friend] are on a 1 day streak!"

2. **On Phone B**:
   - (Shortly after Phone A completes)
   - Get same notification or check Notifications
   - Go to Friends → Leaderboard
   - ✓ See: Friendship streak = 1
   - ✓ See: Friend name with streak counter

3. **On Phone A**:
   - Go to Friends → Leaderboard
   - ✓ Streak counter updated to 1

---

### Scenario 3: Streak Reset (24-Hour Cycle)
**Setup**: Both at 1-day streak (from Scenario 2)

**Day 2 - One user doesn't complete**

1. **On Phone A**:
   - Complete all habits again
   - ✓ Get: Friendship streak notification (now 2)

2. **On Phone B**:
   - Do NOT complete any habits
   - Wait for system check (happens every hour)
   - ✓ Get notification: "😢 Streak Reset - 24 hours passed without both completing"

3. **On Both phones**:
   - Go to Friends → Leaderboard
   - ✓ See: Friendship streak = 0

---

### Scenario 4: Incomplete Friend Warning
**Setup**: Both are friends

**At 8 PM**

1. **On Phone A**:
   - Complete all habits
   - Go to Notifications
   - ✓ See: "⚠️ Help Your Friend! Remind [Friend] to complete their task in the next 16 hours..."

2. **On Phone B** (if incomplete):
   - Go to Notifications
   - ✓ See: Same warning message

---

### Scenario 5: Real-Time Cross-Device Sync
**Setup**: Both friends are looking at Leaderboard

1. **On Phone A**:
   - Complete a habit
   - Scroll to see if streak updates in real-time

2. **On Phone B**:
   - Watch Leaderboard
   - ✓ See immediate notification of completion
   - ✓ See streak increment in real-time (may need to refresh)
   - ✓ Look at exact same friendship entry
   - ✓ Both show same streak number

---

### Scenario 6: Notification Center
**Test**: Badge count and notification display

1. Open app with multiple pending notifications
2. ✓ Bell icon in header shows red badge with count
3. Tap bell icon
4. ✓ All notifications appear with:
   - Icon/emoji matching type
   - Title and body text
   - Time relative ("2 hours ago")
   - Blue dot for unread
5. Tap "Mark All Read"
   - ✓ Blue dots disappear
   - ✓ Badge goes away
6. Long-press notification
   - ✓ Delete dialog appears
   - ✓ Confirmation required

---

## Debugging Checklist

### If Friend Couldn't Be Added:
- [ ] Verify Friend ID is correct (copy-paste to avoid typos)
- [ ] Check Friend ID format (should autoconvert to uppercase)
- [ ] Confirm friend account exists (they're logged in)
- [ ] Check firestore rules allow reading users collection
- [ ] Verify friendship doesn't already exist

### If No Notifications Received:
- [ ] Check user is logged in
- [ ] Verify other device is also logged in (same Firebase account)
- [ ] Check app has notification permissions (Settings > Apps > Notifications)
- [ ] On iOS: App must be in foreground OR background messaging enabled
- [ ] On Android: Foreground service might be needed
- [ ] Check Firebase Cloud Messaging is enabled in Firebase console

### If Streak Didn't Sync:
- [ ] Verify user completed ALL active habits (not just one)
- [ ] Check firestore shows completion records with "completed" status
- [ ] Wait for hourly check (happens every 60 minutes)
- [ ] Manually restart app to trigger check
- [ ] Check system time is correct on both devices
- [ ] Look at lastBothCompletedDate in firestore (should be today)

### If Streak Reset Didn't Happen:
- [ ] Check 24 hours have actually passed since completion
- [ ] System checks every hour at :00 minutes
- [ ] If 2 AM comes and neither completed → will reset at 2:00 AM
- [ ] Check firestore console for friendships collection
- [ ] Verify friendshipStreak field > 0 before reset
- [ ] With status = "accepted"

---

## Manual Firestore Checks

Open Firebase Console > Firestore > Browse Collections

### Check Notifications:
```
notifications > [doc]
- userId: Match current logged-in user
- type: Should match notification type (friendRequest, etc)
- isRead: true/false
- createdAt: Should be recent
```

### Check Friendships:
```
friendships > [doc]
- user1Id & user2Id: Both user IDs
- status: "accepted" or "pending"
- friendshipStreak: Should be 0, 1, 2, etc
- lastBothCompletedDate: Check if today's date
```

### Check Completions:
```
completions > [doc]
- userId: User ID
- habitId: Habit ID
- date: Should be today
- status: "completed"
- completedAt: Timestamp of completion
```

---

## Common Test Scenarios Summary

| Scenario | Expected Result | Check |
|----------|-----------------|-------|
| Send friend request | Notification sent immediately | Bell icon badge +1 |
| Accept request | Sender gets notification | Bell icon updates |
| Complete habits first | Streak notification sent | Firebase shows streak=1 |
| Sync to other device | Other sees notification instantly | Real-time update visible |
| Skip day (24hrs no complete) | Streak resets at next check | Streak=0 in leaderboard |
| At 8 PM incomplete | Friend gets warning | "Help your friend" notification |

---

## Firebase Debugging

### Enable Debug Logging:
```dart
// In main.dart before runApp()
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
);

debugPrint('Firebase ready');
```

### Check Realtime Database Sync:
- Firestore console > Leaderboard tab
- Should see friends sorted by friendshipStreak (descending)
- Updates should happen within 1-2 seconds

### Monitor Notifications Collection:
- Watch size grow as notifications are created
- Check createdAt timestamps are recent
- If locked at 50+ docs, cleanup is working

---

## Performance Notes

- **Notifications**: Limit to 50 most recent per user
- **Streak Checks**: Every 60 minutes (not every minute)
- **Default Complete Window**: Full day (midnight-to-midnight your timezone)
- **Cleanup**: Notifications older than 30 days auto-delete

---

## Success Indicators ✅

You'll know everything is working when:

1. ✅ Friend requests send notifications instantly
2. ✅ Both devices show same streak number at same time
3. ✅ Streak increments when both complete
4. ✅ Streak resets if one person misses a day
5. ✅ Notifications appear in notification center with correct types
6. ✅ Badge count shows unread notifications
7. ✅ Real-time sync works across devices
8. ✅ Leaderboard updates immediately
9. ✅ Friend warnings sent at 8 PM for incomplete
10. ✅ No duplicate notifications
