# Changelog Rays.v1.3

## Added

- Added new extension modules for TadSync field following, reconnect sync.
- Added new patch templates for glitter extend, sticker stack interrupt, blue booster stat counters, NM conversion, and preset GUI copying.
- Added new reconnect-sync GUI/config support and new TadSync configuration fields, including hive redirect support.
- Boosted field counter in hourlies

## Changed

- Glitter extend timings to the last 30 second before the boost ends while gathering and 1 minute before a boost ends while converting
- Changed the bar style field boost graph to a chart style

## Fixed

- Fixed multiple patcher recovery paths for older or partially broken patched files, including duplicated functions, repeated blocks, and malformed hook insertion.
- Reduced reconnect-sync debug log noise while preserving reconnect behavior.
- Restored and hardened several StatMonitor code paths that could fail on empty data sets or inconsistent attachment state.
- Mondo interupt causing gathering to be broken

## Notes

- A clean Natro folder is still the safest starting point if an older install was heavily customized.
- If something looks unchanged after patching, make sure the patched macro was restarted fully before testing.
