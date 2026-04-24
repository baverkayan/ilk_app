import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const BorcKocuApp());
}

class BorcKocuApp extends StatelessWidget {
  const BorcKocuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Borç Koçu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Debt {
  final String name;
  final double amount;
  final double interest;
  final double minimum;

  Debt({
    required this.name,
    required this.amount,
    required this.interest,
    required this.minimum,
  });

  Debt copyWith({
    String? name,
    double? amount,
    double? interest,
    double? minimum,
  }) {
    return Debt(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      interest: interest ?? this.interest,
      minimum: minimum ?? this.minimum,
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
  final bool canBePaid;
  final List<MonthPlan> plans;

  SimulationResult({
    required this.months,
    required this.totalInterest,
    required this.canBePaid,
    required this.plans,
  });
}

enum PayoffStrategy { avalanche, snowball }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Debt> debts = [];
  double monthlyBudget = 60000;
  bool isPremium = false;

  double get totalDebt => debts.fold(0.0, (sum, d) => sum + d.amount);

  double get totalMinimum => debts.fold(0.0, (sum, d) => sum + d.minimum);

  double get extraPayment {
    final extra = monthlyBudget - totalMinimum;
    return extra > 0 ? extra : 0;
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
    if (debts.isEmpty || monthlyBudget <= 0) return null;

    if (monthlyBudget < totalMinimum) {
      return SimulationResult(
        months: 0,
        totalInterest: 0,
        canBePaid: false,
        plans: [],
      );
    }

    List<Debt> sim = debts
        .map(
          (d) => Debt(
            name: d.name,
            amount: d.amount,
            interest: d.interest,
            minimum: d.minimum,
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

      double remainingBudget = monthlyBudget;

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

        final extraPay = remainingBudget > d.amount
            ? d.amount
            : remainingBudget;

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
      canBePaid: month < 600,
      plans: plans,
    );
  }

  SimulationResult? get avalancheResult => simulate(PayoffStrategy.avalanche);
  SimulationResult? get snowballResult => simulate(PayoffStrategy.snowball);

  String get bestStrategyText {
    final avalanche = avalancheResult;
    final snowball = snowballResult;

    if (debts.isEmpty) return 'Borç ekleyince stratejileri karşılaştıracağım.';
    if (monthlyBudget <= 0) return 'Aylık ödeme bütçeni gir.';
    if (avalanche == null || snowball == null) return 'Veri eksik.';
    if (!avalanche.canBePaid || !snowball.canBePaid) {
      return 'Bu bütçeyle borçların sağlıklı kapanmıyor.';
    }

    final difference = snowball.totalInterest - avalanche.totalInterest;

    if (difference > 0) {
      return 'Yüksek faiz stratejisi daha avantajlı. Yaklaşık ${difference.toStringAsFixed(0)} TL daha az faiz ödersin.';
    }

    if (difference < 0) {
      return 'Küçük borç stratejisi daha avantajlı. Yaklaşık ${difference.abs().toStringAsFixed(0)} TL daha az faiz ödersin.';
    }

    return 'İki strateji arasında belirgin faiz farkı yok.';
  }

  String get recommendation {
    if (debts.isEmpty) return 'İlk borcunu ekleyince öneri vereceğim.';
    if (monthlyBudget <= 0)
      return 'Aylık ödeme bütçeni girince analiz başlayacak.';
    if (monthlyBudget < totalMinimum) {
      return 'Aylık bütçen minimum ödemeleri karşılamıyor. En az ${totalMinimum.toStringAsFixed(0)} TL gerekli.';
    }

    final d = priorityDebt;
    if (d == null) return 'Öneri oluşturulamadı.';

    return 'Önce "${d.name}" borcuna yüklen. Çünkü en yüksek faiz oranı bu borçta: %${d.interest}. Minimum ödemelerden sonra kalan ${extraPayment.toStringAsFixed(0)} TL’yi bu borca yönlendir.';
  }

  void openAddDebtDialog() {
    if (!isPremium && debts.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ücretsiz sürümde en fazla 2 borç ekleyebilirsin.'),
        ),
      );
      return;
    }

    String name = '';
    String amountText = '';
    String interestText = '';
    String minimumText = '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Borç Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Borç adı'),
                  onChanged: (value) => name = value,
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kalan borç tutarı',
                  ),
                  onChanged: (value) => amountText = value,
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Aylık faiz oranı',
                  ),
                  onChanged: (value) => interestText = value,
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum aylık ödeme',
                  ),
                  onChanged: (value) => minimumText = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountText.replaceAll(',', '.'));
                final interest = double.tryParse(
                  interestText.replaceAll(',', '.'),
                );
                final minimum = double.tryParse(
                  minimumText.replaceAll(',', '.'),
                );

                if (name.trim().isEmpty ||
                    amount == null ||
                    interest == null ||
                    minimum == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tüm alanları doldurman gerekiyor.'),
                    ),
                  );
                  return;
                }

                setState(() {
                  debts.add(
                    Debt(
                      name: name.trim(),
                      amount: amount,
                      interest: interest,
                      minimum: minimum,
                    ),
                  );
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  void deleteDebt(int index) {
    setState(() {
      debts.removeAt(index);
    });
  }

  Widget infoCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget lockedCard(String title) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: const Text('Premium ile aç'),
        trailing: const Icon(Icons.lock),
      ),
    );
  }

  Widget premiumActionCard(String title, String subtitle, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title yakında aktif edilecek.')),
          );
        },
      ),
    );
  }

  Widget strategyCard({
    required String title,
    required String description,
    required SimulationResult? result,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(description),
        trailing: result == null
            ? const Text('-')
            : result.canBePaid
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.months} ay',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${result.totalInterest.toStringAsFixed(0)} TL faiz',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              )
            : const Text('Yetersiz'),
      ),
    );
  }

  Widget chartSection(SimulationResult? result) {
    if (result == null || result.plans.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text('Grafik'),
          subtitle: Text('Grafik için borç ve bütçe gir.'),
        ),
      );
    }

    final maxDebt = result.plans
        .map((p) => p.startingDebt)
        .fold(0.0, (a, b) => a > b ? a : b);

    final spots = result.plans
        .map((p) => FlSpot(p.month.toDouble(), p.endingDebt))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Borç Azalış Grafiği',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxDebt <= 0 ? 1 : maxDebt,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget monthlyPlanSection(SimulationResult? result) {
    if (result == null) {
      return const Card(
        child: ListTile(
          title: Text('Ay Ay Ödeme Planı'),
          subtitle: Text('Plan için borç ve bütçe gir.'),
        ),
      );
    }

    if (!result.canBePaid) {
      return const Card(
        child: ListTile(
          title: Text('Ay Ay Ödeme Planı'),
          subtitle: Text('Bu bütçeyle plan oluşturulamıyor.'),
        ),
      );
    }

    final plansToShow = isPremium
        ? result.plans
        : result.plans.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ay Ay Ödeme Planı',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...plansToShow.map(
          (p) => Card(
            child: ListTile(
              title: Text('Ay ${p.month}'),
              subtitle: Text(
                isPremium
                    ? 'Başlangıç: ${p.startingDebt.toStringAsFixed(0)} TL | Faiz: ${p.interestAdded.toStringAsFixed(0)} TL | Ödeme: ${p.paymentMade.toStringAsFixed(0)} TL'
                    : 'Borç azalıyor. Detaylı plan Premium’da.',
              ),
              trailing: Text(
                '${p.endingDebt.toStringAsFixed(0)} TL',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        if (!isPremium && result.plans.length > 2)
          lockedCard('Tüm ayları görmek için Premium'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avalanche = avalancheResult;
    final snowball = snowballResult;
    final selectedResult = avalanche;
    final d = priorityDebt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borç Strateji Koçu'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isPremium = !isPremium;
              });
            },
            icon: Icon(isPremium ? Icons.star : Icons.star_border),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Aylık ödeme bütçen',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  monthlyBudget =
                      double.tryParse(value.replaceAll(',', '.')) ?? 0;
                });
              },
            ),
            const SizedBox(height: 12),

            infoCard('Toplam Borç', '${totalDebt.toStringAsFixed(0)} TL'),
            infoCard(
              'Toplam Minimum Ödeme',
              '${totalMinimum.toStringAsFixed(0)} TL',
            ),
            infoCard(
              'Ekstra Ödeme Gücü',
              '${extraPayment.toStringAsFixed(0)} TL',
            ),

            const SizedBox(height: 12),

            if (isPremium) ...[
              infoCard(
                'Toplam Faiz Tahmini',
                selectedResult == null
                    ? '-'
                    : '${selectedResult.totalInterest.toStringAsFixed(0)} TL',
              ),
              chartSection(selectedResult),
              const Text(
                'Strateji Karşılaştırması',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              strategyCard(
                title: 'Yüksek Faiz Stratejisi',
                description: 'Önce en yüksek faizli borcu kapatır.',
                result: avalanche,
              ),
              strategyCard(
                title: 'Küçük Borç Stratejisi',
                description: 'Önce en küçük borcu kapatır.',
                result: snowball,
              ),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(bestStrategyText),
                ),
              ),
              premiumActionCard(
                'PDF Rapor',
                'Borç planını PDF olarak indir.',
                Icons.picture_as_pdf,
              ),
              premiumActionCard(
                'Türkçe / İngilizce Detaylı Rapor',
                'Rapor dilini seç ve detaylı analiz al.',
                Icons.translate,
              ),
              premiumActionCard(
                'Hatırlatma',
                'Ödeme günleri için bildirim oluştur.',
                Icons.notifications,
              ),
            ] else ...[
              lockedCard('Toplam Faiz Tahmini'),
              lockedCard('Grafik'),
              lockedCard('Strateji Karşılaştırması'),
              lockedCard('PDF Rapor'),
              lockedCard('Türkçe / İngilizce Detaylı Rapor'),
              lockedCard('Hatırlatma'),
            ],

            const SizedBox(height: 12),

            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(recommendation),
              ),
            ),

            const SizedBox(height: 16),

            if (d != null)
              Text(
                'Öncelikli borç: ${d.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 16),

            monthlyPlanSection(selectedResult),

            const SizedBox(height: 16),

            const Text(
              'Borçlarım',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            debts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('Henüz borç eklenmedi.')),
                  )
                : ListView.builder(
                    itemCount: debts.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final debt = debts[index];

                      return Card(
                        child: ListTile(
                          title: Text(debt.name),
                          subtitle: Text(
                            'Faiz: %${debt.interest} | Minimum: ${debt.minimum.toStringAsFixed(0)} TL',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${debt.amount.toStringAsFixed(0)} TL',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () => deleteDebt(index),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddDebtDialog,
        icon: const Icon(Icons.add),
        label: const Text('Borç Ekle'),
      ),
    );
  }
}
