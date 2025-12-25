class FlashCard {
  final String id;
  final String frontText;
  final String backText;
  final bool isLearned;

  FlashCard({
    required this.id,
    required this.frontText,
    required this.backText,
    this.isLearned = false,
  });
}

