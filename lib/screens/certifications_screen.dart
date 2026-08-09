import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/certification.dart';
import '../providers/dive_providers.dart';

class CertificationsScreen extends ConsumerWidget {
  const CertificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCerts = ref.watch(certificationListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Certifications')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: asyncCerts.when(
        data: (certs) {
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
                    leading: const Icon(Icons.card_membership),
                    title: Text(cert.level),
                    subtitle: cert.issueDate != null
                        ? Text(
                            'Issued ${cert.issueDate!.year}-${cert.issueDate!.month.toString().padLeft(2, '0')}',
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await ref
                            .read(databaseProvider)
                            .deleteCertification(cert.id!);
                        ref.invalidate(certificationListProvider);
                      },
                    ),
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final orgCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Certification'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: orgCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Organization (e.g. PADI, SSI)',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: levelCtrl,
                  decoration: const InputDecoration(labelText: 'Level'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await ref
                    .read(databaseProvider)
                    .insertCertification(
                      Certification(org: orgCtrl.text, level: levelCtrl.text),
                    );
                ref.invalidate(certificationListProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
