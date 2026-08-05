// lib/presentation/thix_reservation/bus/widgets/client/bus_filter_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bus_search_provider.dart';

class BusFilterBottomSheet extends StatelessWidget {
  const BusFilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusSearchProvider>();
    // CORRIGÉ : allResults est public maintenant, plus _allResults
    final agencies = provider.allResults.map((e) => e.agency).whereType().toSet().toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Filtres', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),

          const Text('Prix (FCFA)', style: TextStyle(fontWeight: FontWeight.w600)),
          RangeSlider(
            min: 0,
            max: 50000,
            divisions: 10,
            labels: RangeLabels('${provider.minPrice.round()}', '${provider.maxPrice.round()}'),
            values: RangeValues(provider.minPrice, provider.maxPrice),
            onChanged: (v) => provider.updatePriceFilter(v.start, v.end)
          ),

          const SizedBox(height: 16),
          const Text('Type de bus', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Tous'), selected: provider.selectedBusType == null, onSelected: (_) => provider.clearFilters()),
            ChoiceChip(label: const Text('VIP'), selected: provider.selectedBusType == 'vip', onSelected: (_) { provider.selectedBusType = 'vip'; provider.updatePriceFilter(provider.minPrice, provider.maxPrice); }),
            ChoiceChip(label: const Text('Standard'), selected: provider.selectedBusType == 'standard', onSelected: (_) { provider.selectedBusType = 'standard'; provider.updatePriceFilter(provider.minPrice, provider.maxPrice); }),
            ChoiceChip(label: const Text('Climatisé'), selected: provider.selectedBusType == 'clim', onSelected: (_) { provider.selectedBusType = 'clim'; provider.updatePriceFilter(provider.minPrice, provider.maxPrice); }),
          ]),

          if (agencies.isNotEmpty)...[
            const SizedBox(height: 16),
            const Text('Agences', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
          ...agencies.map((ag) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(children: [
                if (ag.logoUrl!= null) CircleAvatar(radius: 12, backgroundImage: NetworkImage(ag.logoUrl!)),
                if (ag.logoUrl == null) CircleAvatar(radius: 12, child: Text(ag.name[0])),
                const SizedBox(width: 8),
                Expanded(child: Text(ag.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                if (ag.isVerified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: Colors.blue)),
              ]),
              value: provider.selectedAgencies.contains(ag.id),
              onChanged: (_) => provider.toggleAgency(ag.id),
            )),
          ],

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () { provider.clearFilters(); Navigator.pop(context); }, child: const Text('Réinitialiser'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)), child: const Text('Appliquer', style: TextStyle(color: Colors.white)))),
          ]),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ]),
      ),
    );
  }
}
