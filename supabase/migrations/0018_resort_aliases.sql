-- 0018_resort_aliases (DATA-RESORTS-2): one resort, one id.
--
-- The bundled resort list (app/assets/data/resorts.json, tools/data/import_resorts.py)
-- folds sub-areas of a Verbund and exact duplicates into one canonical entry;
-- the retired ids live on as aliases (Lech Zürs, Warth-Schröcken and both old
-- 'Ski Arlberg' ids → st-anton; three Damüls variants → Damüls-Mellau-Faschina).
-- Days recorded before the import may still carry an alias id, so:
--
--   1. public.resort_aliases(alias_id → canonical_id), filled from the importer
--      (`python3 tools/data/import_resorts.py --sql`), no client grants;
--   2. private.canonical_resort(id) — alias → canonical, anything else unchanged;
--   3. before-insert/update triggers canonicalise days.resort_id and
--      profiles.home_resort_id, so old app builds that still send an alias
--      land on the canonical board;
--   4. backfill: UPDATE days / profiles that carry an alias (no deletes);
--   5. private.board (0014 body) resolves p_resort_id through the alias table,
--      so leaderboard() / my_rank() / public_board_teaser() with an old id
--      return the canonical board.
--
-- Definer pattern (docs/BACKEND.md). Idempotent: re-running re-upserts the
-- pairs, flattens chains and re-runs the backfill (a no-op the second time).
-- Drops no table, deletes no row.

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- 1. alias table
-- ---------------------------------------------------------------------------
create table if not exists public.resort_aliases (
  alias_id text primary key,
  canonical_id text not null,
  created_at timestamptz not null default now(),
  constraint resort_aliases_not_self check (alias_id <> canonical_id)
);
alter table public.resort_aliases enable row level security;
revoke all on table public.resort_aliases from public, anon, authenticated;
comment on table public.resort_aliases is
  'Retired resort ids of the bundled resort list (0018) → canonical id. Read only through private.canonical_resort(); filled from tools/data/import_resorts.py --sql.';

