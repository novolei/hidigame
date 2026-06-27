#!/usr/bin/env python3
"""Upload hot-update artifacts to the TX/AL VPS pair using password SSH."""

from __future__ import annotations

import argparse
import getpass
import os
import posixpath
import shlex
import socket
import sys
from dataclasses import dataclass
from pathlib import Path

import paramiko


@dataclass(frozen=True)
class Host:
    code: str
    address: str


HOSTS = (
    Host("AL", "8.153.148.157"),
    Host("TX", "1.13.175.170"),
)

PASSWORD_PROMPT_ORDER = (
    Host("TX", "1.13.175.170"),
    Host("AL", "8.153.148.157"),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Upload hot-update release files to AL then TX.")
    parser.add_argument("--user", default="", help="Default SSH user. Leave blank to prompt interactively.")
    parser.add_argument("--tx-user", default="", help="Override SSH user for TX.")
    parser.add_argument("--al-user", default="", help="Override SSH user for AL.")
    parser.add_argument("--only", choices=("all", "TX", "AL"), default="all", help="Limit upload/preflight to one host.")
    parser.add_argument("--release-dir", type=Path, default=Path("builds/hot_update/dev/0.4.5"))
    parser.add_argument("--base-zip", type=Path, default=Path("builds/hot_update/base/0.4.4/baseInstall.zip"))
    parser.add_argument("--server-pack", type=Path, default=Path("newrelease/maomao_server.pck"))
    parser.add_argument("--remote-root", default="/var/www/maomao-updates")
    parser.add_argument("--channel-path", default="maomao/dev")
    parser.add_argument("--base-path", default="maomao/base/0.4.4")
    parser.add_argument("--remote-server-pack", default="/opt/maomao/maomao_server.pck")
    parser.add_argument("--server-backups-to-keep", type=int, default=1, help="Number of old server PCK backups to keep.")
    parser.add_argument("--stage-root", default="/var/tmp", help="Remote staging directory root.")
    parser.add_argument(
        "--server-service",
        default="auto",
        help="systemd service to restart after server pack install. Use 'auto' or 'none'.",
    )
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--no-base", action="store_true", help="Do not upload baseInstall.zip.")
    parser.add_argument("--no-server-pack", action="store_true", help="Do not upload the public server PCK.")
    parser.add_argument("--configure-nginx", action="store_true", help="Install and enable an Nginx static file config.")
    parser.add_argument("--manifest-only", action="store_true", help="Upload/configure only the release manifest.")
    parser.add_argument("--cleanup-only", action="store_true", help="Only remove stale remote PCK files and old stage dirs.")
    parser.add_argument("--preflight-only", action="store_true", help="Connect and inspect remote capacity/services only.")
    parser.add_argument(
        "--allow-empty-packages",
        action="store_true",
        help="Allow a baseline release manifest with no incremental PCK packages.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path.cwd()
    release_dir = resolve(repo_root, args.release_dir)
    manifest = release_dir / "manifest.json"
    package_dir = release_dir / "packages"
    base_zip = resolve(repo_root, args.base_zip)
    server_pack = resolve(repo_root, args.server_pack)
    packages = sorted(package_dir.glob("*.pck"))
    uploads_enabled = not args.manifest_only and not args.cleanup_only

    if not manifest.is_file():
        raise FileNotFoundError(manifest)
    if uploads_enabled and not packages and not args.allow_empty_packages:
        raise FileNotFoundError(f"No PCK packages found under {package_dir}")
    if uploads_enabled and not args.no_base and not base_zip.is_file():
        raise FileNotFoundError(base_zip)
    if uploads_enabled and not args.no_server_pack and not server_pack.is_file():
        raise FileNotFoundError(server_pack)

    hosts = selected_hosts(args.only)
    users = host_users(args)
    passwords = prompt_passwords(users, hosts)

    remote_channel_dir = posixpath.join(args.remote_root, args.channel_path)
    remote_package_dir = posixpath.join(remote_channel_dir, "packages")
    remote_manifest = posixpath.join(remote_channel_dir, "manifest.json")
    remote_base_dir = posixpath.join(args.remote_root, args.base_path)
    remote_base_zip = posixpath.join(remote_base_dir, "baseInstall.zip")
    remote_server_pack = normalize_absolute_posix(args.remote_server_pack)
    stage_root = normalize_absolute_posix(args.stage_root)

    if args.preflight_only:
        for host in hosts:
            user = users[host.code]
            password = passwords[host.code]
            with connect(host, user, password, args.port) as ssh:
                print(f"[{host.code}] connected to {host.address}")
                remote_preflight(ssh, host.code, args.remote_root, remote_server_pack, stage_root)
        return 0

    if args.cleanup_only:
        for host in hosts:
            user = users[host.code]
            password = passwords[host.code]
            with connect(host, user, password, args.port) as ssh:
                print(f"[{host.code}] connected to {host.address}")
                cleanup_remote_files(
                    ssh,
                    remote_server_pack,
                    remote_package_dir,
                    [package.name for package in packages],
                    args.server_backups_to_keep,
                    password,
                    user,
                    host.code,
                )
        return 0

    staged: dict[str, str] = {}
    for host in hosts:
        stage_dir = posixpath.join(stage_root, f"maomao-hot-update-{os.getpid()}-{host.code.lower()}")
        staged[host.code] = stage_dir
        user = users[host.code]
        password = passwords[host.code]
        with connect(host, user, password, args.port) as ssh:
            prepare_stage(ssh, stage_dir, password, user)
            sftp = ssh.open_sftp()
            try:
                print(f"[{host.code}] connected to {host.address}")
                mkdir_p_sftp(sftp, stage_dir)
                if not args.manifest_only and packages:
                    mkdir_p_sftp(sftp, posixpath.join(stage_dir, "packages"))
                if not args.manifest_only and not args.no_server_pack:
                    put_file(sftp, server_pack, posixpath.join(stage_dir, "maomao_server.pck"), host.code)
                if not args.manifest_only and not args.no_base:
                    put_file(sftp, base_zip, posixpath.join(stage_dir, "baseInstall.zip"), host.code)
                if not args.manifest_only:
                    for package in packages:
                        put_file(sftp, package, posixpath.join(stage_dir, "packages", package.name), host.code)
                put_file(sftp, manifest, posixpath.join(stage_dir, "manifest.json"), host.code)
            finally:
                sftp.close()

            if not args.manifest_only and not args.no_server_pack:
                install_server_pack(ssh, stage_dir, remote_server_pack, args.server_backups_to_keep, password, user, host.code)
                restart_server_service(ssh, args.server_service, password, user, host.code)

            if not args.manifest_only:
                install_packages_command = [
                    "set -e",
                    f"mkdir -p {shlex.quote(remote_package_dir)}",
                ]
                stat_paths = []
                if packages:
                    install_packages_command.append(
                        f"cp -f {shlex.quote(posixpath.join(stage_dir, 'packages'))}/*.pck {shlex.quote(remote_package_dir)}/"
                    )
                    stat_paths.append(remote_package_dir)
                if not args.no_base:
                    install_packages_command.extend([
                        f"mkdir -p {shlex.quote(remote_base_dir)}",
                        f"cp -f {shlex.quote(posixpath.join(stage_dir, 'baseInstall.zip'))} {shlex.quote(remote_base_zip)}",
                    ])
                    stat_paths.append(remote_base_zip)
                if stat_paths:
                    install_packages_command.append(remote_stat_command(stat_paths))
                run_privileged(ssh, "\n".join(install_packages_command), password, user)
                print(f"[{host.code}] package/base files installed")
            if args.configure_nginx:
                configure_nginx(ssh, args.remote_root, password, user, host.code)

    for host in hosts:
        user = users[host.code]
        password = passwords[host.code]
        with connect(host, user, password, args.port) as ssh:
            stage_dir = staged[host.code]
            install_manifest_command = "\n".join([
                "set -e",
                f"mkdir -p {shlex.quote(remote_channel_dir)}",
                f"cp -f {shlex.quote(posixpath.join(stage_dir, 'manifest.json'))} {shlex.quote(remote_manifest)}",
                remote_stat_command([remote_manifest]),
                f"rm -rf {shlex.quote(stage_dir)}",
            ])
            run_privileged(ssh, install_manifest_command, password, user)
            print(f"[{host.code}] manifest installed")

    if [host.code for host in hosts] == ["AL", "TX"]:
        print("Upload complete. TX manifest was published last.")
    else:
        print("Upload complete for selected host.")
    print(f"TX manifest URL: http://1.13.175.170/{args.channel_path}/manifest.json")
    print(f"AL manifest URL: http://8.153.148.157/{args.channel_path}/manifest.json")
    return 0


def resolve(repo_root: Path, value: Path) -> Path:
    return value.resolve() if value.is_absolute() else (repo_root / value).resolve()


def normalize_absolute_posix(value: str) -> str:
    normalized = posixpath.normpath(value.replace("\\", "/"))
    if not normalized.startswith("/"):
        raise ValueError(f"Remote path must be absolute: {value}")
    return normalized


def selected_hosts(only: str) -> tuple[Host, ...]:
    if only == "all":
        return HOSTS
    return tuple(host for host in HOSTS if host.code == only)


def host_users(args: argparse.Namespace) -> dict[str, str]:
    default_user = args.user.strip()
    if not default_user and (not args.tx_user.strip() or not args.al_user.strip()):
        default_user = input("SSH user [root]: ").strip() or "root"
    tx_user = args.tx_user.strip() or default_user
    al_user = args.al_user.strip() or default_user
    if not tx_user or not al_user:
        raise RuntimeError("Missing SSH user for TX or AL.")
    return {"TX": tx_user, "AL": al_user}


def prompt_passwords(users: dict[str, str], hosts: tuple[Host, ...]) -> dict[str, str]:
    passwords: dict[str, str] = {}
    selected_codes = {host.code for host in hosts}
    for host in PASSWORD_PROMPT_ORDER:
        if host.code not in selected_codes:
            continue
        user = users[host.code]
        password = getpass.getpass(f"Password for {user}@{host.code} ({host.address}): ")
        if not password:
            raise RuntimeError(f"Password for {host.code} was empty.")
        passwords[host.code] = password
    return passwords


def connect(host: Host, user: str, password: str, port: int) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        host.address,
        port=port,
        username=user,
        password=password,
        look_for_keys=False,
        allow_agent=False,
        timeout=15,
        banner_timeout=15,
        auth_timeout=15,
    )
    transport = client.get_transport()
    if transport is not None:
        transport.set_keepalive(30)
    return client


def mkdir_p_sftp(sftp: paramiko.SFTPClient, path: str) -> None:
    current = ""
    for part in path.split("/"):
        if not part:
            current = "/"
            continue
        current = posixpath.join(current, part)
        try:
            sftp.stat(current)
        except FileNotFoundError:
            sftp.mkdir(current)


def put_file(sftp: paramiko.SFTPClient, local_path: Path, remote_path: str, host_code: str) -> None:
    size = local_path.stat().st_size
    next_report = 0

    def progress(sent: int, total: int) -> None:
        nonlocal next_report
        if total <= 0:
            return
        pct = int(sent * 100 / total)
        if pct >= next_report or sent == total:
            print(f"[{host_code}] {local_path.name}: {pct}% ({sent}/{total} bytes)")
            next_report += 25

    print(f"[{host_code}] upload {local_path.name} ({size} bytes) -> {remote_path}")
    sftp.put(str(local_path), remote_path, callback=progress)


def prepare_stage(ssh: paramiko.SSHClient, stage_dir: str, password: str, user: str) -> None:
    cleanup_command = (
        "find /tmp /var/tmp -maxdepth 1 -type d -name 'maomao-hot-update-*' "
        "-mmin +5 -exec rm -rf {} + 2>/dev/null || true"
    )
    run_privileged(ssh, cleanup_command, password, user)
    out, err, code = run_command(
        ssh,
        f"rm -rf {shlex.quote(stage_dir)} && mkdir -p {shlex.quote(stage_dir)} && chmod 0700 {shlex.quote(stage_dir)}",
    )
    if out.strip():
        print(out.strip())
    if err.strip():
        print(err.strip(), file=sys.stderr)
    if code != 0:
        raise RuntimeError(f"Remote stage preparation failed with exit code {code}: {stage_dir}")


def install_server_pack(
    ssh: paramiko.SSHClient,
    stage_dir: str,
    remote_server_pack: str,
    backups_to_keep: int,
    password: str,
    user: str,
    host_code: str,
) -> None:
    remote_server_dir = posixpath.dirname(remote_server_pack)
    staged_pack = posixpath.join(stage_dir, "maomao_server.pck")
    backup_glob = f"{remote_server_pack}.bak-*"
    command = "\n".join([
        "set -e",
        "ts=$(date +%Y%m%d%H%M%S)",
        f"mkdir -p {shlex.quote(remote_server_dir)}",
        f"if [ -f {shlex.quote(remote_server_pack)} ]; then cp -f {shlex.quote(remote_server_pack)} {shlex.quote(remote_server_pack)}.bak-$ts; fi",
        f"cp -f {shlex.quote(staged_pack)} {shlex.quote(remote_server_pack)}",
        f"chmod 0644 {shlex.quote(remote_server_pack)}",
        prune_backups_command(backup_glob, backups_to_keep),
        remote_stat_command([remote_server_pack]),
    ])
    run_privileged(ssh, command, password, user)
    print(f"[{host_code}] server PCK installed")


def restart_server_service(
    ssh: paramiko.SSHClient,
    service_arg: str,
    password: str,
    user: str,
    host_code: str,
) -> None:
    service = service_arg.strip()
    if not service or service.lower() == "none":
        print(f"[{host_code}] server service restart skipped")
        return
    if service.lower() == "auto":
        candidates = service_candidates(ssh)
        if len(candidates) != 1:
            if candidates:
                print(f"[{host_code}] server service restart skipped; candidates: {', '.join(candidates)}")
            else:
                print(f"[{host_code}] server service restart skipped; no matching systemd service found")
            return
        service = candidates[0]
    command = "\n".join([
        "set -e",
        f"systemctl restart {shlex.quote(service)}",
        f"systemctl is-active --quiet {shlex.quote(service)}",
        f"systemctl --no-pager --full status {shlex.quote(service)} | sed -n '1,12p'",
    ])
    run_privileged(ssh, command, password, user)
    print(f"[{host_code}] restarted {service}")


def configure_nginx(
    ssh: paramiko.SSHClient,
    remote_root: str,
    password: str,
    user: str,
    host_code: str,
) -> None:
    config = f"""server {{
    listen 80;
    listen [::]:80;
    server_name _;
    root {remote_root};

    location /maomao/ {{
        try_files $uri =404;
        add_header Cache-Control "public, max-age=300";
    }}

    location ~* \\.json$ {{
        try_files $uri =404;
        default_type application/json;
        add_header Cache-Control "no-cache";
    }}

    location ~* \\.pck$ {{
        try_files $uri =404;
        default_type application/octet-stream;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }}

    location ~* \\.zip$ {{
        try_files $uri =404;
        default_type application/zip;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }}
}}
"""
    command = "\n".join([
        "set -e",
        "mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled",
        "rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/maomao-updates",
        "if command -v apt-get >/dev/null 2>&1; then",
        "  DEBIAN_FRONTEND=noninteractive apt-get install -f -y",
        "fi",
        "if ! command -v nginx >/dev/null 2>&1; then",
        "  if command -v apt-get >/dev/null 2>&1; then",
        "    DEBIAN_FRONTEND=noninteractive apt-get update",
        "    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx",
        "  elif command -v yum >/dev/null 2>&1; then",
        "    yum install -y nginx",
        "  elif command -v dnf >/dev/null 2>&1; then",
        "    dnf install -y nginx",
        "  else",
        "    echo 'No supported package manager found for nginx install' >&2",
        "    exit 127",
        "  fi",
        "fi",
        "cat > /etc/nginx/sites-available/maomao-updates <<'NGINX_CONF'",
        config.rstrip(),
        "NGINX_CONF",
        "ln -sf /etc/nginx/sites-available/maomao-updates /etc/nginx/sites-enabled/maomao-updates",
        "nginx -t",
        "systemctl enable --now nginx",
        "systemctl reload nginx",
        "systemctl is-active nginx",
    ])
    run_privileged(ssh, command, password, user)
    print(f"[{host_code}] nginx static distribution configured")


def cleanup_remote_files(
    ssh: paramiko.SSHClient,
    remote_server_pack: str,
    remote_package_dir: str,
    current_package_names: list[str],
    backups_to_keep: int,
    password: str,
    user: str,
    host_code: str,
) -> None:
    keep_array = " ".join(shlex.quote(name) for name in current_package_names)
    command = "\n".join([
        "set -e",
        f"keep_packages='{keep_array}'",
        f"package_dir={shlex.quote(remote_package_dir)}",
        "if [ -d \"$package_dir\" ]; then",
        "  for file in \"$package_dir\"/*.pck; do",
        "    [ -e \"$file\" ] || continue",
        "    name=$(basename \"$file\")",
        "    keep=no",
        "    for expected in $keep_packages; do",
        "      if [ \"$name\" = \"$expected\" ]; then keep=yes; break; fi",
        "    done",
        "    if [ \"$keep\" = no ]; then rm -f \"$file\"; echo \"[remote-cleanup] removed stale package $file\"; fi",
        "  done",
        "fi",
        prune_backups_command(f"{remote_server_pack}.bak-*", backups_to_keep),
        "rm -rf /tmp/maomao-hot-update-* /var/tmp/maomao-hot-update-* 2>/dev/null || true",
        "systemctl daemon-reload 2>/dev/null || true",
        f"ls -lh {shlex.quote(remote_server_pack)} {shlex.quote(remote_server_pack)}.bak-* 2>/dev/null || true",
        f"find {shlex.quote(remote_package_dir)} -maxdepth 1 -type f -name '*.pck' -printf '[remote-stat] %f %s bytes\\n' 2>/dev/null | sort",
    ])
    run_privileged(ssh, command, password, user)
    print(f"[{host_code}] stale PCK cleanup complete")


def service_candidates(ssh: paramiko.SSHClient) -> list[str]:
    command = (
        "systemctl list-units --type=service --all --no-legend --no-pager "
        "| awk '{print $1}' | grep -Ei 'maomao|godot|lobby|room' || true"
    )
    stdin, stdout, stderr = ssh.exec_command(f"sh -lc {shlex.quote(command)}")
    stdin.close()
    out = stdout.read().decode("utf-8", errors="replace")
    stderr.read()
    stdout.channel.recv_exit_status()
    services: list[str] = []
    for line in out.splitlines():
        service = line.strip()
        if service and service.endswith(".service"):
            services.append(service)
    return sorted(set(services))


def remote_preflight(
    ssh: paramiko.SSHClient,
    host_code: str,
    remote_root: str,
    remote_server_pack: str,
    stage_root: str,
) -> None:
    commands = [
        "echo '[preflight] disk'",
        f"df -h / /tmp /var /opt {shlex.quote(stage_root)} {shlex.quote(remote_root)} 2>/dev/null || true",
        "echo '[preflight] existing server pack'",
        f"ls -lh {shlex.quote(remote_server_pack)} 2>/dev/null || true",
        "echo '[preflight] stale stages'",
        "find /tmp /var/tmp -maxdepth 1 -type d -name 'maomao-hot-update-*' -printf '%p %TY-%Tm-%Td %TH:%TM\\n' 2>/dev/null || true",
        "echo '[preflight] nginx/systemd'",
        "systemctl is-active nginx 2>/dev/null || true",
        "echo '[preflight] candidate services'",
        "systemctl list-units --type=service --all --no-legend --no-pager 2>/dev/null | awk '{print $1}' | grep -Ei 'maomao|godot|lobby|room' || true",
    ]
    out, err, code = run_command(ssh, "\n".join(commands))
    print(f"[{host_code}] preflight exit={code}")
    if out.strip():
        print(out.strip())
    if err.strip():
        print(err.strip(), file=sys.stderr)


def run_command(ssh: paramiko.SSHClient, command: str) -> tuple[str, str, int]:
    stdin, stdout, stderr = ssh.exec_command(f"sh -lc {shlex.quote(command)}")
    stdin.close()
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    return out, err, code


def remote_stat_command(paths: list[str]) -> str:
    quoted_paths = " ".join(shlex.quote(path) for path in paths)
    return f"stat -c '[remote-stat] %n %s bytes %y' {quoted_paths}"


def prune_backups_command(backup_glob: str, keep_count: int) -> str:
    keep_count = max(0, keep_count)
    normalized_glob = backup_glob.replace("\\", "/").lstrip("/")
    return (
        "python3 - <<'PY'\n"
        "from pathlib import Path\n"
        f"keep = {keep_count}\n"
        f"items = sorted(Path('/').glob({normalized_glob!r}), key=lambda p: p.stat().st_mtime, reverse=True)\n"
        "for item in items[keep:]:\n"
        "    item.unlink()\n"
        "print('[remote-cleanup] server backups kept=%d removed=%d' % (min(keep, len(items)), max(0, len(items) - keep)))\n"
        "PY"
    )


def run_privileged(ssh: paramiko.SSHClient, command: str, password: str, user: str) -> None:
    if user == "root":
        wrapped = f"sh -lc {shlex.quote(command)}"
        stdin, stdout, stderr = ssh.exec_command(wrapped)
    else:
        wrapped = f"sudo -S -p '' sh -lc {shlex.quote(command)}"
        stdin, stdout, stderr = ssh.exec_command(wrapped)
        stdin.write(password + "\n")
        stdin.flush()
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if out.strip():
        print(scrub_secret(out, password).strip())
    if err.strip():
        print(scrub_secret(err, password).strip(), file=sys.stderr)
    if code != 0:
        raise RuntimeError(f"Remote command failed with exit code {code}: {wrapped}")


def scrub_secret(text: str, secret: str) -> str:
    if not secret:
        return text
    return text.replace(secret, "[redacted]")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, socket.error, paramiko.SSHException, RuntimeError, FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
