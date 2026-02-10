# OSBot-Playwright Research Report

**Date:** 2026-02-09
**Researcher roles:** Dev, QA
**Status:** Active

---

## 1. What Is OSBot-Playwright?

OSBot-Playwright is a Python library that wraps Microsoft's Playwright browser automation framework, providing a higher-level API for headless browser operations. It is part of the OWASP Security Bot (owasp-sbot) ecosystem, authored by Dinis Cruz.

**Repository:** https://github.com/owasp-sbot/OSBot-Playwright
**PyPI package:** `osbot-playwright` (v0.6.10, released January 25, 2025)
**License:** MIT (pyproject.toml) / Apache-2.0 (GitHub)
**Language:** Python 99.3%, Shell 0.7%
**Default branch:** `dev`

### Problems It Solves

1. **Browser automation abstraction** -- Wraps Playwright's sync API into a simpler class hierarchy for launching browsers, managing pages, and extracting content.
2. **Browser lifecycle management** -- Manages Chromium processes as standalone subprocesses with CDP (Chrome DevTools Protocol) debugging ports, health checks, and persistent process state (saved to JSON).
3. **HTML parsing integration** -- Provides an `Html_Parser` class (wrapping BeautifulSoup) that integrates directly with browser pages for content extraction.
4. **Request capture** -- Intercepts and records network requests, frames, and routes for analysis.
5. **Docker/Lambda deployment** -- Includes Docker images and AWS Lambda integration for running headless browsers in cloud environments.
6. **FastAPI REST API** -- Provides REST endpoints for browser operations (screenshots, HTML fetching, code execution) via FastAPI.
7. **Browserless.io integration** -- Supports connecting to remote Browserless.io instances via CDP over WebSocket.

---

## 2. Architecture Overview

### Package Structure

```
osbot_playwright/
  __init__.py
  _extra_methdos_osbot.py
  docker/
    Build__Docker_Playwright.py
    ECR__Docker_Playwright.py
    Lambda__Docker_Playwright.py
    Local__Docker_Playwright.py
    images/osbot_playwright/
      dockerfile
      handler.py
      requirements.txt
      run-docker.sh
  html_parser/
    Html_Parser.py
  playwright/
    api/
      API_Browserless.py
      Playwright_Browser.py
      Playwright_Browser__Chrome.py
      Playwright_CLI.py
      Playwright_Install.py
      Playwright_Page.py
      Playwright_Process.py
      Playwright_Requests.py
    fastapi/
      Fast_API_Playwright.py
      Routes__Playwright.py
```

### Key Classes

#### `Playwright_Browser` (base class)
- Abstract base class for browser management
- Manages the Playwright sync API context (`sync_playwright().start()`)
- Provides context and page management (new/close contexts, new/close pages)
- Uses CDP (`connect_over_cdp`) for browser connections
- Returns `Playwright_Page` wrappers for pages

#### `Playwright_Browser__Chrome` (extends `Playwright_Browser`)
- Concrete implementation for Chromium
- Manages `Playwright_Process` for launching Chrome with a debug port
- Auto-starts browser process if not running
- Connects to browser via CDP endpoint (`http://localhost:{port}`)
- Delegates browser installation to `Playwright_CLI` and `Playwright_Install`

#### `Playwright_Process`
- Manages a Chromium subprocess launched via `subprocess.Popen`
- Uses Chrome's `--remote-debugging-port` for CDP access
- Persists process details (PID, port, args) to a JSON file on disk
- Provides health checks: port open, process running, data folder exists
- Supports start/stop/restart lifecycle
- Waits for the debug port to open after process start

#### `Playwright_Page`
- Wraps Playwright's `Page` and `BrowserContext` objects
- Key methods: `goto()`, `open()`, `close()`, `title()`, `url()`, `screenshot()`, `html_raw()`, `html()`, `set_html()`, `json()`
- `html()` returns an `Html_Parser` instance (BeautifulSoup wrapper)
- `url_info()` parses the current URL into components (scheme, host, port, path, query params)
- `screenshot()` defaults to saving at `/tmp/playwright_screenshot.png`
- Supports request/frame/route capturing via `Playwright_Requests`

