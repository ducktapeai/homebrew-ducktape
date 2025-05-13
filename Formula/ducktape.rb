class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  # Latest release URL (updated to v0.16.22 on May 13, 2025)
  url "https://github.com/ducktapeai/ducktape/archive/v0.16.22.tar.gz"
  version "0.16.22"
  sha256 "472aaa03437fad0a5db971712163723aed16e577c719c6afc98b89e16b467fa5"
  license "MIT"
  
  # Explicitly mark as macOS only
  depends_on :macos
  depends_on "rust" => :build

  def install
    system "cargo", "install", "--root", prefix, "--path", "."

    # Generate shell completions - with error handling
    begin
      output = Utils.safe_popen_read(bin/"ducktape", "completions")
      (bash_completion/"ducktape").write output
      (zsh_completion/"_ducktape").write output
      (fish_completion/"ducktape.fish").write output
    rescue => e
      opoo "Shell completions couldn't be generated: \#{e.message}"
      # Create minimal completions as fallback
      (bash_completion/"ducktape").write "# Fallback bash completions for ducktape\n"
      (zsh_completion/"_ducktape").write "# Fallback zsh completions for ducktape\n"
      (fish_completion/"ducktape.fish").write "# Fallback fish completions for ducktape\n"
    end

    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    # Only test version output as it doesn't require Apple Calendar setup
    assert_match version.to_s, shell_output("#{bin}/ducktape --version")
    
    # Skip functional test that might fail in CI environment
    # system "#{bin}/ducktape", "calendar", "list"
  end
end
