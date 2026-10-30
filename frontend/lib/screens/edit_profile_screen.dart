import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/primary_button.dart';
import '../widgets/user_avatar.dart';

/// Screen 18: change name and phone. Email is shown but cannot be changed.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: session.user?.fullName ?? '');
  late final _phone = TextEditingController(text: session.user?.phone ?? '');
  late final _email = TextEditingController(text: session.user?.email ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Lets the user pick a photo from the gallery or camera (or remove it). It is resized and kept on the device.
  Future<void> _changePhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
            if (session.avatar != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      await session.setAvatar(null);
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (file == null) return; // user cancelled
      await session.setAvatar(await file.readAsBytes());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the photo picker. Check the app\'s photo/camera permission.')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.updateProfile(fullName: _name.text.trim(), phone: _phone.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Stack(
              children: [
                const UserAvatar(radius: 46),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _changePhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('Photo is stored on this device only',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(controller: _name, label: 'Name', validator: Validators.name),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _email,
                  label: 'Email (cannot be changed)',
                  enabled: false,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phone,
                  label: 'Mobile Number',
                  keyboardType: TextInputType.phone,
                  digitsOnly: true,
                  maxLength: 10,
                  textInputAction: TextInputAction.done,
                  validator: Validators.phone,
                  onSubmitted: _save, // Enter saves
                ),
              ],
            ),
          ),
          if (_error != null) ...[const SizedBox(height: AppSpacing.md), ErrorBox(_error!)],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Save Changes', onPressed: _save, loading: _saving),
        ],
      ),
    );
  }
}
