# Homebrew Cask formula for Waymark
# Copy this to a homebrew-tap repo: homebrew-tap/Casks/waymark.rb
# Update version, sha256, and url on each release.

cask "waymark" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/AtrRandom/WindowMark/releases/download/v#{version}/Waymark-#{version}-universal.dmg"
  name "Waymark"
  desc "Mark windows you need to come back to and cycle through them with hotkeys"
  homepage "https://github.com/AtrRandom/WindowMark"

  app "Waymark.app"

  zap trash: [
    "~/Library/Preferences/io.atrandom.Waymark.plist",
  ]
end
