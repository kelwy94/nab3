const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// 1. Notify Farmer when a new Bid is submitted by a worker
exports.onNewBid = functions.firestore
    .document("jobs/{jobId}/job_bids/{bidId}")
    .onCreate(async (snap, context) => {
        const bid = snap.data();
        const jobId = context.params.jobId;

        // Get the job to find the farmer's ID
        const jobDoc = await admin.firestore().collection("jobs").doc(jobId).get();
        if (!jobDoc.exists) return null;
        const farmerId = jobDoc.data().requesterUserId;

        // Get the farmer's FCM token
        const userDoc = await admin.firestore().collection("users").doc(farmerId).get();
        if (!userDoc.exists) return null;
        const fcmToken = userDoc.data().fcmToken;

        if (fcmToken) {
            const payload = {
                notification: {
                    title: "عرض سعر جديد!",
                    body: `تلقيت عرض سعر بقيمة ${bid.currentPrice} ج.م من ${bid.workerName}`,
                },
                data: {
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                    jobId: jobId,
                },
            };
            return admin.messaging().sendToDevice(fcmToken, payload);
        }
        return null;
    });

// 2. Notify Workers when a new job is broadcasting
exports.onJobRequested = functions.firestore
    .document("jobs/{jobId}")
    .onCreate(async (snap, context) => {
        const job = snap.data();

        // If it's a broadcast looking for workers
        if (job.status === "JobStatus.requested" && job.type === "worker") {
            const workersSnap = await admin.firestore().collection("users").where("role", "==", "UserRole.worker").get();

            const tokens = [];
            workersSnap.forEach((doc) => {
                const u = doc.data();
                if (u.fcmToken) tokens.push(u.fcmToken);
            });

            if (tokens.length > 0) {
                const payload = {
                    notification: {
                        title: "طلب عمل جديد متاح!",
                        body: `مهمة جديدة: ${job.serviceType} بانتظار العروض.`,
                    }
                };
                return admin.messaging().sendToDevice(tokens, payload);
            }
        }
        return null;
    });

// 3. Notify Equipment Owner when a rental request is made
exports.onRentalRequest = functions.firestore
    .document("rental_requests/{requestId}")
    .onCreate(async (snap, context) => {
        const req = snap.data();

        const ownerDoc = await admin.firestore().collection("users").doc(req.equipmentOwnerId).get();
        if (!ownerDoc.exists) return null;
        const fcmToken = ownerDoc.data().fcmToken;

        if (fcmToken) {
            const payload = {
                notification: {
                    title: "طلب إيجار معدة!",
                    body: `يطلب ${req.requesterName} معدة ${req.equipmentName}`,
                }
            };
            return admin.messaging().sendToDevice(fcmToken, payload);
        }
        return null;
    });
