# Visual regression screenshots

A plan for catching unintended UI changes by screenshotting pages during the feature specs and
showing the differences on each pull request. The immediate motivation is a safety net for
front-end upgrades (Dart Sass, Bootstrap 3 → 5), where a change can touch about half the views.

Status: **in progress.** The capture hook (phase 1) works locally and most of the repeatability
work (phase 2) is done; see [Where it stands](#where-it-stands). Nothing runs in CI yet.

## Usage

```sh
SCREENSHOTS=1 bundle exec rspec spec/features
```

Screenshots land in `tmp/screenshots` (override with `SCREENSHOT_DIR`). Without `SCREENSHOTS`, the
hook in `spec/support/screenshots.rb` does nothing and the suite runs as before.

## What the specs cover today

Measured in November 2026 by logging every controller action hit during the feature, cucumber and
controller/request suites, and comparing against `rails routes`.

The app has 166 distinct GET actions, which are the ones that can be screenshotted.

| Coverage                                                    | GET actions |
| ----------------------------------------------------------- | ----------- |
| Hit by a browser spec (feature or cucumber)                 | 105         |
| Only hit by controller/request specs (no page in a browser) | 23          |
| Not hit by any spec                                         | 38          |

Of the 105, 97 return an HTML page with status 200. By area, browser specs reach 76 of 105 admin
actions and 29 of 55 public ones. The 6 API actions return JSON and do not matter here.

This is action-level coverage: a page counts as covered even if only one of its states (empty,
populated, error) was rendered.

### Pages with no browser spec

Public:

- Schedule: `schedules#show`, `schedules#vertical_schedule`, `schedules#app`
- `conferences#calendar`, `conferences#code_of_conduct`
- Booths: `index`, `new`, `edit`, `show`
- `tracks#show`, `surveys#index`, `physical_tickets#show`
- Payments: `success`, `cancel`, `index`; `ticket_purchases#index`
- Password reset (`devise/passwords#new`, `#edit`) and confirmation (`confirmations#new`, `#show`)
- `rooms#live_session`, `proposals#registrations`, `registrations#cancel`

Admin:

- Questions: `new`, `edit`, `show`; surveys `edit`; survey questions `edit`, `show`
- Schedules: `new`, `edit`
- Volunteers: `index`, `show`; physical tickets `index`; comments `index`; users `new`
- `show` pages for booths, registrations, tickets, emails, resources, event types, difficulty
  levels and cfps
- `events#registrations`, `events#preview_tentative_accept`, `roles#edit`
- `versions#revert_attribute`, `versions#revert_object`

A few of these may be routes with no real action behind them; they have not been checked one by one.

## Phase 1: capture hook

`spec/support/screenshots.rb` saves screenshots during feature specs when `SCREENSHOTS=1` is set.

- **Every feature spec runs in Chrome.** Most feature specs use the `rack_test` driver, which
  cannot take screenshots, so screenshot mode makes a 1280×900 headless Chrome the default driver.
  (The normal spec window is narrow enough to collapse the navbar and sidebar.)
- **When to capture.** Just before the spec navigates away (`visit`, `click_link`, `click_button`,
  `click_on`) and once more when the example ends. Capturing before an action, not after, avoids
  racing a page that is still loading.
- **Waits for requests to finish.** The hook waits for jQuery's in-flight requests before each
  capture. Besides giving a complete page, this is required: leaving a page while its DataTable is
  still loading makes DataTables raise an "Ajax error" alert, which breaks the browser session.
- **Full page.** The whole document, not only the viewport.
- **Stable names.** `tmp/screenshots/<spec file>/<example>/<NN>-<controller>-<action>.png`, so the
  same example produces the same file names on the base and head commits.
- **Failures are skipped.** A failing example keeps the existing failure screenshot from
  `save_feature_failures.rb`, contributes no images, and gets a fresh browser for the next example.

## Phase 2: make the pixels repeatable

Two runs of the same commit must produce identical images before any diff is worth reading.

| Source                                           | Status                                             |
| ------------------------------------------------ | -------------------------------------------------- |
| Faker data differs every run                     | Done: Faker and `rand` seeded from the example id  |
| Factory sequences depend on spec order           | Done: sequences rewound before each example        |
| `SecureRandom` short titles and codes            | Done: stubbed to use the seeded generator          |
| Timestamps printed on pages                      | Done: time frozen at a fixed moment                |
| Blinking text cursor                             | Done: caret hidden before capture                  |
| Database ids shown on pages                      | To check                                           |
| Trianglify random backgrounds                    | To check                                           |
| Gravatar images, Leaflet map tiles (network)     | To check                                           |
| Chart rendering and web font loading             | To check                                           |

Pages that stay noisy after this are listed in an ignore file instead of blocking the rest.

## Where it stands

Measured locally on 22 November 2026 by running the feature suite twice in screenshot mode and
comparing the two sets of images.

- **Images:** about 485 per run. 405 were byte-identical between the two runs and 74 differed.
- **Still differing:** mostly `admin/events#index` (28 images), `admin/roles#index` and `#show`
  (23), and `admin/tracks#index` (7). The causes have not been looked at yet.
- **Failing examples:** 10 or 11 of 155 fail in screenshot mode; all pass in the normal suite.
  - Seven fail every time because they were written for `rack_test`: delete confirmations that are
    never accepted, and flash messages or record changes that do not appear after a form submit
    (`venues_spec`, `tickets_spec`, `event_types_spec`, `resource_spec`).
  - `event_schedules_spec.rb:41` started failing once time was frozen.
  - A few more come and go between runs (`voting_spec`, `proposals_spec`,
    `conference_registration_spec`).

Next steps, in order:

1. Fix or tag the examples that fail under Chrome, so a screenshot run is green.
2. Track down the remaining differing pages until two runs match.
3. Pick the reporting route (phase 3) and wire up CI.

## Phase 3: show diffs on pull requests

GitHub cannot embed workflow artifacts in a PR comment, so the images need somewhere to live.

1. **A visual review service (recommended).** CI uploads the screenshot folder; the service stores
   baselines from `main`, diffs each PR against them, and adds a status check with a review UI.
   Argos and Percy both have free tiers for open source. Least code to own.
2. **Baselines committed to the repository.** GitHub's built-in image diff (swipe / onion skin)
   then shows changes in the PR's Files tab. No third party, but the repository grows, and every
   intentional UI change needs regenerated images.
3. **Self-hosted.** CI runs the suite on base and head, diffs with ImageMagick, pushes the images to
   an orphan branch and posts a sticky PR comment linking them. Full control, most to maintain.

Whichever is chosen, the CI job is separate from the `spec` matrix and does not block merging until
the screenshots have proven stable.

## Phase 4: widen coverage

Add simple "visit and render" feature specs for the uncovered pages above, public pages first and
the schedule before anything else. These exist to be screenshotted, so one example per page state
(empty, populated) is enough.

## Rough effort

- Phases 1 and 2: one to two days, mostly chasing unstable pixels.
- Phase 3: about half a day with a service; longer if self-hosted.
- Phase 4: incremental.
