part of 'cloud_app.dart';

class PassyChapter {
  const PassyChapter(
    this.label,
    this.icon,
    this.title,
    this.story,
    this.action,
    this.color,
  );
  final String label, icon, title, story, action;
  final Color color;
}

const passyChapters = [
  PassyChapter(
    'Câu chuyện Passy',
    'shop',
    'Đồ đi tiếp.\nNgười gần nhau hơn.',
    'Một chiếc ghế từng ở cạnh cửa sổ nhà bạn có thể thành góc đọc sách của một người hàng xóm. Passy bắt đầu từ ý nghĩ giản dị ấy: khi đồ còn dùng được, câu chuyện của nó vẫn còn tiếp.',
    'Xem đồ quanh bạn',
    Color(0xFFFFEBD9),
  ),
  PassyChapter(
    'Ký gửi tại Passy',
    'parcel',
    'Gửi một món đồ,\nnhường chỗ cho điều mới.',
    'Bạn dọn nhà và còn một chiếc đèn tốt, nhưng chẳng có thời gian đăng bán và hẹn khách. Gửi yêu cầu cho Passy, cùng chốt giá và hoa hồng, rồi bàn giao tại điểm tiếp nhận đã hẹn.',
    'Xem cách ký gửi',
    Color(0xFFFFE8D4),
  ),
  PassyChapter(
    'Quyên góp',
    'gift',
    'Cuốn sách cũ,\ntrang đầu của ai đó.',
    'Cuốn sách đã đọc xong có thể là cuốn đầu tiên người khác mang về. Nếu món đồ còn tốt và bạn muốn trao miễn phí, hãy đăng vào mục Quyên góp và hẹn người nhận gần bạn.',
    'Khám phá quyên góp',
    Color(0xFFFCE4E8),
  ),
  PassyChapter(
    'Cộng đồng',
    'apartments',
    'Chung một mái nhà,\nthêm một lời chào.',
    'Một câu hỏi trong nhóm chung cư có thể dẫn tới buổi đổi sách ở sảnh. Bắt đầu bằng một bài viết hỏi đáp, lời nhờ giúp đỡ hay lời rủ gặp mặt với những người sống bên cạnh.',
    'Gặp hàng xóm',
    Color(0xFFDEEEE6),
  ),
];

class PassyChapterPanel extends StatelessWidget {
  const PassyChapterPanel({
    super.key,
    required this.chapter,
    this.action,
    this.secondary,
    this.compact = false,
  });

  final PassyChapter chapter;
  final VoidCallback? action;
  final Widget? secondary;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final horizontal = box.maxWidth >= 640;
      final story = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapter.label,
            style: const TextStyle(
              color: Color(0xFF674E42),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            chapter.title,
            style: TextStyle(
              fontSize: horizontal && !compact ? 43 : 27,
              height: 1.08,
              letterSpacing: -.8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            chapter.story,
            style: const TextStyle(color: Color(0xFF53443E), height: 1.5),
          ),
          if (action != null || secondary != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (action != null)
                  FilledButton(onPressed: action, child: Text(chapter.action)),
                if (secondary != null) secondary!,
              ],
            ),
          ],
        ],
      );
      final art = ExcludeSemantics(
        child: Container(
          height: horizontal ? (compact ? 178 : 224) : 91,
          width: horizontal ? (compact ? 190 : 264) : 106,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: .92),
                Colors.white.withValues(alpha: .16),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (horizontal && !compact)
                Positioned(
                  right: 18,
                  top: 10,
                  child: emoji(
                    chapter.icon == 'apartments'
                        ? 'chat'
                        : chapter.icon == 'shop'
                        ? 'pin'
                        : 'heart',
                    65,
                  ),
                ),
              emoji(chapter.icon, horizontal ? (compact ? 147 : 177) : 78),
            ],
          ),
        ),
      );
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(horizontal ? 30 : 18),
        decoration: BoxDecoration(
          color: chapter.color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: horizontal
            ? Row(
                children: [
                  Expanded(child: story),
                  const SizedBox(width: 28),
                  art,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [art, story],
              ),
      );
    },
  );
}

