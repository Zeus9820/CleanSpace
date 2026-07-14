# Performance verification

CleanSpace measures allocated bytes, so the large-capacity fixture uses a sparse logical file. It is safe for local profiling and does not consume 501 GB of physical storage.

1. Run `Tools/create-performance-fixture.sh` (optionally pass a destination).
2. Inject the printed directory as the scanner's fixture Home in the Performance scheme or a test harness.
3. Profile the Direct target with Instruments using **Time Profiler**, **File Activity**, **Allocations**, and **Swift Tasks**.
4. Start a scan, resize the window continuously, select categories, and cancel/rescan once.
5. Verify no filesystem traversal appears on the main actor, selection remains responsive, memory stays bounded, and cancellation stops traversal promptly.

The default fixture contains 100,001 files and a 501 GB sparse logical file. Never point destructive tests at the real Home directory.
