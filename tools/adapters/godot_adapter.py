"""Godot adapter — wraps Godot CLI operations for CLI-Anything."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

from tools.adapters.base_adapter import BaseAdapter

# ── Constants ───────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(r"C:\Users\PGNK2128\Godot-MCP")

_GODOT_CANDIDATES = [
    Path(r"C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64_console.exe"),
    Path(r"C:\Users\PGNK2128\AppData\Local\Programs\Godot\Godot.exe"),
    Path(r"C:\Users\PGNK2128\AppData\Local\Programs\Godot\godot.exe"),
    "godot4",
    "godot",
]

_ERROR_PATTERNS = [
    re.compile(r"\bERROR\b", re.IGNORECASE),
    re.compile(r"\bSCRIPT ERROR\b", re.IGNORECASE),
]
_WARNING_PATTERNS = [
    re.compile(r"\bWARNING\b", re.IGNORECASE),
    re.compile(r"\bWARN\b"),
]
# Noise patterns filtered BEFORE classification. The Godot editor at headless
# parse time recursively scans the project root and emits ERROR-level lines
# for any non-Godot subfolder it encounters (node_modules under
# tools/octogent/, etc.). These are filesystem-scan complaints, not script
# errors — filtering them prevents false-positive gate failures that pause
# the autonomous loop. Keep this list narrow; if a real script error happens
# to phrase-match, prefer suppressing it elsewhere.
_NOISE_PATTERNS = [
    re.compile(r"Cannot go into subdir '"),                       # editor recursive scan
    re.compile(r"\.import.*not found.*tools/"),                    # asset import cache misses (tools/ only — narrowed per C45 code review HIGH)
    re.compile(r"Failed to load script .*\.js"),                   # node_modules .js files
    re.compile(r"buffer error: Stream ends prematurely"),          # editor proj resource parse
]

# Windows user-data directory for Godot save files (app_userdata/<app_name>)
_GODOT_APPDATA = Path(os.environ.get("APPDATA", ""), "Godot", "app_userdata")


# ── Helpers ─────────────────────────────────────────────────────────────────


def _find_godot() -> str | None:
    """Return the first usable Godot executable path, or None."""
    import shutil

    for candidate in _GODOT_CANDIDATES:
        path = str(candidate)
        if isinstance(candidate, Path):
            if candidate.exists():
                return path
        else:
            resolved = shutil.which(path)
            if resolved:
                return resolved
    return None


def _run(cmd: list[str], timeout: int = 120, env: dict | None = None) -> tuple[str, str, int]:
    """Run a subprocess, return (stdout, stderr, returncode). Optional env overlay."""
    full_env: dict | None = None
    if env:
        full_env = os.environ.copy()
        full_env.update(env)
    result = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
        env=full_env,
    )
    return result.stdout, result.stderr, result.returncode


def _classify_output(text: str) -> dict[str, list[str]]:
    """Parse combined stdout/stderr for errors and warnings.

    Noise lines (filesystem scan complaints, asset cache misses) are skipped
    BEFORE classification — see `_NOISE_PATTERNS` for rationale.
    """
    errors: list[str] = []
    warnings: list[str] = []
    for line in text.splitlines():
        if any(p.search(line) for p in _NOISE_PATTERNS):
            continue
        if any(p.search(line) for p in _ERROR_PATTERNS):
            errors.append(line.strip())
        elif any(p.search(line) for p in _WARNING_PATTERNS):
            warnings.append(line.strip())
    return {"errors": errors, "warnings": warnings}


def _read_project_version() -> str:
    """Extract the application version string from project.godot."""
    project_file = PROJECT_ROOT / "project.godot"
    if not project_file.exists():
        return "unknown"
    try:
        content = project_file.read_text(encoding="utf-8")
        match = re.search(r'config/version\s*=\s*"([^"]+)"', content)
        if match:
            return match.group(1)
        # Fallback: use config_version (engine version field)
        match = re.search(r"config_version\s*=\s*(\d+)", content)
        if match:
            return f"v{match.group(1)}"
    except OSError:
        pass
    return "unknown"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _parse_export_presets() -> list[dict[str, str]]:
    """Parse export_presets.cfg and return list of preset dicts."""
    cfg_path = PROJECT_ROOT / "export_presets.cfg"
    if not cfg_path.exists():
        return []

    presets: list[dict[str, str]] = []
    content = cfg_path.read_text(encoding="utf-8")

    # Sections are named [preset.N] with key=value pairs following
    section_pattern = re.compile(r"\[preset\.(\d+)\]")
    current: dict[str, str] = {}
    for line in content.splitlines():
        line = line.strip()
        if section_pattern.match(line):
            if current:
                presets.append(current)
            current = {}
        else:
            kv = re.match(r'^(\w+)\s*=\s*"?([^"]*)"?$', line)
            if kv:
                current[kv.group(1)] = kv.group(2)
    if current:
        presets.append(current)
    return presets


# ── Adapter ─────────────────────────────────────────────────────────────────


class GodotAdapter(BaseAdapter):
    """Adapter for Godot 4.x CLI operations."""

    def __init__(self) -> None:
        super().__init__("godot")
        self._godot_bin: str | None = _find_godot()

    # ── BaseAdapter interface ────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            "validate": "Run validate.bat — full project validation pipeline",
            "validate_step0": "Run Godot editor headless parse check only",
            "smoke": "Smoke-test a specific scene (requires scene= kwarg)",
            "verify_all": "FORGE: parse-check + smoke ALL scenes/*.tscn, write JSON report (one-shot autonomy verify)",
            "test": "Run headless test suite via res://tests/headless_runner.tscn",
            "export": "Export project for a named preset (requires preset= kwarg)",
            "telemetry": "Aggregate JSON stats from Godot user:// save files",
            "list_presets": "List available export presets from export_presets.cfg",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        match action:
            case "validate":
                return self._validate()
            case "validate_step0":
                return self._validate_step0()
            case "smoke":
                return self._smoke(**kwargs)
            case "verify_all":
                return self._verify_all(**kwargs)
            case "test":
                return self._test()
            case "export":
                return self._export(**kwargs)
            case "telemetry":
                return self._telemetry()
            case "list_presets":
                return self._list_presets()
            case _:
                raise NotImplementedError(action)

    # ── Actions ─────────────────────────────────────────────────────────────

    def _validate(self) -> dict:
        """Run validate.bat and parse its output."""
        self.log("Running validate.bat …")
        try:
            stdout, stderr, code = _run(
                ["cmd", "/c", str(PROJECT_ROOT / "validate.bat")],
                timeout=300,
            )
        except subprocess.TimeoutExpired:
            return self.error("validate.bat timed out after 300s")
        except OSError as exc:
            return self.error(f"Failed to launch validate.bat: {exc}")

        combined = stdout + "\n" + stderr
        classified = _classify_output(combined)
        self.log(
            f"validate.bat exit={code} | errors={len(classified['errors'])} "
            f"warnings={len(classified['warnings'])}"
        )
        return self.ok(
            {
                "exit_code": code,
                "passed": code == 0 and not classified["errors"],
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _validate_step0(self) -> dict:
        """Run the Godot editor headless parse check (Step 0 equivalent)."""
        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        self.log("Running editor parse check (--editor --headless --quit) …")
        try:
            stdout, stderr, code = _run(
                [godot, "--editor", "--headless", "--quit"],
                timeout=300,
            )
        except subprocess.TimeoutExpired:
            return self.error("Editor parse check timed out after 120s")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        combined = stdout + "\n" + stderr
        classified = _classify_output(combined)
        self.log(
            f"step0 exit={code} | errors={len(classified['errors'])} "
            f"warnings={len(classified['warnings'])}"
        )
        return self.ok(
            {
                "exit_code": code,
                "passed": code == 0 and not classified["errors"],
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _smoke(self, scene: str = "", duration: str = "10", capture: str = "", capture_interval: str = "200", **_kwargs: Any) -> dict:
        """Smoke-test a scene by running it (windowed) for N seconds and grepping for runtime errors.

        Headless mode skips _ready/_process for many engine subsystems (3D rendering, input,
        audio), so SCRIPT ERROR from those paths are NOT caught. We launch with a normal display
        but `--quit-after` to bound the run. The scene is passed as a positional arg
        (Godot 4 ignores --scene-path).

        Optional --capture <dir> records frames every <capture-interval> ms (default 200) via
        the CaptureRecorder autoload. Frames saved as frame_NNNN.png in <dir>.
        """
        if not scene:
            return self.error("smoke action requires scene= kwarg (e.g. scene='res://scenes/MerlinGame.tscn')")

        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        try:
            quit_after = max(2, int(duration))
        except (TypeError, ValueError):
            quit_after = 10

        timeout_s = quit_after + 30  # generous buffer for project loading
        # Capture mode: gate the CaptureRecorder autoload via env vars.
        capture_env: dict | None = None
        capture_dir_resolved: str = ""
        if capture:
            capture_dir_resolved = str((PROJECT_ROOT / capture).resolve()) if not Path(capture).is_absolute() else capture
            Path(capture_dir_resolved).mkdir(parents=True, exist_ok=True)
            try:
                cap_int_ms = max(50, int(capture_interval))
            except (TypeError, ValueError):
                cap_int_ms = 200
            max_frames = max(1, int((quit_after * 1000) / cap_int_ms) + 5)
            capture_env = {
                "MERLIN_CAPTURE_DIR": capture_dir_resolved,
                "MERLIN_CAPTURE_INTERVAL_MS": str(cap_int_ms),
                "MERLIN_CAPTURE_MAX_FRAMES": str(max_frames),
            }
            self.log(f"Capture: dir={capture_dir_resolved} interval={cap_int_ms}ms max_frames={max_frames}")
        self.log(f"Smoke-testing scene '{scene}' for {quit_after}s (timeout {timeout_s}s)")
        try:
            stdout, stderr, code = _run(
                [godot, "--path", str(PROJECT_ROOT), "--quit-after", str(quit_after), scene],
                timeout=timeout_s,
                env=capture_env,
            )
        except subprocess.TimeoutExpired:
            return self.error(f"Smoke test for '{scene}' timed out after {timeout_s}s — likely hang in _ready")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        combined = stdout + "\n" + stderr
        classified = _classify_output(combined)
        # Runtime-only signal: SCRIPT ERROR is what crashes a play session (parse errors are caught
        # by validate_step0). We surface them separately.
        script_errors = [e for e in classified["errors"] if "SCRIPT ERROR" in e or "Identifier" in e or "not declared" in e]
        passed = code == 0 and not script_errors
        self.log(
            f"smoke exit={code} | script_errors={len(script_errors)} "
            f"total_errors={len(classified['errors'])} warnings={len(classified['warnings'])} "
            f"passed={passed}"
        )
        result_data: dict = {
            "scene": scene,
            "duration_s": quit_after,
            "exit_code": code,
            "passed": passed,
            "script_errors": script_errors,
            "errors": classified["errors"],
            "warnings": classified["warnings"][:20],  # cap noise
            "stdout_tail": "\n".join(stdout.splitlines()[-50:]),
            "stderr_tail": "\n".join(stderr.splitlines()[-50:]),
        }
        if capture and capture_dir_resolved:
            captured = sorted(Path(capture_dir_resolved).glob("frame_*.png"))
            result_data["capture_dir"] = capture_dir_resolved
            result_data["capture_frames"] = len(captured)
            result_data["capture_first"] = str(captured[0]) if captured else ""
            result_data["capture_last"] = str(captured[-1]) if captured else ""
        return self.ok(result_data)

    def _verify_all(
        self,
        scenes_dir: str = "scenes",
        duration: str = "5",
        capture: str = "true",
        strict: str = "false",
        **_kwargs: Any,
    ) -> dict:
        """FORGE one-shot autonomy verification.

        Flow:
          1. validate_step0 (editor headless parse-check on every script)
          2. enumerate scenes_dir/*.tscn (default `scenes/`)
          3. _smoke each scene for `duration` seconds (default 5)
             [C47] If capture=true (default), each scene also drops PNG frames
             via the CaptureRecorder autoload. Last frame = visual baseline.
          4. write JSON report to .octogent/tentacles/godot_runtime/last_verify.json
          5. return aggregated PASS/FAIL

        Args:
          scenes_dir: relative dir under PROJECT_ROOT to scan for *.tscn.
          duration:   per-scene smoke window in seconds.
          capture:    "true"/"false" — toggle PNG capture during smoke.
                      Defaults true; set "false" for fast no-baseline checks.
          strict:     [C50] "true"/"false" — enforce ZERO-WARNING BAR.
                      When true, the run FAILS if ANY warnings are detected
                      (step0 OR any scene smoke), regardless of error/script
                      error status. This adds a quality dimension on top of
                      the legacy errors-only gate: clean output is required
                      before merge. Default "false" preserves the existing
                      behavior so legacy callers see no change.

        Used by:
          - Manual: `python tools/cli.py godot verify_all`
          - Watchdog: periodic call from director-watchdog.sh
          - Workers: spawned godot_runtime tentacle workers
        """
        from datetime import datetime, timezone
        import json as _json

        self.log(
            f"verify_all: scenes_dir='{scenes_dir}' duration={duration}s "
            f"capture={capture} strict={strict}"
        )

        capture_enabled = str(capture).lower() in ("true", "1", "yes", "on")
        # [C50] When strict mode is on, we also gate on warnings — see
        # aggregation block below. Surfaced into the JSON report as
        # `strict_mode` so consumers can tell which gate produced the verdict.
        strict_enabled = str(strict).lower() in ("true", "1", "yes", "on")

        # Step 1: parse-check
        step0 = self._validate_step0()
        step0_ok = step0.get("status") == "ok"
        step0_data = step0.get("data", {}) if step0_ok else {}
        step0_passed = bool(step0_data.get("passed"))
        # [C50] Count step0 warnings for the strict gate. `_validate_step0`
        # already exposes `data["warnings"]` as a list[str].
        step0_warnings_count = len(step0_data.get("warnings", []) or [])

        # Step 2: enumerate scenes (top-level .tscn only — subfolders excluded by design;
        # main playable scenes live in scenes/)
        scenes_root = PROJECT_ROOT / scenes_dir
        scene_paths = sorted(scenes_root.glob("*.tscn")) if scenes_root.exists() else []
        scene_results: list[dict] = []
        scenes_passed = 0
        scenes_failed = 0

        # [C47] Build a unique capture root per verify_all run so successive runs
        # don't overwrite each other. Uses ISO-UTC stripped of colons for FS safety.
        # Lives under the godot_runtime tentacle so the UI can find baselines.
        capture_root: Path | None = None
        if capture_enabled and scene_paths:
            ts_safe = (
                datetime.now(timezone.utc)
                .isoformat()
                .replace(":", "-")
                .replace(".", "-")
            )
            capture_root = (
                PROJECT_ROOT
                / "tools"
                / "octogent"
                / ".octogent"
                / "tentacles"
                / "godot_runtime"
                / "captures"
                / ts_safe
            )
            capture_root.mkdir(parents=True, exist_ok=True)
            self.log(f"verify_all: capture_root={capture_root}")

        # Step 3: smoke each scene
        for sp in scene_paths:
            rel = sp.relative_to(PROJECT_ROOT).as_posix()
            res_uri = f"res://{rel}"
            self.log(f"verify_all: smoking {res_uri}")

            # [C47] Per-scene capture dir + interval ≈ duration*1000ms
            # → CaptureRecorder fires ~1-2 frames; we keep the LAST one as the
            # baseline (last_frame is what the player sees at end of smoke).
            smoke_kwargs: dict = {"scene": res_uri, "duration": duration}
            if capture_root is not None:
                scene_stem = sp.stem  # e.g. "MerlinGame"
                scene_capture_dir = capture_root / scene_stem
                smoke_kwargs["capture"] = str(scene_capture_dir)
                # Cap interval at half-duration so we get at least 1 frame even
                # on shorter smokes; floor at 1000ms.
                try:
                    cap_interval = max(1000, (int(duration) * 1000) // 2)
                except (TypeError, ValueError):
                    cap_interval = 2500
                smoke_kwargs["capture_interval"] = str(cap_interval)

            r = self._smoke(**smoke_kwargs)
            data = r.get("data", {}) if isinstance(r, dict) else {}
            passed = bool(data.get("passed"))

            # [C47] Resolve capture_path — prefer the LAST frame for end-of-scene
            # state; fall back to first if last missing; empty if capture failed.
            capture_path = ""
            if capture_root is not None:
                last_frame = data.get("capture_last") or data.get("capture_first") or ""
                if last_frame:
                    try:
                        # Store as repo-relative POSIX path for portability.
                        capture_path = (
                            Path(last_frame).resolve().relative_to(PROJECT_ROOT).as_posix()
                        )
                    except (ValueError, OSError):
                        capture_path = last_frame  # absolute fallback

            # [C50] Surface warnings_count from underlying _smoke data so the
            # strict gate can aggregate without re-parsing stdout. _smoke caps
            # the warnings list at 20 entries (noise control), so we count the
            # raw list length here — adequate for go/no-go decisions.
            scene_warnings_count = len(data.get("warnings", []) or [])
            scene_results.append(
                {
                    "scene": res_uri,
                    "passed": passed,
                    "duration_s": data.get("duration_s"),
                    "exit_code": data.get("exit_code"),
                    "script_errors": data.get("script_errors", []),
                    "warnings_count": scene_warnings_count,
                    "capture_path": capture_path,
                    "capture_frames": data.get("capture_frames", 0),
                }
            )
            if passed:
                scenes_passed += 1
            else:
                scenes_failed += 1

        # Step 4: write report
        all_passed = step0_passed and scenes_failed == 0 and len(scene_paths) > 0
        # [C50] ZERO-WARNING BAR — strict gate applied AFTER the legacy gate.
        # Sum scene warnings independently so report consumers (UI, logs) see
        # the breakdown even when not in strict mode.
        scenes_warnings_total = sum(s["warnings_count"] for s in scene_results)
        if strict_enabled:
            all_passed = (
                all_passed
                and step0_warnings_count == 0
                and scenes_warnings_total == 0
            )
        report = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "passed": all_passed,
            "strict_mode": strict_enabled,
            "step0_passed": step0_passed,
            "step0_warnings_count": step0_warnings_count,
            "scenes_total": len(scene_paths),
            "scenes_passed": scenes_passed,
            "scenes_failed": scenes_failed,
            "scenes_warnings_total": scenes_warnings_total,
            "scenes": scene_results,
            "scenes_dir": scenes_dir,
        }
        # Distinguish "no scenes found" (misconfigured path) from "scenes failed"
        # — both yield passed=False but consumers must respond differently.
        # (per C45 code-review MEDIUM)
        if not scene_paths:
            report["no_scenes_found"] = True
            report["error_hint"] = (
                f"scenes_dir '{scenes_dir}' contains no .tscn files — "
                f"check the path or the scenes_dir kwarg."
            )
        report_dir = PROJECT_ROOT / "tools" / "octogent" / ".octogent" / "tentacles" / "godot_runtime"
        report_dir.mkdir(parents=True, exist_ok=True)
        report_path = report_dir / "last_verify.json"
        try:
            report_path.write_text(_json.dumps(report, indent=2), encoding="utf-8")
        except OSError as exc:
            self.log(f"verify_all: WARN failed to write report: {exc}")

        self.log(
            f"verify_all: passed={all_passed} strict={strict_enabled} "
            f"step0={step0_passed} (warns={step0_warnings_count}) "
            f"scenes={scenes_passed}/{len(scene_paths)} "
            f"(warns={scenes_warnings_total}) report={report_path}"
        )
        return self.ok(
            {
                **report,
                "report_path": str(report_path),
                "step0_summary": {
                    "exit_code": step0.get("data", {}).get("exit_code"),
                    "errors": step0.get("data", {}).get("errors", [])[:5],
                }
                if step0_ok
                else step0,
            }
        )

    def _test(self) -> dict:
        """Run the headless test suite and parse JSON output."""
        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        runner_script = "res://tests/headless_runner.gd"
        self.log(f"Running test suite via {runner_script} …")
        try:
            stdout, stderr, code = _run(
                [godot, "--headless", "--quit-after", "60", "--script", runner_script],
                timeout=90,
            )
        except subprocess.TimeoutExpired:
            return self.error("Test run timed out after 90s")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        # Attempt to extract JSON block from stdout
        test_results: dict | None = None
        json_match = re.search(r"(\{.*\"total\".*\})", stdout, re.DOTALL)
        if json_match:
            try:
                test_results = json.loads(json_match.group(1))
            except json.JSONDecodeError as exc:
                self.log(f"Warning: could not parse test JSON: {exc}")

        classified = _classify_output(stdout + "\n" + stderr)
        passed_overall = (
            code == 0
            and not classified["errors"]
            and (test_results is None or test_results.get("failed") == [])
        )
        return self.ok(
            {
                "exit_code": code,
                "passed": passed_overall,
                "test_results": test_results,
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _export(self, preset: str = "", **_kwargs: Any) -> dict:
        """Export project for the given preset name."""
        if not preset:
            return self.error("export action requires preset= kwarg")

        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        version = _read_project_version()
        output_dir = PROJECT_ROOT / "builds" / preset / version
        output_dir.mkdir(parents=True, exist_ok=True)

        # Determine extension based on preset name heuristic
        ext_map = {
            "windows": ".exe",
            "win": ".exe",
            "linux": ".x86_64",
            "mac": ".app",
            "web": ".html",
            "android": ".apk",
        }
        ext = next(
            (v for k, v in ext_map.items() if k in preset.lower()),
            ".bin",
        )
        output_path = output_dir / f"game{ext}"

        self.log(f"Exporting preset '{preset}' → {output_path}")
        try:
            stdout, stderr, code = _run(
                [godot, "--export-release", preset, str(output_path)],
                timeout=300,
            )
        except subprocess.TimeoutExpired:
            return self.error(f"Export of '{preset}' timed out after 300s")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        size_bytes: int | None = None
        sha256: str | None = None
        if output_path.exists():
            size_bytes = output_path.stat().st_size
            sha256 = _sha256(output_path)
            self.log(f"Output: {output_path} ({size_bytes} bytes, sha256={sha256[:12]}…)")
        else:
            self.log("Warning: output file not found after export")

        classified = _classify_output(stdout + "\n" + stderr)
        return self.ok(
            {
                "preset": preset,
                "version": version,
                "output_path": str(output_path),
                "exit_code": code,
                "passed": code == 0 and output_path.exists(),
                "size_bytes": size_bytes,
                "sha256": sha256,
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _telemetry(self) -> dict:
        """Read and aggregate JSON stats from Godot user:// save files."""
        # Determine app name from project.godot
        project_file = PROJECT_ROOT / "project.godot"
        app_name = "DRU"  # default from project.godot config/name
        if project_file.exists():
            content = project_file.read_text(encoding="utf-8")
            match = re.search(r'config/name\s*=\s*"([^"]+)"', content)
            if match:
                app_name = match.group(1)

        userdata_dir = _GODOT_APPDATA / app_name
        self.log(f"Reading save files from: {userdata_dir}")

        if not userdata_dir.exists():
            return self.ok(
                {
                    "userdata_dir": str(userdata_dir),
                    "files_found": 0,
                    "stats": {},
                    "note": "Directory does not exist — no save data found",
                }
            )

        json_files = list(userdata_dir.glob("*.json"))
        stats: dict[str, Any] = {}
        parse_errors: list[str] = []

        for f in json_files:
            try:
                # Try utf-8-sig first (handles BOM), then utf-8
                try:
                    text = f.read_text(encoding="utf-8-sig")
                except UnicodeDecodeError:
                    text = f.read_text(encoding="utf-8", errors="replace")
                data = json.loads(text)
                stats[f.name] = data
            except (json.JSONDecodeError, OSError) as exc:
                parse_errors.append(f"{f.name}: {exc}")
                self.log(f"Warning: could not parse {f.name}: {exc}")

        self.log(f"Found {len(json_files)} JSON save file(s), {len(parse_errors)} parse error(s)")
        return self.ok(
            {
                "userdata_dir": str(userdata_dir),
                "files_found": len(json_files),
                "stats": stats,
                "parse_errors": parse_errors,
            }
        )

    def _list_presets(self) -> dict:
        """List export preset names from export_presets.cfg."""
        presets = _parse_export_presets()
        names = [p.get("name", f"preset_{i}") for i, p in enumerate(presets)]
        self.log(f"Found {len(names)} export preset(s): {names}")
        return self.ok(
            {
                "presets": names,
                "details": presets,
                "cfg_path": str(PROJECT_ROOT / "export_presets.cfg"),
                "cfg_exists": (PROJECT_ROOT / "export_presets.cfg").exists(),
            }
        )

    # ── Internal helpers ─────────────────────────────────────────────────────

    def _require_godot(self) -> str | dict:
        """Return godot binary path or an error dict if not found."""
        if self._godot_bin is None:
            self._godot_bin = _find_godot()
        if self._godot_bin is None:
            searched = ", ".join(str(c) for c in _GODOT_CANDIDATES)
            return self.error(
                f"Godot binary not found. Searched: {searched}. "
                "Install Godot 4 and ensure it is in PATH."
            )
        return self._godot_bin