class PassyStoryCarousel extends StatefulWidget {
  const PassyStoryCarousel({
    super.key,
    required this.onAction,
    required this.onArea,
  });
  final ValueChanged<int> onAction;
  final VoidCallback onArea;

  @override
  State<PassyStoryCarousel> createState() => _PassyStoryCarouselState();
}

class _PassyStoryCarouselState extends State<PassyStoryCarousel> {
  final controller = PageController();
  int current = 0;
  bool paused = false, hovering = false, focusing = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (paused ||
          hovering ||
          focusing ||
          !mounted ||
          MediaQuery.disableAnimationsOf(context) ||
          !(ModalRoute.of(context)?.isCurrent ?? false))
        return;
      move((current + 1) % passyChapters.length);
    });
  }

  void move(int index) {
    if (!controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(index);
    } else {
      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 440),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => hovering = true,
    onExit: (_) => hovering = false,
    child: Focus(
      onFocusChange: (value) => focusing = value,
      child: LayoutBuilder(
        builder: (context, box) {
          final desktop = box.maxWidth >= 640;
          final scaled = MediaQuery.textScalerOf(context).scale(16) / 16;
          return Column(
            children: [
              SizedBox(
                height:
                    (desktop ? 340.0 : 421.0) + (scaled - 1).clamp(0, 4) * 350,
                child: NotificationListener<ScrollStartNotification>(
                  onNotification: (event) {
                    if (event.dragDetails != null && !paused)
                      setState(() => paused = true);
                    return false;
                  },
                  child: PageView.builder(
                    controller: controller,
                    itemCount: passyChapters.length,
                    onPageChanged: (index) => setState(() => current = index),
                    itemBuilder: (context, index) => PassyChapterPanel(
                      chapter: passyChapters[index],
                      action: () => widget.onAction(index),
                      secondary: index == 0
                          ? TextButton(
                              onPressed: widget.onArea,
                              child: const Text('Đổi khu vực'),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Chương trước',
                    onPressed: () => move(
                      (current - 1 + passyChapters.length) %
                          passyChapters.length,
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  for (final (index, chapter) in passyChapters.indexed)
                    IconButton(
                      tooltip: chapter.label,
                      onPressed: () => move(index),
                      icon: Icon(
                        index == current ? Icons.circle : Icons.circle_outlined,
                        size: 11,
                        color: brand,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Chương tiếp',
                    onPressed: () => move((current + 1) % passyChapters.length),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  if (!MediaQuery.disableAnimationsOf(context))
                    IconButton(
                      tooltip: paused ? 'Phát tự động' : 'Tạm dừng',
                      onPressed: () => setState(() => paused = !paused),
                      icon: Icon(
                        paused ? Icons.play_arrow : Icons.pause,
                        size: 19,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class PassyStoryTour extends StatefulWidget {
  const PassyStoryTour({super.key});

  @override
  State<PassyStoryTour> createState() => _PassyStoryTourState();
}

class _PassyStoryTourState extends State<PassyStoryTour> {
  int index = 0;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Chào mừng đến Passy  ·  ${index + 1}/${passyChapters.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Bỏ qua',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            PassyChapterPanel(chapter: passyChapters[index], compact: true),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (index > 0)
                  TextButton(
                    onPressed: () => setState(() => index--),
                    child: const Text('Quay lại'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bỏ qua'),
                ),
                FilledButton(
                  onPressed: index == passyChapters.length - 1
                      ? () => Navigator.pop(context)
                      : () => setState(() => index++),
                  child: Text(
                    index == passyChapters.length - 1
                        ? 'Bắt đầu khám phá'
                        : 'Tiếp theo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
