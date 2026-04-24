
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();

  const settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await notificationsPlugin.initialize(settings);

  runApp(const BorcKocuApp());
}

enum PayoffStrategy { avalanche, snowball }
enum AppThemeMode { safe, blue, pink, dark, yellow, green }
enum AppLanguage { tr, en }
enum DebtType { loan, creditCard, overdraft }
enum AppCurrency { tryCurrency, usd, eur, gbp }

class PaymentRecord {
  final double amount;
  final String date;

  PaymentRecord({required this.amount, required this.date});

  Map<String, dynamic> toJson() => {'amount': amount, 'date': date};

  static PaymentRecord fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
    );
  }
}

class Debt {
  final String id;
  final String name;
  final DebtType type;
  final double amount;
  final double originalAmount;
  final double interest;
  final double minimum;
  final int paymentDay;
  final int? termMonths;
  final int? statementDay;
  final int? dueDay;
  final bool reminderEnabled;
  final List<PaymentRecord> payments;

  Debt({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.originalAmount,
    required this.interest,
    required this.minimum,
    required this.paymentDay,
    required this.termMonths,
    required this.statementDay,
    required this.dueDay,
    required this.reminderEnabled,
    required this.payments,
  });

  Debt copyWith({
    String? id,
    String? name,
    DebtType? type,
    double? amount,
    double? originalAmount,
    double? interest,
    double? minimum,
    int? paymentDay,
    int? termMonths,
    int? statementDay,
    int? dueDay,
    bool? reminderEnabled,
    List<PaymentRecord>? payments,
  }) {
    return Debt(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      originalAmount: originalAmount ?? this.originalAmount,
      interest: interest ?? this.interest,
      minimum: minimum ?? this.minimum,
      paymentDay: paymentDay ?? this.paymentDay,
      termMonths: termMonths ?? this.termMonths,
      statementDay: statementDay ?? this.statementDay,
      dueDay: dueDay ?? this.dueDay,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      payments: payments ?? this.payments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'amount': amount,
        'originalAmount': originalAmount,
        'interest': interest,
        'minimum': minimum,
        'paymentDay': paymentDay,
        'termMonths': termMonths,
        'statementDay': statementDay,
        'dueDay': dueDay,
        'reminderEnabled': reminderEnabled,
        'payments': payments.map((e) => e.toJson()).toList(),
      };

  static Debt fromJson(Map<String, dynamic> json) {
    int typeIndex = 0;
    final rawType = json['type'];
    if (rawType is int) typeIndex = rawType;
    if (typeIndex < 0 || typeIndex >= DebtType.values.length) typeIndex = 0;

    return Debt(
      id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      type: DebtType.values[typeIndex],
      amount: (json['amount'] ?? 0).toDouble(),
      originalAmount: (json['originalAmount'] ?? json['amount'] ?? 0).toDouble(),
      interest: (json['interest'] ?? 0).toDouble(),
      minimum: (json['minimum'] ?? 0).toDouble(),
      paymentDay: json['paymentDay'] ?? json['dueDay'] ?? 1,
      termMonths: json['termMonths'],
      statementDay: json['statementDay'],
      dueDay: json['dueDay'],
      reminderEnabled: json['reminderEnabled'] ?? false,
      payments: ((json['payments'] ?? []) as List)
          .map((e) => PaymentRecord.fromJson(e))
          .toList(),
    );
  }
}

class MonthPlan {
  final int month;
  final double startingDebt;
  final double interestAdded;
  final double paymentMade;
  final double endingDebt;

  MonthPlan({
    required this.month,
    required this.startingDebt,
    required this.interestAdded,
    required this.paymentMade,
    required this.endingDebt,
  });
}

class SimulationResult {
  final int months;
  final double totalInterest;
  final List<MonthPlan> plans;

  SimulationResult({
    required this.months,
    required this.totalInterest,
    required this.plans,
  });
}

class ThemeColors {
  final Color background;
  final Color card;
  final Color cardAlt;
  final Color primary;
  final Color soft;
  final Color text;
  final Color muted;
  final Color success;
  final Color danger;
  final Color chartLine;

  ThemeColors({
    required this.background,
    required this.card,
    required this.cardAlt,
    required this.primary,
    required this.soft,
    required this.text,
    required this.muted,
    required this.success,
    required this.danger,
    required this.chartLine,
  });
}

class BorcKocuApp extends StatelessWidget {
  const BorcKocuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Borç Strateji Koçu',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Debt> debts = [];
  double monthlyIncome = 0;
  double savingsAmount = 0;
  bool isPremium = false;
  AppThemeMode selectedTheme = AppThemeMode.safe;
  AppLanguage selectedLanguage = AppLanguage.tr;
  AppCurrency selectedCurrency = AppCurrency.tryCurrency;

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
    loadData();
  }

