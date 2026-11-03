/// Public schema contract used by backup/bootstrap code and migration tests.
library;

export 'app_database.dart'
    show
        ActiveSessions,
        AppDatabase,
        AuditLogs,
        LegacySchemaDetectedException,
        MatchClocks,
        MatchEvents,
        MatchParticipants,
        Matches,
        MatchSeries,
        SeriesMatches,
        PossessionSegments,
        Players,
        RuleTemplates,
        ShotLocations;

const schemaVersion = 2;

const schemaTableNames = <String>{
  'matches',
  'match_participants',
  'match_clocks',
  'active_sessions',
  'match_events',
  'shot_locations',
  'players',
  'rule_templates',
  'possession_segments',
  'audit_logs',
  'app_settings',
};
