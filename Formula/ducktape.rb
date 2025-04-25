class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  url "https://github.com/ducktapeai/ducktape/archive/v0.16.6.tar.gz"
  version "0.16.6"
  sha256 "6b8bf222ab6236637fa50928f99b8abaf5341d5c57e7f253a5fd2c93bce2fd5c"
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
