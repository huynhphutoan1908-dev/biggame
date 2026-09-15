# Dung tren may co Xcode (hoac trong workflow GitHub Actions):
#   make ipa   -> hien ra build/ipa/hi-unsigned.ipa

IPA_NAME = hi-unsigned

.PHONY: project build ipa clean

project:
	xcodegen generate

build: project
	xcodebuild -project hi.xcodeproj -scheme hi -configuration Release \
		-destination "generic/platform=iOS" -derivedDataPath build \
		CODE_SIGNING_ALLOWED=NO \
		build

ipa: build
	rm -rf payload_root "$(IPA_NAME).ipa"
	mkdir -p payload_root/Payload
	cp -R build/Build/Products/Release-iphoneos/hi.app payload_root/Payload/
	cd payload_root && zip -qr ../$(IPA_NAME).ipa Payload
	mkdir -p build/ipa
	mv $(IPA_NAME).ipa build/ipa/
	rm -rf payload_root
	@echo "==> build/ipa/$(IPA_NAME).ipa  (chenh ky, tai ve va ky bang AltStore/Sideloadly)"

clean:
	rm -rf build hi.xcodeproj
