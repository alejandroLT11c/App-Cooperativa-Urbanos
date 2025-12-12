import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;

class WalletScreen extends StatefulWidget {
  // AQUI ESTÁ EL CAMBIO: Pedimos el ID obligatoriamente para entrar
  final String userId; 
  const WalletScreen({super.key, required this.userId});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // Ya no hardcodeamos el ID, usamos "widget.userId"
  
  double _saldo = 0.0;
  String? _qrData;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    // Aquí podrías llamar al backend para consultar el saldo real
  }

  Future<void> _recargar() async {
    setState(() => _cargando = true);
    try {
      final url = Uri.parse('http://192.168.0.112:3000/wallet/recharge');
      final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        // OJO: Aquí usamos widget.userId
        body: jsonEncode({"user_id": widget.userId, "amount": 10000}) 
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _saldo = double.parse(data['nuevo_saldo'].toString());
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ ¡Recarga exitosa!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _cargando = false);
  }

  Future<void> _comprarTiquete() async {
    setState(() => _cargando = true);
    try {
      final url = Uri.parse('http://192.168.0.112:3000/tickets/buy');
      final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        // OJO: Aquí usamos widget.userId
        body: jsonEncode({"user_id": widget.userId}) 
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _qrData = data['qr_code'];
          _saldo = double.parse(data['saldo_restante'].toString());
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎟️ ¡Pasaje comprado!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['error']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Billetera"), backgroundColor: Colors.purple),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Muestra el ID pequeño para que sepas que funcionó
            Text("Usuario: ${widget.userId.substring(0,8)}...", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.purple)
              ),
              child: Column(
                children: [
                  const Text("Saldo Disponible", style: TextStyle(fontSize: 16)),
                  Text("\$${_saldo.toStringAsFixed(0)}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.purple)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _cargando ? null : _recargar,
                    icon: const Icon(Icons.add_card),
                    label: const Text("Recargar \$10.000"),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            if (_qrData == null)
              ElevatedButton(
                onPressed: _cargando ? null : _comprarTiquete,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600), foregroundColor: Colors.white),
                child: const Text("COMPRAR PASAJE (\$2.800)"),
              )
            else
              Column(
                children: [
                  QrImageView(data: _qrData!, version: QrVersions.auto, size: 200.0),
                  TextButton(
                    onPressed: () => setState(() => _qrData = null),
                    child: const Text("Cerrar Tiquete"),
                  )
                ],
              )
          ],
        ),
      ),
    );
  }
}