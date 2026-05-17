import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'captain_waiting_approval_screen.dart';

class CaptainProfileCompletionScreen extends StatefulWidget {
  const CaptainProfileCompletionScreen({super.key});

  @override
  State<CaptainProfileCompletionScreen> createState() =>
      _CaptainProfileCompletionScreenState();
}

class _CaptainProfileCompletionScreenState
    extends State<CaptainProfileCompletionScreen> {
  final ImagePicker _picker = ImagePicker();
  final Map<String, File?> _files = {};

  // 🚗 CAR INFO CONTROLLERS
  final TextEditingController _carTypeController = TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();
  final TextEditingController _carColorController = TextEditingController();

  bool _isSubmitting = false;

  final List<String> _requiredDocs = [
    'profileImage',
    'nationalIdFront',
    'nationalIdBack',
    'driverLicense',
    'carLicense',
    'carFront',
    'carBack',
  ];

  // ==========================
  // PICK IMAGE
  // ==========================
  Future<void> _pickImage(String key) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        _files[key] = File(picked.path);
      });
    }
  }

  // ==========================
  // SUBMIT PROFILE
  // ==========================
  Future<void> _submit() async {
    // 🔴 VALIDATE CAR INFO
    if (_carTypeController.text.trim().isEmpty ||
        _carNumberController.text.trim().isEmpty ||
        _carColorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال بيانات السيارة كاملة')),
      );
      return;
    }

    // 🔴 VALIDATE DOCUMENTS
    if (_requiredDocs.any((k) => _files[k] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى رفع جميع المستندات المطلوبة')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final Map<String, String> uploadedUrls = {};

      for (final key in _requiredDocs) {
        final ref =
        FirebaseStorage.instance.ref('users/$uid/$key.jpg');
        await ref.putFile(_files[key]!);
        uploadedUrls[key] = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .set({
        // docs urls
        'documents': uploadedUrls,

        // car info
        'carType': _carTypeController.text.trim(),
        'carNumber': _carNumberController.text.trim(),
        'carColor': _carColorController.text.trim(),

        // gate flags
        'profileCompleted': true,
        'documentsUploaded': true, // ✅ THIS IS THE KEY FOR CaptainStatusGate
        'approved': false,

        // optional status
        'status': 'pending_review',

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));





      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الملف للمراجعة')),


      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CaptainWaitingApprovalScreen(),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الملفات: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==========================
  // UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استكمال الملف الشخصي'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'بيانات السيارة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _carTypeController,
              decoration: const InputDecoration(
                labelText: 'نوع السيارة',
                hintText: 'مثال: Toyota Corolla',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _carNumberController,
              decoration: const InputDecoration(
                labelText: 'رقم اللوحة',
                hintText: 'مثال: ABC-1234',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _carColorController,
              decoration: const InputDecoration(
                labelText: 'لون السيارة',
                hintText: 'مثال: أبيض',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'يرجى رفع المستندات المطلوبة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ..._requiredDocs.map(_buildUploadTile),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('إرسال للمراجعة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTile(String key) {
    final isProfileImage = key == 'profileImage';

    return Card(
      child: ListTile(
        leading: isProfileImage
            ? CircleAvatar(
          radius: 28,
          backgroundImage:
          _files[key] != null ? FileImage(_files[key]!) : null,
          child: _files[key] == null
              ? const Icon(Icons.person, size: 30)
              : null,
        )
            : null,
        title: Text(_docLabel(key)),
        subtitle:
        _files[key] != null ? const Text('تم الرفع') : const Text('مطلوب'),
        trailing: IconButton(
          icon: const Icon(Icons.camera_alt),
          onPressed: () => _pickImage(key),
        ),
      ),
    );
  }

  // ==========================
  // DOCUMENT LABELS (AR)
  // ==========================
  String _docLabel(String key) {
    switch (key) {
      case 'profileImage':
        return 'الصورة الشخصية';
      case 'nationalIdFront':
        return 'الهوية الوطنية (الوجه الأمامي)';
      case 'nationalIdBack':
        return 'الهوية الوطنية (الوجه الخلفي)';
      case 'driverLicense':
        return 'رخصة القيادة';
      case 'carLicense':
        return 'رخصة السيارة';
      case 'carFront':
        return 'صورة السيارة من الأمام';
      case 'carBack':
        return 'صورة السيارة من الخلف';
      default:
        return key;
    }
  }

  @override
  void dispose() {
    _carTypeController.dispose();
    _carNumberController.dispose();
    _carColorController.dispose();
    super.dispose();
  }
}
