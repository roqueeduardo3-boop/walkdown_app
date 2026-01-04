import 'package:flutter/foundation.dart';

enum AppLanguage { pt, en }

enum TowerType { fourSections, fiveSections }

final ValueNotifier<AppLanguage> appLanguage =
    ValueNotifier<AppLanguage>(AppLanguage.pt);

class ProjectInfo {
  final String projectName;
  final String projectNumber;
  final String supervisorName;
  final String road;
  final String towerNumber;
  final DateTime date;

  ProjectInfo({
    required this.projectName,
    required this.projectNumber,
    required this.supervisorName,
    required this.road,
    required this.towerNumber,
    required this.date,
  });
}

class Occurrence {
  final String id;
  final int walkdownId;
  final String location;
  final String description;
  final DateTime createdAt;
  final List<String> photos;

  Occurrence({
    required this.id,
    required this.walkdownId,
    required this.location,
    required this.description,
    required this.createdAt,
    required this.photos,
  });
}

class OccurrencePhoto {
  final int? id;
  final int occurrenceId;
  final String path;

  OccurrencePhoto({
    this.id,
    required this.occurrenceId,
    required this.path,
  });

  factory OccurrencePhoto.fromMap(Map<String, dynamic> map) {
    return OccurrencePhoto(
      id: map['id'] as int?,
      occurrenceId: map['occurrence_id'] as int,
      path: map['path'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'occurrence_id': occurrenceId,
      'path': path,
    };
  }
}

class WalkdownData {
  final int? id;
  final String? ownerUid;
  final ProjectInfo projectInfo;
  final List<Occurrence> occurrences;
  final TowerType towerType;
  final String turbineName;
  final bool isCompleted;
  final String? firestoreId;
  final int needsSync;

  WalkdownData({
    this.id,
    this.ownerUid,
    required this.projectInfo,
    required this.occurrences,
    required this.towerType,
    required this.turbineName,
    this.firestoreId,
    this.isCompleted = false,
    this.needsSync = 1,
  });

