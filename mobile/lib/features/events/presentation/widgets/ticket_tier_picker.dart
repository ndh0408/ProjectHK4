import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../shared/models/ticket_type.dart';



class TicketTierPickerResult {
  const TicketTierPickerResult({required this.tier, required this.quantity});
  final TicketType tier;
  final int quantity;
}

Future<TicketTierPickerResult?> showTicketTierPicker({
  required BuildContext context,
  required List<TicketType> tiers,
}) {
  return showModalBottomSheet<TicketTierPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _TicketTierPickerSheet(tiers: tiers),
  );
}

class _TicketTierPickerSheet extends StatefulWidget {
  const _TicketTierPickerSheet({required this.tiers});
  final List<TicketType> tiers;

  @override
  State<_TicketTierPickerSheet> createState() => _TicketTierPickerSheetState();
}

class _TicketTierPickerSheetState extends State<_TicketTierPickerSheet> {
  TicketType? _selected;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _selected = widget.tiers.firstWhere(
      (t) => t.isAvailable,
      orElse: () => widget.tiers.first,
    );
  }

  NumberFormat get _usd =>
      NumberFormat.currency(locale: 'en_US', symbol: '\$');

  Widget _tierCard(TicketType tier) {
    final isSelected = _selected?.id == tier.id;
    final enabled = !tier.isSoldOut && tier.availableQuantity > 0;

    Color borderColor;
    if (!enabled) {
      borderColor = Colors.grey.shade300;
    } else if (isSelected) {
      borderColor = AppColors.primary;
    } else {
      borderColor = Colors.grey.shade300;
    }

    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: Material(
        color: isSelected
            ? AppColors.primary.withOpacity(0.08)
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: enabled
              ? () => setState(() {
                    _selected = tier;
                    if (_quantity > tier.maxAllowedPurchase) {
                      _quantity = tier.maxAllowedPurchase.clamp(1, tier.maxPerOrder);
                    }
                  })
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tier.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      tier.isFree ? 'FREE' : _usd.format(tier.price),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tier.isFree ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if ((tier.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    tier.description!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      tier.isSoldOut
                          ? 'Sold out'
                          : '${tier.availableQuantity}/${tier.quantity} available',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Max ${tier.maxPerOrder}/order',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                if (!enabled) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Sold out',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quantityStepper() {
    final tier = _selected;
    final max = tier?.maxAllowedPurchase ?? 1;
    final disabled = tier == null || !tier.isAvailable || max == 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: disabled || _quantity <= 1
              ? null
              : () => setState(() => _quantity--),
          icon: const Icon(Icons.remove_circle_outline),
          iconSize: 32,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$_quantity',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: disabled || _quantity >= max
              ? null
              : () => setState(() => _quantity++),
          icon: const Icon(Icons.add_circle_outline),
          iconSize: 32,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = _selected;
    final total = (tier?.price ?? 0) * _quantity;
    final canConfirm = tier != null && tier.isAvailable && _quantity > 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.confirmation_number_outlined),
                  SizedBox(width: 8),
                  Text(
                    'Select Ticket Type',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.tiers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _tierCard(widget.tiers[i]),
              ),
            ),
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Quantity',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            _quantityStepper(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(
                    tier != null && tier.isFree
                        ? 'FREE'
                        : _usd.format(total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canConfirm
                      ? () => Navigator.of(context).pop(
                            TicketTierPickerResult(
                              tier: tier,
                              quantity: _quantity,
                            ),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    tier != null && tier.isFree
                        ? 'Continue — FREE'
                        : 'Continue — ${_usd.format(total)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
