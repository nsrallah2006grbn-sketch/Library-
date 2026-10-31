import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'data.dart';

String? pendingCountry; // الدولة المختارة عند أول تسجيل

Future<bool> vpnActive() async {
  final r = await Connectivity().checkConnectivity();
  return r.contains(ConnectivityResult.vpn);
}

const _radius = BorderRadius.all(Radius.circular(14));

// ================= تسجيل الدخول: دولة ← هاتف ← رمز =================
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  int step = 0, resend = 0;
  Country? country;
  final phone = TextEditingController(), otp = TextEditingController();
  String? verificationId, error;
  String q = '';
  bool busy = false;
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    timer?.cancel();
    setState(() => resend = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => resend--);
      if (resend <= 0) t.cancel();
    });
  }

  Future<void> sendCode() async {
    final n = phone.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
    if (n.length < 7 || n.length > 11) {
      setState(() => error = 'رقم الهاتف غير صحيح');
      return;
    }
    setState(() { busy = true; error = null; });
    if (await vpnActive()) {
      if (mounted) setState(() { busy = false; error = 'تم اكتشاف VPN. أوقفه ثم حاول مرة أخرى.'; });
      return;
    }
    pendingCountry = country!.code;
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '${country!.dial}$n',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        try { await FirebaseAuth.instance.signInWithCredential(cred); } catch (_) {}
      },
      verificationFailed: (e) {
        if (mounted) setState(() { busy = false; error = 'تعذر إرسال الرمز. تأكد من الرقم وحاول لاحقًا.'; });
      },
      codeSent: (id, _) {
        if (!mounted) return;
        verificationId = id;
        setState(() { busy = false; step = 2; error = null; });
        startTimer();
      },
      codeAutoRetrievalTimeout: (id) => verificationId = id,
    );
  }

  Future<void> confirm() async {
    if (otp.text.trim().length != 6 || verificationId == null) return;
    setState(() { busy = true; error = null; });
    try {
      await FirebaseAuth.instance.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: otp.text.trim()));
    } on FirebaseAuthException {
      if (mounted) setState(() => error = 'الرمز غير صحيح أو منتهي الصلاحية');
    }
    if (mounted) setState(() => busy = false);
  }

  Widget errorBox() => error == null
      ? const SizedBox(height: 8)
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        );

  Widget pickCountry() {
    final list = countries.where((c) => c.name.contains(q) || c.dial.contains(q)).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          onChanged: (v) => setState(() => q = v.trim()),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن دولتك', border: OutlineInputBorder(borderRadius: _radius)),
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (c, i) {
            final k = list[i];
            return ListTile(
              leading: Text(k.flag, style: const TextStyle(fontSize: 28)),
              title: Text(k.name),
              trailing: Text(k.dial, textDirection: TextDirection.ltr),
              onTap: () => setState(() { country = k; step = 1; error = null; }),
            );
          },
        ),
      ),
    ]);
  }

  Widget enterPhone() => ListView(padding: const EdgeInsets.all(24), children: [
        Card(
          child: ListTile(
            leading: Text(country!.flag, style: const TextStyle(fontSize: 28)),
            title: Text(country!.name),
            trailing: TextButton(onPressed: () => setState(() => step = 0), child: const Text('تغيير')),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: 'رقم الهاتف', prefixText: '${country!.dial} ', border: const OutlineInputBorder(borderRadius: _radius)),
        ),
        errorBox(),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: busy ? null : sendCode,
            child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('إرسال رمز التحقق'),
          ),
        ),
        const SizedBox(height: 16),
        Text('يُقبل رقم هاتف من ${country!.name} فقط، ولا يُسمح بالدخول عبر VPN.',
            textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
      ]);

  Widget enterOtp() => ListView(padding: const EdgeInsets.all(24), children: [
        Text('أرسلنا رمزًا من 6 أرقام إلى ${country!.dial}${phone.text.replaceFirst(RegExp(r'^0+'), '')}',
            textAlign: TextAlign.center, textDirection: TextDirection.rtl),
        const SizedBox(height: 20),
        TextField(
          controller: otp,
          maxLength: 6,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 28, letterSpacing: 10),
          decoration: const InputDecoration(counterText: '', border: OutlineInputBorder(borderRadius: _radius)),
          onChanged: (v) { if (v.length == 6) confirm(); },
        ),
        errorBox(),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: busy ? null : confirm,
            child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تأكيد'),
          ),
        ),
        TextButton(
          onPressed: resend > 0 || busy ? null : sendCode,
          child: Text(resend > 0 ? 'إعادة الإرسال بعد $resend ثانية' : 'إعادة إرسال الرمز'),
        ),
        TextButton(onPressed: () => setState(() { step = 1; otp.clear(); error = null; }), child: const Text('تغيير الرقم')),
      ]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 28, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [cs.primary, cs.primary.withOpacity(.75)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(children: [
            const Icon(Icons.local_library, size: 56, color: Colors.white),
            const SizedBox(height: 8),
            const Text('المكتبة الطلابية العربية', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(['اختر دولتك', 'أدخل رقم هاتفك', 'أدخل رمز التحقق'][step], style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(key: ValueKey(step), child: [pickCountry(), enterPhone(), enterOtp()][step]),
          ),
        ),
      ]),
    );
  }
}

// ================= بوابة التحقق من الخادم (دولة + IP + VPN) =================
class AccessGate extends StatefulWidget {
  final Widget Function(String country) builder;
  const AccessGate({super.key, required this.builder});
  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> with WidgetsBindingObserver {
  Map<String, dynamic>? res;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    run();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) run(); // إعادة الفحص كل مرة يرجع فيها المستخدم للتطبيق
  }

  Future<Map<String, dynamic>> check() async {
    if (await vpnActive()) return {'ok': false, 'reason': 'vpn'};
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('verifyAccess').call({'country': pendingCountry});
      return Map<String, dynamic>.from(r.data as Map);
    } catch (e) {
      return {'ok': false, 'reason': 'network'};
    }
  }

  Future<void> run() async {
    final r = await check();
    if (mounted) setState(() => res = r);
  }

  static const messages = {
    'vpn': 'تم اكتشاف VPN أو بروكسي. أوقفه ثم أعد المحاولة.',
    'phone': 'رقم هاتفك لا يطابق الدولة المختارة.',
    'ip_country': 'موقع اتصالك بالإنترنت لا يطابق دولتك المسجّلة.',
    'network': 'تعذر التحقق. تأكد من الاتصال بالإنترنت ثم أعد المحاولة.',
  };

  @override
  Widget build(BuildContext context) {
    final r = res;
    if (r == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (r['ok'] == true) return widget.builder('${r['country']}');
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_outlined, size: 72, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(messages['${r['reason']}'] ?? 'تعذر السماح بالدخول.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: () { setState(() => res = null); run(); }, child: const Text('إعادة المحاولة')),
            TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('تسجيل الخروج')),
          ]),
        ),
      ),
    );
  }
}
