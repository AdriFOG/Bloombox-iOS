# BloomBox · Android Files (Takopi reuse)

**State:** architecture prepared on a feature branch only; no UI/runtime integration yet.
**Base:** `main` as of 2026-11-21. Do not merge or publish release until compiled and tested on device.

## Sources inspected

- Takopi Explorer / old NikaView repository: https://github.com/adri23rep-stack/NikaView
  - `SolidSecViewer/ExplorerFileEngine.swift`: file listing, safe-root checks, coordinated imports, copy/move/rename, symlink exclusion and sorting.
  - `SolidSecViewer/ExplorerPaneState.swift`: independent panel navigation, selection/search, list/grid.
  - `SolidSecViewer/ExplorerOperationQueue.swift`: queued copy/move operations, cancel and progress UI.
  - `SolidSecViewer/ExplorerFolderPicker.swift`: authorized iOS folder picker.
  - `SolidSecViewer/ExplorerArchiveManager.swift`: ZIP / RAR / 7z, but imports additional libraries and must be evaluated separately.
- BloomBox's existing lightweight manager:
  - `LiveContainerSwiftUI/Views/BloomBox/BloomBoxFileStore.swift`
  - `LiveContainerSwiftUI/Views/BloomBox/BloomBoxFilesView.swift`
- Husk (upstream): https://github.com/Leviidev/Husk
  - `src/app/Husk/TranslationLayer.swift`: `Documents/TranslationLayer` (per-app storage), `Documents/Shared Storage` (host storage for translated `/sdcard`).
  - `src/translation-layer-next/husk-tl-bionic-io.c`: `/sdcard` and `/storage/emulated/0` path translation; `Android/data` and `Android/obb` are handled specially.
  - `src/app/Husk/FilesTab.swift`: existing guest-side browser rooted at `/sdcard` in the appropriate Husk runtime.
  - `src/java-framework/src/husk/Documents.java`: file picker bridge for GET_CONTENT / OPEN_DOCUMENT / PICK; no complete directory-picker bridge for Android OPEN_DOCUMENT_TREE.
 
## Integration strategy

1. **Separate interface:** `BloomBox > Files > Android` next to the existing iOS file manager. Do not replace or restructure the existing BloomBox storage or copy Takopi's entire application into BloomBox.
2. **Reuse real Takopi components:** port its pane state, file-operation queue, selection and root-bounded file logic as a self-contained module; preserve original attribution in source comments. Remove Vault, SMB, Face ID, private backup, and app-specific preferences.
3. **Storage abstraction:** do *not* present a manufactured Android filesystem. Detect Husk guest model and permitted container(s), then map only real accessible storage. The root shown to the user is `/sdcard` where supported; expose each game's private data and expansion files only through *verified, separately bounded* mappings. Distinguish native translation storage from the separate guest-VM path, which may be an entirely different model.
4. **Safe import:** choose files and folders via iOS pickers; retain access only during copies or authorized bookmarks; copy selected data into the *correct* container without assuming that the iOS Downloads folder is Android `Download`. Do not write over saves, shared data, APKs or OBB by default. For archives, enforce decompression limits, traversal protection, and conflict resolution before extraction.
5. **Folder operations:** list/search, create/copy/move/rename/preview, multiple selection, optional two-pane navigation and history, clear progress and cancellation. First milestone read-only file exploration and mapping validation; then opt-in writes with backups and explicit confirmation.
6. **Compatibility diagnostics:** detect whether a game requests a file picker or Android directory-tree permission; fixing `ACTION_OPEN_DOCUMENT_TREE` may require a Husk upstream change rather than only a BloomBox file UI.
7. **Device testing:** test native Husk mode and any VM guest mode separately; paths, installs and permissions differ. Confirm UI and mapping on iPhone before any merge.

## Non-goals / safety

- No access to the real iOS or Android root beyond granted containers.
- No synthetic folders presented as existing filesystem paths.
- No automatic `Android/data` or `Android/obb` mass copying.
- No changes to Takopi's own repository, users' existing data, or BloomBox `main`.
- No release, IPA build or claim of a working Android explorer at this preparation stage.

## Next implementation milestone

Build a mount/provider protocol for (a) native Husk Shared Storage, (b) per-app scoped directories, and (c) any supported guest file bridge, then integrate Takopi's isolated navigation components. Require a failing/passing test for traversal and symlink protection before enabling writes.
