const {onDocumentCreated, onDocumentUpdated} =
    require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
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

// Notify the equipment owner of a rental request.
exports.onRentalRequest = onDocumentCreated("rental_requests/{requestId}", async (event) => {
  const req = event.data && event.data.data();
  if (!req) return;
  await sendToUser(req.equipmentOwnerId, {
    title: "طلب إيجار معدة!",
    body: `يطلب ${req.requesterName} معدة ${req.equipmentName}`,
  });
});
