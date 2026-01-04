FROM python:3.11-slim

# Install Git for gh-deploy
RUN apt-get update && apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m docsuser
WORKDIR /home/docsuser/docs

# Create and activate virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install mkdocs and plugins with pinned versions
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    mkdocs>=1.5 \
    mkdocs-material==9.6.2 \
    "pymdown-extensions[extra]==10.14.3" \
    mkdocs-awesome-pages-plugin

# Copy docs and configuration
COPY . .
RUN chown -R docsuser:docsuser /home/docsuser

USER docsuser

# Fix SSH permissions for git operations
RUN mkdir -p /home/docsuser/.ssh && chmod 700 /home/docsuser/.ssh

# Expose port for local development
EXPOSE 8000

# Default command: serve docs for local development
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]

# To build static site: docker run --rm -v $(pwd)/site:/home/docsuser/docs/site mkdocs-flockfinder mkdocs build
# To deploy to gh-pages: docker run --rm -v ~/.ssh:/home/docsuser/.ssh:ro mkdocs-flockfinder mkdocs gh-deploy --force