# devbox-container

Alpine-basierte Distrobox mit [Determinate Systems Nix](https://determinate.systems/) und
[devbox](https://www.jetify.com/devbox) — die reproduzierbare Entwicklungsumgebung für dieses Repo.

## Warum diese Kombination?

| Problem | Lösung |
|---------|--------|
| `nix-portable` erstellt `/nix/store` als Symlink | `nixos-anywhere` bricht ab → echtes Nix nötig |
| systemd fehlt im Container | Determinate Nix mit `--init none` + manueller nix-daemon-Start |
| devbox braucht Nix | erkennt system Nix automatisch, kein nix-portable mehr nötig |

## Einmalige Einrichtung

```bash
cd devbox-container
bash setup.sh
```

Das Script:
1. Baut das Container-Image mit `podman build`
2. Erstellt die Distrobox via `distrobox assemble`

## Benutzen

```bash
distrobox enter devbox
```

Danach im Container devbox-Shell starten:

```bash
devbox shell   # aus dem Repo-Root
```

Alle Tools aus `devbox.json` (OpenTofu, nixos-anywhere, jq, ...) sind dann verfügbar.

## Bekannte Warnungen

### `warning: unknown setting 'eval-cores'` / `warning: unknown setting 'lazy-trees'`

Tauchen beim `tofu apply` während des nixos-anywhere-Schritts auf. Ursache: devbox installiert
nixos-anywhere mit einer älteren Nix-Version, die die Determinate-spezifischen Settings
`eval-cores` und `lazy-trees` aus der System-`nix.conf` nicht kennt.

**Harmlos** — nixos-anywhere läuft trotzdem korrekt durch.

### `accepted connection from pid ..., user user`

Nix-Daemon-Log, das auf stderr landet. Kein Fehler.

## Struktur

```
devbox-container/
├── Containerfile   # Alpine + Nix (Determinate) + devbox
├── distrobox.ini   # distrobox assemble Konfiguration
├── setup.sh        # Build + Erstell-Script
└── README.md       # diese Datei
```