  Future<void> requestNotificationPermission() async {
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> sendNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'borc_kocu_channel',
      'Borç Koçu Bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  ThemeColors get colors {
    switch (selectedTheme) {
      case AppThemeMode.blue:
        return ThemeColors(
          background: const Color(0xFF0F172A),
          card: const Color(0xFF1E293B),
          cardAlt: const Color(0xFF263449),
          primary: const Color(0xFF60A5FA),
          soft: const Color(0xFF334155),
          text: const Color(0xFFF8FAFC),
          muted: const Color(0xFFCBD5E1),
          success: const Color(0xFF22C55E),
          danger: const Color(0xFFEF4444),
          chartLine: const Color(0xFFEF4444),
        );
      case AppThemeMode.dark:
        return ThemeColors(
          background: const Color(0xFF000000),
          card: const Color(0xFF171717),
          cardAlt: const Color(0xFF242424),
          primary: const Color(0xFFFFFFFF),
          soft: const Color(0xFF2A2A2A),
          text: const Color(0xFFFFFFFF),
          muted: const Color(0xFFE5E5E5),
          success: const Color(0xFF22C55E),
          danger: const Color(0xFFEF4444),
          chartLine: const Color(0xFFEF4444),
        );
      case AppThemeMode.pink:
        return ThemeColors(
          background: const Color(0xFFFFF1F2),
          card: const Color(0xFFFFFFFF),
          cardAlt: const Color(0xFFFFE4E6),
          primary: const Color(0xFFDB2777),
          soft: const Color(0xFFFCE7F3),
          text: const Color(0xFF111827),
          muted: const Color(0xFF4B5563),
          success: const Color(0xFF16A34A),
          danger: const Color(0xFFEF4444),
          chartLine: const Color(0xFFEF4444),
        );
      case AppThemeMode.yellow:
        return ThemeColors(
          background: const Color(0xFFFFFBEA),
          card: const Color(0xFFFFFFFF),
          cardAlt: const Color(0xFFFEF3C7),
          primary: const Color(0xFFD97706),
          soft: const Color(0xFFFDE68A),
          text: const Color(0xFF111827),
          muted: const Color(0xFF4B5563),
          success: const Color(0xFF16A34A),
          danger: const Color(0xFFEF4444),
          chartLine: const Color(0xFFEF4444),
        );
      case AppThemeMode.green:
        return ThemeColors(
          background: const Color(0xFFECFDF5),
          card: const Color(0xFFFFFFFF),
          cardAlt: const Color(0xFFD1FAE5),
          primary: const Color(0xFF059669),
          soft: const Color(0xFFA7F3D0),
          text: const Color(0xFF111827),
          muted: const Color(0xFF4B5563),
          success: const Color(0xFF16A34A),
          danger: const Color(0xFFEF4444),
          chartLine: const Color(0xFFEF4444),
        );
      case AppThemeMode.safe:
        return ThemeColors(
          background: const Color(0xFFF5F7FA),
          card: const Color(0xFFFFFFFF),
          cardAlt: const Color(0xFFEFF3FF),
          primary: const Color(0xFF2F3A8F),
          soft: const Color(0xFFE5E7EB),
          text: const Color(0xFF111827),
          muted: const Color(0xFF4B5563),
          success: const Color(0xFF2E7D32),
          danger: const Color(0xFFEF4444),
          chartLine: const Color(0xFFEF4444),
        );
    }
  }

  String t(String tr, String en) => selectedLanguage == AppLanguage.tr ? tr : en;

