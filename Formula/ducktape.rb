class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v0.11.9.tar.gz"
  version "0.11.9"
  sha256 "fd8b2ae3e7039fffceadb80298fc80dc7745d39c14096c205631fff4af5239b1"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", "--root", prefix, "--path", "."
    
    # Generate shell completions
    output = Utils.safe_popen_read(bin/"ducktape", "completions")
    (bash_completion/"ducktape").write output
    (zsh_completion/"_ducktape").write output
    (fish_completion/"ducktape.fish").write output
    
    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ducktape --version")
    system "#{bin}/ducktape", "calendar", "list"
  end
end
