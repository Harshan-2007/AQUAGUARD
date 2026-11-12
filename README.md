# AQUA GUARD

AQUA GUARD is a Spring Boot API and responsive dashboard for water measurements, sample analysis, and trend charts. It imports station metadata and water-quality observations from explicitly configured HTTPS CSV, JSON, or ZIP datasets. Imported observations are validated and retain their source metadata in the backend.

## Data source availability

The [TNPCB water-quality programme page](https://tnpcb.gov.in/waterquality.php) describes river and lake monitoring. The [TNPCB RTWQMS dashboard](https://tnpcb.gov.in/rtwqmstnpcb/) lists live station pages and uses the public JSON endpoint `https://tnpcb.gov.in/rtwqmstnpcb/api/readings/graph/?site_id={site_id}` for its station charts. AQUA GUARD refreshes these agency observations and displays the nearest Tamil Nadu station with a recorded value in a separate public-station panel, including the station's waterbody, coordinates, distance from the selected point, observation timestamp, measured parameters, and source link. These station readings are not represented as measurements from the selected coordinates and are never substituted into the user's saved sample history or sample WQI. The endpoint is used by the agency's public dashboard but is not a versioned API contract and may change. The [CPCB national real-time dashboard](https://rtwqmsdb1.cpcb.gov.in/) was also checked; its current public station catalogue did not list Tamil Nadu stations, so its national feed is not used for Tamil Nadu locations. The [CPCB NWMP page](https://cpcb.gov.in/nwmp-data/) publishes criteria documents, including [primary river water-quality criteria](https://cpcb.gov.in/wqm/Primary_Water_Quality_Criteria.pdf) and [designated best-use criteria](https://cpcb.gov.in/wqm/Designated_Best_Use_Water_Quality_Criteria.pdf). The [India-WRIS portal](https://indiawris.gov.in/wris/) is interactive; a public coordinate lookup API suitable for this application was not verified.

An official station or telemetry dataset must be explicitly configured and its source reviewed before import. If none is configured, station selection remains empty and no official basin, waterbody identity, or current water quality is claimed. Coordinate-only locations may show a nearest OpenStreetMap feature and administrative area as **community map suggestions**, not official hydrography or proof that a point lies in a waterbody. The interactive basemap is also OpenStreetMap and is not an official boundary layer.

Manual entry provides a separate-scale chart preview for the six measurements already collected: pH, temperature, turbidity, dissolved oxygen, TDS, and conductivity. The report calculates an app-defined, equal-weight six-parameter screening index for each accepted sample; when multiple samples are recorded for the selected date and location, the headline result is the arithmetic mean of their individual index scores. Parameter values and ratings in that aggregate are also averaged, while individual sample scores remain visible in the chart so a daily mean does not conceal variation. A single-sample report uses that sample's score and still provides recommendations. This is not the standard NSF WQI. Reference bands are pH 6.5–8.5, temperature 15–25 °C, turbidity ≤5 NTU, dissolved oxygen ≥6.5 mg/L, TDS ≤500 mg/L, and conductivity 100–1,000 µS/cm. Ratings range from 0 to 100 and decrease linearly outside each reference band to the parameter-specific zero points in `SixParameterWqiEngine`. Graphs use recorded values only and do not simulate readings. The result gives a concise overall screening grade and lists which measured parameters fall within or outside the app's reference ranges. A poor score advises against using the water untreated for drinking or cooking; a good score is not a drinking-water safety certification. Irrigation and recreational use are not recommended by this index because it does not assess crop-specific salinity or microbial safety.

Map selection resolves location metadata only. The dashboard and report show measurements saved for the selected node; they do not substitute a different, nearby station's readings. When new updates stop, the latest saved measurement for that same node remains visible with its original timestamp. If that location has no saved measurements, the page prompts the user to enter a sample instead of presenting another location's data. Simulated demo readings, if enabled for an imported station, are labeled as demo data.

The Nominatim lookup is enabled by default, uses a one-request-per-second limit and an in-memory cache, and can be disabled with `AQUA_LOCATION_LOOKUP_ENABLED=false`. An optional `AQUA_LOCATION_USER_AGENT` may be set to identify the deployment. Coordinates are sent to the public OpenStreetMap service when a new virtual location is resolved. OpenStreetMap feature names are attributed in the dashboard and are not water-quality measurements.

Configure each actual source using Spring Boot indexed properties/environment variables. For example, a Kaggle dataset's public download endpoint follows this pattern:

```powershell
$env:AQUA_DATASETS_SOURCES_0_NAME = "My reviewed water dataset"
$env:AQUA_DATASETS_SOURCES_0_URL = "https://www.kaggle.com/api/v1/datasets/download/OWNER/DATASET"
$env:AQUA_DATASETS_SOURCES_0_FORMAT = "ZIP"
$env:AQUA_DATASETS_SOURCES_0_FILE_NAME = "water-quality.csv"
$env:AQUA_DATASETS_SOURCES_0_LICENSE = "Copy the dataset's actual license here"
$env:AQUA_DATASETS_SOURCES_0_USERNAME = $env:KAGGLE_USERNAME
$env:AQUA_DATASETS_SOURCES_0_PASSWORD = $env:KAGGLE_KEY
```

For India's API at `api.data.gov.in`, configure its resource endpoint in `_URL` (without a key), `_FORMAT=JSON`, and set the API key separately:

```powershell
$env:AQUA_DATASETS_SOURCES_1_NAME = "Government water dataset"
$env:AQUA_DATASETS_SOURCES_1_URL = "https://api.data.gov.in/resource/RESOURCE_ID?format=json&limit=1000"
$env:AQUA_DATASETS_SOURCES_1_FORMAT = "JSON"
$env:AQUA_DATASETS_SOURCES_1_API_KEY = $env:DATA_GOV_IN_API_KEY
```

For a public government CSV/JSON endpoint, configure the source name, URL, format (`CSV`, `JSON`, or `AUTO`), and actual license; credentials are not required for a genuinely public endpoint. Add more sources as `AQUA_DATASETS_SOURCES_2_*`, `..._3_*`, etc. Keep credentials in environment variables; never place API keys or credentials in a URL, source file, or browser code. Kaggle username/API-key Basic authentication is supported over HTTPS. A separately configured API key is accepted only for `api.data.gov.in`; it is added to the HTTPS request and is not stored with source provenance.

On startup, configured sources are downloaded with connect/read timeouts and a 25 MB response limit. Kaggle ZIPs are read without extracting files to disk; select the desired archive member with `FILE_NAME` when needed. JSON input must be an array or contain a `records`, `data`, `results`, or `items` array. CSV and JSON records must contain Tamil Nadu latitude/longitude. Recognized field names include station/site ID and name, basin/river, upstream station ID, timestamp, pH, temperature, turbidity, dissolved oxygen, TDS, conductivity, and nitrate. Values are parsed from each source row rather than generated. A station row can be imported without telemetry; a telemetry observation is created only when all required measurements and an ISO-8601 timestamp are present. Out-of-bounds coordinates and malformed rows fail the source import rather than being silently normalized.

Review a source's ownership, license, collection method, station identity, units, and timestamp semantics before configuring it. Dataset-supplied upstream IDs are the only source of imported graph links. The application does not infer a river network from proximity. Dataset license and URL are stored with imported station metadata; query strings are omitted to avoid persisting URL credentials. `GET /api/datasets/status` reports the latest import, and authenticated `POST /api/datasets/refresh` re-fetches configured sources.

The map and coordinate resolver accept global WGS84 coordinates and may show the nearest OpenStreetMap-mapped feature or place. This community map lookup is approximate; it is not an authoritative waterbody boundary, station registry, or confirmation that the coordinate is on a river or lake. The TNPCB live feed and Tamil Nadu station dataset are available only in their configured coverage area; elsewhere the app does not claim live readings. A nearby imported station may be shown as a reference, but proximity is not proof that the point lies on that waterbody. Without accepted telemetry or a manually entered sample, the app displays no chemistry or analysis result. The optional simulator only generates clearly labelled demo samples for stations with imported baselines; disable it with `AQUA_SIMULATOR_ENABLED=false`.

## Local setup (Windows)

Requirements: Java 17+ and Maven 3.9+ (or the cached Maven used by `run.ps1`). No MySQL, XAMPP, Docker, or command-line admin password is required for local execution.

1. Set any dataset source variables described above, then start Spring Boot from the project root:

   ```powershell
   .\run.ps1
   ```

   Keep that terminal open and open [http://localhost:8080](http://localhost:8080). `run.cmd` is also available. The website lets each person create an account or sign in. Accounts and telemetry are stored in `backend/data/aquaguard_users.mv.db`; keep this file private and back it up to preserve records. The server binds to this computer only, so this local setup is not publicly accessible over the internet. There is no password reset or account recovery flow yet.

## Included functionality

- JPA repositories for monitoring nodes and telemetry, with H2 as the local runtime database.
- Open website registration with BCrypt-hashed passwords and per-account private manual samples; shared station/imported telemetry remains available to signed-in users.
- Optional TNPCB station-feed integration in the backend; readings from other stations are not substituted for the selected location.
- Configurable startup ingestion from HTTPS CSV, JSON, and zipped CSV/JSON sources; bounded downloads, status reporting, field normalization, coordinate checks, and source/license provenance.
- CSV and API-key batch ingestion, a bounded asynchronous worker queue, quality validation, and WebSocket broadcasts.
- Tamil Nadu coordinate bounds (latitude 8.0–13.5, longitude 76.2–80.3), interactive point selection, and coordinate-only nodes that do not infer a basin or water chemistry from nearby stations.
- Community map suggestions with administrative-area context and source attribution. These are not official waterbody boundaries.
- Asia/Kolkata shift review over accepted samples from 08:00–17:00 IST. Reports identify the date, sample count, source, and values; an empty shift produces no sample assessment.
- Six-parameter equal-weight screening index, per-parameter ratings, consumption guidance, printable/downloadable reports, and recorded-sample graphs (including one-sample reports).
- Separate in-session trend charts for incoming accepted telemetry.

## API

- `POST /api/auth/register` — `{ "username": "...", "password": "..." }`; usernames are 3–32 letters, numbers, dot, underscore, or hyphen; passwords must be at least 7 characters.
- `POST /api/auth/login` — `{ "username": "...", "password": "..." }`
- `POST /api/auth/logout`
- `GET /api/stations`
- `GET /api/stations/resolve?latitude=...&longitude=...`
- `GET /api/telemetry/latest?nodeId=...`
- `GET /api/live-water/nearby?latitude=...&longitude=...` — latest TNPCB station nearest the selected Tamil Nadu coordinates; returns source status, distance, observation timestamp, raw parameter values and units, and the TNPCB station-page link. The service refreshes the public TNPCB dashboard directory and chart endpoint every five minutes.
- `POST /api/analysis/{nodeId}?date=YYYY-MM-DD` — analyzes only accepted readings in the selected Asia/Kolkata 08:00–17:00 shift; returns the shift summary, hourly trend, and CPCB criteria assessment for each included sample. Date is optional and defaults to today.
- `POST /api/ingestion/manual` — authenticated operator entry of measured sample results for a resolved node. Values are plausibility-checked and stored as `MANUAL_ENTRY_UNVERIFIED`; include a timestamp with offset, for example `2025-06-15T10:30:00+05:30`.
- `GET /api/ingestion/manual?nodeId=...&date=YYYY-MM-DD` — lists saved manual samples for that node and IST date.
- `GET /api/datasets/status`
- `POST /api/datasets/refresh`
- `POST /api/ingestion/csv` — multipart field `file`
- `POST /api/ingestion/readings` — batch JSON authenticated with `X-API-Key`
- `GET /ws?token=...` — live telemetry WebSocket

The dashboard uses website accounts. Manual samples are private to the account that entered them, including their listing, latest-reading selection, shift report, and live WebSocket delivery. Shared station and imported telemetry remains visible to all signed-in accounts. Sensor API keys are for trusted gateways only; never place an ingestion key in browser code. To enable sensor push, set a randomly generated secret in `AQUA_INGESTION_API_KEY` before starting Spring Boot, and configure the gateway to send it in the `X-API-Key` header over HTTPS. The key authenticates a sender; it does not validate instrument calibration or sample accuracy.

The dashboard's **Enter water-test results** form accepts a sample timestamp in IST and six required measurements: pH, temperature, turbidity, dissolved oxygen, TDS, and conductivity. Optional laboratory fields cover the remaining parameters used by CPCB designated-use Classes A–E: BOD₅ (3 days at 27 °C), total coliform, free ammonia as N, SAR, and boron. Conductivity can be entered in µS/cm or mS/cm; mS/cm is converted to µS/cm before saving. Mark the 25 °C compensation checkbox only when the meter or method confirms it. The timestamp determines the sample date and 08:00–17:00 IST shift. Reports include individual sample charts even for a single reading; they plot recorded values only. Manual samples are private to the account that entered them. The local H2 database is file-backed, so accounts and saved records persist when the server restarts.

The CPCB designated best-use criteria identify source-water classes and are not, by themselves, a drinking-water potability test or use approval. The report compares available measurements with listed criteria and calls out other class requirements that were not measured. Water intended for drinking requires the applicable treatment and drinking-water quality controls; this dashboard does not certify potability.

The map and a Google Maps Platform key provide location/map features, not water measurements. An arbitrary coordinate has no direct live reading unless a sensor or telemetry feed covers that point. Backend integrations for nearby-station data and historical datasets are not displayed in the dashboard. Never reuse another website's embedded Google Maps key or commit private API credentials.

Manual CSV uploads expect:

```text
nodeId,timestamp,ph,temperatureC,turbidityNtu,dissolvedOxygenMgL,tdsMgL,conductivityUsCm,nitrateMgL
```

Station IDs must exist in the database. Timestamps are ISO-8601 instants; blank timestamps use current time. CSV/API imports are labelled unverified.

## Data limitations

External records, configured metadata, fixed screening ranges, flow velocity, simulator, and fingerprint heuristics are not certified TN WRD, TN-SMART, or TNPCB datasets or policy interpretations. Imported provenance labels are declarative metadata and do not authenticate a publisher. A high trust score means only that programmed plausibility checks passed; it is not measurement accuracy or regulatory approval. Contamination source results are not for enforcement, public-health, or remediation decisions. Verify station metadata, water-quality requirements, river topology, and flow data with the relevant authorities and accredited laboratory before operational use.

## Tests

```powershell
cd backend
mvn test
```

Tests use the H2 in-memory database in MySQL compatibility mode; they do not require a running MySQL service or configured external dataset.
