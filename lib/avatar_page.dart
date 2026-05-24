import 'package:flutter/material.dart';
import 'package:avatar_maker/avatar_maker.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'core/api_client.dart';

class AvatarHeader extends StatefulWidget {
  const AvatarHeader({super.key, this.expression = AvatarExpression.normal});

  final AvatarExpression expression;

  @override
  State<AvatarHeader> createState() => _AvatarHeaderState();
}

class _AvatarHeaderState extends State<AvatarHeader> {
  late AvatarMakerController _avatarController;

  @override
  void initState() {
    super.initState();
    _avatarController = NonPersistentAvatarMakerController(
      customizedPropertyCategories: [],
    );
    _loadAvatarFromDb();
    _applyAvatarExpression(_avatarController, widget.expression);
  }

  @override
  void didUpdateWidget(covariant AvatarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      _applyAvatarExpression(_avatarController, widget.expression);
    }
  }

  Future<void> _loadAvatarFromDb() async {
    try {
      final user = await ApiClient.getMe();
      final avatarSvg = user['avatarSvg']?.toString();
      if (!mounted || avatarSvg == null || avatarSvg.trim().isEmpty) return;
      setState(() {
        _avatarController = NonPersistentAvatarMakerController.fromSvg(
          svg: avatarSvg,
          customizedPropertyCategories: [],
        );
        _applyAvatarExpression(_avatarController, widget.expression);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AvatarCustomizePage(
              controller: _avatarController,
              initialExpression: widget.expression,
            ),
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
  final AvatarExpression initialExpression;

  const AvatarCustomizePage({
    super.key,
    required this.controller,
    this.initialExpression = AvatarExpression.normal,
  });

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
                _AvatarDbSaveButton(controller: controller),
                const SizedBox(width: 8),
                AvatarMakerRandomWidget(controller: controller),
                const SizedBox(width: 8),
                AvatarMakerResetWidget(controller: controller),
              ],
            ),

            const SizedBox(height: 20),

            _AvatarTopTabsCustomizer(
              controller: controller,
              width: panelWidth,
              initialExpression: initialExpression,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AvatarDbSaveButton extends StatefulWidget {
  const _AvatarDbSaveButton({required this.controller});

  final AvatarMakerController controller;

  @override
  State<_AvatarDbSaveButton> createState() => _AvatarDbSaveButtonState();
}

class _AvatarDbSaveButtonState extends State<_AvatarDbSaveButton> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ApiClient.saveAvatar(
        avatarSvg: widget.controller.getAvatarSVGSync(),
        avatarOptions: widget.controller.getJsonOptionsSync(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avatar kaydedildi.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Avatarı kaydet',
      onPressed: _saving ? null : _save,
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_rounded),
    );
  }
}

class _AvatarTopTabsCustomizer extends StatefulWidget {
  const _AvatarTopTabsCustomizer({
    required this.controller,
    required this.width,
    required this.initialExpression,
  });

  final AvatarMakerController controller;
  final double width;
  final AvatarExpression initialExpression;

  @override
  State<_AvatarTopTabsCustomizer> createState() =>
      _AvatarTopTabsCustomizerState();
}

class _AvatarTopTabsCustomizerState extends State<_AvatarTopTabsCustomizer> {
  static const double _panelHeight = 250;

  int _selectedIndex = 0;
  _AvatarGender _gender = _AvatarGender.neutral;
  late AvatarExpression _expression;

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
      expressionTab: true,
      label: 'İfade',
      icon: Icons.face_6_outlined,
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
    _expression = widget.initialExpression;
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
                : currentTab.expressionTab
                ? _ExpressionSelector(
                    selected: _expression,
                    onChanged: _selectExpression,
                  )
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

  void _selectExpression(AvatarExpression expression) {
    _expression = expression;
    _applyAvatarExpression(widget.controller, expression);
    setState(() {});
  }
}

class _AvatarCustomizerTab {
  const _AvatarCustomizerTab({
    this.id,
    this.genderTab = false,
    this.expressionTab = false,
    required this.label,
    required this.icon,
  });

  final PropertyCategoryIds? id;
  final bool genderTab;
  final bool expressionTab;
  final String label;
  final IconData icon;
}

enum _AvatarGender { feminine, masculine, neutral }

enum AvatarExpression { normal, sleepy, stressed }

void _applyAvatarExpression(
  AvatarMakerController controller,
  AvatarExpression expression,
) {
  switch (expression) {
    case AvatarExpression.normal:
      controller.selectedOptions[PropertyCategoryIds.EyeType] = Eyes.Default;
      controller.selectedOptions[PropertyCategoryIds.EyebrowType] =
          Eyebrows.Default;
      controller.selectedOptions[PropertyCategoryIds.MouthType] =
          Mouths.Default;
      break;
    case AvatarExpression.sleepy:
      controller.selectedOptions[PropertyCategoryIds.EyeType] = Eyes.Closed;
      controller.selectedOptions[PropertyCategoryIds.EyebrowType] =
          Eyebrows.DefaultNatural;
      controller.selectedOptions[PropertyCategoryIds.MouthType] =
          Mouths.Disbelief;
      break;
    case AvatarExpression.stressed:
      controller.selectedOptions[PropertyCategoryIds.EyeType] = Eyes.Dizzy;
      controller.selectedOptions[PropertyCategoryIds.EyebrowType] =
          Eyebrows.SadConcerned;
      controller.selectedOptions[PropertyCategoryIds.MouthType] =
          Mouths.Grimace;
      break;
  }
  controller.updatePreview();
}

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

class _ExpressionSelector extends StatelessWidget {
  const _ExpressionSelector({required this.selected, required this.onChanged});

  final AvatarExpression selected;
  final ValueChanged<AvatarExpression> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        AvatarExpression.normal,
        'Normal',
        Icons.sentiment_satisfied_alt_rounded,
        'Varsayılan yüz ifadesi',
      ),
      (
        AvatarExpression.sleepy,
        'Uykulu',
        Icons.bedtime_rounded,
        'Kapalı gözlü, yorgun görünüm',
      ),
      (
        AvatarExpression.stressed,
        'Stresli',
        Icons.sentiment_very_dissatisfied_rounded,
        'Gergin kaş ve ağız ifadesi',
      ),
    ];

    return Row(
      children: options.map((option) {
        final active = selected == option.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: option.$1 == AvatarExpression.stressed ? 0 : 10,
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
                      size: 30,
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
