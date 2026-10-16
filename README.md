# Google Analytics plugin for Redmine 6.1

Insert an administrator-provided analytics snippet into Redmine's HTML page head, with separate switches for anonymous visitors, signed-in users, and administrators. The snippet can come from Google Analytics, Matomo (formerly Piwik), or another provider that supports installation in the page head.

This fork is maintained for Redmine 6.1 by **[SaaS-Secure.com, S. Ruttloff](https://www.saas-secure.com/)**. It builds on the original plugin by Eric Davis and the forks maintained by Raphael Kallensee and [pagina GmbH](https://github.com/paginagmbh/redmine-google-analytics-plugin).

**Version: 1.1.0.** Validated with Redmine **6.1.2-stable**, Rails **7.2.3**, Ruby **3.3.7**, and MySQL **8.4.11**. See the [validation report](doc/REDMINE_6_1_VALIDATION.md) for tested behavior and limits, and the [changelog](CHANGELOG.md) for release notes. Other Redmine versions and database adapters have not been verified.

## Features

- Store a complete tracking snippet, including its `<script>` tags.
- Insert the snippet once into each rendered page using Redmine's standard base layout.
- Independently enable tracking for anonymous visitors, authenticated users, and administrators.
- Turn tracking off by clearing the code or disabling all three groups.
- Configure everything under **Administration → Plugins → Google Analytics plugin → Configure**.
- Use the English or German configuration interface; existing Hungarian, Italian, Japanese, Dutch, Portuguese, Brazilian Portuguese, and Russian translations are retained.
- Keep existing settings when upgrading: the plugin ID and setting keys remain unchanged.

## Requirements

- Redmine 6.1.x and a Ruby/Rails combination supported by that Redmine release.
- Administrator access to configure the plugin.
- A complete snippet from your analytics provider, suitable for the HTML `<head>`.

No additional gems, database migrations, JavaScript packages, or plugin assets are required.

## Installation

Back up your installation before installing or upgrading. The directory must be named exactly **`google_analytics_plugin`**:

```sh
cd /path/to/redmine/plugins
git clone --branch v1.1.0 https://github.com/sruttloff/redmine-google-analytics-plugin.git google_analytics_plugin
```

Restart the Redmine application server (Puma, Passenger, Docker, or your deployment's equivalent). Plugin-specific migrations and asset compilation are unnecessary. If your normal deployment process runs `bundle install` or precompiles Redmine assets, keep those steps as usual.

### Upgrade from 1.0.1

Keep the original plugin directory and fetch the release:

```sh
cd /path/to/redmine/plugins/google_analytics_plugin
git fetch origin --tags
git checkout v1.1.0
```

Restart Redmine and review the configuration. Existing snippets and flags are preserved. Old Boolean flags and omitted unchecked flags are supported. Newly saved settings explicitly store `1` for enabled and `0` for disabled groups.

### Uninstallation

Remove the plugin directory and restart Redmine. There are no plugin tables or migrations to roll back. The saved settings remain in Redmine's `settings` table, allowing a later reinstall to recover them.

## Configuration and usage

1. Sign in as an administrator and open **Administration → Plugins**.
2. Select **Configure** for **Google Analytics plugin**.
3. Paste the complete tracking snippet, including its HTML script tags. A measurement ID alone is insufficient.
4. Select the required groups and click **Apply**.
5. Open a normal Redmine page as a visitor from each selected group and check the snippet in the page head.

| Option | Applies to |
| --- | --- |
| Log anonymous users | Visitors who have not signed in |
| Log authenticated users | Signed-in users without administrator status |
| Log administrator users | Administrators, independently of the authenticated-user option |

All groups are enabled on a fresh installation, but the code starts empty, so no tracking is performed until you configure a snippet. These options refer to the three account categories above, rather than Redmine's project roles or permissions.

### Google Analytics and Matomo

For Google Analytics, copy the current Google tag snippet from your own property. Refer to [Google's official setup instructions](https://developers.google.com/tag-platform/gtagjs). For Matomo or another provider, use its JavaScript snippet for the page head. The plugin outputs your code as supplied; it does not generate a tag, validate an account ID, contact an analytics API, or display reports.

Only the head portion of a snippet belongs in this field. Integrations requiring a separate `<body>` or `<noscript>` block need an additional integration. Requests returning JSON, CSV, feeds, downloads, or partial HTML without Redmine's base layout do not receive the snippet.

### Safe local verification

This harmless snippet marks the current document and sends no data to an external service:

```html
<script id="redmine-analytics-check">
  document.documentElement.setAttribute('data-analytics-check', 'executed');
</script>
```

After saving, inspect the page head and the `<html data-analytics-check="executed">` attribute. Disable a group and verify that both disappear on a fresh page load for that group. Clearing the field disables injection for every group. Changing a setting takes effect on subsequent page loads; it does not undo scripts already executed in an open page.

The field intentionally accepts executable HTML/JavaScript and is accessible only to administrators. Review the supplied code before saving. Consent handling and provider-specific configuration belong in your snippet or your existing consent integration; this plugin provides audience switches, without a consent dialog.

## Changes for Redmine 6.1

- Use Zeitwerk constant loading instead of the obsolete plugin `require_dependency` lookup that fails under Rails 7.2.
- Keep one active hook listener across Rails reloads and repeated plugin initialization.
- Normalize Boolean and string settings, including disabled values `0`, `false`, and `off`.
- Explicitly submit unchecked flags and render their saved state correctly.
- Associate labels with controls and use the settings partial's local variable.
- Update English/German guidance and sanitize translated links.
- Preserve the existing plugin ID, setting keys, original credits, and license.

## Validation and development

Run these commands from an already migrated Redmine installation:

```sh
bundle exec rake zeitwerk:check
bundle exec rails runner plugins/google_analytics_plugin/test/compatibility_smoke.rb
bundle exec rails runner plugins/google_analytics_plugin/test/reload_smoke.rb
```

The compatibility script requires a development or test database. It creates temporary accounts, makes real Rails requests, checks all eight audience combinations, saved checkbox states, page-head placement, empty/legacy settings, translations, and access control, then rolls back its database changes. The reload script verifies three reloads with the plugin isolated from unrelated plugins' reload behavior. Neither script sends tracking data to a provider.

Browser checks and the distinction between snippet execution and provider-side data collection are described in the [validation report](doc/REDMINE_6_1_VALIDATION.md).

## Troubleshooting

- **Redmine cannot find the plugin:** verify the folder name `google_analytics_plugin` and restart the application server.
- **No tracking code appears:** ensure the field is not empty, the current user's group is enabled, and the page uses Redmine's standard base layout. Administrators use their own switch.
- **Code appears but the provider receives nothing:** check the snippet, account ID, consent configuration, browser console, network requests, content security policy, and browser blockers. Confirm receipt with your provider's own debugging tools.
- **A page breaks after saving a snippet:** clear the field as an administrator and correct the supplied JavaScript. If the script prevents access to the form, an operator can clear it using `bundle exec rails runner 'Setting.plugin_google_analytics_plugin = Setting.plugin_google_analytics_plugin.merge("google_analytics_code" => "")'` from the Redmine directory.

## More plugins from SaaS-Secure.com

- **[Redmine UX Toolkit](https://www.saas-secure.com/online-services/redmine-ux-toolkit.html)** – Modern interface, dashboards, checklists, templates, reminders, and administration tools.
- **[SCM Creator for Redmine](https://www.saas-secure.com/online-services/redmine-scm.html)** – Repository management for Git, Subversion, Mercurial, Bazaar, and GitHub.
- **[Redcase](https://github.com/sruttloff/redcase)** – Test case management and execution in Redmine.

These plugins are optional and are not required. For hosting and other services, visit **[www.saas-secure.com](https://www.saas-secure.com/)**.

## Support and credits

Report issues through **[GitHub Issues](https://github.com/sruttloff/redmine-google-analytics-plugin/issues)**, including your Redmine, Rails, and Ruby versions and steps to reproduce the issue. Remove private tracking IDs or secrets from reports.

- Original plugin: Eric Davis, Little Stream Software.
- Earlier forks: Raphael Kallensee and Tobias Fischer / pagina GmbH.
- Redmine 6.1 adaptation and maintenance: SaaS-Secure.com, S. Ruttloff.
- Additional contributors are listed in [CREDITS.txt](CREDITS.txt).

## License

GNU General Public License, version 2 or later. Original copyright notices are preserved. See [COPYRIGHT.txt](COPYRIGHT.txt) and [GPL.txt](GPL.txt).
