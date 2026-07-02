import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isForceEdit;
  const EditProfileScreen({super.key, this.isForceEdit = false});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _nameController = TextEditingController(text: appState.currentCustomerName ?? '');
    _emailController = TextEditingController(text: appState.currentCustomerEmail ?? '');
    _phoneController = TextEditingController(text: appState.currentCustomerPhone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final appState = context.read<AppState>();
    await appState.updateUserProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );

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
                'Profile updated successfully!',
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

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return PopScope(
      canPop: !widget.isForceEdit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isForceEdit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please enter your phone number to continue.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161426),
          elevation: 0,
          leading: widget.isForceEdit
              ? IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  onPressed: () async {
                    await context.read<AppState>().logout();
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          automaticallyImplyLeading: !widget.isForceEdit,
          title: Text(
            widget.isForceEdit ? 'Complete Profile' : 'Edit Profile',
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
                color: const Color(0xFF00E676).withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.05),
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
                      'Personal Information',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Keep your details updated so we can reach you and sync your bookings.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8B88A5),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name field
                    _buildLabel('Full Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Enter your name',
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Email field
                    _buildLabel('Email Address'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Enter your email',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false,
                    ),
                    const SizedBox(height: 24),

                    // Phone field
                    _buildLabel(appState.userRole == 'mechanic' ? 'Phone Number' : 'Phone Number'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _phoneController,
                      hintText: 'Enter your phone number',
                      icon: Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (appState.userRole == 'mechanic') {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
                          if (!phoneRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid phone number';
                          }
                        }
                        return null;
                      },
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
                                onTap: _saveProfile,
                                child: Center(
                                  child: Text(
                                    'Save Changes',
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
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(color: enabled ? Colors.white : Colors.white60),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF161426),
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF8B88A5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: enabled ? const Color(0xFF302B53) : const Color(0xFF302B53).withOpacity(0.4),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF302B53), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF302B53).withOpacity(0.4), width: 1.5),
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
