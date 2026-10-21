// Adapted from Sorted's features/orders/order_presentation.dart @902dc25.
// The statuses are a participant's (spec §2), worded as DESIGN.md's
// ShareStatusPill.

/// How a share's status is drawn. Wording is specific so Waiting, Pending
/// and Declined stay distinct; Paid is the one success colour.
enum StatusTone { paid, waiting, progress, pending, declined, draft, closed }

class StatusPresentation {
  const StatusPresentation(this.label, this.tone);
  final String label;
  final StatusTone tone;
}

StatusPresentation statusPresentation(String status) => switch (status) {
  'paid' => const StatusPresentation('Paid', StatusTone.paid),
  'paid_cash' => const StatusPresentation('Paid in cash', StatusTone.paid),
  'owes' || 'link_opened' => const StatusPresentation('Waiting', StatusTone.waiting),
  'processing' => const StatusPresentation('Confirming', StatusTone.progress),
  'pending' => const StatusPresentation('Pending', StatusTone.pending),
  'declined' => const StatusPresentation('Declined', StatusTone.declined),
  'claimed' => const StatusPresentation('Claimed', StatusTone.progress),
  'invited' => const StatusPresentation('Invited', StatusTone.draft),
  'on_us' => const StatusPresentation('On us', StatusTone.draft),
  _ => const StatusPresentation('Unknown', StatusTone.closed),
};
