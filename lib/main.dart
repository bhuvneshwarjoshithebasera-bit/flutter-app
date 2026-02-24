import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'models/customer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(CustomerAdapter());
  await Hive.openBox<Customer>('customers');

  runApp(CustomerApp());
}

class CustomerApp extends StatefulWidget {
  @override
  _CustomerAppState createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  String _selectedPayment = "Cash";
  DateTime? _selectedDate;

  void _addCustomer() async {
    if (_formKey.currentState!.validate()) {
      final box = Hive.box<Customer>('customers');
      final newCustomer = Customer(
        name: nameController.text,
        amount: double.tryParse(amountController.text) ?? 0,
        paymentMethod: _selectedPayment,
        createdAt: DateTime.now(),
      );

      await box.add(newCustomer);

      nameController.clear();
      amountController.clear();
      _selectedPayment = "Cash";
      setState(() {});
    }
  }

  List<Customer> _filterByPayment(String method) {
    final box = Hive.box<Customer>('customers');
    final all = box.values.toList();

    final filtered = _selectedDate == null
        ? all
        : all.where((c) =>
            c.createdAt.year == _selectedDate!.year &&
            c.createdAt.month == _selectedDate!.month &&
            c.createdAt.day == _selectedDate!.day).toList();

    final list = filtered.where((c) => c.paymentMethod == method).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  double _grandTotal() {
    final box = Hive.box<Customer>('customers');
    final all = box.values.toList();

    final filtered = _selectedDate == null
        ? all
        : all.where((c) =>
            c.createdAt.year == _selectedDate!.year &&
            c.createdAt.month == _selectedDate!.month &&
            c.createdAt.day == _selectedDate!.day).toList();

    return filtered.fold<double>(0, (sum, c) => sum + c.amount);
  }

  String _generateReport(String method) {
    final list = _filterByPayment(method);
    if (list.isEmpty) return "No Data";

    final buffer = StringBuffer();
    buffer.writeln("Payment Method: $method");
    if (_selectedDate != null) {
      buffer.writeln(
          "Date: ${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}");
    }
    buffer.writeln("--------------------------------------------------");
    for (var c in list) {
      buffer.writeln(
          "${c.name} - ₹${c.amount} - ${c.createdAt.day}-${c.createdAt.month}-${c.createdAt.year}");
    }
    final total = list.fold<double>(0, (sum, c) => sum + c.amount);
    buffer.writeln("--------------------------------------------------");
    buffer.writeln("Total: ₹$total");
    return buffer.toString();
  }

  void _shareReport(String method) {
    final text = _generateReport(method);
    Share.share(text, subject: 'Customer Report - $method');
  }

  Future<void> _printReport(String method) async {
	final list = _filterByPayment(method);
	  if (list.isEmpty) return;

	  final pdf = pw.Document();
	  final ttf = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));

	  pdf.addPage(
		pw.Page(
		  build: (context) {
			return pw.Column(
			  crossAxisAlignment: pw.CrossAxisAlignment.start,
			  children: [
				pw.Text("Payment Method: $method", style: pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
				if (_selectedDate != null)
				  pw.Text("Date: ${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}", style: pw.TextStyle(font: ttf, fontSize: 14)),
				pw.SizedBox(height: 10),
				pw.Table.fromTextArray(
				  headers: ["Name", "Amount (₹)", "Date"],
				  data: list.map((c) => [
					c.name,
					c.amount.toString(),
					"${c.createdAt.day}-${c.createdAt.month}-${c.createdAt.year}"
				  ]).toList(),
				  headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
				  cellStyle: pw.TextStyle(font: ttf),
				  cellAlignment: pw.Alignment.centerLeft,
				),
				pw.SizedBox(height: 10),
				pw.Text(
				  "Total: ₹${list.fold<double>(0, (sum, c) => sum + c.amount)}",
				  style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
				),
			  ],
			);
		  },
		),
	  );

	  await Printing.layoutPdf(onLayout: (format) => pdf.save());
	}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text("Customer Entry"),
            bottom: TabBar(
              tabs: [
                Tab(text: "Cash"),
                Tab(text: "UPI"),
                Tab(text: "Card"),
              ],
            ),
            actions: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.date_range),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx, // correct context
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _selectedDate = null;
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                color: Colors.blue.shade50,
                child: Text(
                  "Grand Total: ₹${_grandTotal()} ${_selectedDate != null ? "(on ${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year})" : ""}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildList("Cash", key: ValueKey(_selectedDate)),
                    _buildList("UPI", key: ValueKey(_selectedDate)),
                    _buildList("Card", key: ValueKey(_selectedDate)),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: Builder(
            builder: (context) => FloatingActionButton(
              child: Icon(Icons.add),
              onPressed: () => _showForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(String method, {Key? key}) {
    final list = _filterByPayment(method);
    if (list.isEmpty) return Center(child: Text("No Data"));

    final total = list.fold<double>(0, (sum, c) => sum + c.amount);

    return Column(
      key: key,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(Icons.print),
              onPressed: () => _printReport(method),
            ),
            IconButton(
              icon: Icon(Icons.share),
              onPressed: () => _shareReport(method),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          color: Colors.grey.shade200,
          child: Text(
            "Total $method: ₹$total",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text(
                    "${c.createdAt.day}-${c.createdAt.month}-${c.createdAt.year}"),
                trailing: Text("₹${c.amount}"),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showForm(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: Text("Add Customer"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Name"),
                validator: (v) => v!.isEmpty ? "Enter name" : null,
              ),
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(labelText: "Amount"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter amount" : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedPayment,
                items: ["Cash", "UPI", "Card"]
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPayment = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            child: Text("Submit"),
            onPressed: () {
              _addCustomer();
              Navigator.pop(dialogContext);
            },
          ),
        ],
      ),
    );
  }
}