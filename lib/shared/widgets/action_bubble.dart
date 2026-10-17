// lib/shared/widgets/action_bubble.dart
// 圆角小气泡菜单：竖向排列的图标+文字行，用于记录详情页「⋯」菜单。
// 以后首页卡片长按、分类/标签页长按需要菜单时也复用这个，保持风格一致。

import 'package:flutter/material.dart';
import 'package:suicun/shared/theme/app_theme.dart';

/// 气泡中的一行。
class ActionBubbleItem {
  const ActionBubbleItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false, // 删除用红色，并在上方加分隔线
    this.enabled = true, // 置灰时仍可点击（由 onTap 决定行为，如提示）
  });

  final IconData icon;
  final String label;
  final bool destructive;
  final bool enabled;
  final VoidCallback onTap;
}

/// 在 [anchorKey] 对应的按钮正下方弹出气泡菜单。
///
/// - 遮罩颜色 #202938 6%，点击空白处关闭；返回键可关闭。
/// - 气泡在锚点按钮正下方 4px，右边缘与按钮右边缘对齐，距屏幕右边缘 ≥12px。
/// - 宽度自适应 168–240px。
/// - 弹出：缩放 0.92→1.0 + 淡入，160ms easeOutCubic；关闭：淡出 100ms。
/// - 点击某一行后先关闭气泡，再执行 [ActionBubbleItem.onTap]。
Future<void> showActionBubble({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<ActionBubbleItem> items,
}) async {
  if (items.isEmpty) return;

  // 在打开对话框前算好位置（对话框的 context 拿不到锚点位置）。
  final box =
      anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final screenSize = MediaQuery.sizeOf(context);
  double top = 0;
  double right = ActionBubbleTheme.screenEdgeMargin;
  if (box != null) {
    final anchorTopLeft = box.localToGlobal(Offset.zero);
    top = anchorTopLeft.dy +
        box.size.height +
        ActionBubbleTheme.anchorGap;
    right = (screenSize.width -
            (anchorTopLeft.dx + box.size.width))
        .clamp(
            ActionBubbleTheme.screenEdgeMargin, double.infinity);
  }

  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0xFF202938)
          .withValues(alpha: ActionBubbleTheme.barrierOpacity),
      transitionDuration:
          const Duration(milliseconds: ActionBubbleTheme.popInMs),
      reverseTransitionDuration:
          const Duration(milliseconds: ActionBubbleTheme.fadeOutMs),
      pageBuilder: (dialogContext, _, __) => Stack(
        children: [
          Positioned(
            top: top,
            right: right,
            child: _ActionBubble(
              items: items,
              onItemTap: (item) {
                // 先关气泡，再执行操作。
                Navigator.of(dialogContext).pop();
                item.onTap();
              },
            ),
          ),
        ],
      ),
      transitionsBuilder: (dialogContext, animation, _, child) {
        // 弹出：缩放 + 淡入；关闭：只淡出。
        final Animation<double> scale = animation.status ==
                AnimationStatus.reverse
            ? const AlwaysStoppedAnimation<double>(1.0)
            : Tween<double>(
                    begin: ActionBubbleTheme.popScaleFrom, end: 1.0)
                .animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scale,
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    ),
  );
}

class _ActionBubble extends StatelessWidget {
  const _ActionBubble({required this.items, required this.onItemTap});

  final List<ActionBubbleItem> items;
  final void Function(ActionBubbleItem item) onItemTap;

  @override
  Widget build(BuildContext context) {
    final t = context.actionBubble;
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.destructive && i > 0) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          indent: ActionBubbleTheme.dividerIndent,
          endIndent: ActionBubbleTheme.dividerIndent,
          color: t.divider,
        ));
      }
      rows.add(_ActionBubbleRow(
        item: item,
        onTap: () => onItemTap(item),
      ));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: ActionBubbleTheme.minWidth,
        maxWidth: ActionBubbleTheme.maxWidth,
      ),
      child: IntrinsicWidth(
        child: Container(
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: BorderRadius.circular(
                ActionBubbleTheme.borderRadius),
            border: Border.all(color: t.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: t.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
              vertical: ActionBubbleTheme.verticalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    );
  }
}

class _ActionBubbleRow extends StatelessWidget {
  const _ActionBubbleRow({required this.item, required this.onTap});

  final ActionBubbleItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.actionBubble;
    final iconColor =
        item.destructive ? t.destructive : t.rowIcon;
    final textColor =
        item.destructive ? t.destructive : t.rowText;
    final pressedBg =
        item.destructive ? t.pressedDestructive : t.pressedRow;

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ActionBubbleTheme.rowHMargin),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
            ActionBubbleTheme.pressedRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
              ActionBubbleTheme.pressedRadius),
          splashFactory: NoSplash.splashFactory,
          highlightColor: pressedBg,
          child: Container(
            height: ActionBubbleTheme.rowHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: ActionBubbleTheme.rowHPadding -
                  ActionBubbleTheme.rowHMargin,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon,
                    size: ActionBubbleTheme.iconSize,
                    color: iconColor),
                const SizedBox(
                    width: ActionBubbleTheme.iconTextGap),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ActionBubbleTheme.fontSize,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!item.enabled) {
      row = Opacity(
          opacity: ActionBubbleTheme.disabledOpacity, child: row);
    }
    return row;
  }
}
