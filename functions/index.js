const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
admin.initializeApp();

const IPINFO = defineSecret('IPINFO_TOKEN');

const DIAL = {
  SA: ['+966'], AE: ['+971'], KW: ['+965'], QA: ['+974'], BH: ['+973'], OM: ['+968'],
  YE: ['+967'], JO: ['+962'], LB: ['+961'], SY: ['+963'], IQ: ['+964'], PS: ['+970', '+972'],
  EG: ['+20'], LY: ['+218'], TN: ['+216'], DZ: ['+213'], MA: ['+212'], MR: ['+222'],
  SD: ['+249'], SO: ['+252'], DJ: ['+253'], KM: ['+269'],
};

// يتحقق من: (1) رقم الهاتف يطابق الدولة (2) دولة الـ IP تطابق (3) عدم وجود VPN/Proxy
// ثم يكتب users/{uid}.verified. العميل لا يستطيع تعديل هذا الحقل (قواعد Firestore تمنع ذلك).
exports.verifyAccess = onCall({ secrets: [IPINFO], enforceAppCheck: true }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'سجّل الدخول أولًا');
  const ref = admin.firestore().doc(`users/${req.auth.uid}`);
  const snap = await ref.get();
  // الدولة تُقفل عند أول تحقق ولا يمكن تغييرها لاحقًا
  const country = (snap.exists && snap.data().country) || String((req.data && req.data.country) || '').toUpperCase();
  const dials = DIAL[country];
  if (!dials) throw new HttpsError('invalid-argument', 'دولة غير صالحة');

  const phone = req.auth.token.phone_number || '';
  const ip = req.rawRequest.ip;
  let reason = null;

  if (!dials.some((d) => phone.startsWith(d))) {
    reason = 'phone';
  } else {
    try {
      const r = await fetch(`https://ipinfo.io/${ip}?token=${IPINFO.value()}`);
      const j = await r.json();
      const p = j.privacy || {};
      if (j.country !== country && !(country === 'PS' && j.country === 'IL')) reason = 'ip_country';
      else if (p.vpn || p.proxy || p.tor || p.relay) reason = 'vpn';
    } catch (e) {
      reason = 'network'; // عند تعذر الفحص نمنع الدخول (صارم)
    }
  }

  const ok = reason === null;
  await ref.set({
    country, phone, verified: ok, reason,
    checkedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return { ok, reason, country };
});