-- 186 pairs from tools/data/import_resorts.py --sql (2026-09-30 import)
insert into public.resort_aliases (alias_id, canonical_id) values
  ('-cn-bd13be', '-cn-734bf8'),
  ('3-zinnen-dolomites-dobbiaco-san-candido--it-c443cc', 'drei-zinnen-tre-cime-drei-zinnen-tre-cim-it-3768b8'),
  ('adanac-ca-367a30', 'adanac-ski-hill-ca-2f994e'),
  ('adelboden-lenk-ch-42e761', 'adelboden-lenk'),
  ('airolo-luina-ch-fbcc3b', 'airolo-pescium-ch-67a848'),
  ('akakura-kanko-ski-resort-jp-b52fb4', 'akakura-onsen-ski-area-jp-b6c538'),
  ('atzmannig-ch-ed1dc3', 'atzmannig-ch-27c943'),
  ('auron-saint-etienne-de-tinee-fr-5386c2', 'auron-fr-46e449'),
  ('autrans-fr-587083', 'domaine-autrans-meaudre-fr-5c76d1'),
  ('autrans-grand-domaine-la-sure-fr-248c5c', 'domaine-autrans-meaudre-fr-5c76d1'),
  ('ax-3-domaines-fr-aa9678', 'ax-3-domaines-fr-cb17ba'),
  ('bad-kleinkirchheim-at-62219c', 'bad-kleinkirchheim-at-b0a93f'),
  ('bedrichov-cz-4e5f13', 'bedrichov-klindera-cz-52091d'),
  ('bedrichov-cz-7341ef', 'bedrichov-klindera-cz-52091d'),
  ('beijing-yuyang-resort-cn-998e23', 'beijing-yuyang-international-ski-resort-cn-28c85b'),
  ('belle-neige-ca-f3f99d', 'belle-neige-ca-33802b'),
  ('benecko-na-sychrove-cz-213185', 'skiareal-benecko-cz-297ba7'),
  ('borsec-ro-4b61b9', 'borsec-ro-a2e863'),
  ('bozi-dar-cz-838422', 'bozi-dar-cz-3cc92c'),
  ('brevent-flegere-chamonix-fr-c2fba9', 'chamonix'),
  ('brunni-haggenegg-ch-816f70', 'brunni-holzegg-rotenflue-ch-11d9e3'),
  ('bundalift-davos-ch-fc70da', 'davos-klosters'),
  ('canaan-valley-resort-us-aae8e9', 'canaan-valley-ski-resort-us-231b2f'),
  ('caviahue-ar-bc8f67', 'caviahue-ar-c16407'),
  ('cenkovice-nad-parkovistem-cz-93f60c', 'tj-cenkovice-cz-126c53'),
  ('centre-dexcellence-acrobatique-de-val-sa-ca-95f191', 'station-touristique-val-saint-come-ca-dcd0e2'),
  ('certovica-stiv-sk-dfbaf2', 'certovica-sk-f5e997'),
  ('cloudmont-ski-resort-us-c101d3', 'cloudmont-ski-hill-us-6ef390'),
  ('club-de-ski-de-beauce-ca-fbcdeb', 'club-ski-beauce-ca-ec180c'),
  ('cochran-s-ski-area-us-42779c', 'cochran-s-ski-area-us-a83106'),
  ('col-de-porte-fr-840b9d', 'col-de-porte-fr-390e31'),
  ('cortina-d-ampezzo-faloria-cristallo-miet-it-ee60c8', 'cortina'),
  ('cortina-tofane-it-7563ab', 'cortina'),
  ('craigieburn-nz-318e8c', 'craigieburn-valley-ski-area-nz-508643'),
  ('cranmore-tubing-park-us-f684ce', 'cranmore-mountain-resort-us-0ca8f9'),
  ('damuls-at-4f8cc7', 'skigebiet-damuls-mellau-faschina-at-da710e'),
  ('destne-na-spicaku-cz-133db1', 'destne-v-orlickych-horach-cz-6cd364'),
  ('disentis-muster-ch-d49fb7', 'andermatt-sedrun'),
  ('domaine-du-barioz-fr-c4dc4a', 'stade-des-neiges-du-barioz-fr-82f3bd'),
  ('domaine-nordique-col-d-ornon-fr-9493e6', 'domaine-alpin-du-col-d-ornon-fr-cfbdf0'),
  ('domaine-skiable-chamrousse-fr-8ea4e4', 'chamrousse-fr-13e89a'),
  ('ebingen-de-166d7f', 'ebingen-de-ed6261'),
  ('eggberge-ch-fd054f', 'eggberge-ch-34a5ff'),
  ('elbrus-ru-bac8f9', 'elbrus-ru-ddf907'),
  ('estacion-invernal-y-de-montana-san-isidr-es-b02801', 'estacion-invernal-y-de-montana-san-isidr-es-d10f2f'),
  ('fagerfjell-skisenter-no-b4de07', 'fagerfjell-skisenter-no-3485eb'),
  ('fela-zlatnik-cz-44d1d0', 'biocel-zlatnik-cz-b99e69'),
  ('forsteralm-at-76cb9d', 'forsteralm-at-d40f49'),
  ('geilo-no-5acf20', 'ski-geilo-no-039270'),
  ('goderdzi-ge-da954b', 'goderdzi-mountain-resort-ge-e5a747'),
  ('great-bear-recreation-park-us-a6c372', 'great-bear-recreation-park-us-809a4c'),
  ('grindelwald-mannlichen-schlittelpiste-ch-17b19c', 'grindelwald-wengen-kleine-scheidegg-mann-ch-1d111e'),
  ('happylift-semmering-at-b9ba7d', 'semmering-hirschenkogel-at-b4584f'),
  ('haukkavuoren-laskettelurinne-fi-a975d8', 'haukkavuoren-ulkoilu-ja-luontomatkailuke-fi-52756d'),
  ('havas-bucsin-ro-1f4e43', 'havas-bucsin-ro-f9e94d'),
  ('heavenly-ski-resort-us-bc9bc6', 'heavenly-mountain-resort-us-3f6185'),
  ('hiihtokeskus-luosto-ski-fi-f98a2e', 'pyhatunturi-luosto-fi-1eaeae'),
  ('hochkar-at-72153b', 'hochkar-at-16766c'),
  ('hochoetz-at-3eb5b1', 'kuehtai'),
  ('hochoetz-kuhtai-at-ac1956', 'kuehtai'),
  ('hors-piste-station-de-ski-mont-edouard-ca-e52e7d', 'mont-edouard-ca-376ba1'),
  ('horsefeathers-superpark-planai-at-adde9b', 'planai-hochwurzen-at-a52b30'),
  ('hurdal-no-0f57d8', 'hurdal-skisenter-no-00add1'),
  ('hurdal-skisenter-no-4bcf6f', 'hurdal-skisenter-no-00add1'),
  ('ilgaz-tr-e6af20', 'ilgaz-kayak-merkezi-ilgaz-ski-resort-tr-c0b8ef'),
  ('jizni-svahy-cz-47707f', 'severni-svahy-cz-322b63'),
  ('kaste-petrikov-cz-a3a4fb', 'ski-petrikov-cz-a431b9'),
  ('klausberg-monte-chiusetta-klausberg-mont-it-d54a78', 'klausberg-skiarena-it-d68b7c'),
  ('kolasin-1600-ski-resort-1600-me-b276a7', 'kolasin-1600-me-2705ff'),
  ('kouty-cz-f12215', 'kouty-cz-e7c8a2'),
  ('la-colmiane-fr-d49227', 'la-colmiane-fr-b85ed4'),
  ('la-grave-la-meije-fr-55c54d', 'la-grave-fr-93786d'),
  ('lachtal-at-edc9f9', 'lachtal-at-23c1a9'),
  ('lans-en-vercors-fr-ed68f7', 'montagnes-de-lans-fr-27f2c6'),
  ('las-lenas-ar-dc51a8', 'las-lenas-ar-f45543'),
  ('lech-zuers', 'st-anton'),
  ('les-angles-fr-7119a6', 'les-angles-els-angles-fr-a2fed1'),
  ('les-entremonts-fr-5fd11b', 'les-entremonts-fr-179079'),
  ('les-pleiades-ch-c73339', 'les-pleiades-ch-eb95f5'),
  ('leysin-les-mosses-la-lecherette-ch-4c94fd', 'les-mosses-ch-a0ff12'),
  ('loveland-valley-ski-area-us-e0538e', 'loveland-basin-ski-area-us-1dd232'),
  ('lyzarsky-areal-svetly-vrch-cz-70ba92', 'svetly-vrch-cz-95fe16'),
  ('manza-onsen-jp-063b66', 'manza-onsen-jp-cdc71e'),
  ('marisel-havasnagyfalu-ro-045ad7', 'partiile-marisel-ro-09bfbf'),
  ('martinske-hole-sk-065bb4', 'martinske-hole-sk-520704'),
  ('master-ski-pl-fe870d', 'master-ski-pl-eec299'),
  ('meaudre-fr-c1bd4c', 'domaine-autrans-meaudre-fr-5c76d1'),
  ('mellau-at-832501', 'skigebiet-damuls-mellau-faschina-at-da710e'),
  ('menthieres-fr-62b93e', 'menthieres-fr-2a4154'),
  ('mogno-ch-93dd64', 'mogno-ch-a7053b'),
  ('mont-grand-fonds-ca-f5eaf0', 'mont-grand-fonds-ca-9c6841'),
  ('monte-cimone-it-733093', 'cimone-area-sciistica-monte-cimone-it-bb224e'),
  ('muroran-kogen-danpara-jp-d798ec', 'muroran-shi-ski-area-jp-9cb527'),
  ('nakazato-snow-wood-ski-area-nakazato-sun-jp-85fd0f', 'yuzawa-nakazato-ski-resort-jp-6783f6'),
  ('nayoro-piyashiri-jp-a3f7c0', 'piyashiri-nayoro-snow-park-jp-a04941'),
  ('nove-hamry-u-reky-cz-e1a717', 'nove-hamry-nad-kostelem-cz-01dc2f'),
  ('orcieres-fr-3ecad4', 'orcieres-merlette-fr-293ced'),
  ('orelle-fr-13ba86', 'val-thorens-orelle-fr-3ab737'),
  ('ounasvaaran-laskettelukeskus-ounasvaara--fi-e3e392', 'ounasvaara-ski-resort-fi-5f5155'),
  ('ounasvaaran-laskettelukeskus-totto-ounas-fi-5dfe0f', 'ounasvaara-ski-resort-fi-5f5155'),
  ('p-o-m-a-malenovice-cz-88e660', 'ski-malenovice-cz-708bda'),
  ('parsenn-ch-403c8d', 'davos-klosters'),
  ('passo-rolle-it-c8a21c', 'san-martino-di-castrozza-passo-rolle-it-11b427'),
  ('pec-pod-snezkou-cz-dd5b18', 'pec-pod-snezkou-cz-ee6416'),
  ('pernink-velflink-cz-76c94d', 'pernink-pod-nadrazim-cz-a8a0eb'),
  ('petrikov-relax-cz-998296', 'ski-petrikov-cz-a431b9'),
  ('piancavallo-it-55ee20', 'piancavallo-it-0deab1'),
  ('porac-brodok-sk-6d717b', 'porac-park-sk-2531fd'),
  ('prali-it-708f36', 'prali-it-d44757'),
  ('pukkivuori-fi-d4c44f', 'pukkivuori-fi-9c31ce'),
  ('ramsau-am-dachstein-at-78a67a', 'schladming'),
  ('rauland-skisenter-no-c9fc10', 'rauland-skisenter-no-71df93'),
  ('rauland-skisenter-no-f062ff', 'rauland-skisenter-no-71df93'),
  ('ravna-planina-pale-ba-91d2d5', 'ski-centar-ravna-planina-pale-ski-center-ba-3d906e'),
  ('ruunarinteet-fi-6729ea', 'ruunarinteet-fi-5212ed'),
  ('saariselka-fi-1b5d78', 'ski-saariselka-laskuttelukeskus-ski-spor-fi-52f7b1'),
  ('saas-almagell-furggstalden-heidbodme-ch-3a47b8', 'saas-fee-ch-fc37a3'),
  ('sainte-croix-les-rasses-ch-d1bd1c', 'sainte-croix-les-rasses-ch-59d4e1'),
  ('salzstiegl-at-d5dc80', 'salzstiegl-at-8a6334'),
  ('san-martino-di-castrozza-it-461485', 'san-martino-di-castrozza-passo-rolle-it-11b427'),
  ('savognin-ch-588e8e', 'savognin-ch-2cbe40'),
  ('scanno-it-4695bc', 'scanno-it-7f9cb5'),
  ('schiestandlift-flirsch-at-b6fb43', 'flirsch-at-3c7738'),
  ('schnabelsberg-einsiedeln-ch-1278db', 'bennau-einsiedeln-ch-a33fac'),
  ('seefeld-birkenlift-geigenbuhellift-at-db530e', 'seefeld-rosshutte-at-80df52'),
  ('shiga-kogen-ichinose-family-ski-area-jp-973e1c', 'shiga-kogen-ichinose-diamond-ski-area-jp-46dace'),
  ('shiga-kogen-ichinose-yamanokami-ski-area-jp-956c33', 'shiga-kogen-ichinose-diamond-ski-area-jp-46dace'),
  ('sjusjen-no-8ff15e', 'sjusjen-skisenter-no-524965'),
  ('skeikampen-no-85381f', 'skeikampen-alpinsenter-no-b97412'),
  ('ski-arlberg-at-1dc7dc', 'st-anton'),
  ('ski-arlberg-at-53410f', 'st-anton'),
  ('ski-bezovec-sk-0fbebb', 'ski-bezovec-sk-68a931'),
  ('ski-center-kopaonik-rs-bc0217', 'kopaonik-rs-7c478a'),
  ('ski-centrum-oaza-cz-f6b382', 'ski-centrum-oaza-cz-409610'),
  ('ski-ostruzna-retezarna-cz-a298c7', 'jonas-park-ostruzna-cz-256d33'),
  ('skiareal-novako-cz-532e4e', 'skiareal-novako-cz-6f7c7f'),
  ('skigebiet-damuls-mellau-at-f83cb9', 'skigebiet-damuls-mellau-faschina-at-da710e'),
  ('skigebiet-fontanella-faschina-at-09da65', 'skigebiet-damuls-mellau-faschina-at-da710e'),
  ('skigebiet-zuckerfeld-wasserkuppe-de-69405c', 'ski-und-rodelarena-wasserkuppe-de-488625'),
  ('skilift-brunni-ch-5a7c67', 'brunni-holzegg-rotenflue-ch-11d9e3'),
  ('skilifte-geiersberg-de-c0295c', 'skilifte-geiersberg-de-b3daae'),
  ('skilifte-ibergeregg-ch-87d634', 'ibergeregg-handgruobi-ch-eca584'),
  ('skiliftkarussell-winterberg-de-d05da8', 'skiliftkarussell-winterberg-de-d09876'),
  ('skipisten-titlis-bergbahnen-ch-97e9df', 'engelberg'),
  ('skitatry-zadna-lopusna-dolina-sk-af1ec3', 'lopusna-dolina-sk-525267'),
  ('slavske-menchil-ua-d1f942', 'slavske-trostyan-ua-0783af'),
  ('snow-snake-ski-golf-us-005b57', 'snow-snake-ski-resort-us-3f883c'),
  ('snowkite-markstein-fr-12a748', 'le-markstein-fr-b3e6cf'),
  ('snowshoe-mountain-us-4a4697', 'snowshoe-mountain-us-1facaf'),
  ('sonnenbergbahn-at-e50d5f', 'sonnenbergbahn-at-1b21ce'),
  ('sotwiny-ski-pl-f955e3', 'sotwiny-arena-pl-5bf24d'),
  ('spindleruv-mlyn-labska-cz-85023d', 'skiareal-spindleruv-mlyn-medvedin-cz-0bd87c'),
  ('stacja-narciarska-kotelnica-biaczanska-k-pl-9c8c1c', 'osrodek-narciarski-kotelnica-biaczanska--pl-1792fc'),
  ('sugadaira-taro-area-jp-8b0fb3', 'sugadaira-kogen-davos-hill-ski-area-jp-4a46b3'),
  ('sugarloaf-outdoor-center-us-9cbd8a', 'sugarloaf-us-ba6f00'),
  ('tahoe-donner-downhill-ski-area-us-e5228f', 'tahoe-donner-downhill-ski-area-us-56b34c'),
  ('tangram-madarao-ski-circus-jp-b40167', 'madarao-kogen-mountain-resort-jp-b7e060'),
  ('terre-ronde-la-praille-fr-3273ad', 'terre-ronde-fr-a15039'),
  ('thollon-les-memises-fr-0d8f01', 'thollon-les-memises-fr-d3c7b8'),
  ('todtnauberg-de-3e0993', 'todtnauberg-de-82939f'),
  ('too-ashuu-kg-cae7e2', 'ski-base-too-ashuu-kg-798d50'),
  ('troms-alpinpark-no-46763c', 'troms-alpinpark-no-459ec6'),
  ('trysil-no-2c88b8', 'trysil-no-24ab41'),
  ('turracher-hohe-at-610bb1', 'turracher-hohe-at-75013e'),
  ('tyrol-basin-us-170c43', 'tyrol-basin-ski-and-snowboard-area-us-4ca587'),
  ('ussita-frontignano-it-9a1556', 'area-sciistica-ussita-frontignano-it-299e9e'),
  ('val-di-fassa-it-e615b3', 'val-di-fassa'),
  ('val-thorens-fr-b66cd0', 'val-thorens-orelle-fr-3ab737'),
  ('valdelinares-es-e5b468', 'valdelinares-es-f6faf9'),
  ('velika-planina-si-ad0a74', 'velika-planina-si-638d54'),
  ('vergio-fr-5783a7', 'vergio-fr-892db7'),
  ('vigo-di-fassa-ciampedie-it-8ff7c3', 'val-di-fassa'),
  ('villars-gryon-les-diablerets-glacier-300-ch-452204', 'villars-gryon-les-diablerets-ch-b63d5d'),
  ('warth-schrocken-at-29248a', 'st-anton'),
  ('watles-it-d85748', 'watles-vatles-watles-vatles-it-15f974'),
  ('wild-chutes-snow-tubing-us-460ecf', 'wild-mountain-us-1befbc'),
  ('willingen-de-315b96', 'willingen-de-c70830'),
  ('yawgoo-valley-ski-area-us-b3b0a2', 'yawgoo-valley-ski-area-us-1cc41c'),
  ('yllas-fi-acb78b', 'yllas-fi-10f9e4'),
  ('yllas-ski-resort-akaslompolo-fi-aa317f', 'yllas-fi-10f9e4'),
  ('yuzawa-kogen-ski-resort-jp-e0debe', 'gala-yuzawa-snow-resort-jp-7a2884'),
  ('yuzawa-park-ski-resort-yuzawa-paku-suki--jp-c8b860', 'yuzawa-nakazato-ski-resort-jp-6783f6'),
  ('zelezna-ruda-spicak-nad-nadrazim-cz-f1130b', 'nad-nadrazim-belveder-cz-eb5ec1'),
  ('zieleniec-pl-452b81', 'zieleniec-pl-fd0ec0'),
  ('zieleniec-pl-4d511a', 'zieleniec-pl-fd0ec0'),
  ('zwardon-centrum-pl-621ed5', 'zwardon-ski-pl-5052d9')
