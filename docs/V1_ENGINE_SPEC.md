# Version 1 engine rules (frozen)

Changes to these rules need a spec update and new tests.

## Scope
Merge, split (every N pages or by ranges), extract, delete, reorder, rotate,
image-to-PDF. No editing of page content, OCR, conversion or compression of
existing PDFs.

## Page planning
1. Every output is described by an immutable page plan before any file is touched.
2. Page input is 1-based ("1-3, 5"). Repeated pages, reversed ranges, empty parts and pages outside the document are rejected with a clear message.
3. No operation may produce an empty document.
4. Reorder must contain every page exactly once.
5. Split parts never overlap and never produce a single identical copy.
6. Rotation is added in quarter turns to the page's existing rotation.

## Writing
7. Originals are never modified or replaced. Output can never use a source path (compared case-insensitively) or an existing file name.
8. Output is encoded in memory, reopened, and verified: page count, and each page's dimensions in either orientation.
9. Verified bytes go to an app-private unfinished file, then are moved to the final name. A failed, cancelled or unverified job leaves no output and no unfinished file.
10. Unfinished files from an interrupted session are removed at startup.

## Protection
11. Password-protected sources need the password. It is offered once, kept in memory only and never stored.
12. Output from a protected source has no password. The user must confirm this first.
13. Modifying a signed PDF invalidates its signature. The interface must warn about this (milestone 2).

## Images
14. EXIF orientation is applied. Images are downscaled, never upscaled: compact 1600 px, balanced 2480 px, high 3508 px on the long edge.
15. Transparent areas become white. Each page matches its image aspect ratio, 841.89 pt on the long edge.

## Privacy
16. No document content leaves the device. The release Android build must not request the INTERNET permission.
