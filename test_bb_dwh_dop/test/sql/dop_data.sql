WITH hourly_grid AS (
  SELECT
    d.date AS datum,
    d.year AS jaar,
    d.month AS maand,
    d.day_name_nl AS weekdag,
    d.season AS seizoen,
    DATETIME_ADD(DATETIME(d.date, TIME(0, 0, 0)), INTERVAL hour_num HOUR) AS datumUurEnum,
    DATETIME_ADD(DATETIME(d.date, TIME(0, 0, 0)), INTERVAL hour_num + 1 HOUR) AS datumUurEnumNext
  FROM
    `prj-uzl-gold-uzl-prd-806f.DWH.dim_date` d
  CROSS JOIN
    UNNEST(GENERATE_ARRAY(0, 23)) AS hour_num
    -- to be defined as parameter in pipeline; now hard coded for testing purposes
  WHERE
    d.year IN (2024)
)
SELECT
  h.jaar,
  p.activity_center.activity_center_code AS AC_CODE,
  p.presence.unit.unit_code AS eenheid,
  h.datum,
  h.datumUurEnum,
  h.weekdag,
  h.seizoen,
  h.maand,
  SUM(
    DATETIME_DIFF(
      LEAST(h.datumUurEnumNext, DATETIME_ADD(p.presence_detail.period_end, INTERVAL 1 SECOND)),
      GREATEST(h.datumUurEnum, p.presence_detail.period_start),
      SECOND
    )
  ) / 3600.0 AS bb
FROM
  hourly_grid h
LEFT JOIN
  `prj-uzl-gold-uzl-prd-806f.DWH.dm_presence_detail_mir` p
  ON h.datum = p.calendar_date
  AND h.datumUurEnum < DATETIME_ADD(p.presence_detail.period_end, INTERVAL 1 SECOND)
  AND h.datumUurEnumNext > p.presence_detail.period_start
WHERE
  COALESCE(p.stay.main_administrative_episode_type, 'H') = 'H'
  AND COALESCE(p.stay.is_birth_stay_rooming_in, FALSE) = FALSE
  AND COALESCE(p.activity_center.object_activity_center_type, '31') IN ('30', '31')
  AND (
    CASE
      WHEN p.stay.is_birth_stay = TRUE AND p.presence.unit.unit_code IN ('431', '441', '430', '2330') THEN FALSE
      ELSE COALESCE(p.presence_detail.is_LBT, TRUE)
    END = TRUE
  )
  AND COALESCE(p.presence_detail.absence_type.absence_type_code, '') NOT IN ('WE', 'VL')
  -- an array or reference to parameters is script to be inserted when applyting to pipeline; now one unit hardcoded as for a test
  AND (p.presence.unit.unit_code IN ('650'))
GROUP BY
  h.jaar,
  p.activity_center.activity_center_code,
  p.presence.unit.unit_code,
  h.datum,
  h.datumUurEnum,
  h.weekdag,
  h.seizoen,
  h.maand
ORDER BY
  h.datumUurEnum,
  eenheid;