#### `Playwright_CLI`
- Wraps the `playwright` CLI tool
- Manages a custom browser installation path: `/tmp/osbot_playwright_browsers/`
- Sets `PLAYWRIGHT_BROWSERS_PATH` environment variable
- Provides `install()`, `version()`, `dry_run()`, `help()` methods
- Parses `--dry-run` output to extract browser details (version, install location, download URL)
- Determines executable paths per OS (macOS, Linux)

#### `Playwright_Install`
- Higher-level installer that uses `Playwright_CLI`
- Discovers all browser executable paths via Playwright's API
- Caches browser details to `browsers_details.json`
- Supports chromium, firefox, webkit

#### `Html_Parser` (BeautifulSoup wrapper)
- Standalone HTML parsing with a rich API
- Methods: `title()`, `paragraphs()`, `hrefs()`, `tags__stats()`, `class__text()`, `id__text()`, `img_src()`, `options()`, `select()`, `find()`, `find_all()`, `json()`, `footer()`, `body()`, `text()`
- Can be used independently of Playwright (just pass HTML string)

#### `Playwright_Requests`
- Captures browser network requests, frames, and routes
- Supports serialization to/from JSON files
- Designed to hook into Playwright's event system (`page.on("requestfinished", ...)`)

#### `API_Browserless`
- Connects to Browserless.io via WebSocket CDP
- Requires `BROWSERLESS__API_KEY` env var
- Uses `wss://chrome.browserless.io?token={key}` endpoint

#### `Routes__Playwright` / `Fast_API_Playwright`
- FastAPI routes for `/playwright/code`, `/playwright/html`, `/playwright/screenshot`
- The `code` endpoint executes arbitrary Python code with a `callback` function that receives a browser
- Authentication via `Http_Shell__Server` auth key
- Requires `osbot-fast-api` package (not included in PyPI dependencies)

### Dependencies

From `pyproject.toml`:
- `python ^3.11`
- `osbot-utils` (OWASP Security Bot utilities)
- `playwright` (Microsoft Playwright)
- `psutil` (process management)
- `fastapi` + `uvicorn` (REST API)
- `httpx` (HTTP client)
- `beautifulsoup4` (HTML parsing)

Additional runtime dependencies (from `requirements.txt`, not in pyproject.toml):
- `osbot-aws` (for Docker/ECR/Lambda)
- `osbot-docker` (for Docker builds)
- `osbot-fast-api` (for FastAPI routes)
- `boto3`, `docker`, `requests`, `python-dotenv`

### Design Patterns

1. **No Type_Safe** -- Unlike other owasp-sbot projects, OSBot-Playwright does NOT use `Type_Safe` base classes. Classes use plain `__init__` with manual attribute assignment.
2. **Context managers** -- All major classes support `with` statement (`__enter__`/`__exit__`).
3. **CDP-first architecture** -- Rather than using Playwright's `launch()` directly, it launches Chrome as a subprocess with a debug port and connects via CDP. This allows process reuse and external connections.
4. **Custom browser paths** -- Uses `/tmp/osbot_playwright_browsers/` instead of Playwright's default `~/.cache/ms-playwright/`.
5. **Process persistence** -- Saves process state to JSON files for health checking and reconnection.

---

## 3. Experiments

### Environment Details

- **Platform:** Linux 4.4.0, x86_64
- **Python:** 3.11.14
- **Sandbox:** Claude Code remote container with egress proxy (many external domains blocked)

### Experiment 1: Package Installation

**Command:**
```
pip install osbot-playwright
```

**Result:** Already installed (v0.6.10). Dependencies:
- `beautifulsoup4==4.14.3`
- `fastapi==0.128.6`
- `httpx==0.28.1`
- `osbot-utils==3.72.0`
- `playwright==1.58.0`
- `psutil==7.2.2`
- `uvicorn==0.40.0`

**Status: SUCCESS**

### Experiment 2: Browser Installation -- Version Mismatch

**Problem:** The pip-installed Playwright library (v1.58.0) expected chromium revision 1208, but the pre-installed browser was revision 1194 (for Playwright CLI v1.56.1).

**Command:**
```
python3 -m playwright install chromium
```

**Result:** Failed with `403 Host not allowed` -- the download URL `cdn.playwright.dev/chrome-for-testing-public/...` was blocked by the sandbox egress proxy.

**Fix:** Downgraded Playwright to match the pre-installed browser:
```
pip install playwright==1.56.0
```
This version expects chromium-1194, which was already installed at `/root/.cache/ms-playwright/chromium-1194/`.

**Status: SUCCESS (after workaround)**

