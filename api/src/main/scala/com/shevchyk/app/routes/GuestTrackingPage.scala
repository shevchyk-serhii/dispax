package com.shevchyk.app.routes

/**
 * The HTML document for the public guest tracking page. Pure string templating (no framework) so it is trivial to serve
 * and unit-test. All user-facing strings are localized inline (de/en/uk); the token and Mapbox access token are
 * injected as JSON-safe JS string literals.
 */
object GuestTrackingPage:

  /**
   * Localized UI strings for the page, keyed by the 2-letter language.
   */
  final private case class Strings(
      title: String,
      findingDriver: String,
      driverOnTheWay: String,
      onTrip: String,
      tripCompleted: String,
      tripCancelled: String,
      approaching: String,
      pickup: String,
      dropoff: String,
      driverLabel: String, // map marker caption for the car ("Your driver")
      linkExpired: String,
      etaSuffix: String,   // e.g. " min"
      loading: String
  )

  private val strings: Map[String, Strings] = Map(
    "de" -> Strings(
      title = "Fahrt verfolgen",
      findingDriver = "Fahrer wird gesucht",
      driverOnTheWay = "Fahrer ist unterwegs",
      onTrip = "Unterwegs",
      tripCompleted = "Fahrt abgeschlossen",
      tripCancelled = "Fahrt storniert",
      approaching = "Ihr Fahrer trifft gleich ein",
      pickup = "Abholung",
      dropoff = "Ziel",
      driverLabel = "Ihr Fahrer",
      linkExpired = "Dieser Tracking-Link ist nicht mehr verfügbar.",
      etaSuffix = " Min.",
      loading = "Wird geladen …"
    ),
    "en" -> Strings(
      title = "Track your ride",
      findingDriver = "Finding a driver",
      driverOnTheWay = "Driver on the way",
      onTrip = "On trip",
      tripCompleted = "Trip completed",
      tripCancelled = "Trip cancelled",
      approaching = "Your driver is arriving",
      pickup = "Pickup",
      dropoff = "Destination",
      driverLabel = "Your driver",
      linkExpired = "This tracking link is no longer available.",
      etaSuffix = " min",
      loading = "Loading …"
    ),
    "uk" -> Strings(
      title = "Відстеження поїздки",
      findingDriver = "Шукаємо водія",
      driverOnTheWay = "Водій у дорозі",
      onTrip = "У дорозі",
      tripCompleted = "Поїздку завершено",
      tripCancelled = "Поїздку скасовано",
      approaching = "Ваш водій під'їжджає",
      pickup = "Подача",
      dropoff = "Призначення",
      driverLabel = "Ваш водій",
      linkExpired = "Це посилання для відстеження більше недоступне.",
      etaSuffix = " хв",
      loading = "Завантаження …"
    )
  )

  /**
   * Escape a value for safe embedding inside a single-quoted JS string literal.
   */
  private def jsString(s: String): String = s.flatMap {
    case '\\' => "\\\\"
    case '\'' => "\\'"
    case '"'  => "\\\""
    case '\n' => "\\n"
    case '\r' => "\\r"
    case '<'  => "\\u003c" // defang any chance of </script> breaking out
    case '>'  => "\\u003e"
    case '&'  => "\\u0026"
    case c    => c.toString
  }

  /**
   * Escape for HTML text/attribute context.
   */
  private def htmlEscape(s: String): String = s
    .replace("&", "&amp;")
    .replace("<", "&lt;")
    .replace(">", "&gt;")
    .replace("\"", "&quot;")

  def render(token: String, lang: String, mapboxToken: String): String =
    val s    = strings.getOrElse(lang, strings("de"))
    val l    = if strings.contains(lang) then lang else "de"
    // Build the JS i18n object literal.
    val i18n =
      s"""{
         |    findingDriver: '${jsString(s.findingDriver)}',
         |    driverOnTheWay: '${jsString(s.driverOnTheWay)}',
         |    onTrip: '${jsString(s.onTrip)}',
         |    tripCompleted: '${jsString(s.tripCompleted)}',
         |    tripCancelled: '${jsString(s.tripCancelled)}',
         |    approaching: '${jsString(s.approaching)}',
         |    pickup: '${jsString(s.pickup)}',
         |    dropoff: '${jsString(s.dropoff)}',
         |    driverLabel: '${jsString(s.driverLabel)}',
         |    linkExpired: '${jsString(s.linkExpired)}',
         |    etaSuffix: '${jsString(s.etaSuffix)}',
         |    loading: '${jsString(s.loading)}'
         |  }""".stripMargin

    s"""<!DOCTYPE html>
       |<html lang="$l">
       |<head>
       |  <meta charset="utf-8" />
       |  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
       |  <meta name="robots" content="noindex" />
       |  <title>${htmlEscape(s.title)}</title>
       |  <link href="https://api.mapbox.com/mapbox-gl-js/v3.0.1/mapbox-gl.css" rel="stylesheet" />
       |  <script src="https://api.mapbox.com/mapbox-gl-js/v3.0.1/mapbox-gl.js"></script>
       |  <style>
       |    * { box-sizing: border-box; }
       |    html, body { margin: 0; height: 100%; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
       |    #map { position: absolute; inset: 0; background: #e8eaed; }
       |    #overlay { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
       |      text-align: center; padding: 24px; color: #444; background: #f5f6f7; }
       |    #overlay.hidden { display: none; }
       |    #card { position: absolute; left: 12px; right: 12px; bottom: 12px; background: #fff; border-radius: 16px;
       |      box-shadow: 0 4px 24px rgba(0,0,0,.18); padding: 16px 18px; }
       |    #card.hidden { display: none; }
       |    .row { display: flex; align-items: center; justify-content: space-between; }
       |    #status { font-size: 18px; font-weight: 600; color: #1a1a2e; }
       |    #eta { font-size: 18px; font-weight: 600; color: #2563eb; }
       |    .addr { margin-top: 12px; display: flex; gap: 8px; align-items: flex-start; }
       |    .addr .dot { width: 10px; height: 10px; border-radius: 50%; margin-top: 5px; flex: 0 0 auto; }
       |    .addr .pickup-dot { background: #16a34a; }
       |    .addr .dropoff-dot { background: #dc2626; }
       |    .addr .label { font-size: 11px; text-transform: uppercase; letter-spacing: .04em; color: #888; }
       |    .addr .value { font-size: 14px; color: #222; }
       |    #banner { position: absolute; top: 12px; left: 12px; right: 12px; background: #dbeafe; color: #1e3a8a;
       |      border-radius: 12px; padding: 12px 14px; font-weight: 600; display: none; }
       |    #banner.show { display: block; }
       |    /* Map markers: a labeled icon over a point. Mapbox owns the root element's transform (positioning),
       |       so we only ever animate child nodes (.halo, .icon) — never the root .map-marker. */
       |    .map-marker { position: relative; width: 0; height: 0; }
       |    .map-marker .tag { position: absolute; bottom: 46px; left: 50%; transform: translateX(-50%);
       |      white-space: nowrap; background: #1a1a2e; color: #fff; font-size: 11px; font-weight: 600;
       |      padding: 3px 8px; border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,.25); pointer-events: none; }
       |    .map-marker .tag::after { content: ''; position: absolute; top: 100%; left: 50%; transform: translateX(-50%);
       |      border: 4px solid transparent; border-top-color: #1a1a2e; }
       |    .map-marker .icon { position: absolute; bottom: 0; left: 50%; transform: translateX(-50%);
       |      width: 34px; height: 34px; border-radius: 50%; background: #fff; border: 3px solid currentColor;
       |      box-shadow: 0 2px 8px rgba(0,0,0,.3); display: flex; align-items: center; justify-content: center; }
       |    .map-marker .icon svg { width: 20px; height: 20px; fill: currentColor; }
       |    /* Driver: pulsing radar halo + gentle shimmer to read as a "live" position. */
       |    .driver-marker { color: #2563eb; }
       |    .driver-marker .halo { position: absolute; bottom: 5px; left: 50%; width: 28px; height: 28px;
       |      margin-left: -14px; border-radius: 50%; background: #2563eb;
       |      animation: pulse-halo 1.6s ease-out infinite; pointer-events: none; }
       |    .driver-marker .icon { animation: shimmer 1.6s ease-in-out infinite; }
       |    .pickup-marker { color: #16a34a; }
       |    .dropoff-marker { color: #dc2626; }
       |    @keyframes pulse-halo {
       |      0%   { transform: scale(0.6); opacity: .55; }
       |      100% { transform: scale(2.2); opacity: 0; }
       |    }
       |    @keyframes shimmer {
       |      0%, 100% { box-shadow: 0 2px 8px rgba(0,0,0,.3); filter: brightness(1); }
       |      50%      { box-shadow: 0 0 14px 3px rgba(37,99,235,.7); filter: brightness(1.12); }
       |    }
       |    @media (prefers-reduced-motion: reduce) {
       |      .driver-marker .halo { animation: none; opacity: .35; }
       |      .driver-marker .icon { animation: none; }
       |    }
       |  </style>
       |</head>
       |<body>
       |  <div id="map"></div>
       |  <div id="banner"></div>
       |  <div id="overlay">${htmlEscape(s.loading)}</div>
       |  <div id="card" class="hidden">
       |    <div class="row"><span id="status"></span><span id="eta"></span></div>
       |    <div class="addr"><span class="dot pickup-dot"></span><div><div class="label" id="pickupLabel"></div><div class="value" id="pickup"></div></div></div>
       |    <div class="addr"><span class="dot dropoff-dot"></span><div><div class="label" id="dropoffLabel"></div><div class="value" id="dropoff"></div></div></div>
       |  </div>
       |  <script>
       |  (function () {
       |    var T = '${jsString(token)}';
       |    var MAPBOX_TOKEN = '${jsString(mapboxToken)}';
       |    var I = $i18n;
       |    var apiBase = location.origin;
       |    var wsBase = location.origin.replace(/^http/, 'ws');
       |
       |    var overlay = document.getElementById('overlay');
       |    var card = document.getElementById('card');
       |    var banner = document.getElementById('banner');
       |    document.getElementById('pickupLabel').textContent = I.pickup;
       |    document.getElementById('dropoffLabel').textContent = I.dropoff;
       |
       |    function statusLabel(status, driverAssigned) {
       |      switch (status) {
       |        case 'Requested': return I.findingDriver;
       |        case 'Assigned': case 'Confirmed': case 'HandedOff': return I.driverOnTheWay;
       |        case 'InProgress': return I.onTrip;
       |        case 'Completed': return I.tripCompleted;
       |        case 'Cancelled': return I.tripCancelled;
       |        default: return driverAssigned ? I.driverOnTheWay : I.findingDriver;
       |      }
       |    }
       |
       |    function showExpired() {
       |      overlay.textContent = I.linkExpired;
       |      overlay.classList.remove('hidden');
       |      card.classList.add('hidden');
       |    }
       |
       |    var map = null, driverMarker = null, ride = null, haveMapbox = !!MAPBOX_TOKEN;
       |
       |    function lngLat(loc) {
       |      return (loc && loc.longitude != null && loc.latitude != null) ? [loc.longitude, loc.latitude] : null;
       |    }
       |
       |    function initMap() {
       |      if (!haveMapbox) return;
       |      mapboxgl.accessToken = MAPBOX_TOKEN;
       |      map = new mapboxgl.Map({ container: 'map', style: 'mapbox://styles/mapbox/streets-v12',
       |        center: [11.5820, 48.1351], zoom: 11 });
       |      map.on('load', function () { drawRoute(); drawDriver(); fitBounds(); });
       |    }
       |
       |    // Inline SVGs (page is self-contained — Flutter asset files are not reachable here).
       |    var SVG_CAR = '<svg viewBox="0 0 24 24"><path d="M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11h1a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-1v1a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1v-1H8v1a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-1H4a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1h1zm1.6 0h10.8l-1-3a.5.5 0 0 0-.5-.4H8.1a.5.5 0 0 0-.5.4l-1 3zM6.5 15a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm11 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2z"/></svg>';
       |    var SVG_PERSON = '<svg viewBox="0 0 24 24"><path d="M12 12a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zm0 1.5c-3 0-6 1.5-6 4V19h12v-1.5c0-2.5-3-4-6-4z"/></svg>';
       |    var SVG_FLAG = '<svg viewBox="0 0 24 24"><path d="M6 3a1 1 0 0 1 1 1v1h11l-1.6 3.2L18 11.5H7V20a1 1 0 1 1-2 0V4a1 1 0 0 1 1-1zm1 4v2.5h2V7H7zm2 0v2.5h2V7H9zm2 0v2.5h2V7h-2zm2 0v2.5h2V7h-2z"/></svg>';
       |
       |    // Builds a labeled icon marker. `extraClass` adds driver/pickup/dropoff theming; `withHalo` adds the
       |    // pulsing radar ring (driver only). Caption goes through textContent — never innerHTML — so it can't inject.
       |    function makeMarkerEl(svg, extraClass, label, withHalo) {
       |      var root = document.createElement('div');
       |      root.className = 'map-marker ' + extraClass;
       |      if (withHalo) {
       |        var halo = document.createElement('div');
       |        halo.className = 'halo';
       |        root.appendChild(halo);
       |      }
       |      var icon = document.createElement('div');
       |      icon.className = 'icon';
       |      icon.innerHTML = svg; // static, trusted SVG constant
       |      root.appendChild(icon);
       |      var tag = document.createElement('div');
       |      tag.className = 'tag';
       |      tag.textContent = label;
       |      root.appendChild(tag);
       |      return root;
       |    }
       |
       |    var pickupMarker = null, dropoffMarker = null;
       |    function drawRoute() {
       |      if (!map || !ride) return;
       |      var p = lngLat(ride.pickup), d = lngLat(ride.dropoff);
       |      if (p && !pickupMarker) pickupMarker = new mapboxgl.Marker({ element: makeMarkerEl(SVG_PERSON, 'pickup-marker', I.pickup, false), anchor: 'bottom' }).setLngLat(p).addTo(map);
       |      if (d && !dropoffMarker) dropoffMarker = new mapboxgl.Marker({ element: makeMarkerEl(SVG_FLAG, 'dropoff-marker', I.dropoff, false), anchor: 'bottom' }).setLngLat(d).addTo(map);
       |    }
       |    function drawDriver() {
       |      if (!map || !ride) return;
       |      var pos = (ride.driverLat != null && ride.driverLng != null) ? [ride.driverLng, ride.driverLat] : null;
       |      if (!pos) return;
       |      if (!driverMarker) driverMarker = new mapboxgl.Marker({ element: makeMarkerEl(SVG_CAR, 'driver-marker', I.driverLabel, true), anchor: 'bottom' }).setLngLat(pos).addTo(map);
       |      else driverMarker.setLngLat(pos);
       |    }
       |    function fitBounds() {
       |      if (!map || !ride) return;
       |      var pts = [lngLat(ride.pickup), lngLat(ride.dropoff)];
       |      if (ride.driverLat != null && ride.driverLng != null) pts.push([ride.driverLng, ride.driverLat]);
       |      pts = pts.filter(Boolean);
       |      if (pts.length === 0) return;
       |      if (pts.length === 1) { map.setCenter(pts[0]); map.setZoom(13); return; }
       |      var b = pts.reduce(function (acc, x) { return acc.extend(x); }, new mapboxgl.LngLatBounds(pts[0], pts[0]));
       |      map.fitBounds(b, { padding: 80, maxZoom: 14 });
       |    }
       |
       |    function renderCard() {
       |      if (!ride) return;
       |      document.getElementById('status').textContent = statusLabel(ride.status, ride.driverAssigned);
       |      document.getElementById('eta').textContent = (ride.etaMinutes != null) ? (ride.etaMinutes + I.etaSuffix) : '';
       |      document.getElementById('pickup').textContent = ride.pickup ? ride.pickup.address : '';
       |      document.getElementById('dropoff').textContent = ride.dropoff ? ride.dropoff.address : '';
       |      overlay.classList.add('hidden');
       |      card.classList.remove('hidden');
       |    }
       |
       |    function applyInitial(dto) {
       |      ride = {
       |        status: dto.status,
       |        pickup: dto.pickup, dropoff: dto.dropoff,
       |        driverLat: dto.driverLocation ? dto.driverLocation.latitude : null,
       |        driverLng: dto.driverLocation ? dto.driverLocation.longitude : null,
       |        etaMinutes: dto.etaMinutes, driverAssigned: dto.driverAssigned
       |      };
       |      renderCard();
       |      if (map && map.loaded()) { drawRoute(); drawDriver(); fitBounds(); }
       |    }
       |
       |    function onEvent(msg) {
       |      var type = Object.keys(msg)[0]; var p = msg[type];
       |      if (!ride) return;
       |      if (type === 'LocationUpdated' && p.locationType === 'driver') {
       |        ride.driverLat = p.latitude; ride.driverLng = p.longitude; drawDriver();
       |      } else if (type === 'RideStatusChanged') {
       |        ride.status = p.newStatus; renderCard();
       |      } else if (type === 'DriverApproaching') {
       |        banner.textContent = I.approaching; banner.classList.add('show');
       |      }
       |    }
       |
       |    function connectWs() {
       |      try {
       |        var ws = new WebSocket(wsBase + '/api/ws/track?token=' + encodeURIComponent(T));
       |        ws.onmessage = function (e) { try { onEvent(JSON.parse(e.data)); } catch (_) {} };
       |        ws.onclose = function () { setTimeout(connectWs, 5000); };
       |      } catch (_) { setTimeout(connectWs, 5000); }
       |    }
       |
       |    initMap();
       |    fetch(apiBase + '/api/track/' + encodeURIComponent(T))
       |      .then(function (r) { if (r.status === 404) { showExpired(); throw 'expired'; } return r.json(); })
       |      .then(function (dto) { applyInitial(dto); connectWs(); })
       |      .catch(function (e) { if (e !== 'expired') showExpired(); });
       |  })();
       |  </script>
       |</body>
       |</html>""".stripMargin
