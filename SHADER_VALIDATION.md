# Shader Validation Workflow

## Establish the baseline

- Read the relevant pipeline README and inspect its actual preset/include chain before editing. Production `handheld/shaders/pixel_transparency/` (integrated grids), the former external-LCD production `v2.4-external-lcd`, and universal `v2.4-live-grid` are distinct pipelines; name which one is under test.
- Freeze the working baseline before changing shared includes. Two presets pointing at the same edited include are not a before/after comparison. Snapshot sources and dependencies, or expand the original shaders into owned temporary files inside the repo.
- Resolve each inherited shader, include and texture path relative to the file that declares it. A texture inherited through `#reference` must not be resolved relative to the child preset.
- Save preset contents, source/dependency hashes and parameter values with the evidence. Invalidate cached captures whenever any input changes; archive superseded runs instead of silently reusing them.

## Choose checks that match the change

- For path-only renames, expand all affected include chains and compare compiler inputs before/after. Exact equality plus valid preset dependencies is sufficient; do not rerun device benchmarks for a rename.
- For source restructuring, compile affected vertex/fragment stages, including sensor-enabled and sensor-disabled variants, and validate SPIR-V. Compare binaries when claiming a purely structural change preserves generated code.
- For shader math or controls, compilation is only the first check. Capture actual rendering at unchanged defaults and at the new control's endpoints. Preserve existing parameter IDs, defaults, ranges and steps; distinguish display-label edits from changed behaviour.
- Cover every affected grid family and both Pixel Transparency/Sunlight Shimmer when their shared code changes. Exercise both Above/Below placements; verify that changing placement actually changes the output. Include GB/GBC and GBA, fit/integer scaling, subpixels and shadow modes where the changed code depends on them. Keep the matrix bounded by the change rather than repeating every historical test.
- Check default-preserving changes pixel-for-pixel. Report maximum/mean absolute RGB error and changed-pixel counts; repeat a representative pair to establish determinism if a discrepancy appears. Algebraically equivalent shader edits can change rounding through compiler optimisation. Do not call a 1/255 difference identical or assume a visible difference is a regression without inspecting it.

## Capture discipline

- Keep screenshots, logs, manifests, compiled shaders and comparison pages in a fresh folder under `/Volumes/Ensemble/Screenshots/Reviews/`, outside the checkout. Keep only temporary render presets/shaders inside the repo, then remove or archive the files owned by this test.
- On macOS, launch with `open -g -W -n -a /Applications/RetroArch.app --args ...` to keep the run in the background. Do not use `-j`: hidden launches stalled frame advancement in this workflow. For Mario Tennis gameplay captures, use save slot 9 unless another state is requested.
- Run captures and benchmarks serially; do not compete with another RetroArch session or terminate an unrelated session. Use isolated config/save/state/cache directories, disable config saving and automatic state changes, and disable shader auto-loading/watching that could replace the requested preset.
- Use `--max-frames 10 --max-frames-ss --max-frames-ss-path <absolute-png-path>` for the established fixed-frame captures. Disable sensor motion in both sides when comparing a fixed lighting/shadow position, and record that override. Keep paper texture and rainbow quality at defaults unless the test explicitly targets reduced quality.
- Verify successful exit, expected image dimensions and the ordered shader paths in the log. Reject shader fallback, missing passes or compile/reflection errors. If the renderer reinitialises, verify every repeated pass sequence and the effective settings rather than treating any successful launch as proof.
- Static native PNGs rendered through RetroArch's `imageviewer` core are useful repeatable fixtures, but must be labelled static saved-frame renders. Record the original ROM/core/state provenance and PNG hash; never describe these as fresh gameplay or device captures.

## Image comparison deliverable

- Read the `screenshot-compare` skill, including its RetroArch capture notes, and use its bundled builder. Local installation: `/Users/matt/.codex/skills/screenshot-compare/SKILL.md`; builder: `/Users/matt/.codex/skills/screenshot-compare/scripts/build_compare.py`. `SCREENSHOT_COMPARISONS.txt` is the portable fallback specification.
- Build from a manifest pointing at untouched paired PNGs, with capture context per case. Keep default-preservation cases separate from intentional appearance changes. Choose crop coordinates within each image's actual dimensions; GB/GBC and GBA captures differ in height.
- Inspect generated full-image and nearest-neighbour zoom PNGs, including representative paper/rainbow regions as well as the largest difference. Verify wipe/fade, case selection and zoom/pan in the browser when available; generating HTML alone is not live UI verification.
- If browser policy blocks local-file automation, do not bypass it through another browser surface or a temporary server. Inspect the static PNGs, provide the local artifact links and state that browser interaction was not verified. Keep existing viewers intact.

## Performance evidence

