SELECT
    current_database(),
    schemaname,
    tablename AS table_name,
    object_type,
    bloat,
    wastedbytes,
    hwastedbytes,
    table_size,
    raw_table_size
FROM (
    SELECT
        schemaname,
        tablename,
        object_type,
        ROUND(
            (
                CASE
                    WHEN otta = 0 THEN 0.0
                    ELSE sml.relpages :: FLOAT / otta
                END
            ) :: NUMERIC,
            1
        ) AS bloat,
        CASE
            WHEN relpages < otta THEN 0
            ELSE bs * (sml.relpages - otta) :: BIGINT
        END AS wastedbytes,
        pg_size_pretty(
            CASE
                WHEN relpages < otta THEN 0
                ELSE bs * (sml.relpages - otta) :: BIGINT
            END
        ) AS hwastedbytes,
        pg_size_pretty(bs * sml.relpages) AS table_size,
        bs * sml.relpages AS raw_table_size
    FROM (
        SELECT
            schemaname,
            tablename,
            cc.reltuples,
            cc.relpages,
            bs,
            CASE
                WHEN cc.relkind = 'r' THEN 'Table'
                WHEN cc.relkind = 'i' THEN 'Index'
                WHEN cc.relkind = 'S' THEN 'Sequence'
                WHEN cc.relkind = 'v' THEN 'View'
                WHEN cc.relkind = 'm' THEN 'Materialized View'
                WHEN cc.relkind = 'c' THEN 'Composite Type'
                WHEN cc.relkind = 't' THEN 'TOAST Table'
                WHEN cc.relkind = 'f' THEN 'Foreign Table'
                WHEN cc.relkind = 'p' THEN 'Partitioned Table'
            END AS object_type,
            CEIL(
                (
                    cc.reltuples * (
                        (
                            datahdr + ma - (
                                CASE
                                    WHEN datahdr % ma = 0 THEN ma
                                    ELSE datahdr % ma
                                END
                            )
                        ) + nullhdr2 + 4
                    )
                ) / (bs - 20 :: FLOAT)
            ) AS otta
        FROM (
            SELECT
                ma,
                bs,
                schemaname,
                tablename,
                (
                    datawidth + (
                        hdr + ma - (
                            CASE
                                WHEN hdr % ma = 0 THEN ma
                                ELSE hdr % ma
                            END
                        )
                    )
                ) :: NUMERIC AS datahdr,
                (
                    maxfracsum * (
                        nullhdr + ma - (
                            CASE
                                WHEN nullhdr % ma = 0 THEN ma
                                ELSE nullhdr % ma
                            END
                        )
                    )
                ) AS nullhdr2
            FROM (
                SELECT
                    schemaname,
                    tablename,
                    hdr,
                    ma,
                    bs,
                    SUM((1 - null_frac) * avg_width) AS datawidth,
                    MAX(null_frac) AS maxfracsum,
                    hdr + (
                        SELECT 1 + COUNT(*) / 8
                        FROM pg_stats s2
                        WHERE null_frac <> 0
                          AND s2.schemaname = s.schemaname
                          AND s2.tablename = s.tablename
                    ) AS nullhdr
                FROM
                    pg_stats s,
                    (
                        SELECT
                            (SELECT current_setting('block_size') :: NUMERIC) AS bs,
                            CASE
                                WHEN SUBSTRING(v, 12, 3) IN ('8.0', '8.1', '8.2') THEN 27
                                ELSE 23
                            END AS hdr,
                            CASE
                                WHEN v ~ 'mingw32' THEN 8
                                ELSE 4
                            END AS ma
                        FROM (SELECT version() AS v) AS foo
                    ) AS constants
                GROUP BY 1, 2, 3, 4, 5
            ) AS foo
        ) AS rs
        JOIN pg_class cc ON cc.relname = rs.tablename
        JOIN pg_namespace nn
            ON cc.relnamespace = nn.oid
           AND nn.nspname = rs.schemaname
           AND nn.nspname NOT IN ('information_schema', 'pg_catalog')
    ) AS sml
    WHERE sml.object_type IN ('Table', 'Partitioned Table')
) AS bloat_summary
WHERE (raw_table_size > 50 * 1024^3 AND bloat > 2.0)
   OR (bloat > 5.0)
ORDER BY wastedbytes DESC;
