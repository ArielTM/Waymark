# Homebrew Cask formula for WindowMark
# Copy this to a homebrew-tap repo: homebrew-tap/Casks/windowmark.rb
# Update version, sha256, and url on each release.

cask "windowmark" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/AtrRandom/WindowMark/releases/download/v#{version}/WindowMark-#{version}-universal.dmg"
  name "WindowMark"
  desc "Mark windows you need to come back to and cycle through them with hotkeys"
  homepage "https://github.com/AtrRandom/WindowMark"

  app "WindowMark.app"

  zap trash: [
    "~/Library/Preferences/io.atrandom.WindowMark.plist",
  ]
end
