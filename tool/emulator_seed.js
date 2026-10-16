// Seeds the local Firebase Emulator Suite with test accounts and data.
// Emulator-only credentials; never use these against the real project.
//
//   firebase emulators:start --project nab3-gded
//   node tool/emulator_seed.js
//
// Sign in from the app (run with --dart-define=USE_EMULATORS=true) using the
// phone numbers below and TEST_PASSWORD.

process.env.FIRESTORE_EMULATOR_HOST ||= "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= "127.0.0.1:9099";

const admin = require("../functions/node_modules/firebase-admin");

const TEST_PASSWORD = "naba-emulator-123";
const DISTRICT = "الخارجة";

const ACCOUNTS = [
  {uid: "t_admin", phone: "01000000001", role: "UserRole.admin", name: "أدمن تجريبي"},
  {uid: "t_farmer", phone: "01000000002", role: "UserRole.farmer", name: "مزارع تجريبي"},
  {uid: "t_seller", phone: "01000000003", role: "UserRole.seller", name: "بائع تجريبي",
    paymentMethod: "vodafoneCash", paymentDetails: "01000000003"},
  {uid: "t_worker", phone: "01000000004", role: "UserRole.worker", name: "عامل تجريبي",
    paymentMethod: "vodafoneCash", paymentDetails: "01000000004"},
  {uid: "t_delivery", phone: "01000000005", role: "UserRole.deliveryWorker", name: "مندوب تجريبي"},
];

async function main() {
  admin.initializeApp({projectId: "nab3-gded"});
  const db = admin.firestore();

  for (const a of ACCOUNTS) {
    try {
      await admin.auth().createUser({
        uid: a.uid, email: `${a.phone}@naba.app`, password: TEST_PASSWORD,
      });
    } catch (e) {
      if (e.code !== "auth/uid-already-exists") throw e;
    }
    await db.collection("users").doc(a.uid).set({
      role: a.role,
      fullName: a.name,
      phone: a.phone,
      nationalIdHash: "test",
      address: DISTRICT,
      status: "AccountStatus.approved",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      extraData: {district: DISTRICT, village: ""},
      paymentMethod: a.paymentMethod || null,
      paymentDetails: a.paymentDetails || null,
    });
  }

  await db.collection("catalog").doc("t_product").set({
    sellerUserId: "t_seller",
    name: "سماد عضوي",
    category: "أسمدة",
    unit: "شيكارة",
    price: 150,
    stockStatus: true,
    isApproved: true,
    description: "منتج تجريبي",
  });

  console.log(`Seeded ${ACCOUNTS.length} accounts and 1 product.`);
}

main().then(() => process.exit(0), (e) => {
  console.error(e);
  process.exit(1);
});
