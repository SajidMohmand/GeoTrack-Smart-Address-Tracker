import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'map_screen.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final Set<String> _selectedIds = {};
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        centerTitle: true,
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedIds.clear()),
              tooltip: 'Clear selection',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: colorScheme.primary.withOpacity(0.1),
              child: Center(
                child: Text(
                  'Select ${2 - _selectedIds.length} more to compare',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('saved_addresses')
                  .where('userId', isEqualTo: userId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(theme);
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final docId = doc.id;
                    final isSelected = _selectedIds.contains(docId);

                    return _buildAddressItem(
                      context: context,
                      doc: doc,
                      isSelected: isSelected,
                      onTap: () => _onItemTap(doc, docs),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No saved addresses yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first address',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressItem({
    required BuildContext context,
    required QueryDocumentSnapshot doc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Properly handle the Timestamp
    final timestamp = doc['timestamp'] as Timestamp;
    final date = timestamp.toDate();
    final formattedDate = DateFormat('MMM d, y • h:mm a').format(date);

    return Card(
      color: Colors.white70,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: isSelected ? colorScheme.primary : colorScheme.secondary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      doc['label'] ?? 'Unlabeled',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['address'],
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${doc['latitude'].toStringAsFixed(4)}, ${doc['longitude'].toStringAsFixed(4)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved $formattedDate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTap(QueryDocumentSnapshot doc, List<QueryDocumentSnapshot> docs) {
    final docId = doc.id;

    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(docId);
      }

      if (_selectedIds.length == 2) {
        final selectedDocs = docs.where((d) => _selectedIds.contains(d.id)).toList();

        final point1 = LatLng(
          selectedDocs[0]['latitude'],
          selectedDocs[0]['longitude'],
        );
        final point2 = LatLng(
          selectedDocs[1]['latitude'],
          selectedDocs[1]['longitude'],
        );

        _selectedIds.clear();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapScreen(start: point1, end: point2),
          ),
        );
      }
    });
  }
}