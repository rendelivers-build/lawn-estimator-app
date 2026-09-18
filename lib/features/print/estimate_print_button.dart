/// Print / Share button for a customer estimate.
///
/// Cross-module contract: the class name, constructor signature, and field
/// are depended on by other modules — do not change them.
library;

import 'package:flutter/material.dart';
import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/features/print/estimate_pdf.dart';
import 'package:lawn_estimator/models/models.dart';
import 'package:printing/printing.dart';

class EstimatePrintButton extends StatelessWidget {
  const EstimatePrintButton({super.key, required this.estimate});

  final EstimateFull estimate;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.print),
      label: const Text('Print / Share'),
      onPressed: () => _shareEstimate(context),
    );
  }

  /// Builds the PDF behind a blocking progress dialog, then hands the bytes
  /// to the OS share sheet. The dialog is always dismissed; failures surface
  /// as a SnackBar.
  Future<void> _shareEstimate(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Building PDF…'),
            ],
          ),
        ),
      ),
    );

    var failed = false;
    try {
      final company = await EstimateRepository().loadCompanyProfile();
      final bytes = await buildEstimatePdf(estimate, company: company);
      final rawId = estimate.estimate.id.toString();
      final shortId = rawId.length > 8 ? rawId.substring(0, 8) : rawId;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'estimate-$shortId.pdf',
      );
    } catch (_) {
      failed = true;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (failed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not generate the PDF.')),
      );
    }
  }
}
