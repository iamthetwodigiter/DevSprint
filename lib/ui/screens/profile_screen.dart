import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../services/hive_service.dart';
import '../../services/profile_image_service.dart';
import '../../services/user_preferences_service.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/app_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final preferences = UserPreferencesService();

  static const String defaultName = 'Developer';

  String name = defaultName;
  String bio = '';
  String imagePath = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await preferences.load();

    if (!mounted) return;

    setState(() {
      name = data['name'] ?? '';
      bio = data['bio'] ?? '';
      imagePath = data['profileImagePath'] ?? '';
      loading = false;
    });
  }

  Future<void> _editProfile() async {
    final auth = ref.read(authProvider);

    final nameController = TextEditingController(text: name);
    final bioController = TextEditingController(text: bio);

    String selectedImagePath = imagePath;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final cs = theme.colorScheme;

            Future<void> pickImage() async {
              final path = await ref
                  .read(profileImageServiceProvider)
                  .pickAndPersist();

              if (path == null) return;

              setSheetState(() {
                selectedImagePath = path;
              });
            }

            Future<void> save() async {
              await preferences.saveProfile(
                name: nameController.text.trim(),
                bio: bioController.text.trim(),
              );

              if (selectedImagePath != imagePath) {
                await preferences.saveProfileImagePath(selectedImagePath);
              }

              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFamily: GoogleFonts.ubuntu().fontFamily,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      auth.signedIn
                          ? 'Your Google identity stays connected. '
                                'You can still customise your local bio.'
                          : 'Update your profile information.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),

                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _avatar(
                            context,
                            size: 104,
                            photoUrl: auth.signedIn ? auth.photoUrl : null,
                            imagePath: selectedImagePath,
                            displayName: auth.signedIn
                                ? (auth.name?.trim().isNotEmpty == true
                                      ? auth.name!.trim()
                                      : defaultName)
                                : name.trim().isEmpty
                                ? defaultName
                                : name.trim(),
                          ),
                          Material(
                            color: cs.primaryContainer,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: pickImage,
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    if (!auth.signedIn) ...[
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: bioController,
                      maxLength: 120,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Developer note',
                        hintText: 'What are you building or learning?',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: save,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    bioController.dispose();

    if (result == true) {
      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final records = ref.watch(hiveServiceProvider).getSprintRecords();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (loading || auth.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final signedInName = auth.signedIn && auth.name?.trim().isNotEmpty == true
        ? auth.name!.trim()
        : null;

    final displayName =
        signedInName ?? (name.trim().isEmpty ? defaultName : name.trim());

    final photoUrl = auth.signedIn ? auth.photoUrl : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Developer profile',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontFamily: GoogleFonts.ubuntu().fontFamily,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your identity, progress and developer journey.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatar(
                context,
                size: 96,
                photoUrl: photoUrl,
                imagePath: imagePath,
                displayName: displayName,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _editProfile,
                          tooltip: 'Edit profile',
                          icon: const Icon(Icons.edit_outlined),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),

                    if (bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        bio.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],

                    if (auth.signedIn && auth.email != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              auth.email!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (auth.signedIn) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 17,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Account logged in',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: _stat(context, '${records.length}', 'sprints')),
            const SizedBox(width: 10),
            Expanded(
              child: _stat(
                context,
                '${records.where((e) => e['success'] == true).length}',
                'passed',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stat(
                context,
                records.isEmpty
                    ? '—'
                    : '${(records.map((e) => (e['score'] as num?)?.toInt() ?? 0).reduce((a, b) => a + b) / records.length).round()}',
                'avg score',
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        DeveloperDnaCard(records: records),

        const SizedBox(height: 12),

        SkillMatrixCard(records: records),

        const SizedBox(height: 12),

        RecentExploredCard(records: records),

        const SizedBox(height: 12),

        MomentumCard(records: records),

        const SizedBox(height: 12),

        DeveloperYearReviewCard(records: records, year: DateTime.now().year),

        const SizedBox(height: 12),

        ScoreProgressionCard(records: records),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _avatar(
    BuildContext context, {
    required double size,
    String? photoUrl,
    required String imagePath,
    required String displayName,
  }) {
    final cs = Theme.of(context).colorScheme;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, _) {},
      );
    }

    final file = imagePath.isEmpty ? null : File(imagePath);

    if (file != null && file.existsSync()) {
      return CircleAvatar(radius: size / 2, backgroundImage: FileImage(file));
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: cs.primaryContainer,
      child: Text(
        displayName.trim().isEmpty
            ? defaultName[0]
            : displayName.trim()[0].toUpperCase(),
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
