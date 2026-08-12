import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/certification.dart';
import '../providers/certification_form_provider.dart';
import '../providers/dive_providers.dart';
import '../providers/list_providers.dart';
import '../services/image_store.dart';

class CertificationsScreen extends ConsumerWidget {
  const CertificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(certificationListNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Certifications')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCertDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: asyncState.when(
        data: (state) {
          final certs = state.certs;
          if (certs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_membership, size: 64),
                  SizedBox(height: 16),
                  Text('No certifications yet'),
                  SizedBox(height: 8),
                  Text('Tap + to add a certification'),
                ],
              ),
            );
          }

          // Group by org
          final grouped = <String, List<Certification>>{};
          for (final cert in certs) {
            grouped.putIfAbsent(cert.org, () => []).add(cert);
          }
          final orgs = grouped.keys.toList()..sort();

          return ListView.builder(
            itemCount: orgs.length,
            itemBuilder: (context, index) {
              final org = orgs[index];
              final orgCerts = grouped[org]!;
              return ExpansionTile(
                title: Text(org),
                children: orgCerts.map((cert) {
                  return ListTile(
                    leading: cert.photoPath != null
                        ? CircleAvatar(
                            backgroundImage: FileImage(File(cert.photoPath!)),
                          )
                        : const CircleAvatar(
                            child: Icon(Icons.card_membership),
                          ),
                    title: Text(cert.level),
                    subtitle: _certSubtitle(cert),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _showCertDialog(context, ref, cert.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await ref
                                .read(databaseProvider)
                                .deleteCertification(cert.id!);
                            unawaited(
                              ref
                                  .read(
                                    certificationListNotifierProvider.notifier,
                                  )
                                  .refresh(),
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () => _showCertDialog(context, ref, cert.id),
                  );
                }).toList(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget? _certSubtitle(Certification cert) {
    final parts = <String>[];
    if (cert.certId != null && cert.certId!.isNotEmpty) {
      parts.add('#${cert.certId}');
    }
    if (cert.issueDate != null) {
      parts.add('Issued ${DateFormat.yMMMd().format(cert.issueDate!)}');
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }

  void _showCertDialog(BuildContext context, WidgetRef ref, int? existingId) {
    showDialog(
      context: context,
      builder: (context) => _CertDialog(existingId: existingId),
    );
  }
}

class _CertDialog extends ConsumerWidget {
  const _CertDialog({required this.existingId});

  final int? existingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(certificationFormProvider(existingId));
    return AlertDialog(
      title: Text(
        existingId == null ? 'Add Certification' : 'Edit Certification',
      ),
      content: async.when(
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('Error: $e'),
        data: (state) {
          final notifier = ref.read(
            certificationFormProvider(existingId).notifier,
          );
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: state.org,
                  decoration: InputDecoration(
                    labelText: 'Organization (e.g. PADI, SSI)',
                    errorText: state.validationErrors['org'],
                  ),
                  onChanged: notifier.setOrg,
                ),
                TextFormField(
                  initialValue: state.level,
                  decoration: InputDecoration(
                    labelText: 'Level',
                    errorText: state.validationErrors['level'],
                  ),
                  onChanged: notifier.setLevel,
                ),
                TextFormField(
                  initialValue: state.certId,
                  decoration: const InputDecoration(
                    labelText: 'ID # (optional)',
                  ),
                  onChanged: notifier.setCertId,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    state.issueDate == null
                        ? 'Issue date (optional)'
                        : DateFormat.yMMMd().format(state.issueDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: state.issueDate ?? DateTime.now(),
                      firstDate: DateTime(1970),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) notifier.setIssueDate(d);
                  },
                ),
                if (state.photoPath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Image.file(
                      File(state.photoPath!),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.photo),
                      label: const Text('Photo'),
                      onPressed: () => _pickCertPhoto(ref, notifier),
                    ),
                    if (state.photoPath != null)
                      TextButton(
                        onPressed: () => notifier.setPhotoPath(null),
                        child: const Text('Remove'),
                      ),
                  ],
                ),
                if (state.saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Save failed: ${state.saveError}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final notifier = ref.read(
              certificationFormProvider(existingId).notifier,
            );
            final ok = await notifier.save();
            if (ok) {
              unawaited(
                ref.read(certificationListNotifierProvider.notifier).refresh(),
              );
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickCertPhoto(
    WidgetRef ref,
    CertificationFormNotifier notifier,
  ) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    final path = await ImageStore.instance.copyToAppDir(xfile.path);
    notifier.setPhotoPath(path);
  }
}
