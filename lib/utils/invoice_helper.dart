import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/service_model.dart';

class InvoiceHelper {
  /// Generates a professional tax invoice PDF and saves it locally in the downloads/documents folder.
  static Future<File?> generateInvoice(ServiceBooking booking) async {
    final pdf = pw.Document();

    // Prices calculation
    final serviceTotal = booking.selectedServices.fold<double>(0.0, (sum, item) => sum + item.price);
    final platformFee = booking.platformFee;
    final total = booking.totalAmount;

    // Convert total amount to words
    final String amountInWords = _numberToWords(total.toInt());

    // Load MechTech logo from assets
    Uint8List? logoBytes;
    try {
      final byteData = await rootBundle.load('assets/icon.png');
      logoBytes = byteData.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }
    final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo + Brand name side by side
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 40, height: 40),
                        pw.SizedBox(width: 10),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'MECHTECH',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#00E676'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text('Vehicle Repair & Roadside Assistance Platform', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#161426'),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Invoice ID: ${booking.id}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Invoice Date: ${_formatDate(booking.bookingDate)}', style: pw.TextStyle(fontSize: 8)),
                      pw.Text('Payment Type: ${booking.paymentId == 'COD' ? 'Cash on Delivery (COD)' : 'Online Payment'}', style: pw.TextStyle(fontSize: 8)),
                      pw.Text('Payment Status: ${(booking.paymentStatus ?? 'unpaid').toUpperCase()}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Customer & Mechanic Info — side by side
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // LEFT: Customer details
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CUSTOMER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.8)),
                          pw.SizedBox(height: 6),
                          pw.Text(booking.customerName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 3),
                          if (booking.customerPhone != null && booking.customerPhone!.isNotEmpty)
                            pw.Text('Phone: ${booking.customerPhone}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          if (booking.customerEmail != null && booking.customerEmail!.isNotEmpty)
                            pw.Text('Email: ${booking.customerEmail}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 3),
                          pw.Text('Vehicle: ${booking.vehicleModel}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text('Type: ${booking.vehicleType.name.toUpperCase()}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          if (booking.bookingLocation != null && booking.bookingLocation!.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Text('Location: ${booking.bookingLocation}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // RIGHT: Mechanic / Service Partner details
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SERVICE PARTNER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.8)),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            booking.mechanicName ?? 'Mechanic Partner',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00E676')),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text('Role: Certified Field Technician', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text('Platform: MechTech', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Services Table
              pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.5),
                  top: pw.BorderSide(color: PdfColors.grey400, width: 1.5),
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#161426')),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                headers: ['S.No.', 'Description / Service Item Details', 'Rate (INR)'],
                data: List<List<dynamic>>.generate(
                  booking.selectedServices.length,
                  (index) {
                    final s = booking.selectedServices[index];
                    return [
                      '${index + 1}',
                      '${s.name} (${s.category})',
                      'Rs. ${s.price.toStringAsFixed(2)}',
                    ];
                  },
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                },
                cellStyle: const pw.TextStyle(fontSize: 8),
              ),

              pw.SizedBox(height: 12),

              // Pricing Summary Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Amount in Words:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.Text(amountInWords, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Sub Total Service Fee:', style: pw.TextStyle(fontSize: 9)),
                            pw.Text('Rs. ${serviceTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Flat Platform charges:', style: pw.TextStyle(fontSize: 9)),
                            pw.Text('Rs. ${platformFee.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Divider(color: PdfColors.grey300),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Amount (Net):', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                              'Rs. ${total.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#00E676'),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Divider(color: PdfColors.grey400, thickness: 1.5),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 14),

              // Transaction Details Section
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Transaction ID
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TRANSACTION ID', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.5)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          (booking.paymentId == null || booking.paymentId!.isEmpty || booking.paymentId == 'COD')
                              ? 'N/A (Cash on Delivery)'
                              : booking.paymentId!,
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    // Payment Mode
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('PAYMENT MODE', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.5)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          booking.paymentId == 'COD' ? 'Cash on Delivery' : 'Online',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    // Date & Time
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('DATE & TIME', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.5)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          '${_formatDate(booking.bookingDate)}  ${_formatTime(booking.bookingDate)}',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Terms & Conditions / Signatory
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Terms & Declarations:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.Text('1. This is a computer generated invoice document and requires no physical signatures.', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      pw.Text('2. Tax is charged as applicable under GST guidelines.', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      pw.Text('3. MechTech acts as a facilitator and platform rates are subject to Terms of Service.', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('For MECHTECH', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 20),
                      pw.Container(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text('Authorized Representative Stamp', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    try {
      final pdfBytes = await pdf.save();
      final fileName = 'MechTech_Invoice_${booking.id}.pdf';

      if (Platform.isAndroid) {
        // Android 10+ (API 29+): Use MediaStore API to save to public Downloads.
        // This makes the file immediately visible in Files app — NO permission needed.
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(pdfBytes);

        final mediaStore = MediaStore();
        MediaStore.appFolder = 'MechTech';

        final savedUri = await mediaStore.saveFile(
          tempFilePath: tempFile.path,
          dirType: DirType.download,
          dirName: DirName.download,
        );

        if (savedUri == null) {
          debugPrint('MediaStore save returned null URI');
          return null;
        }

        // Note: media_store_plus deletes the temp file internally after copying.
        // No manual delete needed.
        debugPrint('Invoice saved via MediaStore to Downloads: $savedUri');
        return File(fileName); // non-null = success signal to caller
      } else {
        // iOS / Desktop: use application documents directory
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        debugPrint('Invoice saved at: ${file.path}');
        return file;
      }
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      return null;
    }
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static String _numberToWords(int number) {
    if (number == 0) return 'Zero Rupees Only';
    
    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    
    String convert(int n) {
      if (n < 20) return units[n];
      if (n < 100) return tens[n ~/ 10] + (n % 10 != 0 ? ' ${units[n % 10]}' : '');
      if (n < 1000) return '${units[n ~/ 100]} Hundred${n % 100 != 0 ? ' and ${convert(n % 100)}' : ''}';
      if (n < 100000) return '${convert(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${convert(n % 1000)}' : ''}';
      return n.toString();
    }
    
    return '${convert(number)} Rupees Only';
  }
}
