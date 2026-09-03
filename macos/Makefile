.PHONY: all generate build run install clean

SCHEME := VimiumMac
PROJECT := VimiumMac/VimiumMac.xcodeproj
DERIVED := VimiumMac/build
APP := $(DERIVED)/Build/Products/Release/VimiumMac.app
INSTALL_APP := /Applications/Vimium Mac.app

all: build

generate: $(PROJECT)

$(PROJECT): VimiumMac/project.yml VimiumMac/Info.plist VimiumMac/VimiumMac.entitlements
	cd VimiumMac && xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(DERIVED) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=YES \
		CODE_SIGNING_ALLOWED=YES

run: build
	open "$(APP)"

# Copy to /Applications so System Settings → Accessibility keeps a stable identity
# across rebuilds (ad-hoc signed builds from DerivedData look like a new app).
install: build
	rm -rf "$(INSTALL_APP)"
	ditto "$(APP)" "$(INSTALL_APP)"
	codesign --force --deep --sign - "$(INSTALL_APP)"
	@echo "Installed $(INSTALL_APP)"
	@echo "A window opens on first launch (also Show Window from the menu bar extra). Enable Vimium Mac in System Settings → Privacy & Security → Accessibility."

clean:
	rm -rf $(DERIVED)
