import 'dart:convert';

/// Cấu hình 1 channel (fader)
class ChannelConfig {
  final int id;
  final String name;
  final String? color;

  const ChannelConfig({
    required this.id,
    required this.name,
    this.color,
  });

  factory ChannelConfig.fromJson(Map<String, dynamic> json) {
    return ChannelConfig(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'CH ${(json['id'] as int) + 1}',
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (color != null) 'color': color,
      };

  ChannelConfig copyWith({int? id, String? name, String? color}) {
    return ChannelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}

/// Cấu hình 1 pad
class PadConfig {
  final int id;
  final String name;
  /// URL của ảnh pad (từ server web GUI)
  /// Null = hiển thị tên mặc định
  final String? imageUrl;
  final String? color;
  final PadType type;
  /// Layer mà pad này thuộc về (0, 1, 2)
  /// Trong 1 Layer chỉ có 1 pad sáng tại thời điểm (radio button)
  final int layerId;

  const PadConfig({
    required this.id,
    required this.name,
    this.imageUrl,
    this.color,
    this.type = PadType.trigger,
    this.layerId = 0,
  });

  factory PadConfig.fromJson(Map<String, dynamic> json) {
    return PadConfig(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'PAD ${(json['id'] as int) + 1}',
      imageUrl: json['imageUrl'] as String?,
      color: json['color'] as String?,
      type: PadType.values.firstWhere(
        (e) => e.name == (json['type'] as String?),
        orElse: () => PadType.trigger,
      ),
      layerId: json['layerId'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (color != null) 'color': color,
        'type': type.name,
        'layerId': layerId,
      };

  PadConfig copyWith({
    int? id,
    String? name,
    String? imageUrl,
    String? color,
    PadType? type,
    int? layerId,
  }) {
    return PadConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      color: color ?? this.color,
      type: type ?? this.type,
      layerId: layerId ?? this.layerId,
    );
  }
}

enum PadType { trigger, toggle }

/// Cấu hình 1 Group (layer)
/// Mỗi group có 3 channels
class GroupConfig {
  final int id;
  final String name;
  final List<ChannelConfig> channels;
  final bool isActive;

  const GroupConfig({
    required this.id,
    required this.name,
    required this.channels,
    this.isActive = false,
  });

  factory GroupConfig.fromJson(Map<String, dynamic> json) {
    return GroupConfig(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Group ${(json['id'] as int) + 1}',
      channels: (json['channels'] as List<dynamic>?)
              ?.map((e) => ChannelConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'channels': channels.map((c) => c.toJson()).toList(),
        'isActive': isActive,
      };

  GroupConfig copyWith({
    int? id,
    String? name,
    List<ChannelConfig>? channels,
    bool? isActive,
  }) {
    return GroupConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      channels: channels ?? this.channels,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Layout của pad grid
enum PadLayout {
  grid5x3(5, 3, '5×3 (15 pads)'),
  grid5x4(5, 4, '5×4 (20 pads)'),
  grid5x5(5, 5, '5×5 (25 pads)');

  final int columns;
  final int rows;
  final String label;

  const PadLayout(this.columns, this.rows, this.label);

  int get totalPads => columns * rows;

  factory PadLayout.fromString(String? s) {
    return PadLayout.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PadLayout.grid5x3,
    );
  }
}

/// Toàn bộ cấu hình app
class AppConfig {
  /// Danh sách groups (tối đa 5)
  final List<GroupConfig> groups;

  /// Group đang active
  final int activeGroupId;

  /// Layout của pad grid
  final PadLayout padLayout;

  /// Cấu hình các pads
  final List<PadConfig> pads;

  const AppConfig({
    required this.groups,
    required this.activeGroupId,
    required this.padLayout,
    required this.pads,
  });

  /// Tạo config mặc định
  factory AppConfig.defaults() {
    return AppConfig(
      groups: List.generate(
        3,
        (i) => GroupConfig(
          id: i,
          name: 'Group ${i + 1}',
          channels: List.generate(
            3,
            (j) => ChannelConfig(id: j, name: 'CH ${i * 3 + j + 1}'),
          ),
          isActive: i == 0,
        ),
      ),
      activeGroupId: 0,
      padLayout: PadLayout.grid5x3,
      pads: List.generate(
        PadLayout.grid5x3.totalPads,
        (i) => PadConfig(id: i, name: 'PAD ${i + 1}', layerId: 0),
      ),
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final layout = PadLayout.fromString(json['padLayout'] as String?);
    final padCount = layout.totalPads;
    final padsJson = json['pads'] as List<dynamic>?;
    final padsFromJson = padsJson
            ?.map((e) => PadConfig.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return AppConfig(
      groups: (json['groups'] as List<dynamic>?)
              ?.map((e) => GroupConfig.fromJson(e as Map<String, dynamic>))
              .toList()??
          (json['layers'] as List<dynamic>?) // backward compat
              ?.map((e) => GroupConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      activeGroupId: json['activeGroupId'] as int? ?? json['activeLayerId'] as int? ?? 0,
      padLayout: layout,
      pads: List.generate(padCount, (i) {
        if (i < padsFromJson.length) return padsFromJson[i].copyWith(id: i);
        return PadConfig(id: i, name: 'PAD ${i + 1}', layerId: 0);
      }),
    );
  }

  Map<String, dynamic> toJson() => {
        'groups': groups.map((l) => l.toJson()).toList(),
        'activeGroupId': activeGroupId,
        'padLayout': padLayout.name,
        'pads': pads.map((p) => p.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  /// Copy with pad layout change — resize pads list
  AppConfig withPadLayout(PadLayout newLayout) {
    final newPads = List.generate(newLayout.totalPads, (i) {
      if (i < pads.length) return pads[i].copyWith(id: i);
      return PadConfig(id: i, name: 'PAD ${i + 1}');
    });
    return AppConfig(
      groups: groups,
      activeGroupId: activeGroupId,
      padLayout: newLayout,
      pads: newPads,
    );
  }

  /// Copy with active group change
  AppConfig withActiveGroup(int groupId) {
    final updatedGroups = groups.map((g) {
      return g.copyWith(isActive: g.id == groupId);
    }).toList();
    return AppConfig(
      groups: updatedGroups,
      activeGroupId: groupId,
      padLayout: padLayout,
      pads: pads,
    );
  }
}
