import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static bool _hasCheckedThisSession = false;
  
  static Future<void> checkForUpdates(BuildContext context) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;
    
    try {
      // Get the update document from Firestore
      final updateDoc = await FirebaseFirestore.instance
          .collection('updates')
          .doc('version')
          .get();
      
      if (!updateDoc.exists) return;
      
      final updateData = updateDoc.data();
      final bool isUpdateRequired = updateData?['active'] ?? false;
      
      if (isUpdateRequired && context.mounted) {
        _showUpdateDialog(
          context,
          updateData?['version'] ?? '',
          updateData?['message'] ?? 'A new version is available.',
          updateData?['playStoreUrl'] ?? 'https://play.google.com/store/apps',
          updateData?['forceUpdate'] ?? false,
        );
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }
  
  static void _showUpdateDialog(
    BuildContext context, 
    String version, 
    String message, 
    String playStoreUrl,
    bool forceUpdate,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.system_update, color: Colors.amber.shade800, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Update Available',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.shade300),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Icon(
                Icons.downloading_rounded,
                size: 64,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Version $version is now available',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (forceUpdate)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This update is required to continue using the app',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Later',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ElevatedButton(
              onPressed: () async {
                final Uri url = Uri.parse(playStoreUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open Play Store')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
} 