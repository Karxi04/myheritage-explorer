part of '../vendor_pages.dart';

class VendorQrScannerPage extends StatefulWidget {
  const VendorQrScannerPage({super.key});

  @override
  State<VendorQrScannerPage> createState() => _VendorQrScannerPageState();
}

class _VendorQrScannerPageState extends State<VendorQrScannerPage> {
  final manualCode = TextEditingController();
  bool processing = false;
  bool scanning = true;
  bool hasError = false;
  bool redemptionSucceeded = false;
  String result = 'Scan the temporary QR code or enter the active 6-digit PIN.';

  Future<void> redeem(String? raw) async {
    if (processing) return;
    final validationMessage = RewardInputValidation.redemptionCode(raw);
    if (validationMessage != null) {
      setState(() {
        result = validationMessage;
        hasError = true;
        redemptionSucceeded = false;
        scanning = false;
      });
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => scanning = true);
      return;
    }

    final code = raw!.trim();
    setState(() {
      processing = true;
      scanning = false;
      hasError = false;
      redemptionSucceeded = false;
    });

    try {
      final preview = await AppServices.redemptionPreview(
        code,
        AppServices.auth.currentUser!.uid,
      );
      if (!mounted) return;

      final expiry = asDate(preview['expiresAt']);
      final sessionExpiry = asDate(preview['redemptionSessionExpiresAt']);
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Confirm voucher redemption'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${preview['title'] ?? 'Voucher'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${preview['pointCost'] ?? 0} reward points'),
                  if (expiry != null)
                    Text(
                      'Expires ${DateFormat.yMMMd().add_jm().format(expiry)}',
                    ),
                  if (sessionExpiry != null)
                    Text(
                      'Temporary code valid until ${DateFormat.jm().format(sessionExpiry)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Only confirm after the tourist presents this voucher in person.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Confirm Redemption'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) {
        setState(() {
          result = 'Redemption cancelled. No voucher was changed.';
          hasError = false;
          redemptionSucceeded = false;
        });
        return;
      }

      await AppServices.redeemClaim(
        code,
        AppServices.auth.currentUser!.uid,
        resolvedClaimId: '${preview['claimId'] ?? ''}',
      );
      if (mounted) {
        setState(() {
          result = '${preview['title'] ?? 'Voucher'} redeemed successfully.';
          hasError = false;
          redemptionSucceeded = true;
          manualCode.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          result = rewardModuleErrorMessage(
            e,
            fallback:
                'The voucher could not be validated. Ask the tourist to generate a new code and try again.',
          );
          hasError = true;
          redemptionSucceeded = false;
        });
      }
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
    final success = redemptionSucceeded;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const ExplorerBrand(compact: true)),
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
            'Codes are generated by the tourist and remain valid for 3 minutes.',
            style: TextStyle(color: ExplorerColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const ExplorerCard(
            backgroundColor: ExplorerColors.navySoft,
            borderColor: Color(0xFFC8D6EA),
            padding: EdgeInsets.all(13),
            child: Row(
              children: [
                ExplorerStatusBadge(
                  label: '1  SCAN',
                  tone: ExplorerStatusTone.navy,
                ),
                Expanded(child: Divider(indent: 7, endIndent: 7)),
                ExplorerStatusBadge(
                  label: '2  REVIEW',
                  tone: ExplorerStatusTone.navy,
                ),
                Expanded(child: Divider(indent: 7, endIndent: 7)),
                ExplorerStatusBadge(
                  label: '3  CONFIRM',
                  tone: ExplorerStatusTone.navy,
                ),
              ],
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
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    if (processing)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
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
                : hasError
                ? ExplorerColors.dangerSoft
                : ExplorerColors.navySoft,
            borderColor: success
                ? const Color(0xFFB9E3CF)
                : hasError
                ? const Color(0xFFF4C7C3)
                : const Color(0xFFC8D6EA),
            child: Row(
              children: [
                Icon(
                  success
                      ? Icons.check_circle_outline
                      : hasError
                      ? Icons.error_outline
                      : Icons.info_outline,
                  color: success
                      ? ExplorerColors.success
                      : hasError
                      ? ExplorerColors.danger
                      : ExplorerColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    processing ? 'Processing voucher...' : result,
                    style: TextStyle(
                      color: success
                          ? ExplorerColors.success
                          : hasError
                          ? ExplorerColors.danger
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
            maxLength: 120,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: processing ? null : redeem,
            decoration: InputDecoration(
              labelText: 'Voucher QR data or 6-digit PIN',
              helperText:
                  'Ask the tourist to generate a new code if this one expired.',
              prefixIcon: const Icon(Icons.password_outlined),
              suffixIcon: IconButton(
                tooltip: 'Clear code',
                onPressed: () {
                  manualCode.clear();
                  setState(() {
                    result =
                        'Scan the temporary QR code or enter the active 6-digit PIN.';
                    hasError = false;
                    redemptionSucceeded = false;
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: processing ? null : () => redeem(manualCode.text),
            child: const Text('Validate and Review Voucher'),
          ),
        ],
      ),
    );
  }
}
