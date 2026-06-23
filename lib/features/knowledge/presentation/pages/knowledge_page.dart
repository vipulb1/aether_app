import 'package:flutter/material.dart';

class KnowledgePage extends StatelessWidget {
  const KnowledgePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Knowledge',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              'PINNED MEMORIES',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
          ),
          _KnowledgeCard(
            'Q3 Product Roadmap',
            'From: Q2 Strategy Review',
            'AI-powered analytics module launching Q3. Beta testing with 15 enterprise customers starts next week.',
          ),
          _KnowledgeCard(
            "Elena's Growth Path",
            'From: 1:1 with Elena',
            'Target: Staff Engineer. Focus areas: cross-team communication, public speaking.',
          ),
          _KnowledgeCard(
            'EHR Integration Requirements',
            'From: User Interview — Dr. Patel',
            'Three critical pain points identified in current EHR workflow.',
          ),
        ],
      ),
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  final String title, source, snippet;
  const _KnowledgeCard(this.title, this.source, this.snippet);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            source,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snippet,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.5,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
