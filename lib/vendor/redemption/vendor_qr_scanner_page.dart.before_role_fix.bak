
part of '../vendor_pages.dart';

class VendorQrScannerPage extends StatefulWidget {
  const VendorQrScannerPage({super.key});

  @override
  State<VendorQrScannerPage> createState() =>
      _VendorQrScannerPageState();
}

class _VendorQrScannerPageState extends State<VendorQrScannerPage> {
  final manualCode = TextEditingController();
  bool processing = false;
  bool scanning = true;
  String result =
      'Align the visitor voucher QR code inside the camera view.';

  Future<void> redeem(String? raw) async {
    if (raw == null || raw.trim().isEmpty || processing) return;
    setState(() {
      processing = true;
      scanning = false;
    });

    try {
      await AppServices.redeemClaim(
        raw.trim(),
        AppServices.auth.currentUser!.uid,
      );
      setState(() => result = 'Redemption successful.');
    } catch (e) {
      setState(
        () => result = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          processing = false;
          scanning = true;
        });
      }
    }
  }

  @override
  void dispose() {
    manualCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final success = result == 'Redemption successful.';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          const Text(
            'QR Redemption',
            style: TextStyle(
              color: ExplorerColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan visitor code or enter it manually.',
            style: TextStyle(
              color: ExplorerColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          ExplorerCard(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: 330,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      onDetect: scanning
                          ? (capture) => redeem(
                                capture.barcodes.isEmpty
                                    ? null
                                    : capture.barcodes.first.rawValue,
                              )
                          : (_) {},
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (processing)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ExplorerCard(
            backgroundColor: success
                ? ExplorerColors.successSoft
                : ExplorerColors.navySoft,
            borderColor: success
                ? const Color(0xFFB9E3CF)
                : const Color(0xFFC8D6EA),
            child: Row(
              children: [
                Icon(
                  success
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: success
                      ? ExplorerColors.success
                      : ExplorerColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    processing ? 'Processing voucher...' : result,
                    style: TextStyle(
                      color: success
                          ? ExplorerColors.success
                          : ExplorerColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR ENTER MANUALLY',
                  style: TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: manualCode,
            decoration: const InputDecoration(
              labelText: 'Voucher Code',
              prefixIcon: Icon(Icons.qr_code),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed:
                processing ? null : () => redeem(manualCode.text),
            child: const Text('Redeem Voucher'),
          ),
        ],
      ),
    );
  }
}
