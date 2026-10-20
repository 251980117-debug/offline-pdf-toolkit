# Release checklist

## Engine (milestone 1)
- [ ] `flutter test` passes
- [ ] Integration suite passes on a real Android phone in airplane mode
- [ ] Integration suite passes on a real iPhone in airplane mode
- [ ] 300-page benchmark time and memory recorded on a low-end Android phone

## Screens (milestone 2), on both platforms in airplane mode
- [ ] Merge 3 PDFs, reorder, rotate and delete pages, then open the result in another viewer
- [ ] Extract "1-3, 5" and confirm the right pages
- [ ] Split every 2 pages and by ranges; cancel a split midway and confirm no files remain
- [ ] Images to PDF with portrait, landscape and transparent PNG images at each quality
- [ ] iPhone photos (HEIC) either convert or show a clear error
- [ ] Password-protected PDF: wrong password, skip, correct password, confirm before saving
- [ ] Pick a file from a cloud provider; confirm it downloads or fails clearly
- [ ] Share and Save to device work; back button asks before discarding changes
- [ ] Large-text accessibility setting and dark mode look correct

## Release
- [ ] Release Android manifest has no INTERNET permission
- [ ] No network traffic during use, confirmed with a network monitor
- [ ] Open-source licenses page lists pdfrx, PDFium and other packages
