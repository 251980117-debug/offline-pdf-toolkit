# Release checklist

## Engine (milestone 1)
- [ ] `flutter test` passes
- [ ] Integration suite passes on a real Android phone in airplane mode
- [ ] Integration suite passes on a real iPhone in airplane mode
- [ ] 300-page benchmark time and memory recorded on a low-end Android phone

## Screens (milestone 2), on both platforms in airplane mode
- [ ] Open a PDF from Home and edit it; save a copy and confirm the original is unchanged
- [ ] From a result or a recent file, "Edit pages" opens the same editor with that PDF
- [ ] Duplicate a page and add a blank page, drag them into place, then save
- [ ] Compress a scanned PDF at each level; confirm the result is smaller and opens in another viewer
- [ ] Compress a text-heavy PDF and confirm the "no gain" message when the copy is not smaller
- [ ] PDF to Images: export a 3-page PDF, confirm page-001.jpg and friends are in page order, then share them
- [ ] Cancel a PDF to Images export midway and confirm no JPG files remain
- [ ] App name reads "Offline PDF Toolkit" on the home screen and in system settings, with the new icon
- [ ] Merge 3 PDFs, reorder, rotate and delete pages, then open the result in another viewer
- [ ] Merge with photos: add PDFs and photos in one document, confirm each photo is one page in order
- [ ] Merge: cancel the photo picker and the file picker; the screen stays open with its buttons
- [ ] Images to PDF: take photos one after another with the camera and build one PDF
- [ ] Images to PDF: deny camera permission and confirm a clear message, no crash
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