### Experiment 3: OSBot Custom Browser Path

**Problem:** OSBot-Playwright's `Playwright_CLI` uses a custom browser path (`/tmp/osbot_playwright_browsers/`) different from Playwright's default (`~/.cache/ms-playwright/`).

**Fix:** Created symlinks:
```bash
mkdir -p /tmp/osbot_playwright_browsers
ln -sf /root/.cache/ms-playwright/chromium-1194 /tmp/osbot_playwright_browsers/chromium-1194
ln -sf /root/.cache/ms-playwright/chromium_headless_shell-1194 /tmp/osbot_playwright_browsers/chromium_headless_shell-1194
```

After this, `Playwright_CLI.browser_installed__chrome()` returned `True`.

**Status: SUCCESS (after workaround)**

### Experiment 4: Basic Playwright -- Launch and Evaluate

**Command:**
```python
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'])
    page = browser.new_page()
    result = page.evaluate('() => 1 + 1')
    ua = page.evaluate('() => navigator.userAgent')
    browser.close()
```

**Result:**
```
Browser version: 141.0.7390.37
JS eval result: 2
User agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/141.0.7390.37 Safari/537.36
```

**Status: SUCCESS** -- Browser launches, JS evaluation works. Must use `--no-sandbox` when running as root.

### Experiment 5: Basic Page Operations

**Command:**
```python
page = browser.new_page()
title = page.title()       # returns ''
content = page.content()   # returns '<html><head></head><body></body></html>'
```

**Result:** Title and content of blank page retrieved successfully.

**Status: SUCCESS**

### Experiment 6: External URL Navigation

**Command:**
```python
page.goto('https://httpbin.org/get', timeout=15000)
```

**Result:**
```
Navigation failed: Page.goto: net::ERR_TUNNEL_CONNECTION_FAILED at https://httpbin.org/get
```

**Status: FAILED** -- External URLs blocked by sandbox egress proxy. Not an OSBot-Playwright issue.

### Experiment 7: Screenshots

**Command:**
```python
page.screenshot(path='/tmp/test.png')
```

**Result:**
```
Protocol error (Page.captureScreenshot): Unable to capture screenshot
```

Tried with both regular chromium and headless_shell executable. Both failed.

**Status: FAILED** -- Screenshot capture not supported in this sandboxed environment. This is a Chromium/environment limitation, not an OSBot-Playwright issue.

### Experiment 8: PDF Generation

**Command:**
```python
page.pdf()
```

**Result:**
```
Protocol error (Page.printToPDF): Printing failed
```

**Status: FAILED** -- Same environment limitation as screenshots.

### Experiment 9: `set_content()` and `page.content()` After DOM Modification

**Observations:**
- `page.set_content(html)` hangs indefinitely in this environment
- `page.goto('data:text/html,...')` hangs indefinitely
- `page.evaluate('(h) => { document.body.innerHTML = h; }', html)` works for setting content
- After innerHTML modification, `page.content()` hangs indefinitely
- `page.evaluate('() => document.body.innerHTML')` works for reading content back

This appears to be a Chromium sandbox/container limitation where certain CDP commands that require rendering/layout hang.

**Status: PARTIAL** -- Workarounds exist for some operations.

### Experiment 10: OSBot `Playwright_CLI` Class

**Command:**
```python
from osbot_playwright.playwright.api.Playwright_CLI import Playwright_CLI
cli = Playwright_CLI()
print(cli.version())
print(cli.browser_installed__chrome())
print(cli.executable_path__chrome())
print(cli.executable_version__chrome())
print(cli.install_details__chrome())
```

**Result:**
```
Version: Version 1.56.1
Chrome installed: True
Chrome executable path: /tmp/osbot_playwright_browsers/chromium-1194/chrome-linux/chrome
Chrome executable version: Chromium 141.0.7390.37
Install details: {'version': '141.0.7390.37', 'install_location': '/tmp/osbot_playwright_browsers/chromium-1194', ...}
```

**Status: SUCCESS** -- All CLI methods work correctly.

### Experiment 11: OSBot `Playwright_Install` Class

**Command:**
```python
from osbot_playwright.playwright.api.Playwright_Install import Playwright_Install
install = Playwright_Install()
details = install.browsers_details(reset_data=True)
```

**Result:** Successfully detected chromium as installed, firefox and webkit as not installed. Generated `browsers_details.json` with download URLs, executable paths, and install locations.