  String money(double amount) {
    String locale = 'tr_TR';
    String symbol = '₺';

    switch (selectedCurrency) {
      case AppCurrency.tryCurrency:
        locale = 'tr_TR';
        symbol = '₺';
        break;
      case AppCurrency.usd:
        locale = 'en_US';
        symbol = '\$';
        break;
      case AppCurrency.eur:
        locale = 'de_DE';
        symbol = '€';
        break;
      case AppCurrency.gbp:
        locale = 'en_GB';
        symbol = '£';
        break;
    }

    return NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 0,
    ).format(amount);
  }

  String typeName(DebtType type) {
    switch (type) {
      case DebtType.loan:
        return t('Kredi', 'Loan');
      case DebtType.creditCard:
        return t('Kredi Kartı', 'Credit Card');
      case DebtType.overdraft:
        return t('Avans Hesap', 'Overdraft');
    }
  }

  IconData typeIcon(DebtType type) {
    switch (type) {
      case DebtType.loan:
        return Icons.account_balance;
      case DebtType.creditCard:
        return Icons.credit_card;
      case DebtType.overdraft:
        return Icons.account_balance_wallet;
    }
  }

  String themeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.safe:
        return 'Safe';
      case AppThemeMode.blue:
        return 'Mavi';
      case AppThemeMode.pink:
        return 'Pembe';
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.yellow:
        return 'Sarı';
      case AppThemeMode.green:
        return 'Yeşil';
    }
  }

  String currencyName(AppCurrency currency) {
    switch (currency) {
      case AppCurrency.tryCurrency:
        return 'TRY ₺';
      case AppCurrency.usd:
        return 'USD \$';
      case AppCurrency.eur:
        return 'EUR €';
      case AppCurrency.gbp:
        return 'GBP £';
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'debts',
      jsonEncode(debts.map((e) => e.toJson()).toList()),
    );

    await prefs.setDouble('monthlyIncome', monthlyIncome);
    await prefs.setDouble('savingsAmount', savingsAmount);
    await prefs.setBool('isPremium', isPremium);
    await prefs.setInt('selectedTheme', selectedTheme.index);
    await prefs.setInt('selectedLanguage', selectedLanguage.index);
    await prefs.setInt('selectedCurrency', selectedCurrency.index);
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final debtsRaw = prefs.getString('debts');
    final savedIncome = prefs.getDouble('monthlyIncome');
    final savedSavings = prefs.getDouble('savingsAmount');
    final savedPremium = prefs.getBool('isPremium');
    final savedTheme = prefs.getInt('selectedTheme');
    final savedLang = prefs.getInt('selectedLanguage');
    final savedCurrency = prefs.getInt('selectedCurrency');

    setState(() {
      if (debtsRaw != null) {
        final decoded = jsonDecode(debtsRaw) as List;
        debts = decoded.map((e) => Debt.fromJson(e)).toList();
      }

      monthlyIncome = savedIncome ?? 0;
      savingsAmount = savedSavings ?? savingsAmount;
      if (savedPremium != null) isPremium = savedPremium;

      if (savedTheme != null &&
          savedTheme >= 0 &&
          savedTheme < AppThemeMode.values.length) {
        selectedTheme = AppThemeMode.values[savedTheme];
      }

      if (savedLang != null &&
          savedLang >= 0 &&
          savedLang < AppLanguage.values.length) {
        selectedLanguage = AppLanguage.values[savedLang];
      }

      if (savedCurrency != null &&
          savedCurrency >= 0 &&
          savedCurrency < AppCurrency.values.length) {
        selectedCurrency = AppCurrency.values[savedCurrency];
      }
    });
  }

  double get totalDebt => debts.fold(0.0, (sum, d) => sum + d.amount);
  double get originalDebt =>
      debts.fold(0.0, (sum, d) => sum + d.originalAmount);
  double get totalMinimum => debts.fold(0.0, (sum, d) => sum + d.minimum);
  double get monthlyPaymentPower => monthlyIncome + savingsAmount;

  double get totalPaid {
    final value = originalDebt - totalDebt;
    return value > 0 ? value : 0;
  }

  double get extraPayment {
    final value = monthlyPaymentPower - totalMinimum;
    return value > 0 ? value : 0;
  }

  double get progressPercent {
    if (originalDebt <= 0) return 0;
    return (totalPaid / originalDebt) * 100;
  }

  double get progressValue {
    final value = progressPercent / 100;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  Debt? get priorityDebt {
    if (debts.isEmpty) return null;

    final sorted = [...debts];
    sorted.sort((a, b) {
      final interestCompare = b.interest.compareTo(a.interest);
      if (interestCompare != 0) return interestCompare;
      return b.amount.compareTo(a.amount);
    });

    return sorted.first;
  }

  List<Debt> sortByStrategy(List<Debt> list, PayoffStrategy strategy) {
    final sorted = [...list];

    if (strategy == PayoffStrategy.avalanche) {
      sorted.sort((a, b) {
        final interestCompare = b.interest.compareTo(a.interest);
        if (interestCompare != 0) return interestCompare;
        return b.amount.compareTo(a.amount);
      });
    } else {
      sorted.sort((a, b) {
        final amountCompare = a.amount.compareTo(b.amount);
        if (amountCompare != 0) return amountCompare;
        return b.interest.compareTo(a.interest);
      });
    }

    return sorted;
  }

  SimulationResult? simulate(PayoffStrategy strategy) {
    if (debts.isEmpty || monthlyPaymentPower <= 0) return null;

    if (monthlyPaymentPower < totalMinimum) {
      return SimulationResult(months: 0, totalInterest: 0, plans: []);
    }

    List<Debt> sim = debts
        .map(
          (d) => Debt(
            id: d.id,
            name: d.name,
            type: d.type,
            amount: d.amount,
            originalAmount: d.originalAmount,
            interest: d.interest,
            minimum: d.minimum,
            paymentDay: d.paymentDay,
            termMonths: d.termMonths,
            statementDay: d.statementDay,
            dueDay: d.dueDay,
            reminderEnabled: d.reminderEnabled,
            payments: d.payments,
          ),
        )
        .toList();

    int month = 0;
    double totalInterest = 0;
    final List<MonthPlan> plans = [];

    while (sim.any((d) => d.amount > 0) && month < 600) {
      month++;

      final startingDebt = sim.fold(0.0, (sum, d) => sum + d.amount);
      double interestThisMonth = 0;
      double paymentThisMonth = 0;

      for (int i = 0; i < sim.length; i++) {
        final d = sim[i];
        if (d.amount <= 0) continue;

        final interestAmount = d.amount * (d.interest / 100);
        interestThisMonth += interestAmount;
        totalInterest += interestAmount;

        sim[i] = d.copyWith(amount: d.amount + interestAmount);
      }

      double remainingBudget = monthlyPaymentPower;

      for (int i = 0; i < sim.length; i++) {
        final d = sim[i];
        if (d.amount <= 0) continue;

        final payment = d.minimum > d.amount ? d.amount : d.minimum;
        sim[i] = d.copyWith(amount: d.amount - payment);
        remainingBudget -= payment;
        paymentThisMonth += payment;
      }

      sim = sortByStrategy(sim, strategy);

      for (int i = 0; i < sim.length; i++) {
        final d = sim[i];
        if (d.amount <= 0 || remainingBudget <= 0) continue;

        final extraPay =
            remainingBudget > d.amount ? d.amount : remainingBudget;
        sim[i] = d.copyWith(amount: d.amount - extraPay);
        remainingBudget -= extraPay;
        paymentThisMonth += extraPay;
      }

      sim = sim
          .map((d) => d.copyWith(amount: d.amount < 0 ? 0 : d.amount))
          .toList();

      final endingDebt = sim.fold(0.0, (sum, d) => sum + d.amount);

      plans.add(
        MonthPlan(
          month: month,
          startingDebt: startingDebt,
          interestAdded: interestThisMonth,
          paymentMade: paymentThisMonth,
          endingDebt: endingDebt,
        ),
      );
    }

    return SimulationResult(
      months: month,
      totalInterest: totalInterest,
      plans: plans,
    );
  }

  SimulationResult? get avalancheResult => simulate(PayoffStrategy.avalanche);
  SimulationResult? get snowballResult => simulate(PayoffStrategy.snowball);

  String get coachMessage {
    if (debts.isEmpty) {
      return t(
        'İlk borcunu ekle. Sana nereden başlaman gerektiğini söyleyeceğim.',
        'Add your first debt. I will show you where to start.',
      );
    }

    if (monthlyPaymentPower < totalMinimum) {
      return t(
        'Dikkat. Gelir ve birikim tutarın minimum ödemeleri karşılamıyor. Böyle giderse borç büyüyebilir.',
        'Warning. Your income and savings do not cover minimum payments. Debt may grow.',
      );
    }

    if (extraPayment > 0) {
      final d = priorityDebt;
      return t(
        'Minimum ödemelerden sonra ${money(extraPayment)} ekstra ödeme gücün var. Bunu önce "${d?.name ?? '-'}" borcuna yönlendir.',
        'After minimum payments, you have ${money(extraPayment)} extra power. Direct it to "${d?.name ?? '-'}" first.',
      );
    }

    return t(
      'Şu an sadece minimum ödemelerle ilerliyorsun. Bu borcu kapatır ama süreci uzatır.',
      'You are currently moving with minimum payments only. This works, but extends the process.',
    );
  }

  String get recommendation {
    if (debts.isEmpty) {
      return t(
        'İlk borcunu ekleyince öneri vereceğim.',
        'I will advise after you add a debt.',
      );
    }

    if (monthlyPaymentPower < totalMinimum) {
      return t(
        'Minimum ödeme toplamın ${money(totalMinimum)}. Gelir + birikim gücün ${money(monthlyPaymentPower)}. Bu açık kapanmadan borç planı sağlıklı ilerlemez.',
        'Your total minimum payment is ${money(totalMinimum)}. Your income + savings power is ${money(monthlyPaymentPower)}. The plan is not healthy until this gap closes.',
      );
    }

    final d = priorityDebt;
    if (d == null) return t('Öneri oluşturulamadı.', 'Could not create recommendation.');

    return t(
      'Önce "${d.name}" borcuna yüklen. Minimum ödemelerden sonra kalan ${money(extraPayment)} ekstra tutarı bu borca yönlendir.',
      'Focus on "${d.name}" first. Direct the remaining ${money(extraPayment)} extra amount to this debt after minimum payments.',
    );
  }

  String get bestStrategyText {
    final avalanche = avalancheResult;
    final snowball = snowballResult;

    if (debts.isEmpty) {
      return t(
        'Borç ekleyince stratejileri karşılaştıracağım.',
        'I will compare strategies after you add debt.',
      );
    }

    if (avalanche == null || snowball == null) {
      return t('Veri eksik.', 'Missing data.');
    }

    final difference = snowball.totalInterest - avalanche.totalInterest;

    if (difference > 0) {
      return t(
        'Yüksek faiz stratejisi daha avantajlı. Yaklaşık ${money(difference)} cebinde kalır.',
        'High-interest strategy is better. You save about ${money(difference)}.',
      );
    }

    if (difference < 0) {
      return t(
        'Küçük borç stratejisi yaklaşık ${money(difference.abs())} daha avantajlı.',
        'Small-debt strategy is about ${money(difference.abs())} better.',
      );
    }

    return t(
      'İki strateji arasında belirgin faiz farkı yok.',
      'There is no significant interest difference between strategies.',
    );
  }

  int safeDay(String value) {
    int day = int.tryParse(value) ?? 1;
    if (day < 1) day = 1;
    if (day > 31) day = 31;
    return day;
  }

  void openAddDebtDialog() {
    if (!isPremium && debts.length >= 2) {
      showCenterPopup(
        title: t('Premium Gerekli', 'Premium Required'),
        message: t(
          'Ücretsiz sürümde en fazla 2 borç ekleyebilirsin.',
          'Free version allows up to 2 debts.',
        ),
      );
      return;
    }

    DebtType selectedType = DebtType.loan;
    String name = '';
    String amountText = '';
    String interestText = '';
    String minimumText = '';
    String paymentDayText = '1';
    String termText = '';
    String statementDayText = '1';
    String dueDayText = '1';
    bool reminder = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text(t('Borç Ekle', 'Add Debt')),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<DebtType>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: t('Borç türü', 'Debt type'),
                      ),
                      items: DebtType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(typeName(type)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        dialogSetState(() => selectedType = value);
                      },
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: selectedType == DebtType.creditCard
                            ? t('Kart adı', 'Card name')
                            : selectedType == DebtType.overdraft
                                ? t('Hesap adı', 'Account name')
                                : t('Kredi adı', 'Loan name'),
                      ),
                      onChanged: (v) => name = v,
                    ),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: selectedType == DebtType.creditCard
                            ? t('Kart borcu', 'Card debt')
                            : selectedType == DebtType.overdraft
                                ? t('Kullanılan limit', 'Used limit')
                                : t('Kalan kredi borcu', 'Remaining loan debt'),
                      ),
                      onChanged: (v) => amountText = v,
                    ),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t('Aylık faiz oranı', 'Monthly interest rate'),
                      ),
                      onChanged: (v) => interestText = v,
                    ),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: selectedType == DebtType.loan
                            ? t('Aylık taksit', 'Monthly installment')
                            : t('Minimum ödeme', 'Minimum payment'),
                      ),
                      onChanged: (v) => minimumText = v,
                    ),
                    if (selectedType == DebtType.loan) ...[
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: t('Kaç ay vadeli?', 'Term months'),
                        ),
                        onChanged: (v) => termText = v,
                      ),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: t('Ödeme günü (1-31)', 'Payment day (1-31)'),
                        ),
                        onChanged: (v) => paymentDayText = v,
                      ),
                    ],
                    if (selectedType == DebtType.creditCard) ...[
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: t('Hesap kesim tarihi (1-31)', 'Statement day'),
                        ),
                        onChanged: (v) => statementDayText = v,
                      ),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: t('Son ödeme tarihi (1-31)', 'Due day (1-31)'),
                        ),
                        onChanged: (v) => dueDayText = v,
                      ),
                    ],
                    if (selectedType == DebtType.overdraft)
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: t('Son ödeme tarihi (1-31)', 'Due day (1-31)'),
                        ),
                        onChanged: (v) => dueDayText = v,
                      ),
                    SwitchListTile(
                      title: Text(t('Hatırlatma istiyorum', 'I want reminders')),
                      subtitle: Text(
                        isPremium
                            ? t('Ödeme günü yaklaşınca uyarı gösterilecek.', 'Reminder will be shown near payment day.')
                            : t('Hatırlatma Premium özelliktir.', 'Reminders are a Premium feature.'),
                      ),
                      value: isPremium ? reminder : false,
                      onChanged: isPremium
                          ? (value) => dialogSetState(() => reminder = value)
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t('İptal', 'Cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountText.replaceAll(',', '.'));
                    final interest = double.tryParse(interestText.replaceAll(',', '.'));
                    final minimum = double.tryParse(minimumText.replaceAll(',', '.'));

                    if (name.trim().isEmpty ||
                        amount == null ||
                        interest == null ||
                        minimum == null) {
                      showCenterPopup(
                        title: t('Eksik Bilgi', 'Missing Info'),
                        message: t(
                          'Tüm alanları düzgün doldurman gerekiyor.',
                          'Please fill all fields correctly.',
                        ),
                      );
                      return;
                    }

                    final paymentDay = selectedType == DebtType.loan
                        ? safeDay(paymentDayText)
                        : safeDay(dueDayText);

                    final newDebt = Debt(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: name.trim(),
                      type: selectedType,
                      amount: amount,
                      originalAmount: amount,
                      interest: interest,
                      minimum: minimum,
                      paymentDay: paymentDay,
                      termMonths: selectedType == DebtType.loan
                          ? int.tryParse(termText)
                          : null,
                      statementDay: selectedType == DebtType.creditCard
                          ? safeDay(statementDayText)
                          : null,
                      dueDay: selectedType == DebtType.loan
                          ? null
                          : safeDay(dueDayText),
                      reminderEnabled: isPremium ? reminder : false,
                      payments: [],
                    );

                    setState(() => debts.add(newDebt));

                    await saveData();
                    Navigator.pop(dialogContext);
                  },
                  child: Text(t('Ekle', 'Add')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void openPaymentDialog(Debt debt) {
    String paymentText = '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('${debt.name} için ödeme yap', 'Make payment for ${debt.name}')),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: t('Ödenen tutar', 'Payment amount'),
              hintText: '10000',
            ),
            onChanged: (value) => paymentText = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t('İptal', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final payment = double.tryParse(paymentText.replaceAll(',', '.'));

                if (payment == null || payment <= 0) {
                  showCenterPopup(
                    title: t('Hatalı Tutar', 'Invalid Amount'),
                    message: t('Geçerli bir ödeme gir.', 'Enter a valid payment.'),
                  );
                  return;
                }

                final now = DateTime.now();
                final dateText = '${now.day}.${now.month}.${now.year}';

                setState(() {
                  debts = debts.map((d) {
                    if (d.id != debt.id) return d;

                    final newAmount = d.amount - payment;

                    return d.copyWith(
                      amount: newAmount < 0 ? 0 : newAmount,
                      payments: [
                        ...d.payments,
                        PaymentRecord(amount: payment, date: dateText),
                      ],
                    );
                  }).toList();
                });

                await saveData();
                Navigator.pop(dialogContext);

                showCenterPopup(
                  title: t('Tebrikler', 'Congrats'),
                  message: t(
                    '${money(payment)} ödeme yaptın. Bugün bir kahveyi hak ettin.',
                    'You paid ${money(payment)}. You earned a coffee today.',
                  ),
                );
              },
              child: Text(t('Kaydet', 'Save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteDebt(String id) async {
    setState(() => debts.removeWhere((d) => d.id == id));
    await saveData();
  }

  Future<void> generatePdfReport() async {
    if (debts.isEmpty) {
      showCenterPopup(
        title: t('Rapor Yok', 'No Report'),
        message: t('Rapor için önce borç ekle.', 'Add a debt first.'),
      );
      return;
    }

    final result = avalancheResult;
    final pdf = pw.Document();

    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        build: (context) => [
          pw.Text(
            t('Borç Strateji Raporu', 'Debt Strategy Report'),
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text('${t('Toplam Borç', 'Total Debt')}: ${money(totalDebt)}'),
          pw.Text('${t('Aylık Gelir', 'Monthly Income')}: ${money(monthlyIncome)}'),
          pw.Text('${t('Birikim', 'Savings')}: ${money(savingsAmount)}'),
          pw.Text('${t('Minimum Ödeme', 'Minimum Payment')}: ${money(totalMinimum)}'),
          pw.Text('${t('Ekstra Ödeme Gücü', 'Extra Payment Power')}: ${money(extraPayment)}'),
          if (result != null) ...[
            pw.Text('${t('Tahmini Kapanış', 'Estimated Payoff')}: ${result.months} ${t('ay', 'months')}'),
            pw.Text('${t('Tahmini Faiz', 'Estimated Interest')}: ${money(result.totalInterest)}'),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            t('Öneri', 'Recommendation'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(recommendation),
          pw.SizedBox(height: 16),
          pw.Text(
            t('Borçlar', 'Debts'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          ...debts.map(
            (d) => pw.Text(
              '${d.name} (${typeName(d.type)}): ${money(d.amount)} | ${t('Faiz', 'Interest')}: %${d.interest} | ${t('Min', 'Min')}: ${money(d.minimum)}',
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void openDetailedReport() {
    final result = avalancheResult;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Detaylı Analiz Raporu', 'Detailed Analysis Report')),
        content: SingleChildScrollView(
          child: Text(
            debts.isEmpty
                ? t('Analiz için borç eklemelisin.', 'Add debt for analysis.')
                : selectedLanguage == AppLanguage.tr
                    ? '''
Toplam borcun ${money(totalDebt)}.

Aylık gelirin ${money(monthlyIncome)}.
Birikim tutarın ${money(savingsAmount)}.
Minimum ödeme toplamın ${money(totalMinimum)}.
Minimumlardan sonra ekstra ödeme gücün ${money(extraPayment)}.

${result == null ? '' : 'Bu plana göre borcun yaklaşık ${result.months} ayda kapanır. Tahmini faiz yükün ${money(result.totalInterest)}.'}

Strateji önerisi:
$recommendation
'''
                    : '''
Your total debt is ${money(totalDebt)}.

Your monthly income is ${money(monthlyIncome)}.
Your savings amount is ${money(savingsAmount)}.
Your total minimum payment is ${money(totalMinimum)}.
Your extra payment power after minimums is ${money(extraPayment)}.

${result == null ? '' : 'With this plan, your debt may be paid off in about ${result.months} months. Estimated interest cost is ${money(result.totalInterest)}.'}

Strategy recommendation:
$recommendation
''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Kapat', 'Close')),
          ),
        ],
      ),
    );
  }

  void openSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Ayarlar', 'Settings')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t('Dil', 'Language')),
              subtitle: Text(selectedLanguage == AppLanguage.tr ? 'Türkçe' : 'English'),
              leading: const Icon(Icons.language),
              onTap: openLanguageSelector,
            ),
            ListTile(
              title: Text(t('Para Birimi', 'Currency')),
              subtitle: Text(currencyName(selectedCurrency)),
              leading: const Icon(Icons.attach_money),
              onTap: openCurrencySelector,
            ),
            ListTile(
              title: Text(t('Tema', 'Theme')),
              subtitle: Text(themeName(selectedTheme)),
              leading: const Icon(Icons.palette),
              onTap: openThemeSelector,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Kapat', 'Close')),
          ),
        ],
      ),
    );
  }

  void openLanguageSelector() {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Dil Seç', 'Choose Language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Türkçe'),
              trailing: selectedLanguage == AppLanguage.tr ? const Icon(Icons.check) : null,
              onTap: () async {
                setState(() => selectedLanguage = AppLanguage.tr);
                await saveData();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing: selectedLanguage == AppLanguage.en ? const Icon(Icons.check) : null,
              onTap: () async {
                setState(() => selectedLanguage = AppLanguage.en);
                await saveData();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void openCurrencySelector() {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Para Birimi Seç', 'Choose Currency')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppCurrency.values.map((currency) {
            return ListTile(
              title: Text(currencyName(currency)),
              trailing: selectedCurrency == currency ? const Icon(Icons.check) : null,
              onTap: () async {
                setState(() => selectedCurrency = currency);
                await saveData();
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void openThemeSelector() {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Tema Seç', 'Choose Theme')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            themeOption('Safe', AppThemeMode.safe),
            themeOption('Mavi', AppThemeMode.blue),
            themeOption('Pembe', AppThemeMode.pink),
            themeOption('Dark Mode', AppThemeMode.dark),
            themeOption('Sarı', AppThemeMode.yellow),
            themeOption('Yeşil', AppThemeMode.green),
          ],
        ),
      ),
    );
  }

  Widget themeOption(String title, AppThemeMode mode) {
    return ListTile(
      title: Text(title),
      trailing: selectedTheme == mode ? const Icon(Icons.check) : null,
      onTap: () async {
        setState(() => selectedTheme = mode);
        await saveData();
        Navigator.pop(context);
      },
    );
  }

  void showCenterPopup({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Kapat', 'Close')),
          ),
        ],
      ),
    );
  }

  Widget appCard({required Widget child, Color? color}) {
    return Card(
      elevation: 0,
      color: color ?? colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }

  Widget metricCard(String title, String value, IconData icon) {
    return appCard(
      color: colors.cardAlt,
      child: ListTile(
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
        trailing: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.text)),
      ),
    );
  }

  Widget lockedCard(String title) {
    return appCard(
      color: colors.cardAlt,
      child: ListTile(
        title: Text(title, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
        subtitle: Text(t('Premium ile aç', 'Unlock with Premium'), style: TextStyle(color: colors.muted)),
        trailing: Icon(Icons.lock, color: colors.primary),
      ),
    );
  }

  Widget actionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return appCard(
      color: colors.cardAlt,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: colors.muted)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: colors.primary),
      ),
    );
  }

  Widget coachCard() {
    return appCard(
      color: colors.cardAlt,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.psychology_alt, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                coachMessage,
                style: TextStyle(fontWeight: FontWeight.w700, color: colors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget progressCard() {
    return appCard(
      color: colors.cardAlt,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('İlerleme', 'Progress'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.text)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progressValue,
            minHeight: 10,
            color: colors.success,
            backgroundColor: colors.soft,
          ),
          const SizedBox(height: 8),
          Text(
            t('Borçlarının %${progressPercent.toStringAsFixed(1)} kadarını azalttın.',
                'You reduced ${progressPercent.toStringAsFixed(1)}% of your debt.'),
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w500),
          ),
        ]),
      ),
    );
  }

  Widget upcomingPaymentWarningCard() {
    if (debts.isEmpty) return const SizedBox.shrink();

    final today = DateTime.now().day;

    final upcoming = debts.where((debt) {
      final diff = debt.paymentDay - today;
      return diff >= 0 && diff <= 3;
    }).toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: const Color(0xFFFFE4E6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFDC2626)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t(
                  'Ödemesi yaklaşan borcun var: ${upcoming.map((e) => e.name).join(', ')}',
                  'You have upcoming payments: ${upcoming.map((e) => e.name).join(', ')}',
                ),
                style: const TextStyle(
                  color: Color(0xFF7F1D1D),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String debtDateInfo(Debt debt) {
    switch (debt.type) {
      case DebtType.loan:
        final term = debt.termMonths == null ? '' : ' | ${debt.termMonths} ay';
        return t(
          'Ödeme günü: Ayın ${debt.paymentDay}. günü$term',
          'Payment day: Day ${debt.paymentDay}$term',
        );
      case DebtType.creditCard:
        return t(
          'Kesim: ${debt.statementDay ?? '-'} | Son ödeme: ${debt.dueDay ?? debt.paymentDay}',
          'Statement: ${debt.statementDay ?? '-'} | Due: ${debt.dueDay ?? debt.paymentDay}',
        );
      case DebtType.overdraft:
        return t(
          'Son ödeme: Ayın ${debt.dueDay ?? debt.paymentDay}. günü',
          'Due day: Day ${debt.dueDay ?? debt.paymentDay}',
        );
    }
  }

  Widget debtCard(Debt debt, double width) {
    final isPriority = priorityDebt?.id == debt.id;

    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: colors.cardAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isPriority ? colors.success : colors.soft,
            width: isPriority ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openPaymentDialog(debt),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(typeIcon(debt.type), color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    debt.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.text, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => deleteDebt(debt.id),
                  icon: Icon(Icons.delete_outline, color: colors.muted),
                ),
              ]),
              const SizedBox(height: 4),
              Text(typeName(debt.type), style: TextStyle(color: colors.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(
                money(debt.amount),
                style: TextStyle(color: colors.text, fontWeight: FontWeight.bold, fontSize: 26),
              ),
              const SizedBox(height: 10),
              Text(
                'Faiz: %${debt.interest} | Min: ${money(debt.minimum)}',
                style: TextStyle(color: colors.text, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(debtDateInfo(debt), style: TextStyle(color: colors.muted)),
              const SizedBox(height: 8),
              Text(
                isPremium
                    ? (debt.reminderEnabled ? t('Hatırlatma açık', 'Reminder on') : t('Hatırlatma kapalı', 'Reminder off'))
                    : t('Hatırlatma: Premium', 'Reminder: Premium'),
                style: TextStyle(
                  color: debt.reminderEnabled && isPremium ? colors.success : colors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (debt.payments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  t('Son ödeme: ', 'Last payment: ') +
                      '${money(debt.payments.last.amount)} - ${debt.payments.last.date}',
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                t('Ödeme yap', 'Make payment'),
                style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
              ),
              if (isPriority) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    t('Öncelikli', 'Priority'),
                    style: TextStyle(color: colors.success, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget debtCardsSection() {
    if (debts.isEmpty) {
      return appCard(
        color: colors.cardAlt,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(t('Henüz borç eklenmedi.', 'No debt added yet.'),
                style: TextStyle(color: colors.text)),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width > 1100
            ? (width - 24) / 3
            : width > 700
                ? (width - 12) / 2
                : width;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: debts.map((d) => debtCard(d, cardWidth)).toList(),
        );
      },
    );
  }

  Widget chartSection(SimulationResult? result) {
    if (result == null || result.plans.isEmpty) {
      return appCard(
        color: colors.cardAlt,
        child: ListTile(
          title: Text(t('Grafik', 'Chart'), style: TextStyle(color: colors.text)),
          subtitle: Text(t('Grafik için borç ve bütçe gir.', 'Enter debt and budget for chart.'),
              style: TextStyle(color: colors.muted)),
        ),
      );
    }

    final maxDebt =
        result.plans.map((p) => p.startingDebt).fold(0.0, (a, b) => a > b ? a : b);

    final debtSpots =
        result.plans.map((p) => FlSpot(p.month.toDouble(), p.endingDebt)).toList();

    return appCard(
      color: colors.cardAlt,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Borç Azalış Grafiği', 'Debt Reduction Chart'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.text)),
          const SizedBox(height: 8),
          Text(
            t('Bu planla borcun yaklaşık ${result.months} ayda kapanır.',
                'With this plan, debt closes in about ${result.months} months.'),
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxDebt <= 0 ? 1 : maxDebt,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(color: colors.soft, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: colors.muted.withOpacity(0.4)),
                ),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: const LineTouchData(enabled: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: debtSpots,
                    isCurved: true,
                    color: colors.chartLine,
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget strategyCard(String title, String desc, SimulationResult? result) {
    return appCard(
      color: colors.cardAlt,
      child: ListTile(
        title: Text(title, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
        subtitle: Text(desc, style: TextStyle(color: colors.muted)),
        trailing: result == null
            ? Text('-', style: TextStyle(color: colors.text))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${result.months} ${t('ay', 'mo')}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.text)),
                  Text('${money(result.totalInterest)} ${t('faiz', 'interest')}',
                      style: TextStyle(fontSize: 12, color: colors.muted)),
                ],
              ),
      ),
    );
  }

  Widget monthlyPlanSection(SimulationResult? result) {
    if (result == null || result.plans.isEmpty) {
      return appCard(
        color: colors.cardAlt,
        child: ListTile(
          title: Text(t('Ay Ay Ödeme Planı', 'Monthly Payment Plan'),
              style: TextStyle(color: colors.text)),
          subtitle: Text(t('Plan için borç, gelir ve birikim gir.', 'Enter debt, income and savings for plan.'),
              style: TextStyle(color: colors.muted)),
        ),
      );
    }

    final plansToShow = isPremium ? result.plans : result.plans.take(2).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('Ay Ay Ödeme Planı', 'Monthly Payment Plan'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.text)),
      const SizedBox(height: 8),
      ...plansToShow.map(
        (p) => appCard(
          color: colors.cardAlt,
          child: ListTile(
            title: Text('${t('Ay', 'Month')} ${p.month}',
                style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
            subtitle: Text(
              isPremium
                  ? '${t('Başlangıç', 'Start')}: ${money(p.startingDebt)} | ${t('Faiz', 'Interest')}: ${money(p.interestAdded)} | ${t('Ödeme', 'Payment')}: ${money(p.paymentMade)}'
                  : t('Borç azalıyor. Detaylı plan Premium’da.',
                      'Debt is decreasing. Detailed plan is in Premium.'),
              style: TextStyle(color: colors.muted),
            ),
            trailing: Text(money(p.endingDebt),
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.text)),
          ),
        ),
      ),
      if (!isPremium && result.plans.length > 2)
        lockedCard(t('Tüm ayları görmek için Premium', 'Premium to see all months')),
    ]);
  }

  List<Widget> premiumFeatureCards() {
    if (isPremium) {
      return [
        actionCard(
          t('PDF Rapor', 'PDF Report'),
          t('Borç planını PDF olarak indir.', 'Download your debt plan as PDF.'),
          Icons.picture_as_pdf,
          generatePdfReport,
        ),
        actionCard(
          t('Türkçe / İngilizce Detaylı Rapor', 'Turkish / English Detailed Report'),
          t('Rapor dilini seç ve analiz al.', 'Choose report language and get analysis.'),
          Icons.translate,
          openDetailedReport,
        ),
        actionCard(
          t('Hatırlatma', 'Reminder'),
          t('Ödeme günleri için bildirim oluştur.', 'Create reminders for payment days.'),
          Icons.notifications,
          () => sendNotification(
            t('Hatırlatma', 'Reminder'),
            t('Ödeme planını kontrol etmeyi unutma.', 'Do not forget to check your payment plan.'),
          ),
        ),
      ];
    }

    return [
      lockedCard(t('PDF Rapor', 'PDF Report')),
      lockedCard(t('Türkçe / İngilizce Detaylı Rapor', 'Turkish / English Detailed Report')),
      lockedCard(t('Hatırlatma', 'Reminder')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final avalanche = avalancheResult;
    final snowball = snowballResult;
    final selectedResult = avalanche;
    final d = priorityDebt;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          t('Borç Strateji Koçu', 'Debt Strategy Coach'),
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: openSettings,
            icon: Icon(Icons.settings, color: colors.primary),
          ),
          IconButton(
            onPressed: () async {
              setState(() => isPremium = !isPremium);
              await saveData();
            },
            icon: Icon(isPremium ? Icons.star : Icons.star_border, color: colors.primary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Borçlarım', 'My Debts'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.text)),
          const SizedBox(height: 10),
          debtCardsSection(),
          const SizedBox(height: 14),

          coachCard(),
          const SizedBox(height: 12),
          upcomingPaymentWarningCard(),
          const SizedBox(height: 12),
          progressCard(),
          const SizedBox(height: 14),

          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;
            final fieldWidth = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.text),
                    decoration: InputDecoration(
                      labelText: t('Aylık gelir', 'Monthly income'),
                      hintText: monthlyIncome.toStringAsFixed(0),
                      border: const OutlineInputBorder(),
                      labelStyle: TextStyle(color: colors.text),
                      hintStyle: TextStyle(color: colors.muted),
                    ),
                    onChanged: (value) async {
                      setState(() {
                        monthlyIncome = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                      });
                      await saveData();
                    },
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.text),
                    decoration: InputDecoration(
                      labelText: t('Birikim tutarı', 'Savings amount'),
                      hintText: savingsAmount.toStringAsFixed(0),
                      border: const OutlineInputBorder(),
                      labelStyle: TextStyle(color: colors.text),
                      hintStyle: TextStyle(color: colors.muted),
                    ),
                    onChanged: (value) async {
                      setState(() {
                        savingsAmount = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                      });
                      await saveData();
                    },
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 14),
          metricCard(t('Toplam Borç', 'Total Debt'), money(totalDebt), Icons.account_balance_wallet),
          metricCard(t('Toplam Minimum Ödeme', 'Total Minimum Payment'), money(totalMinimum), Icons.payments),
          metricCard(t('Ekstra Ödeme Gücü', 'Extra Payment Power'), money(extraPayment), Icons.trending_up),
          const SizedBox(height: 14),

          ...premiumFeatureCards(),
          const SizedBox(height: 14),

          if (isPremium) ...[
            metricCard(
              t('Toplam Faiz Tahmini', 'Estimated Total Interest'),
              selectedResult == null ? '-' : money(selectedResult.totalInterest),
              Icons.warning_amber,
            ),
            chartSection(selectedResult),
            const SizedBox(height: 12),
            Text(t('Strateji Karşılaştırması', 'Strategy Comparison'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.text)),
            strategyCard(
              t('Yüksek Faiz Stratejisi', 'High Interest Strategy'),
              t('Önce en yüksek faizli borcu kapatır.', 'Pays the highest-interest debt first.'),
              avalanche,
            ),
            strategyCard(
              t('Küçük Borç Stratejisi', 'Small Debt Strategy'),
              t('Önce en küçük borcu kapatır.', 'Pays the smallest debt first.'),
              snowball,
            ),
            appCard(
              color: selectedTheme == AppThemeMode.dark || selectedTheme == AppThemeMode.blue
                  ? const Color(0xFF14532D)
                  : const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(bestStrategyText,
                    style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            lockedCard(t('Toplam Faiz Tahmini', 'Estimated Total Interest')),
            lockedCard(t('Grafik', 'Chart')),
            lockedCard(t('Strateji Karşılaştırması', 'Strategy Comparison')),
          ],

          const SizedBox(height: 14),
          appCard(
            color: colors.cardAlt,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(recommendation,
                  style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),

          if (d != null)
            Text(t('Öncelikli borç: ${d.name}', 'Priority debt: ${d.name}'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.text)),

          const SizedBox(height: 16),
          monthlyPlanSection(selectedResult),
          const SizedBox(height: 100),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primary,
        foregroundColor: selectedTheme == AppThemeMode.dark ? Colors.black : Colors.white,
        onPressed: openAddDebtDialog,
        icon: const Icon(Icons.add),
        label: Text(t('Borç Ekle', 'Add Debt')),
      ),
    );
  }
}
