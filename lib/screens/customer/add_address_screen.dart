import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _flatController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate if address exists in AppState
    final appState = context.read<AppState>();
    final savedAddress = appState.customerAddress;
    if (savedAddress != null && savedAddress.isNotEmpty) {
      final parts = savedAddress.split(', ');
      if (parts.length >= 4) {
        _flatController.text = parts[0];
        _streetController.text = parts[1];
        if (parts.length == 5) {
          _landmarkController.text = parts[2];
          _cityController.text = parts[3].split(' - ')[0];
          _pincodeController.text = parts[3].split(' - ').length > 1 ? parts[3].split(' - ')[1] : '';
        } else {
          _cityController.text = parts[2].split(' - ')[0];
          _pincodeController.text = parts[2].split(' - ').length > 1 ? parts[2].split(' - ')[1] : '';
        }
      } else {
        // Fallback: put the full text into the street field
        _streetController.text = savedAddress;
      }
    }
  }

  @override
  void dispose() {
    _flatController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final flat = _flatController.text.trim();
    final street = _streetController.text.trim();
    final landmark = _landmarkController.text.trim();
    final city = _cityController.text.trim();
    final pincode = _pincodeController.text.trim();

    // Construct formatted address
    final buffer = StringBuffer();
    buffer.write(flat);
    buffer.write(', ');
    buffer.write(street);
    if (landmark.isNotEmpty) {
      buffer.write(', ');
      buffer.write(landmark);
    }
    buffer.write(', ');
    buffer.write(city);
    buffer.write(' - ');
    buffer.write(pincode);

    final fullAddress = buffer.toString();
    final appState = context.read<AppState>();
    await appState.updateCustomerAddress(fullAddress);

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676)),
              const SizedBox(width: 12),
              Text(
                'Address saved successfully!',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF161426),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF302B53), width: 1),
          ),
        ),
      );

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add Address',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // Background soft glows for aesthetic depth
          Positioned(
            top: 40,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00B0FF).withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B0FF).withOpacity(0.05),
                    blurRadius: 50,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Service Location Address',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please provide your address so the service mechanic knows where to find your vehicle.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8B88A5),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Flat / House No
                    _buildLabel('Flat / House No. / Building Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _flatController,
                      hintText: 'e.g. Flat 104, Blue Bells Apt',
                      icon: Icons.home_work_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter flat or house details';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Street Name / Locality
                    _buildLabel('Street Name / Locality / Sector'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _streetController,
                      hintText: 'e.g. MG Road, Sector 4',
                      icon: Icons.add_road_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter street name or locality';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Landmark
                    _buildLabel('Landmark / Area Description (Optional)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _landmarkController,
                      hintText: 'e.g. Near HDFC Bank',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 20),

                    // Row with City and Pincode
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // City field
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabel('City'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _cityController,
                                hintText: 'e.g. Mumbai',
                                icon: Icons.location_city_outlined,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Pincode field
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabel('Pincode'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _pincodeController,
                                hintText: 'e.g. 400001',
                                icon: Icons.pin_drop_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (value.trim().length < 6) {
                                    return 'Invalid Code';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Save Button
                    _isSaving
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                            ),
                          )
                        : Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _saveAddress,
                                child: Center(
                                  child: Text(
                                    'Save Address',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF0D0B18),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF161426),
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF8B88A5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF302B53), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF302B53), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
