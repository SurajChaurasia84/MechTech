import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/app_state.dart';
import '../../models/service_model.dart';
import 'manage_service_screen.dart';

class MyJobPostsScreen extends StatefulWidget {
  const MyJobPostsScreen({super.key});

  @override
  State<MyJobPostsScreen> createState() => _MyJobPostsScreenState();
}

class _MyJobPostsScreenState extends State<MyJobPostsScreen> {
  bool _isDeleting = false;

  Future<void> _deleteJobPost(String postId) async {
    final appState = context.read<AppState>();
    final uid = appState.user?.uid;
    if (uid == null) return;

    setState(() => _isDeleting = true);

    try {
      // Delete from global job_posts collection
      await FirebaseFirestore.instance
          .collection('job_posts')
          .doc(postId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job post deleted successfully.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting job post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete job post: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showDeleteConfirmation(String postId, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161426),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF302B53), width: 1.5),
          ),
          title: Text(
            'Delete Job Post',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete the job post "$title"? This action cannot be undone.',
            style: GoogleFonts.inter(color: const Color(0xFF8B88A5), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteJobPost(postId);
              },
              child: Text(
                'Delete',
                style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final uid = appState.user?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B18),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Job Posts',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
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
                color: const Color(0xFF00E676).withOpacity(0.04),
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('job_posts')
                .where('mechanicId', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading job posts.',
                    style: GoogleFonts.inter(color: Colors.redAccent),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.post_add_rounded, color: Color(0xFF302B53), size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No Job Posts Yet',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Post your service specialties and rates to start receiving bookings from customers nearby.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: const Color(0xFF8B88A5), height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ManageServiceScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Color(0xFF0D0B18)),
                          label: Text(
                            'Create Your First Post',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: const Color(0xFF0D0B18),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final id = doc.id;
                  final title = data['title'] as String? ?? 'General Mechanic Post';
                  final exp = data['experience'] as String? ?? 'Experienced';
                  final location = data['location'] as String? ?? 'Bengaluru';
                  final desc = data['desc'] as String? ?? '';
                   final categories = (data['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];
                  final tags = (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];
                  final vehicleCategory = data['vehicleCategory'] as String? ?? 'car';
                  final specializationRates = Map<String, int>.from(
                    (data['specializationRates'] as Map<String, dynamic>? ?? {}).map(
                      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
                    ),
                  );

                  // Construct JobPost object to pass for editing
                  final jobPost = JobPost(
                    id: id,
                    mechanicId: uid,
                    mechanicName: appState.currentCustomerName ?? 'Mechanic',
                    mechanicPhotoUrl: appState.currentCustomerPhotoUrl ?? '',
                    title: title,
                    rate: data['rate'] as String? ?? '',
                    experience: exp,
                    desc: desc,
                    location: location,
                    categories: categories,
                    tags: tags,
                    latitude: (data['latitude'] as num?)?.toDouble(),
                    longitude: (data['longitude'] as num?)?.toDouble(),
                    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                    vehicleCategory: vehicleCategory,
                    specializationRates: specializationRates,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161426),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF302B53).withOpacity(0.8),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // Service count badge
                              if (specializationRates.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${specializationRates.length} service${specializationRates.length == 1 ? '' : 's'}',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF00E676),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.work_outline_rounded, color: Color(0xFF8B88A5), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                exp,
                                style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.location_on_outlined, color: Color(0xFF8B88A5), size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              desc,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8B88A5).withOpacity(0.8),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Categories Wrap
                          if (categories.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: categories.map((cat) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF08693F).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4), width: 1),
                                    ),
                                    child: Text(
                                      cat,
                                      style: GoogleFonts.inter(color: const Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )).toList(),
                            ),
                            const SizedBox(height: 6),
                          ],
                          const Divider(color: Color(0xFF302B53), height: 24, thickness: 1),
                          // Edit / Delete Actions row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () => _showDeleteConfirmation(id, title),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ManageServiceScreen(existingPost: jobPost),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit_rounded, size: 14),
                                label: const Text('Edit Post'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF161426),
                                  foregroundColor: const Color(0xFF00B0FF),
                                  side: const BorderSide(color: Color(0xFF00B0FF), width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          if (_isDeleting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E676)),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ManageServiceScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF00E676),
        child: const Icon(Icons.add, color: Color(0xFF0D0B18)),
      ),
    );
  }
}
