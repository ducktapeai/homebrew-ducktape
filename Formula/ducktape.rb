class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  version "0.10.0"
  url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v0.10.0.tar.gz"
  sha256 "d5558cd419c8d46bdc958064cb97f963d1ea793866414c025906ec15033512ed"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "build", "--release"
    bin.install "target/release/ducktape"
    
    # Generate shell completions
    output = Utils.safe_popen_read(bin/"ducktape", "completions")
    (bash_completion/"ducktape").write output
    (zsh_completion/"_ducktape").write output
    (fish_completion/"ducktape.fish").write output
    
    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    assert_match version.to_s, shell_output("\#{bin}/ducktape --version")
    system "\#{bin}/ducktape", "calendar", "list"
  end
end
