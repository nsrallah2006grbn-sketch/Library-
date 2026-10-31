import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth.dart';
import 'data.dart';
import 'firebase_options.dart'; // يتم توليده بالأمر: flutterfire configure

// ضع هنا رابط التطبيق بعد نشره على Google Play
const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.yourname.arabic_student_library';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    );
  }
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'المكتبة الطلابية العربية',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0F5C7A)),
        home: kIsWeb
            ? const DownloadGate()
            : StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (c, s) => s.connectionState == ConnectionState.waiting
                    ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                    : s.data == null
                        ? const AuthFlow()
                        : AccessGate(builder: (country) => Home(country: country)),
              ),
      );
}

// ---------- صفحة الويب: التطبيق إلزامي ----------
class DownloadGate extends StatelessWidget {
  const DownloadGate({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_library, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text('المكتبة الطلابية العربية', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('مناهج من الأول الابتدائي إلى الثالث الثانوي لجميع الدول العربية.\nحمّل التطبيق للدخول والاستفادة.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('تحميل من Google Play'),
                  onPressed: () => launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ---------- الهيكل الرئيسي ----------
class Home extends StatelessWidget {
  final String country;
  const Home({super.key, required this.country});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.doc('admins/$uid').snapshots(),
      builder: (c, s) => HomeShell(isAdmin: s.data?.exists ?? false, country: country),
    );
  }
}

class HomeShell extends StatefulWidget {
  final bool isAdmin;
  final String country;
  const HomeShell({super.key, required this.isAdmin, required this.country});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [LibraryPage(country: widget.country), UploadPage(country: widget.country), if (widget.isAdmin) const AdminPage()];
    final idx = i >= pages.length ? 0 : i;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المكتبة الطلابية العربية'),
        actions: [IconButton(tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.menu_book), label: 'المكتبة'),
          const NavigationDestination(icon: Icon(Icons.upload_file), label: 'رفع كتاب'),
          if (widget.isAdmin) const NavigationDestination(icon: Icon(Icons.verified), label: 'المراجعة'),
        ],
      ),
    );
  }
}

// ---------- بطاقة الكتاب (الضغط عليها يفتح الملف، وهذا ما يستخدمه الأدمن للمعاينة) ----------
class BookTile extends StatelessWidget {
  final Map<String, dynamic> b;
  final Widget? actions;
  const BookTile(this.b, {super.key, this.actions});
  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      for (final x in [b['author'], countryByCode('${b['country']}')?.name, b['grade'], b['subject']])
        if (x != null && '$x'.isNotEmpty) '$x'
    ];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, size: 36),
        title: Text('${b['title']}'),
        subtitle: Text(parts.join(' • ')),
        trailing: actions ?? const Icon(Icons.open_in_new),
        onTap: () => launchUrl(Uri.parse('${b['url']}'), mode: LaunchMode.externalApplication),
      ),
    );
  }
}

// ---------- المكتبة ----------
class LibraryPage extends StatefulWidget {
  final String country;
  const LibraryPage({super.key, required this.country});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late String cc = widget.country;
  String? grade;
  String q = '';
  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('books')
        .where('status', isEqualTo: 'approved')
        .where('country', isEqualTo: cc);
    if (grade != null) query = query.where('grade', isEqualTo: grade);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => q = v.trim()),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بعنوان الكتاب أو المؤلف', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: cc,
            underline: const SizedBox(),
            items: [for (final k in countries) DropdownMenuItem(value: k.code, child: Text('${k.flag} ${k.name}'))],
            onChanged: (v) => setState(() => cc = v ?? cc),
          ),
        ]),
      ),
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
          for (final g in [null, ...grades])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(label: Text(g ?? 'كل الصفوف'), selected: grade == g, onSelected: (_) => setState(() => grade = g)),
            ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (c, s) {
            if (s.hasError) return const Center(child: Text('تعذر تحميل الكتب'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final docs = s.data!.docs.where((d) {
              final b = d.data();
              return q.isEmpty || '${b['title']} ${b['author']}'.contains(q);
            }).toList();
            if (docs.isEmpty) return const Center(child: Text('لا توجد كتب بعد'));
            return ListView(children: [for (final d in docs) BookTile(d.data())]);
          },
        ),
      ),
    ]);
  }
}