on conflict (alias_id) do update set canonical_id = excluded.canonical_id;

-- a canonical id that became an alias itself in a later import: point straight
-- at the new canonical id (one level is all the importer produces).
update public.resort_aliases a
   set canonical_id = b.canonical_id
  from public.resort_aliases b
 where a.canonical_id = b.alias_id
   and a.canonical_id <> b.canonical_id
   and a.alias_id <> b.canonical_id;

-- ---------------------------------------------------------------------------
-- 2. helper
-- ---------------------------------------------------------------------------
create or replace function private.canonical_resort(p_resort_id text)
returns text
language sql security definer stable set search_path = public as $$
  select coalesce((select a.canonical_id from public.resort_aliases a where a.alias_id = p_resort_id), p_resort_id);
$$;
revoke all on function private.canonical_resort(text) from public, anon, authenticated;
comment on function private.canonical_resort(text) is
  'Alias resort id → canonical id (0018); unknown ids and null pass through.';

-- ---------------------------------------------------------------------------
-- 3. write-time canonicalisation
-- ---------------------------------------------------------------------------
create or replace function private.canonical_resort_trg()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'profiles' then
    new.home_resort_id := private.canonical_resort(new.home_resort_id);
  else
    new.resort_id := private.canonical_resort(new.resort_id);
  end if;
  return new;
