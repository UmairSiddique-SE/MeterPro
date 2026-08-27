const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const emailJsServiceId = defineSecret('EMAILJS_SERVICE_ID');
const emailJsTemplateId = defineSecret('EMAILJS_TEMPLATE_ID');
const emailJsPublicKey = defineSecret('EMAILJS_PUBLIC_KEY');
const emailJsPrivateKey = defineSecret('EMAILJS_PRIVATE_KEY');
const OTP_TTL_MS = 5 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_ATTEMPTS = 5;
const APP_NAME = 'MeterUnit';

function requireUser(request) {
  if (!request.auth?.uid || !request.auth.token.email) {
    throw new HttpsError('unauthenticated', 'Sign in before verifying your email.');
  }
  return {uid: request.auth.uid, email: request.auth.token.email};
}

function hashOtp(code, salt) {
  return new Promise((resolve, reject) => {
    crypto.scrypt(code, salt, 64, (error, derivedKey) => {
      if (error) reject(error);
      else resolve(derivedKey.toString('hex'));
    });
  });
}

exports.requestEmailOtp = onCall(
  {region: 'us-central1', secrets: [emailJsServiceId, emailJsTemplateId, emailJsPublicKey, emailJsPrivateKey]},
  async (request) => {
    const {uid, email} = requireUser(request);
    const otpRef = admin.firestore().collection('emailOtps').doc(uid);
    const previous = await otpRef.get();
    const lastSent = previous.data()?.sentAt?.toMillis();
    if (lastSent && Date.now() - lastSent < RESEND_COOLDOWN_MS) {
      throw new HttpsError('resource-exhausted', 'Wait one minute before requesting another code.');
    }

    const code = crypto.randomInt(100000, 1000000).toString();
    const salt = crypto.randomBytes(16).toString('hex');
    const codeHash = await hashOtp(code, salt);
    await otpRef.set({
      codeHash,
      salt,
      sentAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + OTP_TTL_MS),
      attempts: 0,
    });

    try {
      const requestedName = typeof request.data?.name === 'string' ? request.data.name.trim() : '';
      const toName = requestedName || request.auth.token.name || email.split('@')[0];
      const subject = `${APP_NAME} verification code: ${code}`;
      const message = `Your ${APP_NAME} verification code is ${code}. It expires in 5 minutes.`;
      const response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          service_id: emailJsServiceId.value(),
          template_id: emailJsTemplateId.value(),
          user_id: emailJsPublicKey.value(),
          accessToken: emailJsPrivateKey.value(),
          template_params: {
            to_email: email,
            recipient_email: email,
            to: email,
            email,
            user_email: email,
            reply_to: email,
            to_name: toName,
            name: toName,
            user_name: toName,
            from_name: APP_NAME,
            otp_code: code,
            verification_code: code,
            code,
            passcode: code,
            subject,
            message,
            app_name: APP_NAME,
          },
        }),
      });
      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`EmailJS returned ${response.status}: ${errorText}`);
      }
    } catch (error) {
      await otpRef.delete();
      console.error('OTP email delivery failed', error);
      throw new HttpsError('internal', 'Unable to send the verification email.');
    }
    return {expiresInSeconds: OTP_TTL_MS / 1000};
  },
);

exports.verifyEmailOtp = onCall(
  {region: 'us-central1'},
  async (request) => {
  const {uid} = requireUser(request);
  const code = request.data?.code;
  if (typeof code !== 'string' || !/^\d{6}$/.test(code)) {
    throw new HttpsError('invalid-argument', 'Enter a six-digit code.');
  }
  const otpRef = admin.firestore().collection('emailOtps').doc(uid);
  const verified = await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(otpRef);
    const otp = snapshot.data();
    if (!otp || otp.expiresAt.toMillis() <= Date.now() || otp.attempts >= MAX_ATTEMPTS) {
      transaction.delete(otpRef);
      return false;
    }
    const submittedHash = await hashOtp(code, otp.salt);
    const matches = crypto.timingSafeEqual(Buffer.from(submittedHash, 'hex'), Buffer.from(otp.codeHash, 'hex'));
    if (!matches) {
      transaction.update(otpRef, {attempts: admin.firestore.FieldValue.increment(1)});
      return false;
    }
    transaction.delete(otpRef);
    return true;
  });
  if (!verified) throw new HttpsError('permission-denied', 'Invalid or expired code.');
  await admin.auth().setCustomUserClaims(uid, {emailOtpVerified: true});
  return {verified: true};
  },
);
