import 'package:flutter/material.dart';
import 'package:avatar_maker/avatar_maker.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AvatarHeader extends StatefulWidget {
  const AvatarHeader({super.key});

  @override
  State<AvatarHeader> createState() => _AvatarHeaderState();
}

class _AvatarHeaderState extends State<AvatarHeader> {
  final AvatarMakerController _avatarController =
      NonPersistentAvatarMakerController(customizedPropertyCategories: []);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AvatarCustomizePage(controller: _avatarController),
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AvatarMakerAvatar(
          controller: _avatarController,
          radius: 70,
          backgroundColor: Colors.grey.shade200,
        ),
      ),
    );
  }
}

class AvatarCustomizePage extends StatelessWidget {
  final AvatarMakerController controller;

  const AvatarCustomizePage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final panelWidth = width >= 900 ? 820.0 : width * 0.9;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            AvatarMakerAvatar(
              controller: controller,
              radius: 90,
              backgroundColor: Colors.grey.shade200,
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AvatarMakerSaveWidget(controller: controller),
                const SizedBox(width: 8),
                AvatarMakerRandomWidget(controller: controller),
                const SizedBox(width: 8),
                AvatarMakerResetWidget(controller: controller),
              ],
            ),

            const SizedBox(height: 20),

            _AvatarTopTabsCustomizer(controller: controller, width: panelWidth),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AvatarTopTabsCustomizer extends StatefulWidget {
  const _AvatarTopTabsCustomizer({
    required this.controller,
    required this.width,
  });

  final AvatarMakerController controller;
  final double width;

  @override
  State<_AvatarTopTabsCustomizer> createState() =>
      _AvatarTopTabsCustomizerState();
}

class _AvatarTopTabsCustomizerState extends State<_AvatarTopTabsCustomizer> {
  static const double _panelHeight = 250;

  int _selectedIndex = 0;
  _AvatarGender _gender = _AvatarGender.neutral;

