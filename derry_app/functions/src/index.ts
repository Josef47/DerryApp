import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { google } from 'googleapis';

admin.initializeApp();
const db = admin.firestore();

// ─── Daily Notification Trigger ──────────────────────────────────────────────
// Runs every day at 07:00 UTC; reads reminderTime from settings to decide whom to notify.
export const dailyTaskReminder = functions.pubsub
  .schedule('0 7 * * *')
  .timeZone('Europe/Amsterdam')
  .onRun(async (_context) => {
    const settingsDoc = await db.collection('settings').doc('appSettings').get();
    if (!settingsDoc.exists) return null;

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd = new Date(todayStart.getTime() + 86400000);

    // Get all non-archived tasks with reminders
    const tasksSnap = await db
      .collection('tasks')
      .where('archived', '==', false)
      .where('reminderEnabled', '==', true)
      .get();

    if (tasksSnap.empty) return null;

    // Get today's completions
    const completionsSnap = await db
      .collection('completions')
      .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(todayStart))
      .where('completedAt', '<', admin.firestore.Timestamp.fromDate(todayEnd))
      .get();

    const completedPairs = new Set(
      completionsSnap.docs.map((d) => `${d.data().taskId}_${d.data().userId}`)
    );

    // Get all users with FCM tokens
    const usersSnap = await db.collection('users').get();
    const userTokens: Record<string, string> = {};
    usersSnap.docs.forEach((doc) => {
      const data = doc.data();
      if (data.fcmToken) userTokens[doc.id] = data.fcmToken;
    });

    // For each task, find assigned users who haven't completed it
    const notifications: Array<{ token: string; title: string; body: string }> = [];

    for (const taskDoc of tasksSnap.docs) {
      const task = taskDoc.data();
      const assignedTo: string[] = task.assignedTo || [];

      for (const userId of assignedTo) {
        const pairKey = `${taskDoc.id}_${userId}`;
        if (!completedPairs.has(pairKey) && userTokens[userId]) {
          notifications.push({
            token: userTokens[userId],
            title: '📋 Görev Hatırlatıcı',
            body: `"${task.title}" henüz tamamlanmadı!`,
          });
        }
      }
    }

    // Send notifications in batches
    const messaging = admin.messaging();
    const batchSize = 500;
    for (let i = 0; i < notifications.length; i += batchSize) {
      const batch = notifications.slice(i, i + batchSize);
      const messages = batch.map((n) => ({
        token: n.token,
        notification: { title: n.title, body: n.body },
        data: { type: 'task_reminder' },
        webpush: {
          notification: {
            title: n.title,
            body: n.body,
            icon: '/icons/Icon-192.png',
          },
          fcmOptions: { link: '/tasks' },
        },
      }));

      try {
        await messaging.sendEach(messages);
      } catch (err) {
        console.error('FCM batch error:', err);
      }
    }

    return null;
  });

// ─── Sheets Sync ─────────────────────────────────────────────────────────────
// Called via HTTPS when an activity log is created. Writes to the Drive spreadsheet.
export const syncActivityToSheets = functions.firestore
  .document('activityLogs/{logId}')
  .onCreate(async (snap, _context) => {
    const log = snap.data();
    if (!log) return;

    try {
      // Get settings for sheet ID + refresh token
      const settingsDoc = await db.collection('settings').doc('appSettings').get();
      if (!settingsDoc.exists) return;
      const settings = settingsDoc.data()!;
      const sheetId = settings.driveSheetId;
      const refreshToken = settings.googleRefreshToken;
      if (!sheetId || !refreshToken) return;

      // Get user and activity type names
      const [userDoc, typeDoc] = await Promise.all([
        db.collection('users').doc(log.userId).get(),
        db.collection('activityTypes').doc(log.activityTypeId).get(),
      ]);
      const userName = userDoc.data()?.name ?? log.userId;
      const typeName = typeDoc.data()?.name ?? log.activityTypeId;

      // Set up OAuth2 client
      const oauth2Client = new google.auth.OAuth2(
        functions.config().google?.client_id,
        functions.config().google?.client_secret,
      );
      oauth2Client.setCredentials({ refresh_token: refreshToken });

      const sheets = google.sheets({ version: 'v4', auth: oauth2Client });

      // Read current sheet to find/create column for this week
      const response = await sheets.spreadsheets.values.get({
        spreadsheetId: sheetId,
        range: `${typeName}!1:1`,
      });

      const headerRow: string[] = response.data.values?.[0] ?? [];
      let weekColIndex = headerRow.indexOf(log.weekLabel);

      if (weekColIndex === -1) {
        // Append new column
        weekColIndex = headerRow.length;
        await sheets.spreadsheets.values.update({
          spreadsheetId: sheetId,
          range: `${typeName}!${colLetter(weekColIndex + 1)}1`,
          valueInputOption: 'USER_ENTERED',
          requestBody: { values: [[log.weekLabel]] },
        });
      }

      // Find user row or append
      const rowsResponse = await sheets.spreadsheets.values.get({
        spreadsheetId: sheetId,
        range: `${typeName}!A:A`,
      });
      const userCol: string[] = rowsResponse.data.values?.map((r) => r[0]) ?? [];
      let userRowIndex = userCol.indexOf(userName);

      if (userRowIndex === -1) {
        userRowIndex = userCol.length;
        await sheets.spreadsheets.values.update({
          spreadsheetId: sheetId,
          range: `${typeName}!A${userRowIndex + 1}`,
          valueInputOption: 'USER_ENTERED',
          requestBody: { values: [[userName]] },
        });
      }

      // Write value
      const cellRef = `${typeName}!${colLetter(weekColIndex + 1)}${userRowIndex + 1}`;
      await sheets.spreadsheets.values.update({
        spreadsheetId: sheetId,
        range: cellRef,
        valueInputOption: 'USER_ENTERED',
        requestBody: { values: [[log.value]] },
      });

      // Mark synced in Firestore
      await snap.ref.update({ syncedToDrive: true });
    } catch (err) {
      console.error('Sheets sync error:', err);
    }
  });

function colLetter(n: number): string {
  let result = '';
  while (n > 0) {
    n--;
    result = String.fromCharCode(65 + (n % 26)) + result;
    n = Math.floor(n / 26);
  }
  return result;
}