**Status: SUCCESS**

### Experiment 12: OSBot `Playwright_Browser__Chrome` (with `--no-sandbox` patch)

**Problem:** The `Playwright_Process.start_process()` method does not include `--no-sandbox` in Chrome launch args, causing failure when running as root:
```
Running as root without --no-sandbox is not supported.
```

**Fix:** Monkey-patched `Playwright_Process.start_process` to add `--no-sandbox`, `--disable-gpu`, `--disable-dev-shm-usage` flags.

**Result after fix:**
```
Browser version: 141.0.7390.37
Page URL: about:blank
User agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/141.0.0.0 Safari/537.36
URL info: {'raw': 'about:blank', 'scheme': 'about', 'host': None, 'port': None, ...}
Stop result: True
```

The full lifecycle (install check -> process start -> CDP connect -> page creation -> JS evaluation -> page close -> process stop) works.

**Status: SUCCESS (with `--no-sandbox` workaround)**

### Experiment 13: OSBot `Playwright_Process` Healthcheck

**Command:**
```python
proc = Playwright_Process(browser_path='...', headless=True, debug_port=9999)
print(proc.config())
print(proc.healthcheck())
```

**Result:**
```
Config: {'debug_port': 9999, 'path_data_folder': '/tmp/playwright_chrome_data_folder_in_port__9999', ...}
Healthcheck: {'healthy': False, 'chromium_process_exists': False, ...}
```

**Status: SUCCESS** -- Healthcheck correctly reports unhealthy when no process is running.

### Experiment 14: OSBot `Html_Parser` (Standalone)

**Command:**
```python
from osbot_playwright.html_parser.Html_Parser import Html_Parser
parser = Html_Parser('<html>...<h1>Title</h1><p class="summary">...</p>...')
```

**Result:** All methods work perfectly:
- `title()` -> 'Test Document'
- `paragraphs()` -> ['First paragraph...', 'Second paragraph.']
- `hrefs__values()` -> ['https://example.com', 'https://google.com']
- `tag__text('h1')` -> 'Main Title'
- `class__text('content')` -> 'Some content here'
- `id__text('link1')` -> 'Example Link'
- `img_src('logo')` -> '/images/logo.png'
- `options()` -> [{'value': 'opt1', 'text': 'Option 1'}, ...]
- `tags__stats()` -> {'html': 1, 'head': 1, 'body': 1, 'h1': 1, 'p': 2, ...}

**Status: SUCCESS** -- Fully functional standalone HTML parser.

### Experiment 15: OSBot `Playwright_Requests`

**Command:**
```python
reqs = Playwright_Requests()
reqs.requests = [{'url': 'https://example.com', 'method': 'GET'}]
reqs.save_to('/tmp/test_requests.json')
reqs2 = Playwright_Requests()
reqs2.load_from('/tmp/test_requests.json')
```

**Result:** Save/load serialization works correctly.

**Status: SUCCESS**

### Experiment 16: OSBot `Playwright_Page` Wrapper

**Result:**
- `Playwright_Page.__repr__()` -> `[Playwright_Page]: about:blank`
- `title()`, `url()`, `url_info()`, `is_closed()`, `close()` all work
- `html_raw()` works on unmodified pages (returns `page.content()`)
- `html()` returns `Html_Parser` instance
- `html_info()` and `info()` work on unmodified pages
- After DOM modification (innerHTML), `html_raw()` / `page.content()` hangs (sandbox limitation)

**Status: PARTIAL** -- Core wrapper works, but content extraction hangs after DOM modification due to environment.

### Experiment 17: Multiple Contexts and Pages

**Command:**
```python
ctx1 = browser.new_context()
ctx2 = browser.new_context()
page1 = ctx1.new_page()
page2 = ctx1.new_page()
page3 = ctx2.new_page()
```

**Result:** Successfully created 2 contexts with 3 total pages. Each page independently manages state (title, URL).

**Status: SUCCESS**

### Experiment 18: FastAPI Routes Import

**Command:**
```python
from osbot_playwright.playwright.fastapi.Routes__Playwright import Routes__Playwright
```

**Result:**
```
ModuleNotFoundError: No module named 'osbot_fast_api'
```

The FastAPI routes depend on `osbot-fast-api` which is not declared in the pyproject.toml dependencies and was not installed.