end;
$$;
revoke all on function private.canonical_resort_trg() from public, anon, authenticated;

-- 'days_canonical_resort' sorts before 'days_guard', so the guard already sees
-- the canonical id (an old build re-sending an alias is not a new write).
drop trigger if exists days_canonical_resort on public.days;
create trigger days_canonical_resort before insert or update of resort_id on public.days
  for each row execute function private.canonical_resort_trg();

drop trigger if exists profiles_canonical_resort on public.profiles;
create trigger profiles_canonical_resort before insert or update of home_resort_id on public.profiles
  for each row execute function private.canonical_resort_trg();

-- ---------------------------------------------------------------------------
-- 4. backfill (UPDATE only; the days_guard write counter and updated_at move,
--    so clients pull the canonical id with their next sync)
-- ---------------------------------------------------------------------------
update public.days d
   set resort_id = a.canonical_id
  from public.resort_aliases a
 where d.resort_id = a.alias_id;

update public.profiles p
   set home_resort_id = a.canonical_id
  from public.resort_aliases a
 where p.home_resort_id = a.alias_id;

-- ---------------------------------------------------------------------------
-- 5. private.board — 0014's body; p_resort_id resolves through the aliases.
-- ---------------------------------------------------------------------------
create or replace function private.board(p_resort_id text, p_season_key text, p_metric text, p_country text)
returns table (
  rank bigint,
  user_id uuid,
  display_name text,
  avatar_url text,
  country_code text,
  value double precision,
  total bigint,
  last_day timestamptz,
  day_count bigint
)
language plpgsql security definer stable set search_path = public as $$
declare
  v_resort text := private.canonical_resort(p_resort_id);
