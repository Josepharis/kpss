const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");

admin.initializeApp();
setGlobalOptions({ region: "us-central1" });

const db = admin.firestore();

/**
 * Admin panelinden gelen manuel bildirimleri yönetir (V2).
 */
exports.handleManualNotification = onDocumentCreated("notifications/{docId}", async (event) => {
  console.log("🔔 Bildirim Tetiklendi: ", event.params.docId);
  const snapshot = event.data;
  if (!snapshot) return;
  
  const data = snapshot.data();
  if (!data.title || !data.body) return;

  const payload = {
    notification: {
      title: data.title,
      body: data.body,
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      type: "manual",
    },
  };

  try {
    if (data.target === "topic") {
      await admin.messaging().send({
        topic: "general",
        notification: payload.notification,
        data: payload.data
      });
      return snapshot.ref.update({
        status: "sent",
        method: "topic",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      let query = db.collection("users");
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      if (data.target === "active") {
        query = query.where("lastLogin", ">=", admin.firestore.Timestamp.fromDate(sevenDaysAgo));
      } else if (data.target === "inactive") {
        query = query.where("lastLogin", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo));
      }

      const usersSnap = await query.get();
      const tokens = [];
      usersSnap.forEach((doc) => {
        const userData = doc.data();
        if (userData.fcmToken) tokens.push(userData.fcmToken);
      });

      if (tokens.length > 0) {
        // V1 Messaging API (sendToDevice) supports up to 500 tokens. 
        // For professional scale, we use chunks.
        const chunks = [];
        for (let i = 0; i < tokens.length; i += 500) {
          chunks.push(tokens.slice(i, i + 500));
        }

        const sendPromises = chunks.map((chunk) =>
          admin.messaging().sendEachForMulticast({
            tokens: chunk,
            notification: payload.notification,
            data: payload.data
          })
        );
        await Promise.all(sendPromises);

        return snapshot.ref.update({
          status: "sent",
          method: "token_batch",
          sentCount: tokens.length,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      return snapshot.ref.update({ status: "no_tokens_found" });
    }
  } catch (error) {
    console.error("Bildirim gönderim hatası:", error);
    return snapshot.ref.update({ status: "failed", error: error.message });
  }
});

/**
 * OTOMATİK BİLDİRİM (V2): Her gün sabah 09:30 TSİ.
 */
exports.sendDailyMotivation = onSchedule({
  schedule: "30 9 * * *",
  timeZone: "Europe/Istanbul"
}, async (event) => {
  const messages = [
    "📚 Bugün hedeflerine bir adım daha yaklaşmaya ne dersin?",
    "🔥 Senin için yeni güncel bilgiler eklendi, hemen göz at!",
    "⏰ KPSS yolunda istikrar en büyük silahtır. Haydi derse!",
    "💡 Bugün 50 soru çözerek başlamak için harika bir gün."
  ];
  const randomMessage = messages[Math.floor(Math.random() * messages.length)];

  await admin.messaging().send({
    topic: "general",
    notification: {
      title: "Güne Harika Başla! 🚀",
      body: randomMessage,
    }
  });
});

/**
 * OTOMATİK BİLDİRİM (V2): Akşam 21:00 TSİ.
 */
exports.sendEveningReview = onSchedule({
  schedule: "0 21 * * *",
  timeZone: "Europe/Istanbul"
}, async (event) => {
  await admin.messaging().send({
    topic: "general",
    notification: {
      title: "📊 Günün Nasıl Geçti?",
      body: "Bugünkü çalışmalarını ve gelişim analizini kontrol etmeyi unutma.",
    }
  });
});
