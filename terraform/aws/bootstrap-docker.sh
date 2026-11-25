#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/library-bootstrap.log) 2>&1

dnf update -y
dnf install -y docker git

systemctl enable docker
systemctl start docker

# Install Docker Compose plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# App setup
APP_DIR=/opt/library-app
REPO_URL="${repo_url}"
REPO_BRANCH="${repo_branch}"

if [ -d "$APP_DIR/.git" ]; then
  cd "$APP_DIR"
  git fetch --all
  git checkout "$REPO_BRANCH"
  git pull origin "$REPO_BRANCH"
else
  rm -rf "$APP_DIR"
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR"
  cd "$APP_DIR"
fi

cat > "$APP_DIR/.env" <<'ENVFILE'
SECRET_KEY=${secret_key}
ALGORITHM=${algorithm}
DATABASE_URL=postgresql://library_user:library_pass@postgres:5432/library_db
POSTGRES_DB=library_db
POSTGRES_USER=library_user
POSTGRES_PASSWORD=library_pass
ENVFILE

# Build and start services
/usr/local/lib/docker/cli-plugins/docker-compose -f docker-compose.yml up -d --build

# Wait for app health
for i in $(seq 1 30); do
  if curl -fsS http://localhost:8000/health >/dev/null; then
    echo "Library API is healthy"
    exit 0
  fi
  sleep 10
done

echo "Library API did not become healthy in time" >&2
/usr/local/lib/docker/cli-plugins/docker-compose -f docker-compose.yml logs --tail=200 || true
exit 1
