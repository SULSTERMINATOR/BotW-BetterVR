# cpu agent findings (2026-10-28)
Critical path (CEMU_CORE_STATS=1, runs/cpuprof2 stereo, runs/cpumono):
- Stereo: core1 'Default Core 1' runs ~51-54% of wall (~27 ms/frame), idle ~47%:
  ~28% of wall in GX2WaitTimeStamp called from BetterVR codecave lr=0x018141c4
  (patch_RND_StereoRendering.asm waitForLastSubmittedTimeStamp after left-eye procDraw = waits for LatteThread
  to translate the whole left eye), ~7% end-of-frame GX2DrawDone (lr 0x01812824), ~5% job-worker waits.
  LatteThread busy ~31-35 ms/frame, ringIdle ~18-20 ms/frame, vkFence 1-2 ms/frame. -> serial chain core1 <-> Latte.
- Mono: core1 runs only 31% (~15 ms/frame), ~59% of wall in end-of-frame GX2DrawDone; Latte vkFence 9.8 ms/frame:
  Cemu's Vulkan GX2DrawDone forces IT_HLE_SYNC_ASYNC_OPERATIONS -> waits for host GPU (occlusion query/readback finish).
- Idle spin (clock_gettime in AXOut_update) is real idle, not masking work. Interpreter fallback negligible
  (16 small functions fail IML gen, executeInstruction ~0.2% of core1). Guest profile flat (top unit 1.5%).
Benches (bench-botw.sh, true fps): stereo base 22.1/21.7 (18.9 outlier w/ startup dip), CEMU_ASYNC_DRAWDONE=1 21.8/22.4/22.2;
  mono 23.4 -> CEMU_ASYNC_DRAWDONE=1 24.7/24.4; CEMU_FAST_CLOCK=1 CEMU_IDLE_THROTTLE_US=50 21.4 (1 run, no gain).
Round 2 (coordinator follow-up), all stereo, bench-botw.sh:
- base 21.6/21.4 (and 22.1/21.7 earlier). CEMU_WAITTS_LAG=2: 21.5, LAG=4: 21.6, LAG=4+ASYNC_DRAWDONE: 22.3.
- Skip left-eye wait in Cemu (CEMU_WAITTS_LR=018141c4 CEMU_WAITTS_LAG=1000000) alone, with CORE_STATS: 20.7 -> the wait just moves
  to the end-of-frame GX2DrawDone (core1 idle stays 47%), and Latte then blocks 7 ms/frame on vkFence (DrawDone's GPU full sync).
  That is why removing the wait alone never helped (old asm removal 15.9 also had p99 ~250 ms hitches; not reproduced here).
- Skip + CEMU_ASYNC_DRAWDONE=1: 26.2 fps (p50 interval 38.7 ms, p99 ~55 ms), shot-runs 27.0 (right eye) / 26.3 (left) vs 21.3 base.
  Static screenshots shots/cpu-skipdd-{left,right} vs shots/cpu-base-right: no visible corruption. In-headset check for
  flicker / eye mismatch / occlusion (lens flare) and texture readback effects NOT done.
- CEMU_FAST_CLOCK=1 CEMU_IDLE_THROTTLE_US=50: 21.4, 21.5 -> no gain.
