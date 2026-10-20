const {onDocumentCreated, onDocumentUpdated} =
    require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({region: "us-central1"});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// FCM isn't emulated, so local runs log pushes instead of sending them.
const IS_EMULATOR = process.env.FUNCTIONS_EMULATOR === "true";

async function sendToUser(userId, notification, data = {}) {
  if (!userId) return null;
  const userDoc = await db.collection("users").doc(userId).get();
  const token = userDoc.exists ? userDoc.data().fcmToken : null;
  if (!token) return null;
  if (IS_EMULATOR) {
    console.log("[emulator] push to", userId, JSON.stringify(notification));
    return null;
  }
  return admin.messaging().send({token, notification, data});
}

/**
 * Credits a wallet exactly once per source document. The transaction doc id
 * is derived from the source, so a retried trigger can't double-credit.
 */
async function creditWallet({userId, amount, txId, note, extra = {}}) {
  if (!userId || !(amount > 0)) return;
  const txRef = db.collection("transactions").doc(txId);
  const walletRef = db.collection("wallets").doc(userId);

  await db.runTransaction(async (t) => {
    const existing = await t.get(txRef);
    if (existing.exists) return;
    t.set(txRef, {
      userId,
      type: "incoming",
      amount,
      note,
      ...extra,
      createdAt: FieldValue.serverTimestamp(),
    });
    t.set(walletRef, {
      userId,
      balance: FieldValue.increment(amount),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

// ---------------------------------------------------------------------------
// Wallets
// ---------------------------------------------------------------------------

const MAX_DELIVERY_FEE = 200;

// Orders paid by transfer (with a payment proof) credit the seller's wallet.
// Item prices come from the catalog, not from the client-submitted total.
exports.onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data && event.data.data();
  if (!order || !order.paymentProof) return;

  let subtotal = 0;
  for (const item of order.items || []) {
    if (!item.itemId) continue;
    const product = await db.collection("catalog").doc(item.itemId).get();
    if (!product.exists || product.data().sellerUserId !== order.sellerUserId) {
      continue;
    }
    const qty = Math.max(0, Number(item.quantity) || 0);
    subtotal += (Number(product.data().price) || 0) * qty;
  }
  const deliveryFee = Math.min(
      Math.max(0, Number(order.deliveryFee) || 0), MAX_DELIVERY_FEE);

  await creditWallet({
    userId: order.sellerUserId,
    amount: subtotal + deliveryFee,
    txId: `order_${event.params.orderId}`,
    note: `طلب من ${order.buyerName || "مشتري"} (${order.paymentMethod || ""})`,
    extra: {
      paymentMethod: order.paymentMethod || null,
      buyerName: order.buyerName || null,
      relatedId: event.params.orderId,
    },
  });
});

// A job paid by transfer (with a payment proof) credits the worker's wallet.
exports.onJobPaid = onDocumentUpdated("jobs/{jobId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!after || before.status === after.status) return;
  if (after.status !== "JobStatus.paid" || !after.paymentProof) return;

  await creditWallet({
    userId: after.assignedUserId,
    amount: Number(after.price) || 0,
    txId: `job_${event.params.jobId}`,
    note: `مقابل خدمة: ${after.serviceType || ""}`,
    extra: {relatedId: event.params.jobId},
  });
});

// ---------------------------------------------------------------------------
// Ratings
// ---------------------------------------------------------------------------

// Recomputes the reviewed user's average rating from all their reviews.
exports.onReviewCreated = onDocumentCreated("reviews/{reviewId}", async (event) => {
  const review = event.data && event.data.data();
  if (!review || !review.reviewedUserId) return;

  const snap = await db.collection("reviews")
      .where("reviewedUserId", "==", review.reviewedUserId)
      .get();
  if (snap.empty) return;

  let total = 0;
  snap.forEach((d) => {
    total += Number(d.data().stars) || 0;
  });
  const count = snap.size;

  // Both count fields are written because different screens read each.
  await db.collection("users").doc(review.reviewedUserId).update({
    "extraData.rating": total / count,
    "extraData.reviewCount": count,
    "extraData.ratingCount": count,
  });
});

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

// Notify the farmer when a worker submits a bid.
exports.onNewBid = onDocumentCreated("jobs/{jobId}/bids/{bidId}", async (event) => {
  const bid = event.data && event.data.data();
  if (!bid) return;
  const jobDoc = await db.collection("jobs").doc(event.params.jobId).get();
  if (!jobDoc.exists) return;

  await sendToUser(jobDoc.data().requesterUserId, {
    title: "عرض سعر جديد!",
    body: `تلقيت عرض سعر بقيمة ${bid.currentPrice} ج.م من ${bid.workerName}`,
  }, {jobId: event.params.jobId});
});

// Notify all workers when a new worker job is broadcast.
exports.onJobRequested = onDocumentCreated("jobs/{jobId}", async (event) => {
  const job = event.data && event.data.data();
  if (!job || job.status !== "JobStatus.requested" || job.type !== "worker") {
    return;
  }

  const workersSnap = await db.collection("users")
      .where("role", "==", "UserRole.worker")
      .get();
  const tokens = [];
  workersSnap.forEach((doc) => {
    const token = doc.data().fcmToken;
    if (token) tokens.push(token);
  });

  if (IS_EMULATOR) {
    console.log("[emulator] job broadcast to", tokens.length, "workers");
    return;
  }
  // sendEachForMulticast accepts at most 500 tokens per call.
  for (let i = 0; i < tokens.length; i += 500) {
    await admin.messaging().sendEachForMulticast({
      tokens: tokens.slice(i, i + 500),
      notification: {
        title: "طلب عمل جديد متاح!",
        body: `مهمة جديدة: ${job.serviceType} بانتظار العروض.`,
      },
      data: {jobId: event.params.jobId},
    });
  }
});

// Every in-app notification (approvals, land listing reviews, viewing
// requests, delivery updates...) is also sent as a push to the user's phone.
exports.onUserNotificationCreated = onDocumentCreated(
    "users/{userId}/notifications/{notificationId}", async (event) => {
      const n = event.data && event.data.data();
      if (!n || !n.title) return;
      await sendToUser(event.params.userId, {
        title: String(n.title),
        body: String(n.body || ""),
      }, {
        type: String(n.type || ""),
        listingId: String(n.listingId || ""),
      });
    });

// Notify the equipment owner of a rental request.
exports.onRentalRequest = onDocumentCreated("rental_requests/{requestId}", async (event) => {
  const req = event.data && event.data.data();
  if (!req) return;
  await sendToUser(req.equipmentOwnerId, {
    title: "طلب إيجار معدة!",
    body: `يطلب ${req.requesterName} معدة ${req.equipmentName}`,
  });
});

// ---------------------------------------------------------------------------
// Irrigation rotation ("الدور")
// ---------------------------------------------------------------------------

// In-app notification (also pushed by onUserNotificationCreated).
function notifyUser(userId, title, body, extra = {}) {
  if (!userId) return Promise.resolve();
  return db.collection("users").doc(userId).collection("notifications").add({
    title, body, isRead: false, createdAt: FieldValue.serverTimestamp(), ...extra,
  });
}

function turnUser(turn) {
  const ids = turn.memberIds || [];
  return ids.length ? ids[(turn.currentIndex || 0) % ids.length] : null;
}

function hoursText(h) {
  if (h === 1) return "ساعة";
  if (h === 2) return "ساعتين";
  return Number.isInteger(h) ? `${h} ساعات` : `${h} ساعة`;
}

// Tell the next member when the turn reaches them, and everyone when the
// well stops or starts again.
exports.onWellTurnUpdated = onDocumentUpdated("well_turns/{wellId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  const wellName = after.wellName || "البئر";
  const extra = {type: "well_turn", wellId: event.params.wellId};
  const jobs = [];

  const turnMoved = before.currentIndex !== after.currentIndex ||
      before.cycle !== after.cycle;
  if (turnMoved && after.state === "waiting") {
    const uid = turnUser(after);
    const h = (after.hours || {})[uid] || 1;
    jobs.push(notifyUser(uid, "دورك في الري جه",
        `${wellName}: حصتك ${hoursText(h)}. افتح المية ودوس «بدأت».`, extra));
  }

  if (before.state !== "paused" && after.state === "paused") {
    for (const uid of after.memberIds || []) {
      jobs.push(notifyUser(uid, `${wellName} واقف`,
          `${after.pauseReason || "البئر وقف"}، والمواعيد هتتأخر لحد ما يرجع.`, extra));
    }
  }
  if (before.state === "paused" && after.state === "running") {
    for (const uid of after.memberIds || []) {
      jobs.push(notifyUser(uid, `${wellName} رجع يشتغل`,
          "الدور كمل، شوف ميعادك الجديد في التطبيق.", extra));
    }
  }
  await Promise.all(jobs);
});

// About an hour before a running turn ends, remind the next member. Runs
// every 10 minutes; reminderKey makes sure each turn reminds only once.
exports.turnReminders = onSchedule("every 10 minutes", async () => {
  const snap = await db.collection("well_turns")
      .where("state", "==", "running").get();
  const now = Date.now();
  const jobs = [];
  snap.forEach((doc) => {
    const t = doc.data();
    const ids = t.memberIds || [];
    if (ids.length < 2 || !t.startedAt) return;
    const current = turnUser(t);
    const allotted = ((t.hours || {})[current] || 1) * 60;
    const elapsed = (now - t.startedAt.toMillis()) / 60000 - (t.pausedMinutes || 0);
    const remaining = allotted - elapsed;
    const key = `${t.cycle || 0}_${t.currentIndex || 0}`;
    if (remaining > 60 || remaining < 0 || t.reminderKey === key) return;

    const next = ids[((t.currentIndex || 0) + 1) % ids.length];
    const mins = Math.max(5, Math.round(remaining / 5) * 5);
    jobs.push(notifyUser(next, "قرّب دورك في الري",
        `${t.wellName || "البئر"}: دورك بعد حوالي ${mins} دقيقة.`,
        {type: "well_turn", wellId: doc.id}));
    jobs.push(doc.ref.update({reminderKey: key}));
  });
  await Promise.all(jobs);
});