- Benchmark the frozen baseline and candidate on the same device, content, scale, quality and settings. Check device availability first. RPC results cannot be inferred from Mac timing, screenshots, pass counts or shader instruction estimates.
- Record the exact metric, sample count, variability and runtime context. Do not compute GPU FPS from process wall time, which includes launch, compilation and shutdown.
- The established Mac Vulkan/MoltenVK check logs RetroArch's `Average monitor Hz`. It needs more than 4096 frames before reporting; recent runs used 5000 total frames and the final 2048 samples. This counter is a local timing proxy, not isolated GPU FPS or a guaranteed device frame rate.
- On a 120 Hz Mac display that counter reads roughly 100–119 Hz for every Pixel Transparency preset, so it cannot resolve shader cost. For Mac A/B timing, attach `xcrun xctrace record --template 'Metal System Trace' --attach <pid>` to a background run, export the `metal-gpu-intervals` table and report RetroArch GPU busy time per frame (union of depth-0 intervals / distinct frames). Metal HUD logging redacts GPU time without elevated privileges. Reference scripts: `/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-colour-cache-uf6ylcdh/gpu-trace.py`, `gpu-parse.py`, `gpu-bench.py`.
- Interleave baseline/candidate runs and repeat when variability or a possible regression warrants it. Report noisy or presentation-limited results as inconclusive about small GPU costs. Fewer passes or no extra texture reads alone do not establish zero performance impact.

## RPC benchmark protocol

1. Check `adb devices` and record the RPC's normal `retroarch.cfg` sha256. Verify it is unchanged after the run.
2. Copy the newest harness folder's `setup.py` and `run.py` into the scratchpad. Edit `plan` (profile name, source, preset, parameter overrides) and the description, then run `setup.py`; it creates a fresh evidence folder and pushes everything to `/sdcard/RetroArch/temp/<folder>`.
   - Source `WORKTREE` uses the working tree; a commit id uses `git archive`. For a variant, patch the copied tree inside `setup.py` (as the `HARD` block in `pixel-transparency-rainbow-toggle-rpc-9lige9_h/setup.py` does), never the repo.
   - Parameter overrides go in the profile's `parameters`; `PT_FUSED_LAYER` 0 = Soft, 1 = Accurate.
3. Content: Mario Tennis title (Gambatte slot 9, the default) and the New Awakening village (Mac slot 1, staged as `The Legend of Zelda - New Awakening.state.auto`; see `pixel-transparency-na-placement-rpc-0v_xtfj9/setup.py`). Mode `fit` = screen fit 1200x1080, `integer` = 7x integer 1120x1008.
4. Run uncapped (audio, VSync, frameskip and runahead off) over emulated frames 128–384, three rounds with the profile order reversed in the middle round. Report the median of the three run medians and the spread.
5. Run it in the background; a 2-profile x 3-round run takes about 8 minutes. Report only measured numbers, and say when a result comes from older data.

Latest harnesses: `/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-rainbow-toggle-rpc-9lige9_h/` (code variant vs committed) and `pixel-transparency-na-placement-rpc-0v_xtfj9/` (New Awakening state, fit and integer).

Structural refactors need no benchmark: prove them with byte-identical SPIR-V across every Pixel Transparency preset using `/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-promotion/check-presets.py`.

## Local restart references

- Evidence lives under `/Volumes/Ensemble/Screenshots/Reviews/`. It moved there from `/Volumes/Ensemble/Retro/Screenshots/Reviews/` on 2026-10-19. Harness files inside older evidence folders (`context.json`, `templates/*.cfg`, scripts) still contain the old prefix; rewrite it to the new location before replaying them.
- RPC benchmark harness: `/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-integrated-physical-rpc-wdxgzior/` (`setup.py` copies presets from chosen commits to the device, `run.py` interleaves profiles, `benchmark.py` reads FPS over emulated frames 128–384). Check the RPC's normal `retroarch.cfg` hash is unchanged afterwards.
- RPC FPS is read by OCR of RetroArch's on-screen counter, and the macOS OCR tool can stall for 10–100 s (cold start, busy Mac). Never OCR inside the sampling loop: take all screenshots back to back first (about 1 s each), then OCR them afterwards and keep samples whose frame number falls in the window. That harness's `benchmark.py` (`read_shot`) does this; older copies that OCR between screenshots miss the 128–384 window whenever OCR stalls.
- Transparent paper-line evidence: `/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-transparent-lines-zbygiy_8/`. Read `USAGE.md` for the frozen baseline, compiler checks, serial capture API and bounded suites. `runtime.py` supports parameter overrides, both placements, GBC/GBA, fit/integer, disabled-effect checks and explicit benchmark mode. `summary.json` records the final results and limitations; archived temporary fixtures must be restored to their original repo paths before replaying baseline captures.
- Dark/light line-colour evidence: `/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-line-color-g0tq8tbm/`. Start with `summary.json`, `validation.json`, `comparisons.json`, `shade-comparisons.json`, `benchmark.json` and `viewer-manifest.json`; `original/` and `frozen-source/` preserve the baseline.
- That folder's `check.py` and `runtime.py` show compilation, capture, logging and comparison patterns. They are recorded test fixtures, not a general runner: adapt paths/cases, recreate temporary baseline presets inside the repo and use a fresh output folder before replaying them. Historical preset paths may have been renamed or cleaned up.
- Include/preset audit helper: `/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-cleanup-qfcie6xt/audit.py`. The older shared capture helper is `/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-live-grid-rpoqhfle/harness.py`; prefer the audit helper's declaration-relative texture resolution over that older helper's preset parser.
- Check local tool availability instead of assuming a Python version or hardcoding a past bundled runtime. Image analysis needs Pillow and NumPy; offline shader validation uses `glslangValidator` and `spirv-val`.