// ---------- رفع كتاب ----------
class UploadPage extends StatefulWidget {
  final String country;
  const UploadPage({super.key, required this.country});
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final title = TextEditingController(), author = TextEditingController(), subject = TextEditingController();
  late String cc = widget.country;
  String? grade;
  PlatformFile? file;
  bool busy = false, agree = false;

  void msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (r != null) setState(() => file = r.files.single);
  }

  Future<void> send() async {
    if (title.text.trim().isEmpty || grade == null || file?.path == null) {
      msg('أدخل عنوان الكتاب واختر الصف وملف PDF');
      return;
    }
    if (!agree) { msg('يجب الإقرار بملكية حقوق الكتاب أو إذن نشره'); return; }
    if (file!.size > 50 * 1024 * 1024) { msg('الحد الأقصى لحجم الملف 50 ميغابايت'); return; }
    setState(() => busy = true);
    try {
      final head = await File(file!.path!).openRead(0, 5).first;
      if (String.fromCharCodes(head) != '%PDF-') { msg('الملف ليس PDF صالحًا'); setState(() => busy = false); return; }
      final u = FirebaseAuth.instance.currentUser!;
      final ref = FirebaseStorage.instance.ref('books/${u.uid}/${DateTime.now().millisecondsSinceEpoch}.pdf');
      await ref.putFile(File(file!.path!), SettableMetadata(contentType: 'application/pdf'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('books').add({
        'title': title.text.trim(),
        'author': author.text.trim(),
        'subject': subject.text.trim(),
        'grade': grade,
        'country': cc,
        'url': url,
        'status': 'pending',
        'uploaderId': u.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      title.clear(); author.clear(); subject.clear();
      setState(() { file = null; grade = null; agree = false; });
      msg('تم إرسال الكتاب للمراجعة، وسيظهر بعد موافقة المشرف');
    } catch (e) {
      msg('تعذر الرفع، حاول مرة أخرى');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الكتاب', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: author, decoration: const InputDecoration(labelText: 'المؤلف (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: subject, decoration: const InputDecoration(labelText: 'المادة (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: cc,
          decoration: const InputDecoration(labelText: 'مناهج أي دولة؟', border: OutlineInputBorder()),
          items: [for (final k in countries) DropdownMenuItem(value: k.code, child: Text('${k.flag} ${k.name}'))],
          onChanged: (v) => setState(() => cc = v ?? cc),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: grade,
          decoration: const InputDecoration(labelText: 'الصف الدراسي', border: OutlineInputBorder()),
          items: [for (final g in grades) DropdownMenuItem(value: g, child: Text(g))],
          onChanged: (v) => setState(() => grade = v),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: pick, icon: const Icon(Icons.attach_file), label: Text(file?.name ?? 'اختر ملف PDF')),
        CheckboxListTile(
          value: agree,
          onChanged: (v) => setState(() => agree = v ?? false),
          title: const Text('أقر بأنني أملك حقوق هذا الكتاب أو لدي إذن بنشره'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        FilledButton(onPressed: busy ? null : send, child: Text(busy ? 'جارٍ الرفع...' : 'إرسال للمراجعة')),
      ]);
}

// ---------- مراجعة المشرف: اضغط على الكتاب لفتحه ثم اقبل أو ارفض ----------
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('books').where('status', isEqualTo: 'pending').snapshots(),
        builder: (c, s) {
          if (s.hasError) return const Center(child: Text('تعذر التحميل'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.docs.isEmpty) return const Center(child: Text('لا توجد كتب بانتظار المراجعة'));
          return ListView(children: [
            for (final d in s.data!.docs)
              BookTile(d.data(),
                  actions: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'قبول', icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => d.reference.update({'status': 'approved'})),
                    IconButton(tooltip: 'رفض', icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => d.reference.update({'status': 'rejected'})),
                  ])),
          ]);
        },
      );
}
