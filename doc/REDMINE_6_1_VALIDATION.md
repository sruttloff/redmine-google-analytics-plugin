# Redmine 6.1 validation — version 1.1.0

Validation date: **2026-10-16**.

## Environment

| Component | Tested version |
| --- | --- |
| Redmine | 6.1.2-stable |
| Rails | 7.2.3 |
| Ruby | 3.3.7 |
| Database | MySQL 8.4.11 |
| Application | Puma 8.0.1, development mode, Linux Docker container |
| Browser | Codex integrated Chromium browser, `http://localhost:8080` |

The plugin was tested alongside the other plugins installed in the local Redmine environment. No Redmine core changes or additional gems were needed.

## Corrections made

1. **Application startup:** the upstream `require_dependency 'google_analytics_hooks'` raises `LoadError` under the tested Rails version because plugin lib directories are Zeitwerk roots rather than entries on `$LOAD_PATH`. Initialization now resolves the hook constant using Zeitwerk.
2. **Reloads:** initialization restores the listener if Redmine's registry was reloaded and avoids registering it twice.
3. **Audience settings:** HTML string flags are normalized, so disabled values such as `"0"` cannot become enabled through Ruby string truthiness. The form submits explicit disabled values and uses the same conversion when displaying checkboxes. Legacy Boolean settings and absent unchecked flags remain supported.
4. **Configuration view:** controls have associated labels, use the supplied `settings` local, and retain the snippet as escaped textarea content. English/German guidance explains the independent administrator switch and empty-code behavior; translated links are sanitized.
5. **Legacy test helper:** removed the obsolete `Engines::Testing` dependency.

## Automated checks

Run from the Redmine root, against an already migrated development/test database:

```sh
bundle exec rake zeitwerk:check
bundle exec rails runner plugins/google_analytics_plugin/test/compatibility_smoke.rb
bundle exec rails runner plugins/google_analytics_plugin/test/reload_smoke.rb
```

Results:

- **Zeitwerk:** `All is good!`
- **Compatibility:** **323 checks passed**, including all eight combinations of the audience switches, actual administrator settings POSTs, persistence, checkbox state, explicit unchecked values, and snippet placement on Home, Projects, and Issues for all three account categories.
- **Additional request checks:** Boolean/string flags, empty/nil code, legacy omitted settings, English/German configuration text, anonymous login redirect, non-admin GET rejection, and non-admin POST rejection with a valid CSRF token and unchanged settings.
- **Reloads:** three consecutive Rails reloads, each with exactly one current `GoogleAnalyticsHooks` instance, an active head hook, and working flag conversion. Plugin initialization is isolated to this plugin in that runner process, avoiding unrelated plugins' reload behavior.

The compatibility script wraps its writes in a transaction and rolls back all temporary accounts and settings. It restores the current user and mail-delivery state and clears the setting cache afterward. No analytics data is sent by the tests.

## Integrated browser checks

The configuration was opened through **Administration → Plugins → Configure**. Version **1.1.0**, this fork's repository link, and maintainer metadata were visible in the installed-plugin list.

A local snippet set `data-analytics-smoke="1"` on the document's `<html>` element. Each page load was checked for both the script's location and this execution marker. No external analytics URL or measurement ID was configured.

| Anonymous switch | Authenticated switch | Administrator switch | Anonymous visitor | Signed-in non-admin | Administrator |
| --- | --- | --- | --- | --- | --- |
| Off | Off | Off | No code | No code | No code |
| On | Off | Off | Executes once | No code | No code |
| Off | On | Off | No code | Executes once | No code |
| On | On | Off | Executes once | Executes once | No code |
| Off | Off | On | No code | No code | Executes once |
| On | Off | On | Executes once | No code | Executes once |
| Off | On | On | No code | Executes once | Executes once |
| On | On | On | Executes once | Executes once | Executes once |

All **24 matrix cases passed**. Every injected script was in `<head>` with zero copies in `<body>`; disabled groups had no script and no execution marker. Saved checkbox states matched each configuration after submission.

Additional browser results:

- Clearing the code with every audience enabled prevented injection for all three categories; this also persisted after a reload (**four additional execution checks passed**).
- A non-admin opening the configuration received **403**.
- An anonymous visitor opening the configuration was redirected to login.
- Both German and English settings views displayed the expected labels and guidance; the language was changed through the temporary administrator's account form.
- No browser console errors were recorded during these checks.
- German and English screenshots were captured and visually inspected locally. Test accounts and the test snippet were temporary; original plugin settings were restored after validation.

## Scope and limits

All tested plugin functions passed in this environment. The plugin inserts administrator-provided snippets; it does not implement an analytics client or reports. Provider-side collection was **not** tested because no Google Analytics property, Matomo instance, or account credentials were supplied. Validate receipt separately with your real provider's tools after configuring your own snippet.

Other Redmine 6.1 patch releases, Ruby/Rails combinations, database adapters, themes, restrictive content security policies, and deployments have not been independently tested. JSON, CSV, downloads, feeds, and partial responses without the base layout are outside the hook's scope. Consent handling and any required body/noscript portion of a provider integration must be supplied separately.