  static const _tabs = [
    _AvatarCustomizerTab(
      genderTab: true,
      label: 'Cinsiyet',
      icon: Icons.wc_rounded,
    ),
    _AvatarCustomizerTab(
      id: PropertyCategoryIds.SkinColor,
      label: 'Cilt Rengi',
      icon: Icons.face_retouching_natural_outlined,
    ),
    _AvatarCustomizerTab(
      id: PropertyCategoryIds.HairStyle,
      label: 'Saç',
      icon: Icons.content_cut_rounded,
    ),
    _AvatarCustomizerTab(
      id: PropertyCategoryIds.HairColor,
      label: 'Saç Rengi',
      icon: Icons.palette_outlined,
    ),
    _AvatarCustomizerTab(
      id: PropertyCategoryIds.FacialHairType,
      label: 'Sakal',
      icon: Icons.mood_outlined,
    ),
    _AvatarCustomizerTab(
      id: PropertyCategoryIds.OutfitType,
      label: 'Kıyafet',
      icon: Icons.checkroom_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _AvatarTopTabsCustomizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = _tabs[_selectedIndex];
    final columns = widget.width >= 700 ? 7 : 4;

    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final selected = index == _selectedIndex;
              return Expanded(
                child: _AvatarTabButton(
                  tab: tab,
                  selected: selected,
                  onTap: () => setState(() => _selectedIndex = index),
                ),
              );
            }),
          ),
          Container(
            height: _panelHeight,
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              border: Border.all(color: Colors.grey.shade500, width: 2),
            ),
            child: currentTab.genderTab
                ? _GenderSelector(selected: _gender, onChanged: _selectGender)
                : _buildCategoryGrid(currentTab.id!, columns),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(PropertyCategoryIds categoryId, int columns) {
    final category = widget.controller.displayedPropertyCategories.firstWhere(
      (item) => item.id == categoryId,
    );
    final selectedItem =
        widget.controller.selectedOptions[category.id] ??
        category.properties!.first;

    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      primary: false,
      itemCount: category.properties!.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final item = category.properties![index];
        final selected = item == selectedItem;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _selectOption(category.id, item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFEFEAFF)
                  : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF684CFF)
                    : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: SvgPicture.string(
              widget.controller.getComponentSVG(category.id, index),
              fit: BoxFit.contain,
              placeholderBuilder: (_) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectOption(PropertyCategoryIds categoryId, PropertyItem item) {
    if (widget.controller.selectedOptions[categoryId] == item) return;
    widget.controller.selectedOptions[categoryId] = item;
    widget.controller.updatePreview();
    setState(() {});
  }

  void _selectGender(_AvatarGender gender) {
    _gender = gender;
    switch (gender) {
      case _AvatarGender.feminine:
        widget.controller.selectedOptions[PropertyCategoryIds.HairStyle] =
            HairStyles.LongStraight;
        widget.controller.selectedOptions[PropertyCategoryIds.FacialHairType] =
            FacialHairTypes.Nothing;
        widget.controller.selectedOptions[PropertyCategoryIds.OutfitType] =
            OutfitTypes.ShirtScoopNeck;
        break;
      case _AvatarGender.masculine:
        widget.controller.selectedOptions[PropertyCategoryIds.HairStyle] =
            HairStyles.ShortWaved;
        widget.controller.selectedOptions[PropertyCategoryIds.FacialHairType] =
            FacialHairTypes.BeardLight;
        widget.controller.selectedOptions[PropertyCategoryIds.OutfitType] =
            OutfitTypes.Hoodie;
        break;
      case _AvatarGender.neutral:
        widget.controller.selectedOptions[PropertyCategoryIds.HairStyle] =
            HairStyles.ShortRound;
        widget.controller.selectedOptions[PropertyCategoryIds.FacialHairType] =
            FacialHairTypes.Nothing;
        widget.controller.selectedOptions[PropertyCategoryIds.OutfitType] =
            OutfitTypes.GraphicShirt;
        break;
    }
    widget.controller.updatePreview();
    setState(() {});
  }
}

class _AvatarCustomizerTab {
  const _AvatarCustomizerTab({
    this.id,
    this.genderTab = false,
    required this.label,
    required this.icon,
  });

  final PropertyCategoryIds? id;
  final bool genderTab;
  final String label;
  final IconData icon;
}

enum _AvatarGender { feminine, masculine, neutral }

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({required this.selected, required this.onChanged});

  final _AvatarGender selected;
  final ValueChanged<_AvatarGender> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        _AvatarGender.feminine,
        'Kadın',
        Icons.female_rounded,
        'Uzun saç, sakalsız görünüm',
      ),
      (
        _AvatarGender.masculine,
        'Erkek',
        Icons.male_rounded,
        'Kısa saç ve sakal görünümü',
      ),
      (
        _AvatarGender.neutral,
        'Nötr',
        Icons.person_outline_rounded,
        'Sade, sakalsız görünüm',
      ),
    ];

    return Row(
      children: options.map((option) {
        final active = selected == option.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: option.$1 == _AvatarGender.neutral ? 0 : 10,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(option.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFEFEAFF)
                      : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF684CFF)
                        : Colors.grey.shade300,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      option.$3,
                      size: 28,
                      color: active
                          ? const Color(0xFF684CFF)
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      option.$2,
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      option.$4,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AvatarTabButton extends StatelessWidget {
  const _AvatarTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _AvatarCustomizerTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: selected ? 48 : 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF5F5F5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
          border: Border(
            top: BorderSide(color: Colors.grey.shade500, width: 2),
            left: BorderSide(color: Colors.grey.shade500, width: 2),
            right: BorderSide(color: Colors.grey.shade500, width: 2),
            bottom: BorderSide(
              color: selected ? Colors.white : Colors.grey.shade500,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 16, color: Colors.grey.shade800),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade900,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
