# Vimium Mac

Build files for the Mac app. Product docs: [README](../README.md) at the repository root.

```bash
make          # generate the Xcode project and build Release
make run      # build, then open the app
make install  # copy to /Applications/Vimium Mac.app
make clean    # remove DerivedData under VimiumMac/build
```

After install, grant **Vimium Mac** under System Settings → Privacy & Security → Accessibility. There is no Dock icon; use the keyboard extra in the menu bar.