**Status: FAILED** -- Missing dependency. `osbot-fast-api` is an optional dependency not declared in the package metadata.

---

## 4. Summary: What Worked vs. What Did Not

### What Worked

| Feature | Notes |
|---------|-------|
| Package installation from PyPI | v0.6.10 installs cleanly |
| `Playwright_CLI` | Version, install detection, browser details |
| `Playwright_Install` | Browser discovery and detail caching |
| `Playwright_Browser__Chrome` | Full lifecycle (with `--no-sandbox` patch) |
| `Playwright_Process` | Start, stop, healthcheck, process persistence |
| `Playwright_Page` wrapper | Basic URL/title/close operations |
| `Html_Parser` | Full HTML parsing (standalone, no browser needed) |
| `Playwright_Requests` | Save/load serialization |
| Direct Playwright API | Launch, evaluate JS, page.title(), page.content() (blank pages) |
| Multiple contexts/pages | Isolation and independent state management |

### What Did Not Work

| Feature | Reason |
|---------|--------|
| External URL navigation | Sandbox egress proxy blocks most domains |
| Screenshots | Chromium `Page.captureScreenshot` protocol error in sandbox |
| PDF generation | Chromium `Page.printToPDF` fails in sandbox |
| `page.set_content()` | Hangs in this environment |
| `page.content()` after DOM modification | Hangs -- appears to be a rendering/layout issue in the sandbox |
| FastAPI routes | Missing `osbot-fast-api` dependency |
| `Playwright_Process` without `--no-sandbox` | Chrome refuses to run as root without this flag |

### Environment-Specific vs. Code Issues

| Issue | Environment or Code? |
|-------|---------------------|
| Browser download blocked (403) | Environment (egress proxy) |
| `--no-sandbox` required | Environment (running as root) |
| Screenshot/PDF failure | Environment (no GPU, limited rendering) |
| `set_content()` / `content()` hangs | Environment (likely rendering subsystem) |
| Browser path mismatch | **Code** -- OSBot uses custom path; requires browsers at `/tmp/osbot_playwright_browsers/` |
| Missing `osbot-fast-api` | **Code** -- Undeclared optional dependency |
| No `--no-sandbox` in `Playwright_Process` | **Code** -- Should be configurable |

---

## 5. Issues Found

### Issue 1: Missing `--no-sandbox` Support in `Playwright_Process`

`Playwright_Process.start_process()` hardcodes the Chrome launch arguments without a way to add `--no-sandbox`. When running as root (common in Docker/Lambda), Chrome refuses to start.

**Location:** `osbot_playwright/playwright/api/Playwright_Process.py`, line ~148

**Recommendation:** Add a `chrome_args` parameter or a `no_sandbox` flag to `Playwright_Process.__init__()`.

### Issue 2: Undeclared Optional Dependency `osbot-fast-api`

The FastAPI routes (`Routes__Playwright`, `Fast_API_Playwright`) import from `osbot_fast_api` at module level, but this package is not listed in `pyproject.toml` dependencies.

**Impact:** Importing `osbot_playwright.playwright.fastapi` raises `ModuleNotFoundError`.

**Recommendation:** Either add `osbot-fast-api` as an optional dependency (`[tool.poetry.extras]`) or use lazy imports.

### Issue 3: Custom Browser Path Creates Friction

`Playwright_CLI` sets `PLAYWRIGHT_BROWSERS_PATH` to `/tmp/osbot_playwright_browsers/` which differs from Playwright's default `~/.cache/ms-playwright/`. Users who install browsers via `playwright install` must either:
- Set the env var before installing
- Create symlinks
- Re-install browsers

### Issue 4: No Type_Safe Integration

Unlike other owasp-sbot projects, OSBot-Playwright does not use `Type_Safe` base classes. This is inconsistent with the ecosystem's conventions.

### Issue 5: Typo in Attribute Name

`Playwright_Install.__init__()` has `self.playwrtight_cli` (misspelling of "playwright").

---

## 6. Recommendations for Issues-FS Ecosystem

### Potential Use Cases

1. **Web UI Testing** -- OSBot-Playwright could be used by the QA role to automate testing of `Issues-FS__Service__UI`. The `Html_Parser` is particularly useful for content verification without needing a full browser.

2. **Documentation Screenshots** -- Automated screenshot capture of the Issues-FS web UI for documentation (when running in a proper environment with rendering support).

