// Trimmed from Sorted's features/orders/order_presentation.dart @902dc25 to
// the status mapping the pill draws. The labels are still Sorted's order
// statuses; the participant statuses (spec §2, DESIGN.md ShareStatusPill)
// replace them when the Tracker is built.

/// How a backend status is drawn. Wording is specific so Link sent, Pending
/// and Declined stay distinct; Paid is the one success colour.
enum StatusTone { paid, waiting, progress, pending, declined, draft, closed }

class StatusPresentation {
  const StatusPresentation(this.label, this.tone);
  final String label;
  final StatusTone tone;
}

StatusPresentation statusPresentation(String status) => switch (status) {
  'paid' => const StatusPresentation('Paid', StatusTone.paid),
  'link_sent' => const StatusPresentation('Link sent', StatusTone.waiting),
  'processing' => const StatusPresentation('Confirming', StatusTone.progress),
  'pending' => const StatusPresentation('Pending', StatusTone.pending),
  'declined' => const StatusPresentation('Declined', StatusTone.declined),
  'draft' => const StatusPresentation('Draft', StatusTone.draft),
  'cancelled' => const StatusPresentation('Cancelled', StatusTone.closed),
  'expired' => const StatusPresentation('Expired', StatusTone.closed),
  _ => const StatusPresentation('Unknown', StatusTone.closed),
};
