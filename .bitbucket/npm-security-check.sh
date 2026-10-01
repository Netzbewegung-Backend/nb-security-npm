#!/bin/bash
set -euo pipefail

errors=0

echo "nb-security-npm: Version 2026-10-01"

while IFS= read -r -d '' pkg; do
    dir=$(dirname "$pkg")
    echo "---"
    echo "Prüfe: $pkg"

    if ! grep -q '"@lavamoat/preinstall-always-fail"' "$pkg"; then
        echo "❌ ERROR: @lavamoat/preinstall-always-fail fehlt in $pkg"
        errors=1
    else
        echo "✅ @lavamoat/preinstall-always-fail vorhanden"
    fi

    npmrc="$dir/.npmrc"
    if [[ ! -f "$npmrc" ]] || ! grep -qx 'ignore-scripts=true' "$npmrc" 2>/dev/null; then
        echo "❌ ERROR: .npmrc mit ignore-scripts=true fehlt in $dir"
        errors=1
    else
        echo "✅ .npmrc mit ignore-scripts=true vorhanden"
    fi

    yarnrc="$dir/.yarnrc"
    if [[ ! -f "$yarnrc" ]] || ! grep -qxF -- '--ignore-scripts true' "$yarnrc" 2>/dev/null; then
        echo "❌ ERROR: .yarnrc mit --ignore-scripts true fehlt in $dir"
        errors=1
    else
        echo "✅ .yarnrc mit --ignore-scripts true vorhanden"
    fi

    for lockfile in package-lock.json yarn.lock; do
        lockpath="$dir/$lockfile"
        if [[ -f "$lockpath" ]]; then
            # Exakt auf wirklich installiertes node-sass pruefen, nicht nur
            # auf den Substring. Sonst False Positives durch aehnlich
            # benannte Pakete (node-sass-glob-importer etc.) und durch
            # optionale peerDependencies (z.B. sass-loader).
            if [[ "$lockfile" == "package-lock.json" ]]; then
                lockver=$(grep -m1 '"lockfileVersion"' "$lockpath" | grep -o '[0-9]\+')
                if [[ "${lockver:-1}" -ge 2 ]]; then
                    pattern='^ *"node_modules/node-sass":'
                else
                    pattern='^ *"node-sass": \{'
                fi
            else
                pattern='^"?node-sass@'
            fi
            if grep -Eq "$pattern" "$lockpath" 2>/dev/null; then
                echo "❌ ERROR: node-sass in $lockpath gefunden"
                errors=1
            else
                echo "✅ kein node-sass in $lockpath"
            fi
        fi
    done

done < <(find . -name 'package.json' -not -path '*/node_modules/*' -not -path '*/.git/*' -print0)

echo "=== Zusammenfassung ==="
if [[ "$errors" -eq 1 ]]; then
    echo "❌ Fehler gefunden – Pipeline bricht ab."
    exit 1
else
    echo "✅ Alle Sicherheitschecks bestanden."
fi
