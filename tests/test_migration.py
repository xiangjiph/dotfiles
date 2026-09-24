"""Mac migration integration tests with fake Nix, sudo, and activation.

Only temporary directories are mutated. /bin/mv is the real macOS atomic
symlink replacement used by production; no Nix or privileged command runs.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == "darwin", "requires macOS /bin/mv -h semantics")
class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-migration-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.new = self.root / "new checkout"
        self.old = self.root / "old checkout"
        self.old.mkdir()
        (self.old / "flake.nix").write_text("{}\n")
        (self.root / "other-checkout").mkdir()
        for name in ("rebuild.sh", "mac/rebuild.sh", "mac/migrate.sh",
                     "shared/scripts/link-repo.sh"):
            dest = self.new / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / name, dest)
        self.link = self.home / ".dotfiles"
        # Preserve the exact relative target on rollback, not just its referent.
        self.old_target = "../old checkout"
        self.link.symlink_to(self.old_target)
        (self.root / "generation").write_text("system-13-link\n")
        self.old_system = self.root / "old-system"
        (self.root / "current-system").write_text(str(self.old_system) + "\n")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        commands = [self.bin / name for name in
                    ("nix", "nix-env", "sudo", "uname", "id", "readlink", "darwin-rebuild")]
        commands += [self.root / system / "sw/bin/darwin-rebuild"
                     for system in ("old-system", "new-system")]
        for dest in commands:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / "tests/fixtures/migration-command", dest)
            dest.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin",
                        MIGRATION_TEST_ROOT=str(self.root),
                        MIGRATION_TEST_REPO=str(self.new),
                        MIGRATION_TEST_OLD=str(self.old),
                        MIGRATION_TEST_READLINK=shutil.which("readlink"))

    def run_migration(self, mode="success", args=None, entry="rebuild.sh"):
        return subprocess.run(
            ["/bin/bash", str(self.new / entry)] +
            (args if args is not None else ["--migrate-from", str(self.old)]),
            env=dict(self.env, MIGRATION_TEST_MODE=mode), cwd=self.new,
            capture_output=True, text=True, timeout=15)

    def events(self):
        path = self.root / "events"
        return path.read_text().splitlines() if path.exists() else []

    def assert_restored(self):
        self.assertEqual(os.readlink(self.link), self.old_target)
        self.assertEqual((self.root / "current-system").read_text().strip(), str(self.old_system))
        self.assertFalse((self.home / ".dotfiles-migration.lock").exists())
        self.assertEqual(list(self.home.glob(".dotfiles-migrate.*")), [])

    def test_success(self):
        result = self.run_migration()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.events(), ["build", "auth", "set-new", "activate"])
        self.assertEqual(os.readlink(self.link), str(self.new))
        records = list((self.home / ".local/state/dotfiles/migrations").iterdir())
        self.assertEqual(len(records), 1)
        record = records[0]
        self.assertEqual((record / "old-link-target").read_text().strip(), self.old_target)
        self.assertEqual((record / "old-generation").read_text().strip(), "system-13-link")
        self.assertEqual((record / "old-system").read_text().strip(), str(self.old_system))
        self.assertEqual((record / "status").read_text().strip(), "complete")
        self.assertTrue((record / "new-system").is_symlink())
        self.assertFalse((self.home / ".dotfiles-migration.lock").exists())

    def test_explicit_mac_dispatch(self):
        result = self.run_migration(args=["mac", "--migrate-from", str(self.old)])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_direct_mac_dispatch(self):
        result = self.run_migration(entry="mac/rebuild.sh")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_build_failure(self):
        result = self.run_migration("build-fail")
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertEqual(self.events(), ["build"])
        self.assert_restored()

    def test_build_interruption(self):
        result = self.run_migration("build-signal")
        self.assertEqual(result.returncode, 143, result.stderr)
        self.assert_restored()

    def test_auth_failure(self):
        result = self.run_migration("auth-fail")
        self.assertEqual(result.returncode, 19, result.stderr)
        self.assertEqual(self.events(), ["build", "auth"])
        self.assert_restored()

    def test_profile_failure(self):
        result = self.run_migration("profile-fail")
        self.assertEqual(result.returncode, 21, result.stderr)
        self.assertNotIn("activate", self.events())
        self.assert_restored()

    def test_activation_failure(self):
        result = self.run_migration("activate-fail")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.events(), ["build", "auth", "set-new", "activate", "restore-profile"])
        self.assertIn(str(self.old_system / "sw/bin/darwin-rebuild"), result.stderr)
        self.assertIn("Homebrew", result.stderr)
        self.assert_restored()

    def test_term_during_activation(self):
        result = self.run_migration("signal-TERM")
        self.assertEqual(result.returncode, 143, result.stderr)
        self.assert_restored()

    def test_int_during_activation(self):
        result = self.run_migration("signal-INT")
        self.assertEqual(result.returncode, 130, result.stderr)
        self.assert_restored()

    def test_hup_during_activation(self):
        result = self.run_migration("signal-HUP")
        self.assertEqual(result.returncode, 129, result.stderr)
        self.assert_restored()

    def test_wrong_old_checkout(self):
        result = self.run_migration(args=["--migrate-from", str(self.root / "other-checkout")])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.events(), [])
        self.assert_restored()

    def test_real_directory_is_preserved(self):
        self.link.unlink()
        self.link.mkdir()
        result = self.run_migration()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.link.is_symlink())
        self.assertTrue(self.link.is_dir())
        self.assertEqual(self.events(), [])

    def test_changed_link_during_build(self):
        result = self.run_migration("changed-link")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(os.readlink(self.link), str(self.root / "other-checkout"))
        self.assertNotIn("activate", self.events())

    def test_changed_generation_during_build(self):
        result = self.run_migration("changed-generation")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / "generation").read_text().strip(), "system-99-link")
        self.assertNotIn("activate", self.events())
        self.assert_restored()

    def test_independent_link_is_not_overwritten_on_failure(self):
        result = self.run_migration("changed-link-during-activation")
        self.assertEqual(result.returncode, 23)
        self.assertEqual(os.readlink(self.link), str(self.root / "other-checkout"))
        self.assertIn("refusing to overwrite", result.stderr)

    def test_existing_lock(self):
        (self.home / ".dotfiles-migration.lock").mkdir()
        result = self.run_migration()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.events(), [])
        self.assertTrue((self.home / ".dotfiles-migration.lock").exists())

    def test_ordinary_rebuild_still_refuses_other_checkout(self):
        result = self.run_migration(args=[])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already points somewhere else", result.stderr)
        self.assertEqual(self.events(), [])
        self.assert_restored()

    def test_bad_arguments(self):
        for args in (["--migrate-from"], ["--migrate-from", str(self.old), "extra"], ["--unknown"]):
            with self.subTest(args=args):
                result = self.run_migration(args=args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.events(), [])
                self.assert_restored()

    def test_ordinary_mac_rebuild(self):
        self.link.unlink()
        self.link.symlink_to(self.new)
        result = self.run_migration(args=[])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.events(), ["normal-switch"])

    def test_ordinary_rebuild_honors_migration_lock(self):
        (self.home / ".dotfiles-migration.lock").mkdir()
        result = self.run_migration(args=[])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.events(), [])

    def test_linux_arguments_still_forwarded(self):
        self.env["MIGRATION_TEST_OS"] = "Linux"
        for profile, arguments in (("wsl", []), ("server", ["--home-manager"])):
            with self.subTest(profile=profile):
                script = self.new / profile / "rebuild.sh"
                script.parent.mkdir()
                script.write_text('printf "%s\\n" "$@" > "$MIGRATION_TEST_ROOT/forwarded"\n')
                result = self.run_migration(args=[profile] + arguments)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((self.root / "forwarded").read_text().strip(), "\n".join(arguments))
        result = self.run_migration(args=["wsl", "--migrate-from", str(self.old)])
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.events(), [])

    def test_bad_arguments_direct_mac(self):
        for args in (["--migrate-from"], ["--migrate-from", str(self.old), "extra"], ["--unknown"]):
            with self.subTest(args=args):
                result = self.run_migration(args=args, entry="mac/rebuild.sh")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.events(), [])
                self.assert_restored()

    def test_linux_dispatch_rejects_migration(self):
        self.env["MIGRATION_TEST_OS"] = "Linux"
        result = self.run_migration()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.events(), [])
        self.assert_restored()


if __name__ == "__main__":
    unittest.main()