begin
  if p_metric is null or p_metric not in ('drop_m', 'ski_distance_m', 'run_count', 'max_speed_ms', 'day_count', 'points') then
    raise exception 'bad_metric' using errcode = '22023', detail = coalesce(p_metric, 'null');
  end if;
  if p_season_key is null then
    raise exception 'bad_season_key' using errcode = '22023';
  end if;
  return query
  with agg as (
    select d.user_id as uid,
      case p_metric
        when 'drop_m' then sum(d.drop_m)
        when 'ski_distance_m' then sum(d.ski_distance_m)
        when 'run_count' then sum(d.run_count)::double precision
        when 'max_speed_ms' then max(d.max_speed_ms)
        when 'day_count' then count(*)::double precision
        when 'points' then sum(d.points)::double precision
      end as val,
      max(d.started_at) as last_started,
      count(*) as n_days,
      max(d.country_code) as any_country
    from public.days d
    join public.profiles p on p.id = d.user_id
    where p.share_leaderboards
      and d.deleted_at is null
      and not d.suspicious
      and (v_resort is null or d.resort_id = v_resort)
      and (p_country is null or coalesce(p.country_code, d.country_code) = p_country)
      and private.season_match(p_season_key, d.season_key, d.started_at)
      and not exists (
        select 1 from public.blocks b
        where (b.user_id = auth.uid() and b.blocked_id = d.user_id)
           or (b.user_id = d.user_id and b.blocked_id = auth.uid())
      )
    group by d.user_id
  )
  select rank() over (order by a.val desc) as rank,
         a.uid,
         p.display_name,
         p.avatar_url,
         coalesce(p.country_code, a.any_country),
         a.val,
         count(*) over () as total,
         a.last_started,
         a.n_days
  from agg a
  join public.profiles p on p.id = a.uid;
end;
$$;
revoke all on function private.board(text, text, text, text) from public, anon, authenticated;
comment on function private.board(text, text, text, text) is
  'Shared board query (0005; 0014 two-way blocks; 0018 p_resort_id resolves alias → canonical via private.canonical_resort).';