3. **HTML Report Generation** -- The `Playwright_Page` + `Html_Parser` combination could generate and parse HTML reports of issue graphs.

4. **Standalone Html_Parser** -- The `Html_Parser` class is useful independently of Playwright for parsing any HTML content. It could be used in Issues-FS services for processing web content.

### Integration Considerations

1. **Type_Safe migration needed** -- To fit the Issues-FS ecosystem, OSBot-Playwright classes should be migrated to use `Type_Safe` base classes with `Safe_*` primitives.

2. **Version pinning** -- Playwright library and browser versions must be carefully matched. The pyproject.toml uses `playwright = "*"` which can cause version drift. Pin to a specific version.

3. **Docker-first approach** -- Given the browser installation complexity, using the Docker image (`osbot_playwright/docker/`) is the most reliable deployment method.

4. **Browser installation in CI/CD** -- The DevOps role should ensure Playwright browsers are pre-installed in CI/CD images and the `PLAYWRIGHT_BROWSERS_PATH` environment variable is set correctly.

5. **FastAPI integration** -- The `Routes__Playwright` class provides a model for how browser-as-a-service could work within the Issues-FS service architecture, but requires `osbot-fast-api` and careful security review (the `/playwright/code` endpoint executes arbitrary code).

### Security Concerns (AppSec)

1. **Code execution endpoint** -- `Routes__Playwright.code()` executes arbitrary Python code passed via HTTP POST. Even with auth key protection, this is a significant attack surface.

2. **`--no-sandbox` flag** -- Running Chrome without sandbox is required in many container environments but reduces security isolation.

3. **Browser data persistence** -- `Playwright_Process` persists browser data folders in `/tmp/`, which may contain session data, cookies, or cached content.

---

## 7. Raw Experiment Outputs

### Installed Package Versions

```
osbot-playwright==0.6.10
playwright==1.56.0 (downgraded from 1.58.0)
osbot-utils==3.72.0
beautifulsoup4==4.14.3
fastapi==0.128.6
psutil==7.2.2
Chromium: 141.0.7390.37 (revision 1194)
Python: 3.11.14
```

### Playwright CLI `--dry-run` Output

```
browser: chromium version 141.0.7390.37
  Install location:    /root/.cache/ms-playwright/chromium-1194
  Download url:        https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/1194/chromium-linux.zip

browser: chromium-headless-shell version 141.0.7390.37
  Install location:    /root/.cache/ms-playwright/chromium_headless_shell-1194
```

### OSBot Browser Details JSON

```json
{
  "chromium": {
    "download_url": "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/1194/chromium-linux.zip",
    "executable_path": "/tmp/osbot_playwright_browsers/chromium-1194/chrome-linux/chrome",
    "install_location": "/tmp/osbot_playwright_browsers/chromium-1194",
    "installed": true,
    "version": null
  },
  "firefox": {
    "installed": false
  },
  "webkit": {
    "installed": false
  }
}
```

### `Playwright_Browser__Chrome` Full Lifecycle (with patch)

```
Debug port: 51627
Browser exec path: /tmp/osbot_playwright_browsers/chromium-1194/chrome-linux/chrome
DevTools listening on ws://127.0.0.1:51627/devtools/browser/0aa51eb4-...
Browser started: 141.0.7390.37
Page URL: about:blank
User agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/141.0.0.0 Safari/537.36
URL info: {'raw': 'about:blank', 'scheme': 'about', 'host': None, 'port': None, 'path': 'blank', ...}
Page closed
Stopped: True
```

---

## 8. Conclusion

OSBot-Playwright is a functional wrapper around Microsoft Playwright that adds browser process management, HTML parsing, and REST API capabilities. In this sandboxed environment, core browser operations (launch, evaluate JS, page lifecycle) work correctly, while rendering-dependent features (screenshots, PDF, set_content) are limited by the container environment.

The `Html_Parser` class is the most immediately useful component -- it works standalone without any browser and provides a comprehensive HTML parsing API.

For Issues-FS integration, the main barriers are:
1. No `Type_Safe` adoption (ecosystem inconsistency)
2. Browser installation complexity (version matching, custom paths)
3. Missing dependency declarations (`osbot-fast-api`)
4. Security concerns around the code execution endpoint

The package is most valuable in Docker/Lambda environments where browsers can be pre-installed and the rendering subsystem is fully available.
