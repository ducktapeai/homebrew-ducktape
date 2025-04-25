class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  url "https://github.com/ducktapeai/ducktape/archive/v0.16.3.tar.gz"
  version "0.16.3"
  sha256 "c7e8e4887bced2d75a2f7549b1134dc465d6a09a507dcba2bfadedb40ee6030d"
  license "MIT"

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
    assert_match version.to_s, shell_output("#{bin}/ducktape --version")
    system "#{bin}/ducktape", "calendar", "list"
  end
end
