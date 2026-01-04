#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

create_venv() {
    echo "Creating Python virtual environment..."
    python3 -m venv .venv
}

activate_venv() {
    echo "Activating virtual environment..."
    source .venv/bin/activate
}

upgrade_pip() {
    echo "Upgrading pip..."
    pip install --upgrade pip
}

install_dependencies() {
    echo "Installing MkDocs and plugins..."
    pip install \
        mkdocs>=1.5 \
        mkdocs-material==9.6.2 \
        "pymdown-extensions[extra]==10.14.3" \
        mkdocs-awesome-pages-plugin
}

generate_requirements() {
    echo "Generating requirements.txt..."
    pip freeze > requirements.txt
}

print_usage() {
    cat <<EOF

Setup complete!

To start the MkDocs server:
    cd $SCRIPT_DIR
    source .venv/bin/activate
    mkdocs serve

Then open http://127.0.0.1:8000 in your browser

To build static site:
    mkdocs build

To deploy to GitHub Pages:
    mkdocs gh-deploy --force

EOF
}

main() {
    echo "Setting up MkDocs for FlockFinder documentation..."
    cd "$SCRIPT_DIR"
    create_venv
    activate_venv
    upgrade_pip
    install_dependencies
    generate_requirements
    print_usage
}

main "$@"