  WalkdownData copyWith({
    int? id,
    String? firestoreId,
    ProjectInfo? projectInfo,
    List<Occurrence>? occurrences,
    TowerType? towerType,
    String? turbineName,
    bool? isCompleted,
  }) {
    return WalkdownData(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      projectInfo: projectInfo ?? this.projectInfo,
      occurrences: occurrences ?? this.occurrences,
      towerType: towerType ?? this.towerType,
      turbineName: turbineName ?? this.turbineName,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory WalkdownData.fromMap(Map<String, dynamic> m) {
    return WalkdownData(
      id: m['id'] as int?,
      ownerUid: m['ownerUid'],
      firestoreId: m['firestore_id'] as String?,
      needsSync: (m['needs_sync'] as int?) ?? 1,
      projectInfo: ProjectInfo(
        projectName: m['project_name'] as String? ?? '',
        projectNumber: m['project_number'] as String? ?? '',
        supervisorName: m['supervisor_name'] as String? ?? '',
        road: m['road'] as String? ?? '',
        towerNumber: m['tower_number'] as String? ?? '',
        date: DateTime.parse(m['date'] as String),
      ),
      occurrences: const [],
      towerType: TowerType.values[m['tower_type'] as int? ?? 0],
      turbineName: m['turbine_name'] as String? ?? '',
      isCompleted: (m['is_completed'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerUid': ownerUid,
      'firestore_id': firestoreId,
      'needs_sync': needsSync,
      'project_name': projectInfo.projectName,
      'project_number': projectInfo.projectNumber,
      'supervisor_name': projectInfo.supervisorName,
      'road': projectInfo.road,
      'tower_number': projectInfo.towerNumber,
      'date': projectInfo.date.toIso8601String(),
      'tower_type': towerType.index,
      'turbine_name': turbineName,
      'is_completed': isCompleted ? 1 : 0,
    };
  }
}

class ChecklistItem {
  final String id;
  final String textPt;
  final String? textEn; // ✅ Nullable para permitir PT sem EN

  ChecklistItem({
    required this.id,
    required this.textPt,
    this.textEn,
  });
}

class ChecklistSection {
  final String id;
  final String titlePt;
  final String? titleEn; // ✅ Nullable

  final List<ChecklistItem> items;

  ChecklistSection({
    required this.id,
    required this.titlePt,
    this.titleEn,
    required this.items,
  });
}

List<ChecklistSection> buildChecklistForWalkdown(WalkdownData w) {
  final sections = <ChecklistSection>[];

  // HUB
  sections.add(
    ChecklistSection(
      id: 'HUB',
      titlePt: 'HUB',
      titleEn: 'HUB',
      items: [
        ChecklistItem(
          id: 'hub_bolts_marked',
          textPt: 'Parafusos do HUB marcados a preto e vermelho',
          textEn: 'HUB bolts marked in black and red',
        ),
        ChecklistItem(
          id: 'hub_condition',
          textPt: 'HUB em boas condições gerais',
          textEn: 'HUB in good general condition',
        ),
        ChecklistItem(
          id: 'hub_ladders_straight',
          textPt: 'Escadas internas do HUB direitas e seguras',
          textEn: 'HUB internal ladders straight and safe',
        ),
        ChecklistItem(
          id: 'hub_cable_routing',
          textPt: 'Roteamento dos cabos elétricos correto e protegido',
          textEn: 'Electrical cable routing correct and protected',
        ),
        ChecklistItem(
          id: 'hub_emergency_hatches',
          textPt: 'Escotilhas de emergência do spinner fechadas e travadas',
          textEn: 'Spinner emergency hatches closed and locked',
        ),
        ChecklistItem(
          id: 'hub_stickers',
          textPt: 'Autocolantes presentes e bem colocados',
          textEn: 'Stickers present and correctly placed',
        ),
        ChecklistItem(
          id: 'hub_cleanliness',
          textPt: 'Limpeza geral do spinner em condições',
          textEn: 'Spinner general cleanliness acceptable',
        ),
        ChecklistItem(
          id: 'hub_lift_points',
          textPt: 'Os lift points do HUB têm anti corrosão',
          textEn: 'The HUB lift points have anti-corrosion protection',
        ),
        ChecklistItem(
          id: 'hub_studs',
          textPt: 'Os parafusos das blades estão marcados a preto e vermelho',
          textEn: 'The blade studs are correctly marked with black and red',
        ),
        ChecklistItem(
          id: 'hub_ping_test',
          textPt: 'O teste ping nos parafusos da blade foi aceitável',
          textEn: 'The blade ping test was acceptable',
        ),
        ChecklistItem(
          id: 'hub_blade_clean',
          textPt: 'As blades estão limpas por fora e sem danos',
          textEn: 'The blades are clean and without damages outside',
        ),
      ],
    ),
  );

  // NACELE
  sections.add(
    ChecklistSection(
      id: 'NACELE',
      titlePt: 'Nacele',
      titleEn: 'Nacelle',
      items: [
        ChecklistItem(
          id: 'nacelle_ladders_ok',
          textPt: 'Escadas da nacele fixas e com lixas antiderrapantes',
          textEn: 'Nacelle ladders fixed and with anti-slip strips',
        ),
        ChecklistItem(
          id: 'nacelle_floor_hatches',
          textPt: 'Escotilhas do chão metálico com proteção nos cantos',
          textEn: 'Metal floor hatches with edge protection',
        ),
        ChecklistItem(
          id: 'nacelle_underfloor_clean',
          textPt: 'Chão por baixo da plataforma metálica limpo e em condições',
          textEn: 'Area under metal platform clean and in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_cabinets_doors',
          textPt: 'Portas dos armários em boas condições',
          textEn: 'Cabinet doors in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_data_cable',
          textPt: 'Ligação de dados ligada e com folga suficiente',
          textEn: 'Data connection plugged and with enough slack',
        ),
        ChecklistItem(
          id: 'nacelle_first_aid_3lang',
          textPt: 'Kit de primeiros socorros presente nas 3 línguas',
          textEn: 'First aid kit present in 3 languages',
        ),
        ChecklistItem(
          id: 'nacelle_stickers',
          textPt: 'Autocolantes colocados nos locais corretos',
          textEn: 'Stickers installed in correct locations',
        ),
        ChecklistItem(
          id: 'nacelle_clean_torque_marks',
          textPt: 'Limpeza geral e marcas de torque no gerador visíveis',
          textEn: 'Clean nacelle and visible torque marks on generator',
        ),
        ChecklistItem(
          id: 'nacelle_generator_paint',
          textPt: 'Pintura do gerador em boas condições',
          textEn: 'Generator paint in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_drivetrain_paint',
          textPt: 'Pintura do drive train em boas condições',
          textEn: 'Drive train paint in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_filters_above_gen',
          textPt: 'Filtros por cima do gerador em boas condições',
          textEn: 'Filters above generator in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_coupling_ok',
          textPt: 'Coupling em boas condições',
          textEn: 'Coupling in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_work_hatch',
          textPt: 'Escotilha de trabalho em boas condições e fechada',
          textEn: 'Work hatch in good condition and closed',
        ),
        ChecklistItem(
          id: 'nacelle_cooler_bolts_anticorrosion',
          textPt: 'Parafusos do cooler com proteção anticorrosão',
          textEn: 'Cooler bolts with anti-corrosion protection',
        ),
        ChecklistItem(
          id: 'nacelle_flexible_ducts_fixed',
          textPt: 'Mangas flexíveis presas corretamente',
          textEn: 'Flexible ducts properly fixed',
        ),
        ChecklistItem(
          id: 'nacelle_ladders_below_mainshaft',
          textPt: 'Escadas para debaixo do main shaft colocadas',
          textEn: 'Ladders below main shaft installed',
        ),
        ChecklistItem(
          id: 'nacelle_below_mainshaft_clean',
          textPt: 'Zona por baixo do main shaft limpa',
          textEn: 'Area below main shaft clean',
        ),
        ChecklistItem(
          id: 'nacelle_all_bolts_torque_mark',
          textPt: 'Todos os parafusos com marca de torque',
          textEn: 'All relevant bolts with torque mark',
        ),
      ],
    ),
  );

  // aqui depois vais adicionar Nacele, Yaw, etc.

  // NACELE
  sections.add(
    ChecklistSection(
      id: 'NACELE',
      titlePt: 'Nacele',
      titleEn: 'Nacelle',
      items: [
        ChecklistItem(
          id: 'nacelle_ladders_ok',
          textPt: 'Escadas da nacele fixas e com lixas antiderrapantes',
          textEn: 'Nacelle ladders fixed and with anti-slip strips',
        ),
        ChecklistItem(
          id: 'nacelle_floor_hatches',
          textPt: 'Escotilhas do chão metálico com proteção nos cantos',
          textEn: 'Metal floor hatches with edge protection',
        ),
        ChecklistItem(
          id: 'nacelle_underfloor_clean',
          textPt: 'Chão por baixo da plataforma metálica limpo e em condições',
          textEn: 'Area under metal platform clean and in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_cabinets_doors',
          textPt: 'Portas dos armários em boas condições',
          textEn: 'Cabinet doors in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_data_cable',
          textPt: 'Ligação de dados ligada e com folga suficiente',
          textEn: 'Data connection plugged and with enough slack',
        ),
        ChecklistItem(
          id: 'nacelle_first_aid_3lang',
          textPt: 'Kit de primeiros socorros presente nas 3 línguas',
          textEn: 'First aid kit present in 3 languages',
        ),
        ChecklistItem(
          id: 'nacelle_stickers',
          textPt: 'Autocolantes colocados nos locais corretos',
          textEn: 'Stickers installed in correct locations',
        ),
        ChecklistItem(
          id: 'nacelle_clean_torque_marks',
          textPt: 'Limpeza geral e marcas de torque no gerador visíveis',
          textEn: 'Clean nacelle and visible torque marks on generator',
        ),
        ChecklistItem(
          id: 'nacelle_generator_paint',
          textPt: 'Pintura do gerador em boas condições',
          textEn: 'Generator paint in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_drivetrain_paint',
          textPt: 'Pintura do drive train em boas condições',
          textEn: 'Drive train paint in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_filters_above_gen',
          textPt: 'Filtros por cima do gerador em boas condições',
          textEn: 'Filters above generator in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_coupling_ok',
          textPt: 'Coupling em boas condições',
          textEn: 'Coupling in good condition',
        ),
        ChecklistItem(
          id: 'nacelle_work_hatch',
          textPt: 'Escotilha de trabalho em boas condições e fechada',
          textEn: 'Work hatch in good condition and closed',
        ),
        ChecklistItem(
          id: 'nacelle_cooler_bolts_anticorrosion',
          textPt: 'Parafusos do cooler com proteção anticorrosão',
          textEn: 'Cooler bolts with anti-corrosion protection',
        ),
        ChecklistItem(
          id: 'nacelle_flexible_ducts_fixed',
          textPt: 'Mangas flexíveis presas corretamente',
          textEn: 'Flexible ducts properly fixed',
        ),
        ChecklistItem(
          id: 'nacelle_ladders_below_mainshaft',
          textPt: 'Escadas para debaixo do main shaft colocadas',
          textEn: 'Ladders below main shaft installed',
        ),
        ChecklistItem(
          id: 'nacelle_below_mainshaft_clean',
          textPt: 'Zona por baixo do main shaft limpa',
          textEn: 'Area below main shaft clean',
        ),
        ChecklistItem(
          id: 'nacelle_all_bolts_torque_mark',
          textPt: 'Todos os parafusos com marca de torque',
          textEn: 'All relevant bolts with torque mark',
        ),
      ],
    ),
  );
  // NACELE ROOF
  sections.add(
    ChecklistSection(
      id: 'NACELE_ROOF',
      titlePt: 'Nacele roof',
      titleEn: 'Nacelle roof',
      items: [
        ChecklistItem(
          id: 'roof_access_hatch_latches',
          textPt: 'Fechos da escotilha de acesso em boas condições',
          textEn: 'Access hatch latches in good condition',
        ),
        ChecklistItem(
          id: 'roof_floor_condition',
          textPt: 'Chão/teto da nacele em boas condições gerais',
          textEn: 'Nacelle roof/floor in good overall condition',
        ),
        ChecklistItem(
          id: 'roof_met_station_fixed',
          textPt: 'Estação meteorológica apertada e cabos bem roteados',
          textEn: 'Met station tightened and cables well routed',
        ),
        ChecklistItem(
          id: 'roof_devices_sealed',
          textPt: 'Dispositivos meteorológicos com entradas de cabos vedadas',
          textEn: 'Met devices have cable entries sealed and protected',
        ),
        ChecklistItem(
          id: 'roof_no_loose_parts',
          textPt: 'Sem peças soltas no chão/teto da nacele',
          textEn: 'No loose parts on nacelle roof',
        ),
        ChecklistItem(
          id: 'roof_vent_grille_ok',
          textPt: 'Grelha de ventilação em boas condições',
          textEn: 'Ventilation grille in good condition',
        ),
        ChecklistItem(
          id: 'roof_lift_windows_ok',
          textPt: 'Janelas do lift em boas condições',
          textEn: 'Lift windows in good condition',
        ),
        ChecklistItem(
          id: 'roof_anchorage_points_ok',
          textPt: 'Pontos de ancoragem em boas condições (anilha visível)',
          textEn: 'Anchorage points in good condition (safety ring visible)',
        ),
      ],
    ),
  );

  // YAW
  sections.add(
    ChecklistSection(
      id: 'YAW',
      titlePt: 'Yaw',
      titleEn: 'Yaw',
      items: [
        ChecklistItem(
          id: 'yaw_stopper_in_place',
          textPt: 'Stopper colocado no final das escadas',
          textEn: 'Stopper installed at end of stairs',
        ),
        ChecklistItem(
          id: 'yaw_tower_walls_clean',
          textPt: 'Paredes da torre limpas (sem marcas de óxido evidentes)',
          textEn: 'Tower walls clean (no significant rust marks)',
        ),
        ChecklistItem(
          id: 'yaw_shackles_safety_pin',
          textPt: 'Grilhetes dos cabos elétricos com cavilha de segurança',
          textEn: 'Electrical cable shackles with safety pin',
        ),
        ChecklistItem(
          id: 'yaw_cables_clean',
          textPt: 'Cabos limpos e em bom estado',
          textEn: 'Cables clean and in good condition',
        ),
        ChecklistItem(
          id: 'yaw_cables_entry_protection',
          textPt: 'Cabos com proteção na entrada para a nacele',
          textEn: 'Cables protected at nacelle entry support',
        ),
        ChecklistItem(
          id: 'yaw_bolts_torque_mark',
          textPt: 'Todos os parafusos com marca de torque',
          textEn: 'All bolts have torque mark',
        ),
        ChecklistItem(
          id: 'yaw_internal_hoist',
          textPt:
              'Guincho interno em boas condições (proteções, pintura, desgaste)',
          textEn: 'Internal hoist in good condition (guards, paint, wear)',
        ),
        ChecklistItem(
          id: 'yaw_third_party_cert',
          textPt: 'Certificação de terceiro (ex.: TUV) presente e afixada',
          textEn: 'Third-party certification (e.g. TUV) present and posted',
        ),
        ChecklistItem(
          id: 'yaw_hoist_remote_and_mount',
          textPt: 'Comando do guincho em boas condições e suporte bem fixo',
          textEn: 'Hoist remote in good condition and support well fixed',
        ),
        ChecklistItem(
          id: 'yaw_stickers',
          textPt: 'Autocolantes do guincho e avisos nas escadas colocados',
          textEn: 'Hoist and stair warning stickers installed',
        ),
        ChecklistItem(
          id: 'yaw_access_ladder_fixed',
          textPt:
              'Escada de acesso à nacele bem fixa e com torque nos parafusos',
          textEn: 'Access ladder to nacelle well fixed and bolts torqued',
        ),
        ChecklistItem(
          id: 'yaw_access_ladder_condition',
          textPt: 'Escada de acesso em boas condições gerais',
          textEn: 'Access ladder in good overall condition',
        ),
        ChecklistItem(
          id: 'yaw_pin_test_ok',
          textPt: 'Pin test sem anomalias visíveis',
          textEn: 'Pin test without visible anomalies',
        ),
      ],
    ),
  );
  // TOP LIFT PLATFORM
  sections.add(
    ChecklistSection(
      id: 'TOP_LIFT_PLATFORM',
      titlePt: 'Top lift platform',
      titleEn: 'Top lift platform',
      items: [
        ChecklistItem(
          id: 'top_light_connections',
          textPt: 'Conexões elétricas da luminária em boas condições',
          textEn: 'Light fitting electrical connections in good condition',
        ),
        ChecklistItem(
          id: 'top_breaker_box_connections',
          textPt: 'Conexões da caixa de disjuntores corretas',
          textEn: 'Breaker box connections correct',
        ),
        ChecklistItem(
          id: 'top_light_ok',
          textPt: 'Luminária em boas condições e a funcionar',
          textEn: 'Light fitting in good condition and working',
        ),
        ChecklistItem(
          id: 'top_internal_stairs_ok',
          textPt: 'Escadas internas com torque e sem danos',
          textEn: 'Internal stairs torqued and undamaged',
        ),
        ChecklistItem(
          id: 'top_tower_paint',
          textPt: 'Pintura das paredes da torre em boas condições',
          textEn: 'Tower wall paint in good condition',
        ),
        ChecklistItem(
          id: 'top_elevator_guard',
          textPt:
              'Guarda do elevador alinhada, limpa e com marcas de torque visíveis',
          textEn: 'Elevator guard aligned, clean and with visible torque marks',
        ),
        ChecklistItem(
          id: 'top_crane_guard_rails',
          textPt:
              'Rails da guarda da grua interna sem ferrugem e com tampas de borracha',
          textEn:
              'Internal crane guard rails free of rust and with rubber plugs',
        ),
        ChecklistItem(
          id: 'top_crane_hatches',
          textPt:
              'Escotilhas da grua interna sem amolgadelas e com borracha intacta',
          textEn:
              'Internal crane hatches without dents and rubber intact below',
        ),
        ChecklistItem(
          id: 'top_power_cables_loop',
          textPt: 'Cabos elétricos no loop à altura e espaçamento corretos',
          textEn: 'Power cables in loop at correct height and spacing',
        ),
        ChecklistItem(
          id: 'top_support_clamps_ok',
          textPt: 'Grampos da mesa de suporte direitos e em boas condições',
          textEn: 'Support table clamps straight and in good condition',
        ),
        ChecklistItem(
          id: 'top_thermal_label',
          textPt: 'Etiqueta térmica colocada na zona do empalme',
          textEn: 'Thermal label placed on splice area',
        ),
        ChecklistItem(
          id: 'top_electrical_cables_ok',
          textPt: 'Cabos de eletricidade em boas condições gerais',
          textEn: 'Electrical cables in good general condition',
        ),
        ChecklistItem(
          id: 'top_all_shackles_safety',
          textPt:
              'Todos os grilhetes com cavilha de segurança (elevador e cabos elétricos)',
          textEn:
              'All shackles have safety pins (elevator and electrical cables)',
        ),
        ChecklistItem(
          id: 'top_tower_stairs_ok',
          textPt: 'Escadas da torre em boas condições',
          textEn: 'Tower stairs in good condition',
        ),
      ],
    ),
  );
  // S5 – só existe em torres de 5 secções; por enquanto usa os mesmos pontos
  if (w.towerType == TowerType.fiveSections) {
    sections.add(
      ChecklistSection(
        id: 'S5',
        titlePt: 'S5',
        titleEn: 'S5',
        items: [
          ChecklistItem(
            id: 's5_light_connections',
            textPt: 'Conexões elétricas da luminária em boas condições',
            textEn: 'Light fitting electrical connections in good condition',
          ),
          ChecklistItem(
            id: 's5_breaker_box',
            textPt: 'Conexões da caixa de disjuntores corretas',
            textEn: 'Breaker box connections correct',
          ),
          ChecklistItem(
            id: 's5_light_ok',
            textPt: 'Luminária em boas condições e a funcionar',
            textEn: 'Light fitting in good condition and working',
          ),
          ChecklistItem(
            id: 's5_stairs_ok',
            textPt: 'Escadas com torque correto e sem danos',
            textEn: 'Stairs torqued and undamaged',
          ),
          ChecklistItem(
            id: 's5_flange_clean',
            textPt: 'Limpeza das paredes da flange aceitável',
            textEn: 'Flange wall cleanliness acceptable',
          ),
          ChecklistItem(
            id: 's5_flange_paint',
            textPt: 'Pintura da flange em boas condições',
            textEn: 'Flange paint in good condition',
          ),
          ChecklistItem(
            id: 's5_stickers',
            textPt: 'Autocolantes presentes e corretos',
            textEn: 'Stickers present and correct',
          ),
          ChecklistItem(
            id: 's5_elevator_guard',
            textPt:
                'Guarda do elevador alinhada, limpa e com marcas de torque visíveis',
            textEn:
                'Elevator guard aligned, clean and with visible torque marks',
          ),
          ChecklistItem(
            id: 's5_crane_guard_rails',
            textPt:
                'Rails da guarda da grua interna sem ferrugem e com plugs de borracha',
            textEn:
                'Internal crane guard rails free of rust and with rubber plugs',
          ),
          ChecklistItem(
            id: 's5_crane_hatches',
            textPt:
                'Escotilhas da grua interna sem amolgadelas e com borracha intacta',
            textEn:
                'Internal crane hatches without dents and rubber intact below',
          ),
          ChecklistItem(
            id: 's5_pin_test',
            textPt: 'Pin test sem anomalias visíveis',
            textEn: 'Pin test without visible anomalies',
          ),
        ],
      ),
    );
  }
  // Secções S4, S3, S2 (iguais no guia)
  for (final s in ['S4', 'S3', 'S2']) {
    sections.add(
      ChecklistSection(
        id: s,
        titlePt: s,
        titleEn: s,
        items: [
          ChecklistItem(
            id: '${s.toLowerCase()}_light_connections',
            textPt: 'Conexões elétricas da luminária em boas condições',
            textEn: 'Light fitting electrical connections in good condition',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_breaker_box',
            textPt: 'Conexões da caixa de disjuntores corretas',
            textEn: 'Breaker box connections correct',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_light_ok',
            textPt: 'Luminária em boas condições e a funcionar',
            textEn: 'Light fitting in good condition and working',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_stairs_ok',
            textPt: 'Escadas com torque correto e sem danos',
            textEn: 'Stairs torqued and undamaged',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_flange_clean',
            textPt: 'Limpeza das paredes da flange aceitável',
            textEn: 'Flange wall cleanliness acceptable',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_flange_paint',
            textPt: 'Pintura da flange em boas condições',
            textEn: 'Flange paint in good condition',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_stickers',
            textPt: 'Autocolantes presentes e corretos',
            textEn: 'Stickers present and correct',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_elevator_guard',
            textPt:
                'Guarda do elevador alinhada, limpa e com marcas de torque visíveis',
            textEn:
                'Elevator guard aligned, clean and with visible torque marks',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_crane_guard_rails',
            textPt:
                'Rails da guarda da grua interna sem ferrugem e com plugs de borracha',
            textEn:
                'Internal crane guard rails free of rust and with rubber plugs',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_crane_hatches',
            textPt:
                'Escotilhas da grua interna sem amolgadelas e com borracha intacta',
            textEn:
                'Internal crane hatches without dents and rubber intact below',
          ),
          ChecklistItem(
            id: '${s.toLowerCase()}_pin_test',
            textPt: 'Pin test sem anomalias visíveis',
            textEn: 'Pin test without visible anomalies',
          ),
        ],
      ),
    );
  }
  // BOTTOM
  sections.add(
    ChecklistSection(
      id: 'Bottom',
      titlePt: 'Bottom',
      titleEn: 'Bottom',
      items: [
        // Converter
        ChecklistItem(
          id: 'bottom_converter_emergency_label',
          textPt: 'Autocolante do caminho de emergência colocado no converter',
          textEn: 'Emergency path sticker installed on converter',
        ),
        ChecklistItem(
          id: 'bottom_converter_stickers',
          textPt: 'Autocolantes do converter todos colocados',
          textEn: 'All converter stickers installed',
        ),
        ChecklistItem(
          id: 'bottom_converter_base_bolts',
          textPt: 'Parafusos da base do converter marcados e base limpa',
          textEn: 'Converter base bolts marked and base clean',
        ),
        ChecklistItem(
          id: 'bottom_converter_top_bolts',
          textPt: 'Parafusos/porcas do topo do converter marcados e limpos',
          textEn: 'Converter top bolts/nuts marked and clean',
        ),
        ChecklistItem(
          id: 'bottom_converter_cable_protection',
          textPt: 'Proteção no topo dos cabos no loop de entrada do converter',
          textEn: 'Protection on top of cables at converter loop entry',
        ),
        ChecklistItem(
          id: 'bottom_converter_back_connections',
          textPt: 'Ligações atrás do converter bem fixas',
          textEn: 'Connections at back of converter well fixed',
        ),
        ChecklistItem(
          id: 'bottom_converter_buzz_bar_washers',
          textPt: 'Anilhas corretas nas duas buzz bars',
          textEn: 'Correct washers on both buzz bars',
        ),
        // Elevador
        ChecklistItem(
          id: 'bottom_elevator_stickers',
          textPt: 'Autocolantes por detrás do elevador colocados',
          textEn: 'Stickers behind elevator installed',
        ),
        ChecklistItem(
          id: 'bottom_elevator_guard',
          textPt:
              'Guarda do elevador alinhada, limpa e com marcas de torque visíveis',
          textEn: 'Elevator guard aligned, clean and with visible torque marks',
        ),
        ChecklistItem(
          id: 'bottom_elevator_condition',
          textPt:
              'Elevador em boas condições (pintura, limpeza, sem amolgadelas)',
          textEn: 'Elevator in good condition (paint, cleanliness, no dents)',
        ),
        ChecklistItem(
          id: 'bottom_elevator_inside_torque',
          textPt: 'Parafusos internos do elevador com marcas de torque',
          textEn: 'Elevator internal bolts with torque marks',
        ),
        ChecklistItem(
          id: 'bottom_elevator_instructions_3lang',
          textPt: 'Instruções de manuseamento no elevador em 3 línguas',
          textEn: 'Elevator instructions present in 3 languages',
        ),
        ChecklistItem(
          id: 'bottom_elevator_certificate',
          textPt: 'Certificado de segurança do elevador presente',
          textEn: 'Elevator safety certificate present',
        ),
      ],
    ),
  );
  // FUNDAÇÃO
  sections.add(
    ChecklistSection(
      id: 'Fundação',
      titlePt: 'Fundação',
      titleEn: 'Foundation',
      items: [
        ChecklistItem(
          id: 'foundation_access_ladder',
          textPt: 'Escada de acesso à fundação em boas condições',
          textEn: 'Access ladder to foundation in good condition',
        ),
        ChecklistItem(
          id: 'foundation_platform_bolts',
          textPt:
              'Parafusos da plataforma com 2–3 fios de rosca fora da porca e com torque',
          textEn:
              'Platform bolts with 2–3 threads out of nut and torque marked',
        ),
        ChecklistItem(
          id: 'foundation_platform_washers',
          textPt: 'Anilhas e porcas dos pés da plataforma corretas',
          textEn: 'Platform support nuts and washers correct',
        ),
        ChecklistItem(
          id: 'foundation_studs_tension',
          textPt: 'Studs da fundação com anilhas, porcas e marcas de tensão',
          textEn: 'Foundation studs with washers, nuts and tension marks',
        ),
        ChecklistItem(
          id: 'foundation_earth_cables_length',
          textPt:
              'Comprimento dos cabos de terra adequado (sem excesso de tensão)',
          textEn: 'Earth cable length adequate (no over-tension)',
        ),
        ChecklistItem(
          id: 'foundation_tower_walls_paint',
          textPt: 'Pintura e limpeza das paredes da torre em boas condições',
          textEn: 'Tower wall paint and cleanliness in good condition',
        ),
        ChecklistItem(
          id: 'foundation_vent_box_paint',
          textPt: 'Pintura e limpeza da caixa de ventilação aceitáveis',
          textEn: 'Ventilation box paint and cleanliness acceptable',
        ),
        ChecklistItem(
          id: 'foundation_vent_duct_bolting',
          textPt:
              'Conduta de ventilação com duas anilhas por parafuso e tamanho adequado',
          textEn:
              'Ventilation duct with two washers per bolt and correct length',
        ),
        ChecklistItem(
          id: 'foundation_elevator_cables_routed',
          textPt: 'Cabos do elevador bem cableados e sem enrolar em estruturas',
          textEn:
              'Elevator cables correctly routed and not wrapped on structure',
        ),
      ],
    ),
  );
  // OUTSIDE
  sections.add(
    ChecklistSection(
      id: 'Outside',
      titlePt: 'Outside',
      titleEn: 'Outside',
      items: [
        ChecklistItem(
          id: 'outside_stairs_level',
          textPt: 'Escadas exteriores niveladas',
          textEn: 'External stairs levelled',
        ),
        ChecklistItem(
          id: 'outside_leveling_bolts_threads',
          textPt:
              'Parafusos de nivelamento com 2–3 fios de rosca fora da porca',
          textEn: 'Leveling bolts with 2–3 threads visible beyond nut',
        ),
        ChecklistItem(
          id: 'outside_stairs_condition',
          textPt:
              'Escadas exteriores em boas condições (pintura, limpas, sem amolgadelas)',
          textEn: 'External stairs in good condition (paint, clean, no dents)',
        ),
        ChecklistItem(
          id: 'outside_stairs_bolts_washers',
          textPt: 'Anilhas e parafusos das escadas corretos',
          textEn: 'Stair bolts and washers correct',
        ),
        ChecklistItem(
          id: 'outside_vent_duct_under_stairs',
          textPt:
              'Conduta do ventilador sob as escadas em boas condições e com 2 anilhas por parafuso',
          textEn:
              'Fan duct under stairs in good condition with two washers per bolt',
        ),
        ChecklistItem(
          id: 'outside_foundation_studs_marks',
          textPt: 'Studs da fundação com marca de tensionamento e verificação',
          textEn: 'Foundation studs with tension and check marks',
        ),
        ChecklistItem(
          id: 'outside_tower_walls_clean',
          textPt:
              'Paredes exteriores da torre limpas e sem marcas de tensão/óxido',
          textEn: 'Tower external walls clean and free of tension/rust marks',
        ),
        ChecklistItem(
          id: 'outside_external_camera',
          textPt: 'Câmara exterior instalada',
          textEn: 'External camera installed',
        ),
        ChecklistItem(
          id: 'outside_door_seal',
          textPt: 'Borracha de selagem da porta em boas condições e limpa',
          textEn: 'Door sealing rubber in good condition and clean',
        ),
        ChecklistItem(
          id: 'outside_door_stickers',
          textPt: 'Autocolantes ao lado da porta colocados',
          textEn: 'Stickers beside the door installed',
        ),
        ChecklistItem(
          id: 'outside_door_mechanism',
          textPt: 'Mecanismo de fecho da porta apertado e sem folgas',
          textEn: 'Door closing mechanism tight and without play',
        ),
        ChecklistItem(
          id: 'outside_filters_in_door',
          textPt: 'Filtros montados na porta',
          textEn: 'Filters installed in door',
        ),
        ChecklistItem(
          id: 'outside_emergency_exit_sticker',
          textPt: 'Autocolante de saída de emergência colocado na porta',
          textEn: 'Emergency exit sticker installed on door',
        ),
        ChecklistItem(
          id: 'outside_entrance_clean',
          textPt: 'Entrada da torre à volta da porta limpa',
          textEn: 'Tower entrance around door clean',
        ),
        ChecklistItem(
          id: 'outside_door_sensor',
          textPt: 'Sensor na parte superior da porta montado',
          textEn: 'Sensor at top of door installed',
        ),
      ],
    ),
  );

  return sections;
}
